package com.musifly.android.data

import android.content.Context
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

class LibraryRepository(context: Context) {
    private val prefs=context.getSharedPreferences("library",Context.MODE_PRIVATE)
    val credentials=SecureConnection(context)
    val connection=MutableStateFlow(credentials.load())
    val tracks=MutableStateFlow<List<Track>>(emptyList())
    val playlists=MutableStateFlow<List<Playlist>>(loadPlaylists())
    val loading=MutableStateFlow(false)
    val metadataLoading=MutableStateFlow(false)
    val error=MutableStateFlow<String?>(null)
    val scanlines=MutableStateFlow(prefs.getBoolean("scanlines",true))
    val quality=MutableStateFlow(prefs.getString("quality","LOSSLESS")!!)
    val equalizer=MutableStateFlow(prefs.getString("equalizer","PLANO")!!)
    val offline=MutableStateFlow(prefs.getBoolean("offline",true))
    val mobile=MutableStateFlow(prefs.getBoolean("mobile",false))
    private val reader=MetadataReader(File(context.filesDir,"metadata"))
    private val scope=CoroutineScope(SupervisorJob()+Dispatchers.Main.immediate)
    private var job: Job?=null
    init { if(connection.value!=null) refresh() }
    fun setting(name:String,value:String) { prefs.edit().putString(name,value).apply(); if(name=="quality")quality.value=value else equalizer.value=value }
    fun toggle(name:String) { val flow=when(name){"scanlines"->scanlines;"offline"->offline;else->mobile};flow.value=!flow.value;prefs.edit().putBoolean(name,flow.value).apply() }
    fun connect(endpoint:String,token:String) { if(token.isBlank()){error.value="Introduce la clave de la biblioteca.";return};load(Connection(endpoint.trim().trimEnd('/'),token.trim()),true) }
    fun refresh() { connection.value?.let { load(it,false) } }
    private fun load(candidate:Connection,save:Boolean) {
        job?.cancel();job=scope.launch {
            loading.value=true;metadataLoading.value=false;error.value=null
            try {
                val api=R2Api(candidate)
                val list=withContext(Dispatchers.IO){api.catalog()}
                if(save) withContext(Dispatchers.IO){credentials.save(candidate)}
                connection.value=candidate
                val old=tracks.value.associateBy { it.id }
                tracks.value=list.map { old[it.id]?.takeIf { t->t.version==it.version } ?: it }
                loading.value=false;metadataLoading.value=true
                for(track in tracks.value.toList()) {
                    ensureActive()
                    val updated=withContext(Dispatchers.IO){runCatching{reader.read(track,api)}.getOrDefault(track)}
                    tracks.value=tracks.value.map { if(it.id==updated.id)updated else it }
                }
            } catch(e:CancellationException){throw e} catch(e:Exception){error.value=e.message ?: "No se pudo cargar la biblioteca."}
            finally { loading.value=false;metadataLoading.value=false }
        }
    }
    fun disconnect(){job?.cancel();credentials.clear();connection.value=null;tracks.value=emptyList()}
    fun createPlaylist(name:String,track:String?=null):Boolean {
        val clean=name.trim();if(clean.isEmpty())return false
        playlists.value=playlists.value+Playlist(UUID.randomUUID().toString(),clean,listOfNotNull(track));savePlaylists();return true
    }
    fun addToPlaylist(id:String,track:String){playlists.value=playlists.value.map{if(it.id==id)it.copy(tracks=(it.tracks+track).distinct())else it};savePlaylists()}
    private fun loadPlaylists():List<Playlist> = runCatching {
        val a=JSONArray(prefs.getString("playlists","[]"));(0 until a.length()).map { val j=a.getJSONObject(it);val ids=j.getJSONArray("tracks");Playlist(j.getString("id"),j.getString("name"),(0 until ids.length()).map{ids.getString(it)}) }
    }.getOrDefault(emptyList())
    private fun savePlaylists(){val a=JSONArray();playlists.value.forEach{a.put(JSONObject().put("id",it.id).put("name",it.name).put("tracks",JSONArray(it.tracks)))};prefs.edit().putString("playlists",a.toString()).apply()}
}
