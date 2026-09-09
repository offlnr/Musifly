@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.musifly.android.ui
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.musifly.android.playback.PlaybackModel
import com.musifly.android.data.Track
import kotlinx.coroutines.launch

@Composable fun AppScreen(model:PlaybackModel){
    val pager=rememberPagerState(pageCount={4});val scope=rememberCoroutineScope()
    var routes by remember{mutableStateOf(listOf<String>())};var playerOpen by remember{mutableStateOf(false)};var dialog by remember{mutableStateOf(false)};var addTrack by remember{mutableStateOf<Track?>(null)}
    val current by model.current.collectAsState();val playing by model.playing.collectAsState();val scanlines by model.library.scanlines.collectAsState();val error by model.library.error.collectAsState()
    fun back(){if(routes.isNotEmpty())routes=routes.dropLast(1)}
    BackHandler(enabled=routes.isNotEmpty() && !playerOpen){back()}
    val play:(Track)->Unit={model.play(it);playerOpen=true}
    val add:(Track)->Unit={addTrack=it;dialog=true}
    Box(Modifier.fillMaxSize().background(Background).safeDrawingPadding()){
        Column(Modifier.fillMaxSize()){
            Box(Modifier.weight(1f).fillMaxWidth().pointerInput(routes){var start=0f;var distance=0f;detectHorizontalDragGestures(onDragStart={start=it.x;distance=0f},onHorizontalDrag={change,dx->if(start<32.dp.toPx() && routes.isNotEmpty()){distance+=dx;change.consume()}},onDragEnd={if(start<32.dp.toPx() && distance>80.dp.toPx())back()})}){
                when(val route=routes.lastOrNull()){
                    null->HorizontalPager(pager,Modifier.fillMaxSize()){page->LibraryPage(page,model,{routes=routes+it},play,add,{addTrack=null;dialog=true})}
                    "settings"->SettingsPage(model){routes=routes+"connection"}
                    "connection"->ConnectionPage(model)
                    else->DetailPage(route,model,play,add)
                }
            }
            Row(Modifier.fillMaxWidth().padding(horizontal=24.dp,vertical=8.dp).height(64.dp).background(Panel).border(1.dp,Ink.copy(alpha=.5f)).clickable{if(current!=null)playerOpen=true}.padding(10.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(10.dp)){
                Artwork(current?.artwork,Modifier.size(40.dp));Column(Modifier.weight(1f)){Mono(current?.title ?: "Sin canción",lines=1);Mono(current?.artist ?: "Musifly",size=10,lines=1)};TerminalButton(if(playing)"Ⅱ"else "▶",Modifier.width(44.dp)){model.toggle()}
            }
            Row(Modifier.fillMaxWidth().padding(start=24.dp,end=24.dp,bottom=8.dp)){
                listOf("INICIO","BUSCAR","PLAYLISTS","CANCIONES").forEachIndexed{index,label->Column(Modifier.weight(1f).height(48.dp).clickable{routes=emptyList();scope.launch{pager.scrollToPage(index)}},verticalArrangement=Arrangement.Center,horizontalAlignment=Alignment.CenterHorizontally){HorizontalDivider(color=if(pager.currentPage==index)Highlight else Background);Mono(label,Modifier.padding(top=10.dp),size=10,bright=pager.currentPage==index,lines=1)}}
            }
        }
        if(playerOpen)PlayerScreen(model,{playerOpen=false},add)
        if(scanlines)CRTOverlay()
        if(dialog)PlaylistDialog(model.library,addTrack){dialog=false;addTrack=null}
        if(error!=null)AlertDialog(onDismissRequest={model.library.error.value=null},title={Mono("BIBLIOTECA")},text={Mono(error ?: "")},confirmButton={TextButton(onClick={model.library.error.value=null}){Mono("ACEPTAR")}})
    }
}
