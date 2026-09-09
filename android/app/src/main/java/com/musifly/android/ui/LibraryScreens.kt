@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.musifly.android.ui

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.input.PasswordVisualTransformation
import com.musifly.android.data.*
import com.musifly.android.playback.PlaybackModel

@Composable fun LibraryPage(page:Int,model:PlaybackModel,open:(String)->Unit,play:(Track)->Unit,add:(Track)->Unit,create:()->Unit){
    val tracks by model.library.tracks.collectAsState();val loading by model.library.loading.collectAsState();val metadata by model.library.metadataLoading.collectAsState();val lists by model.library.playlists.collectAsState()
    var query by remember{mutableStateOf("")};var filter by remember{mutableStateOf("CANALES")}
    val albums=tracks.groupBy{it.albumId}.values.sortedBy{it.first().album}
    LazyColumn(Modifier.fillMaxSize(),contentPadding=PaddingValues(24.dp),verticalArrangement=Arrangement.spacedBy(18.dp)){
        item{Header(when(page){0->"SESIÓN / MUSIFLY";1->"BUSCAR";2->"DISCO LOCAL";else->"CANCIONES"},if(page==0)"// bienvenido · biblioteca privada"else "// ${tracks.size} canciones")}
        if(loading)item{Mono("CARGANDO BIBLIOTECA…",size=10)}
        if(metadata)item{Mono("LEYENDO ÁLBUMES Y CARÁTULAS…",size=10)}
        if(tracks.isEmpty() && !loading)item{TerminalButton("CONECTAR BIBLIOTECA R2",Modifier.fillMaxWidth()){open("connection")}}
        if(page==0){
            item{Section("ÁLBUMES RECIENTES")}
            items(albums.chunked(2)){pair->Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){pair.forEach{album->Column(Modifier.weight(1f).background(Panel).border(1.dp,Ink.copy(alpha=.5f)).clickable{open("album:${album.first().albumId}")}.padding(12.dp),verticalArrangement=Arrangement.spacedBy(10.dp)){Artwork(album.firstNotNullOfOrNull{it.artwork},Modifier.fillMaxWidth().aspectRatio(1f));Mono(album.first().album,Modifier.height(44.dp),size=17,bright=true,lines=2);Mono(album.first().albumArtist,Modifier.height(30.dp),size=10,lines=2);Mono("${album.size} pistas",size=10,lines=1)}};if(pair.size==1)Spacer(Modifier.weight(1f))}}
            item{Section("REGISTRO RECIENTE");Mono("R2   ${tracks.size} canciones en la biblioteca",Modifier.padding(vertical=12.dp),size=11)}
        }
        if(page==1){
            item{OutlinedTextField(value=query,onValueChange={query=it},label={Mono("grep · pista, artista o álbum")},singleLine=true,modifier=Modifier.fillMaxWidth())}
            val found=tracks.filter{("${it.title} ${it.artist} ${it.album}").contains(query,true)}
            item{Section("${found.size} RESULTADOS")};items(found,key={it.id}){TrackRow(it,{play(it)},{add(it)})}
            items(albums.filter{it.first().album.contains(query,true)}){album->TerminalButton("DIR / ${album.first().album}",Modifier.fillMaxWidth()){open("album:${album.first().albumId}")}}
        }
        if(page==2){
            if(lists.isNotEmpty())item{Section("MIS PLAYLISTS")}
            items(lists,key={it.id}){list->Row(Modifier.fillMaxWidth().clickable{open("playlist:${list.id}")}.heightIn(min=48.dp),verticalAlignment=Alignment.CenterVertically){Mono(list.name,Modifier.weight(1f));Mono("${list.tracks.size} pistas",size=10)}}
            item{Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){listOf("CANALES","PISTAS","NODOS").forEach{label->TerminalButton(label,Modifier.weight(1f),filter==label){filter=label}};TerminalButton("+ NUEVA",Modifier.weight(1f),onClick=create)}}
            when(filter){
                "CANALES"->items(albums){album->TerminalButton("DIR / ${album.first().album}",Modifier.fillMaxWidth()){open("album:${album.first().albumId}")}}
                "PISTAS"->items(tracks,key={it.id}){TrackRow(it,{play(it)},{add(it)})}
                else->tracks.groupBy{it.artist}.toSortedMap().forEach{(artist,songs)->item{Section("/ $artist")};items(songs,key={it.id}){TrackRow(it,{play(it)},{add(it)})}}
            }
        }
        if(page==3){item{TerminalButton("SYS/NODO_07 · AJUSTES",Modifier.fillMaxWidth()){open("settings")}};items(tracks,key={it.id}){TrackRow(it,{play(it)},{add(it)})}}
    }
}
@Composable fun DetailPage(route:String,model:PlaybackModel,play:(Track)->Unit,add:(Track)->Unit){
    val all by model.library.tracks.collectAsState();val lists by model.library.playlists.collectAsState();val album=route.startsWith("album:");val id=route.substringAfter(':');val list=lists.firstOrNull{it.id==id}
    val tracks=if(album)all.filter{it.albumId==id}.sortedWith(compareBy({it.number},{it.title}))else list?.tracks?.mapNotNull{key->all.firstOrNull{it.id==key}} ?: emptyList()
    LazyColumn(Modifier.fillMaxSize(),contentPadding=PaddingValues(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)){
        item{Header(if(album)tracks.firstOrNull()?.album ?: "ÁLBUM" else list?.name ?: "PLAYLIST","// ${tracks.size} pistas")}
        if(album)item{Artwork(tracks.firstNotNullOfOrNull{it.artwork},Modifier.fillMaxWidth().aspectRatio(1f))}
        if(!album && tracks.isEmpty())item{Mono("Mantén presionada una canción y elige Agregar a playlist.")}
        items(tracks,key={it.id}){TrackRow(it,{play(it)},{add(it)})}
    }
}
@Composable fun SettingsPage(model:PlaybackModel,openConnection:()->Unit){
    val repo=model.library;val scan by repo.scanlines.collectAsState();val quality by repo.quality.collectAsState();val eq by repo.equalizer.collectAsState();val offline by repo.offline.collectAsState();val mobile by repo.mobile.collectAsState()
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)){
        Header("SYS/NODO_07","// preferencias locales")
        TerminalButton("BIBLIOTECA R2 >",Modifier.fillMaxWidth(),onClick=openConnection)
        Section("AJUSTES")
        TerminalButton("calidad_audio : $quality",Modifier.fillMaxWidth()){val values=listOf("LOSSLESS","ALTA","ESTÁNDAR");repo.setting("quality",values[(values.indexOf(quality)+1)%values.size])}
        TerminalButton("ecualizador : $eq",Modifier.fillMaxWidth()){val values=listOf("PLANO","GRAVES","VOCES");repo.setting("equalizer",values[(values.indexOf(eq)+1)%values.size])}
        TerminalButton("nodo_offline : ${if(offline)"ON"else "OFF"}",Modifier.fillMaxWidth(),offline){repo.toggle("offline")}
        TerminalButton("scanlines_ui : ${if(scan)"ON"else "OFF"}",Modifier.fillMaxWidth(),scan){repo.toggle("scanlines")}
        TerminalButton("datos_moviles : ${if(mobile)"ON"else "OFF"}",Modifier.fillMaxWidth(),mobile){repo.toggle("mobile")}
        Mono("Los ajustes de audio y red son preferencias de demostración, igual que en iPhone. El efecto CRT sí se aplica.",size=11)
    }
}
@Composable fun ConnectionPage(model:PlaybackModel){
    val connection by model.library.connection.collectAsState();val loading by model.library.loading.collectAsState()
    var endpoint by remember{mutableStateOf(connection?.endpoint ?: "https://sono-private-music.m-lizana003.workers.dev")};var token by remember{mutableStateOf("")}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)){
        Header("BIBLIOTECA R2","// conexión privada")
        Mono(if(connection!=null)"CONECTADO"else "SIN CONEXIÓN CONFIGURADA")
        OutlinedTextField(endpoint,{endpoint=it},label={Mono("URL HTTPS")},singleLine=true,modifier=Modifier.fillMaxWidth())
        OutlinedTextField(token,{token=it},label={Mono("Clave de la biblioteca")},singleLine=true,visualTransformation=PasswordVisualTransformation(),modifier=Modifier.fillMaxWidth())
        TerminalButton(if(loading)"CONECTANDO…"else "CONECTAR",Modifier.fillMaxWidth()){if(!loading){model.library.connect(endpoint,token);token=""}}
        if(connection!=null){TerminalButton("ACTUALIZAR BIBLIOTECA",Modifier.fillMaxWidth()){if(!loading)model.library.refresh()};TerminalButton("DESCONECTAR",Modifier.fillMaxWidth()){model.disconnect();token=""}}
        Mono("La clave se guarda cifrada con Android Keystore. Usa la clave de la biblioteca, no una clave de tu cuenta Cloudflare.",size=11)
    }
}
@Composable fun PlaylistDialog(repo:LibraryRepository,track:Track?,close:()->Unit){
    val lists by repo.playlists.collectAsState();var name by remember{mutableStateOf("")}
    androidx.compose.ui.window.Dialog(onDismissRequest=close){Column(Modifier.fillMaxWidth().heightIn(max=600.dp).background(Background).border(1.dp,Ink).verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)){
        Section(if(track==null)"NUEVA PLAYLIST"else "AGREGAR A PLAYLIST")
        if(track!=null){Mono(track.title,lines=2);lists.forEach{list->val present=track.id in list.tracks;TerminalButton(list.name+if(present)" · AGREGADA"else " +",Modifier.fillMaxWidth()){if(!present){repo.addToPlaylist(list.id,track.id);close()}}}}
        OutlinedTextField(name,{name=it},label={Mono("Nombre de la playlist")},singleLine=true)
        TerminalButton(if(track==null)"CREAR PLAYLIST"else "CREAR Y AGREGAR",Modifier.fillMaxWidth()){if(repo.createPlaylist(name,track?.id))close()}
    }}
}
