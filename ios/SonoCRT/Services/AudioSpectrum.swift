import AVFoundation
import MediaToolbox

/// Reads decoded audio without modifying the samples sent to the speakers.
final class AudioSpectrum: @unchecked Sendable {
    private let lock = NSLock()
    private var levels = [Float](repeating: 0, count: 32)
    private var updated: TimeInterval = 0
    private var displayed = [Float](repeating: 0, count: 32)
    private var lastFrame: TimeInterval = 0

    func snapshot() -> [Float] {
        lock.lock(); defer { lock.unlock() }
        let now = ProcessInfo.processInfo.systemUptime
        let dt = lastFrame == 0 ? 1.0 / 60 : min(0.05, max(0, now - lastFrame))
        lastFrame = now
        let fresh = now - updated < 0.3
        for index in displayed.indices {
            let target = fresh ? levels[index] : 0
            // Time-based interpolation keeps motion smooth between audio buffers.
            let response = target > displayed[index] ? 0.005 : 0.028
            let blend = Float(1 - exp(-dt / response))
            displayed[index] += (target - displayed[index]) * blend
        }
        return displayed
    }

    fileprivate func publish(_ values: [Float]) {
        lock.lock()
        levels = values
        updated = ProcessInfo.processInfo.systemUptime
        lock.unlock()
    }

    func attach(to item: AVPlayerItem) async {
        guard let track = try? await item.asset.loadTracks(withMediaType: .audio).first,
              !Task.isCancelled else { return }
        let state = SpectrumTapState(output: self)
        let retained = Unmanaged.passRetained(state)
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: retained.toOpaque(),
            init: { _, clientInfo, storage in storage.pointee = clientInfo },
            finalize: { tap in
                Unmanaged<SpectrumTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
            },
            prepare: { tap, _, format in
                let state = Unmanaged<SpectrumTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                state.prepare(format.pointee)
            },
            unprepare: { _ in },
            process: { tap, frames, _, buffers, framesOut, flagsOut in
                let status = MTAudioProcessingTapGetSourceAudio(tap, frames, buffers, flagsOut, nil, framesOut)
                guard status == noErr else { return }
                let state = Unmanaged<SpectrumTapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                state.consume(buffers, frames: Int(framesOut.pointee))
            })
        var tap: MTAudioProcessingTap?
        guard MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap) == noErr,
              let tap else { retained.release(); return }
        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        item.audioMix = mix
    }
}

private final class SpectrumTapState {
    let output: AudioSpectrum
    var format = AudioStreamBasicDescription()
    var samples = [Float](repeating: 0, count: 2048)
    var window = [Float](repeating: 0, count: 2048)
    var coefficients = [Float](repeating: 0, count: 32)
    var smoothed = [Float](repeating: 0, count: 32)
    var index = 0
    init(output: AudioSpectrum) { self.output = output }

    func prepare(_ format: AudioStreamBasicDescription) {
        self.format = format
        index = 0
        for n in window.indices { window[n] = 0.5 - 0.5 * cos(2 * .pi * Float(n) / Float(window.count - 1)) }
        for n in coefficients.indices {
            let frequency = 45 * pow(16000.0 / 45, Double(n) / 31)
            coefficients[n] = Float(2 * cos(2 * .pi * min(frequency, format.mSampleRate * 0.45) / format.mSampleRate))
        }
    }

    func consume(_ list: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        guard format.mFormatID == kAudioFormatLinearPCM,
              [16, 32, 64].contains(format.mBitsPerChannel) else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        guard let first = buffers.first, let data = first.mData else { return }
        let stride = max(1, Int(first.mNumberChannels))
        let bytes = Int(format.mBitsPerChannel / 8)
        let count = min(frames, Int(first.mDataByteSize) / bytes / stride)
        let floating = format.mFormatFlags & kAudioFormatFlagIsFloat != 0
        for frame in 0..<count {
            // First channel avoids cancellation between phase-inverted stereo channels.
            let offset = frame * stride
            let sample: Float
            if floating && bytes == 4 { sample = data.assumingMemoryBound(to: Float.self)[offset] }
            else if floating && bytes == 8 { sample = Float(data.assumingMemoryBound(to: Double.self)[offset]) }
            else if bytes == 2 { sample = Float(data.assumingMemoryBound(to: Int16.self)[offset]) / 32768 }
            else if bytes == 4 { sample = Float(data.assumingMemoryBound(to: Int32.self)[offset]) / 2147483648 }
            else { continue }
            samples[index] = sample * window[index]
            index += 1
            if index == samples.count { analyze(); index = 0 }
        }
    }

    private func analyze() {
        for band in coefficients.indices {
            var previous: Float = 0
            var beforePrevious: Float = 0
            let coefficient = coefficients[band]
            for sample in samples {
                let value = sample + coefficient * previous - beforePrevious
                beforePrevious = previous
                previous = value
            }
            let power = max(0, previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious)
            let amplitude = sqrt(power) / Float(samples.count) * 4
            let decibels = 20 * log10(max(amplitude, 0.000001))
            let normalized = min(1, max(0, (decibels + 48) / 48))
            let target = min(1, pow(normalized, 1.7) * 1.45)
            smoothed[band] += (target - smoothed[band]) * (target > smoothed[band] ? 1.0 : 0.9)
        }
        output.publish(smoothed)
    }
}
