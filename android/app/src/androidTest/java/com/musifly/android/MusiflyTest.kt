package com.musifly.android

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.musifly.android.data.*
import com.musifly.android.playback.*
import org.junit.*
import org.junit.runner.RunWith
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.TimeUnit
import kotlin.math.*

@RunWith(AndroidJUnit4::class)
class MusiflyTest {
    @get:Rule val compose=createAndroidComposeRule<MainActivity>()
    private val app get()=compose.activity.application as MusiflyApp
    @Test fun playlistsNavigationAndSecureStorage(){
        val long="Una canción con un nombre extremadamente largo que debe deslizarse sin mover los controles"
        val track=Track("test.flac",long,"Artista de prueba","Álbum de prueba",duration=30000)
        compose.runOnIdle{app.library.tracks.value=listOf(track);app.library.createPlaylist("Prueba")}
        compose.onNodeWithText("Álbum de prueba").performClick()
        compose.onNodeWithText(long).assertExists()
        compose.onNodeWithText("BUSCAR",useUnmergedTree=true).performClick()
        compose.onNodeWithText("grep · pista, artista o álbum").assertExists()
        compose.onNodeWithText(long).performTouchInput{longClick()}
        compose.onNodeWithText("Agregar a playlist").performClick()
        compose.onNodeWithText("Prueba +").performClick()
        compose.onNodeWithText("PLAYLISTS",useUnmergedTree=true).performClick()
        compose.onNodeWithText("Prueba").performClick()
        compose.onNodeWithText(long).assertExists()
        compose.onNodeWithText("PLAYLISTS",useUnmergedTree=true).performClick()
        compose.onNodeWithText("+ NUEVA").assertExists()
        val restored=LibraryRepository(compose.activity)
        Assert.assertTrue(restored.playlists.value.any{track.id in it.tracks})
        val secure=SecureConnection(compose.activity);secure.save(Connection("https://example.com","test-secret"));Assert.assertEquals("test-secret",secure.load()?.token)
        Assert.assertFalse(compose.activity.getSharedPreferences("connection",Context.MODE_PRIVATE).all.toString().contains("test-secret"));secure.clear()
        screenshot("playlists.png")
    }
    @Test fun backgroundPlaybackSpectrumAndSeeking(){
        val file=File(compose.activity.filesDir,"test.wav");val sampleRate=44100;val count=sampleRate*30
        val buffer=ByteBuffer.allocate(44+count*2).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray()).putInt(36+count*2).put("WAVEfmt ".toByteArray()).putInt(16).putShort(1).putShort(1).putInt(sampleRate).putInt(sampleRate*2).putShort(2).putShort(16).put("data".toByteArray()).putInt(count*2)
        repeat(count){buffer.putShort((sin(2*PI*440*it/sampleRate)*20000).toInt().toShort())};file.writeBytes(buffer.array())
        val future=MediaController.Builder(compose.activity,SessionToken(compose.activity,android.content.ComponentName(compose.activity,MusicService::class.java))).buildAsync()
        val controller=future.get(10,TimeUnit.SECONDS)
        compose.runOnIdle{app.library.tracks.value=listOf(Track("test.wav","Canción de prueba","Artista","Álbum",duration=30000));controller.setMediaItem(MediaItem.Builder().setMediaId("test.wav").setUri(Uri.fromFile(file)).setMediaMetadata(MediaMetadata.Builder().setTitle("Canción de prueba").build()).build());controller.prepare();controller.play()}
        compose.waitUntil(15000){SpectrumLevels.values.any{it>.1f}}
        compose.mainClock.autoAdvance=false
        compose.onAllNodesWithText("Canción de prueba").onFirst().performClick()
        compose.mainClock.advanceTimeBy(100)
        compose.onNodeWithContentDescription("Pausar").assertExists()
        screenshot("player.png")
        compose.runOnIdle{controller.seekTo(10000)}
        Thread.sleep(500)
        compose.runOnIdle{Assert.assertTrue(controller.currentPosition>=10000)}
        compose.activity.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        Thread.sleep(1500)
        compose.runOnIdle{Assert.assertTrue(controller.isPlaying);Assert.assertTrue(controller.currentPosition>11000);controller.pause()}
        compose.runOnIdle{MediaController.releaseFuture(future)}
    }
    private fun screenshot(name:String){val bitmap=InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot();File(compose.activity.getExternalFilesDir(null),name).outputStream().use{bitmap.compress(Bitmap.CompressFormat.PNG,100,it)}}
}
