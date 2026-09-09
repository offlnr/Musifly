package com.musifly.android.playback

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.musifly.android.MainActivity
import com.musifly.android.MusiflyApp
import com.musifly.android.data.R2Api
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

class MusicService:MediaSessionService(){
    private var session:MediaSession?=null
    override fun onCreate(){super.onCreate()
        val library=(application as MusiflyApp).library
        val urls=ConcurrentHashMap<String,Pair<Long,String>>()
        val http=DefaultHttpDataSource.Factory().setUserAgent("Musifly/1.0").setConnectTimeoutMs(30000).setReadTimeoutMs(30000)
        val factory=ResolvingDataSource.Factory(DefaultDataSource.Factory(this,http)){spec ->
            if(spec.uri.scheme!="musifly") spec else {
                val connection=library.credentials.load() ?: throw IOException("Conecta tu biblioteca R2")
                val key=spec.uri.getQueryParameter("key") ?: throw IOException("Canción no válida")
                val cacheKey=connection.endpoint+connection.token.hashCode()+key
                val cached=urls[cacheKey];val now=System.currentTimeMillis()
                val url=if(cached!=null && now-cached.first<4*3600000)cached.second else R2Api(connection).playbackUrl(key).also{urls[cacheKey]=now to it}
                spec.withUri(Uri.parse(url))
            }
        }
        val renderers=object:DefaultRenderersFactory(this){
            override fun buildAudioSink(context:android.content.Context,enableFloatOutput:Boolean,enableAudioTrackPlaybackParams:Boolean):AudioSink = DefaultAudioSink.Builder(context).setAudioProcessors(arrayOf(SpectrumProcessor())).build()
        }
        val player=ExoPlayer.Builder(this,renderers).setMediaSourceFactory(DefaultMediaSourceFactory(factory)).build()
        player.setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(),true)
        player.repeatMode=Player.REPEAT_MODE_ALL
        player.setHandleAudioBecomingNoisy(true);player.setWakeMode(C.WAKE_MODE_LOCAL)
        val activity=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        session=MediaSession.Builder(this,player).setSessionActivity(activity).build()
    }
    override fun onGetSession(controllerInfo:MediaSession.ControllerInfo)=session
    override fun onDestroy(){session?.run{player.release();release()};session=null;super.onDestroy()}
}
