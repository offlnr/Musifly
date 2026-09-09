package com.musifly.android.playback

import android.app.Application
import android.content.ComponentName
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.core.content.ContextCompat
import com.musifly.android.MusiflyApp
import com.musifly.android.data.Track
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import java.io.File

class PlaybackModel(app:Application):AndroidViewModel(app){
    val library=(app as MusiflyApp).library
    var controller:MediaController?=null;private set
    val current=MutableStateFlow<Track?>(null)
    val playing=MutableStateFlow(false)
    val buffering=MutableStateFlow(false)
    val position=MutableStateFlow(0L)
    val duration=MutableStateFlow(0L)
    val loop=MutableStateFlow(false)
    val shuffle=MutableStateFlow(false)
    val output=MutableStateFlow("TELÉFONO")
    private val audio=app.getSystemService(AudioManager::class.java)
    private val deviceCallback=object:AudioDeviceCallback(){override fun onAudioDevicesAdded(devices:Array<out AudioDeviceInfo>){updateOutput()};override fun onAudioDevicesRemoved(devices:Array<out AudioDeviceInfo>){updateOutput()}}
    private val listener=object:Player.Listener {
        override fun onEvents(player:Player,events:Player.Events){sync()}
        override fun onPlayerError(error:PlaybackException){library.error.value="No se pudo reproducir. Comprueba la conexión y vuelve a pulsar PLAY."}
    }
    private val future=MediaController.Builder(app,SessionToken(app,ComponentName(app,MusicService::class.java))).buildAsync()
    init {
        future.addListener({controller=future.get();controller?.addListener(listener);sync()},ContextCompat.getMainExecutor(app))
        audio.registerAudioDeviceCallback(deviceCallback,Handler(Looper.getMainLooper()));updateOutput()
        viewModelScope.launch { while(isActive){sync();delay(200)} }
        viewModelScope.launch { library.tracks.collect { list->
            val p=controller
            val id=p?.currentMediaItem?.mediaId
            current.value=list.firstOrNull{it.id==id} ?: current.value
            if(p!=null) for(i in 0 until p.mediaItemCount){
                val old=p.getMediaItemAt(i);val track=list.firstOrNull{it.id==old.mediaId} ?: continue
                val metadata=media(track).mediaMetadata
                if(old.mediaMetadata!=metadata)p.replaceMediaItem(i,old.buildUpon().setMediaMetadata(metadata).build())
            }
        } }
    }
    private fun sync(){val p=controller ?: return;val item=p.currentMediaItem;current.value=library.tracks.value.firstOrNull{it.id==item?.mediaId} ?: current.value?.takeIf{it.id==item?.mediaId};playing.value=p.playWhenReady && p.playbackState!=Player.STATE_ENDED;buffering.value=p.playbackState==Player.STATE_BUFFERING;position.value=p.currentPosition.coerceAtLeast(0);duration.value=p.duration.takeIf{it>0} ?: current.value?.duration ?: 0;loop.value=p.repeatMode==Player.REPEAT_MODE_ONE;shuffle.value=p.shuffleModeEnabled}
    private fun media(track:Track):MediaItem = MediaItem.Builder().setMediaId(track.id).setUri(Uri.Builder().scheme("musifly").authority("track").appendQueryParameter("key",track.id).build()).setMediaMetadata(MediaMetadata.Builder().setTitle(track.title).setArtist(track.artist).setAlbumTitle(track.album).setArtworkUri(track.artwork?.let{Uri.fromFile(File(it))}).build()).build()
    fun play(track:Track){val p=controller ?: return;val queue=library.tracks.value;val index=queue.indexOfFirst{it.id==track.id};if(index<0)return;p.setMediaItems(queue.map(::media),index,0);p.prepare();p.play();sync()}
    fun toggle(){val p=controller ?: return;if(p.playWhenReady)p.pause() else {if(p.playerError!=null || p.playbackState==Player.STATE_IDLE)p.prepare();p.play()};sync()}
    fun next(){val p=controller ?: return;if(p.hasNextMediaItem())p.seekToNextMediaItem() else if(p.mediaItemCount>0)p.seekToDefaultPosition(0);sync()}
    fun previous(){val p=controller ?: return;if(p.currentPosition>3000)p.seekTo(0) else if(p.hasPreviousMediaItem())p.seekToPreviousMediaItem() else if(p.mediaItemCount>0)p.seekToDefaultPosition(p.mediaItemCount-1);sync()}
    fun seek(value:Float){controller?.seekTo((value.coerceIn(0f,1f)*duration.value).toLong());sync()}
    fun toggleLoop(){controller?.repeatMode=if(loop.value)Player.REPEAT_MODE_ALL else Player.REPEAT_MODE_ONE;sync()}
    fun toggleShuffle(){controller?.shuffleModeEnabled=!shuffle.value;sync()}
    fun disconnect(){controller?.stop();controller?.clearMediaItems();current.value=null;library.disconnect()}
    private fun updateOutput(){val devices=audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS);val external=devices.firstOrNull{it.type in listOf(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,AudioDeviceInfo.TYPE_BLE_HEADSET,AudioDeviceInfo.TYPE_WIRED_HEADPHONES,AudioDeviceInfo.TYPE_WIRED_HEADSET,AudioDeviceInfo.TYPE_USB_HEADSET)};output.value=external?.productName?.toString()?.uppercase() ?: "TELÉFONO"}
    override fun onCleared(){audio.unregisterAudioDeviceCallback(deviceCallback);controller?.removeListener(listener);MediaController.releaseFuture(future);super.onCleared()}
}
