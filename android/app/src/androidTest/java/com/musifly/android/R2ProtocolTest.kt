package com.musifly.android
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.musifly.android.data.Connection
import com.musifly.android.data.R2Api
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.tls.HandshakeCertificates
import okhttp3.tls.HeldCertificate
import org.json.JSONObject
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class R2ProtocolTest {
    @Test fun flacTagsDurationAndCache(){
        val certificate=HeldCertificate.Builder().addSubjectAlternativeName("localhost").build()
        val serverTls=HandshakeCertificates.Builder().heldCertificate(certificate).build()
        val clientTls=HandshakeCertificates.Builder().addTrustedCertificate(certificate.certificate).build()
        val server=MockWebServer();server.useHttps(serverTls.sslSocketFactory(),false);server.start()
        val directory=java.io.File(androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"metadata-test").apply{mkdirs()}
        try {
            val stream=ByteArray(34)
            val packed=(48000L shl 44) or (23L shl 36) or 480000L
            for(i in 0..7)stream[10+i]=(packed ushr (56-i*8)).toByte()
            val tags=listOf("TITLE=Kool-Aid","ARTIST=Bring Me the Horizon","ALBUM=POST HUMAN","TRACKNUMBER=1/16")
            val comments=java.io.ByteArrayOutputStream()
            fun little(n:Int){comments.write(java.nio.ByteBuffer.allocate(4).order(java.nio.ByteOrder.LITTLE_ENDIAN).putInt(n).array())}
            little(0);little(tags.size);tags.forEach{val b=it.toByteArray();little(b.size);comments.write(b)}
            val data=java.io.ByteArrayOutputStream();data.write("fLaC".toByteArray())
            fun block(type:Int,bytes:ByteArray){data.write(byteArrayOf(type.toByte(),(bytes.size ushr 16).toByte(),(bytes.size ushr 8).toByte(),bytes.size.toByte()));data.write(bytes)}
            block(0,stream);block(132,comments.toByteArray());val flac=data.toByteArray()
            server.dispatcher=object:okhttp3.mockwebserver.Dispatcher(){override fun dispatch(request:okhttp3.mockwebserver.RecordedRequest):MockResponse {
                if(request.requestUrl!!.encodedPath=="/play")return MockResponse().setBody(JSONObject().put("url",server.url("/media").toString()).toString())
                val range=request.getHeader("Range")!!.removePrefix("bytes=").split('-');val start=range[0].toInt();val end=minOf(range[1].toInt(),flac.lastIndex)
                return MockResponse().setResponseCode(206).setBody(okio.Buffer().write(flac.copyOfRange(start,end+1)))
            }}
            val client=OkHttpClient.Builder().sslSocketFactory(clientTls.sslSocketFactory(),clientTls.trustManager).build()
            val api=R2Api(Connection(server.url("/").toString().trimEnd('/'),"test"),client)
            val reader=com.musifly.android.data.MetadataReader(directory)
            val track=com.musifly.android.data.Track("test.flac","test",version="v1")
            val result=reader.read(track,api)
            assertEquals("Kool-Aid",result.title);assertEquals("Bring Me the Horizon",result.artist);assertEquals("POST HUMAN",result.album);assertEquals(10000L,result.duration);assertEquals(1,result.number)
            val requests=server.requestCount;assertEquals(result,reader.read(track,api));assertEquals(requests,server.requestCount)
        } finally {server.shutdown();directory.deleteRecursively()}
    }
    @Test fun privateCatalogPaginationAndSpecialCharacters(){
        val certificate=HeldCertificate.Builder().addSubjectAlternativeName("localhost").build()
        val serverTls=HandshakeCertificates.Builder().heldCertificate(certificate).build()
        val clientTls=HandshakeCertificates.Builder().addTrustedCertificate(certificate.certificate).build()
        val server=MockWebServer();server.useHttps(serverTls.sslSocketFactory(),false);server.start()
        try {
            val client=OkHttpClient.Builder().sslSocketFactory(clientTls.sslSocketFactory(),clientTls.trustManager).followRedirects(false).build()
            val api=R2Api(Connection(server.url("/").toString().trimEnd('/'),"test-library-token"),client)
            server.enqueue(MockResponse().setBody("""{"objects":[{"key":"n+A #1.flac","version":"v1"}],"cursor":"next+page"}"""))
            server.enqueue(MockResponse().setBody("""{"objects":[{"key":"second.flac","version":"v2"}],"cursor":null}"""))
            val tracks=api.catalog();assertEquals(2,tracks.size)
            val first=server.takeRequest();assertEquals("Bearer test-library-token",first.getHeader("Authorization"));assertEquals("/catalog",first.path)
            assertEquals("next+page",server.takeRequest().requestUrl!!.queryParameter("cursor"))
            val signed=server.url("/media?signature=test").toString();server.enqueue(MockResponse().setBody(JSONObject().put("url",signed).toString()))
            assertEquals(signed,api.playbackUrl("n+A #1.flac"));assertEquals("n+A #1.flac",server.takeRequest().requestUrl!!.queryParameter("key"))
            server.enqueue(MockResponse().setBody("""{"url":"https://other.example/media"}"""))
            assertTrue(runCatching{api.playbackUrl("second.flac")}.isFailure)
            server.enqueue(MockResponse().setResponseCode(401))
            assertTrue(runCatching{api.catalog()}.exceptionOrNull()?.message?.contains("clave")==true)
        } finally {server.shutdown()}
    }
}
