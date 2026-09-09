package com.musifly.android.data

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

class MetadataReader(private val directory: File) {
    fun read(track: Track, api: R2Api): Track {
        directory.mkdirs()
        val hash = MessageDigest.getInstance("SHA-256").digest((api.connection.endpoint + track.id + track.version).toByteArray()).joinToString("") { "%02x".format(it) }
        val cache = File(directory,"$hash.json")
        if(track.version.isNotEmpty() && cache.exists()) return Track.from(org.json.JSONObject(cache.readText()))
        val url = api.playbackUrl(track.id)
        var result = if(track.id.endsWith(".flac",true)) flac(track,api,url,hash) else generic(track,url,hash)
        cache.writeText(result.json().toString()); return result
    }
    private fun artwork(bytes: ByteArray, hash: String): String? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds=true }
        BitmapFactory.decodeByteArray(bytes,0,bytes.size,options)
        options.inSampleSize = maxOf(1, maxOf(options.outWidth,options.outHeight)/1024)
        options.inJustDecodeBounds=false
        val bitmap = BitmapFactory.decodeByteArray(bytes,0,bytes.size,options) ?: return null
        val ratio = minOf(1f, 768f / maxOf(bitmap.width, bitmap.height))
        val scaled = Bitmap.createScaledBitmap(bitmap,maxOf(1,(bitmap.width*ratio).toInt()),maxOf(1,(bitmap.height*ratio).toInt()),true)
        val file = File(directory,"$hash.jpg"); file.outputStream().use { scaled.compress(Bitmap.CompressFormat.JPEG,85,it) }
        if(scaled !== bitmap) scaled.recycle(); bitmap.recycle(); return file.absolutePath
    }
    private fun generic(track: Track, url: String, hash: String): Track {
        val reader = MediaMetadataRetriever()
        try {
            reader.setDataSource(url, emptyMap())
            fun meta(key: Int) = reader.extractMetadata(key)?.takeIf { it.isNotBlank() }
            return track.copy(title=meta(7) ?: track.title,artist=meta(2) ?: track.artist,album=meta(1) ?: track.album,albumArtist=meta(13) ?: meta(2) ?: track.artist,genre=meta(6) ?: "",number=meta(0)?.substringBefore('/')?.toIntOrNull() ?: 0,duration=meta(9)?.toLongOrNull() ?: 0,artwork=reader.embeddedPicture?.let { artwork(it,hash) })
        } finally { reader.release() }
    }
    private fun flac(track: Track, api: R2Api, url: String, hash: String): Track {
        require(String(api.range(url,0,3)) == "fLaC")
        var offset = 4; var last = false; var duration = 0L; var art: String? = null
        val tags = mutableMapOf<String,String>()
        repeat(128) {
            if(last) return@repeat
            val header = api.range(url,offset,offset+3); require(header.size==4)
            last = header[0].toInt() and 128 != 0
            val type = header[0].toInt() and 127
            val size = ((header[1].toInt() and 255) shl 16) or ((header[2].toInt() and 255) shl 8) or (header[3].toInt() and 255)
            require(offset + size < 32*1024*1024)
            if(type in listOf(0,4,6) && size > 0) {
                val bytes = api.range(url,offset+4,offset+3+size); require(bytes.size==size)
                if(type==0 && size>=18) {
                    var value = 0L; for(i in 10..17) value = (value shl 8) or (bytes[i].toLong() and 255)
                    val rate = value ushr 44; if(rate>0) duration = (value and 0xFFFFFFFFFL)*1000/rate
                }
                if(type==4) {
                    val b = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                    fun string(): String { val n=b.int; require(n>=0 && n<=b.remaining()); val data=ByteArray(n); b.get(data); return String(data,Charsets.UTF_8) }
                    string(); val count=b.int; require(count in 0..10000)
                    repeat(count) { val comment=string(); val key=comment.substringBefore('=').uppercase(); tags.putIfAbsent(key,comment.substringAfter('=',"")) }
                }
                if(type==6) {
                    val b=ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN); val pictureType=b.int
                    fun skipString() { val n=b.int; require(n>=0 && n<=b.remaining()); b.position(b.position()+n) }
                    skipString();skipString();b.position(b.position()+16);val n=b.int;require(n>=0 && n<=b.remaining());val picture=ByteArray(n);b.get(picture)
                    if(art==null || pictureType==3) art=artwork(picture,hash)
                }
            }
            offset+=size+4
        }
        require(last)
        return track.copy(title=tags["TITLE"] ?: track.title,artist=tags["ARTIST"] ?: track.artist,album=tags["ALBUM"] ?: track.album,albumArtist=tags["ALBUMARTIST"] ?: tags["ALBUM ARTIST"] ?: tags["ARTIST"] ?: track.artist,genre=tags["GENRE"] ?: "",number=tags["TRACKNUMBER"]?.substringBefore('/')?.toIntOrNull() ?: 0,duration=duration,artwork=art)
    }
}
