package com.musifly.android.data

import org.json.JSONObject

data class Track(val id: String, val title: String, val artist: String = "Artista desconocido", val album: String = "Sin álbum", val albumArtist: String = artist, val genre: String = "", val number: Int = 0, val duration: Long = 0, val artwork: String? = null, val version: String = "") {
    val albumId get() = "$albumArtist::$album"
    fun json() = JSONObject().put("id", id).put("title", title).put("artist", artist).put("album", album).put("albumArtist", albumArtist).put("genre", genre).put("number", number).put("duration", duration).put("artwork", artwork ?: "").put("version", version)
    companion object { fun from(j: JSONObject) = Track(j.getString("id"),j.getString("title"),j.optString("artist"),j.optString("album"),j.optString("albumArtist"),j.optString("genre"),j.optInt("number"),j.optLong("duration"),j.optString("artwork").takeIf { it.isNotBlank() },j.optString("version")) }
}
data class Playlist(val id: String, val name: String, val tracks: List<String>)
data class Connection(val endpoint: String, val token: String)
fun time(ms: Long): String { val s = ms.coerceAtLeast(0) / 1000; return "%d:%02d".format(s / 60, s % 60) }
