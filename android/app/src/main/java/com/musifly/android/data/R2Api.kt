package com.musifly.android.data

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.HttpUrl.Companion.toHttpUrl
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

class R2Api(val connection: Connection, private val client: OkHttpClient = OkHttpClient.Builder().followRedirects(false).callTimeout(30, TimeUnit.SECONDS).build()) {
    private val base = connection.endpoint.toHttpUrl().also { require(it.isHttps && it.username.isEmpty() && it.password.isEmpty() && it.query == null && it.fragment == null) { "Introduce una URL HTTPS válida." } }
    private fun request(path: String, query: Pair<String,String>? = null): JSONObject {
        val url = base.newBuilder().addPathSegment(path).apply { query?.let { addQueryParameter(it.first,it.second) } }.build()
        client.newCall(Request.Builder().url(url).header("Authorization", "Bearer ${connection.token}").build()).execute().use {
            if (it.code == 401 || it.code == 403) throw IOException("La clave de la biblioteca no es válida.")
            if (!it.isSuccessful) throw IOException("No se pudo acceder a R2 (${it.code}).")
            return JSONObject(it.body?.string() ?: throw IOException("Respuesta vacía"))
        }
    }
    fun catalog(): List<Track> {
        val tracks = linkedMapOf<String,Track>(); val seen = mutableSetOf<String>(); var cursor: String? = null
        do {
            val page = request("catalog",cursor?.let { "cursor" to it }); val objects = page.getJSONArray("objects")
            for (i in 0 until objects.length()) { val obj = objects.getJSONObject(i); val key = obj.getString("key"); tracks[key] = Track(key,key.substringAfterLast('/').substringBeforeLast('.'),version=obj.optString("version")) }
            cursor = page.optString("cursor").takeUnless { it.isBlank() || it == "null" }
            check(cursor == null || seen.add(cursor)) { "Catálogo no válido" }
        } while(cursor != null)
        return tracks.values.sortedBy { it.id }
    }
    fun playbackUrl(key: String): String {
        val url = request("play","key" to key).getString("url").toHttpUrl()
        check(url.isHttps && url.host == base.host && url.port == base.port) { "URL de reproducción no válida" }
        return url.toString()
    }
    fun range(url: String, start: Int, end: Int): ByteArray {
        client.newCall(Request.Builder().url(url).header("Range","bytes=$start-$end").build()).execute().use {
            if (it.code != 206) throw IOException("No se pudo leer la metadata")
            val stream = it.body?.byteStream() ?: throw IOException("Respuesta vacía")
            val expected = end - start + 1
            return stream.readBytesLimited(expected)
        }
    }
}
private fun java.io.InputStream.readBytesLimited(limit: Int): ByteArray {
    val out = java.io.ByteArrayOutputStream(); val buffer = ByteArray(8192)
    while(out.size() < limit) { val read = read(buffer,0,minOf(buffer.size,limit-out.size())); if(read < 0) break; out.write(buffer,0,read) }
    return out.toByteArray()
}
