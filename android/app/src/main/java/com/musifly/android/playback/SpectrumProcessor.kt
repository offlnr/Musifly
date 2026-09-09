package com.musifly.android.playback

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.BaseAudioProcessor
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*

object SpectrumLevels {
    @Volatile var values=FloatArray(32)
    @Volatile var updated=0L
}
class SpectrumProcessor: BaseAudioProcessor() {
    private val samples=FloatArray(2048)
    private val window=FloatArray(2048){(0.5-0.5*cos(2*PI*it/2047)).toFloat()}
    private val coefficients=FloatArray(32)
    private var index=0
    override fun onConfigure(input:AudioProcessor.AudioFormat):AudioProcessor.AudioFormat {
        if(input.encoding!=C.ENCODING_PCM_16BIT) throw AudioProcessor.UnhandledAudioFormatException(input)
        for(n in coefficients.indices){val frequency=45*(16000.0/45).pow(n/31.0);coefficients[n]=(2*cos(2*PI*min(frequency,input.sampleRate*0.45)/input.sampleRate)).toFloat()}
        index=0;return input
    }
    override fun queueInput(input:ByteBuffer) {
        if(!input.hasRemaining()) return
        val output=replaceOutputBuffer(input.remaining());val read=input.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        val stride=inputAudioFormat.channelCount*2
        while(read.remaining()>=stride){val sample=read.short/32768f;read.position(read.position()+stride-2);samples[index]=sample*window[index];index++;if(index==samples.size){analyze();index=0}}
        output.put(input);output.flip()
    }
    private fun analyze(){val result=FloatArray(32);for(band in coefficients.indices){var a=0f;var b=0f;val c=coefficients[band];for(s in samples){val next=s+c*a-b;b=a;a=next};val amplitude=sqrt(max(0f,a*a+b*b-c*a*b))/2048*4;val db=20*log10(max(amplitude,0.000001f));val normalized=((db+48)/48).coerceIn(0f,1f);result[band]=(normalized.pow(1.7f)*1.45f).coerceAtMost(1f)};SpectrumLevels.values=result;SpectrumLevels.updated=android.os.SystemClock.elapsedRealtime()}
    override fun onFlush(){index=0;SpectrumLevels.values=FloatArray(32)}
}
