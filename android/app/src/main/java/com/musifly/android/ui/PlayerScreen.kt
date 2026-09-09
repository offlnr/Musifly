@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class, androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.musifly.android.ui
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.musifly.android.playback.PlaybackModel
import com.musifly.android.data.Track
import com.musifly.android.data.time

@Composable fun PlayerScreen(model:PlaybackModel,onClose:()->Unit,onAdd:(Track)->Unit){
    BackHandler(onBack=onClose)
    val track by model.current.collectAsState();val playing by model.playing.collectAsState();val buffering by model.buffering.collectAsState();val position by model.position.collectAsState();val duration by model.duration.collectAsState();val loop by model.loop.collectAsState();val shuffle by model.shuffle.collectAsState();val output by model.output.collectAsState();val tracks by model.library.tracks.collectAsState()
    var dragValue by remember(track?.id){mutableStateOf<Float?>(null)}
    Column(Modifier.fillMaxSize().background(Background).verticalScroll(rememberScrollState()).padding(24.dp),verticalArrangement=Arrangement.spacedBy(20.dp)){
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Mono(if(buffering)"CARGANDO AUDIO…"else "",size=10);Mono("AUDIO: $output",size=10,lines=1)}
        Box(Modifier.fillMaxWidth().aspectRatio(1f).pointerInput(Unit){var distance=0f;detectVerticalDragGestures(onDragStart={distance=0f},onVerticalDrag={change,dy->distance+=dy;change.consume()},onDragEnd={if(distance>90.dp.toPx())onClose()})}){
            Artwork(track?.artwork,Modifier.fillMaxSize());Spectrum(playing && !buffering,Modifier.fillMaxWidth().fillMaxHeight(.45f).align(Alignment.BottomCenter))
        }
        Mono(track?.title ?: "Sin canción",Modifier.fillMaxWidth().height(38.dp).basicMarquee(iterations=Int.MAX_VALUE,velocity=30.dp),size=28,bright=true,lines=1)
        Mono(track?.artist ?: "",lines=1);Mono(track?.album ?: "",lines=1)
        Column {
            Slider(value=dragValue ?: if(duration>0)position.toFloat()/duration else 0f,onValueChange={dragValue=it},onValueChangeFinished={dragValue?.let{model.seek(it)};dragValue=null},enabled=duration>0,modifier=Modifier.fillMaxWidth(),thumb={Box(Modifier.size(6.dp,18.dp).background(Highlight))},track={state->
                Canvas(Modifier.fillMaxWidth().height(8.dp).border(1.dp,Ink.copy(alpha=.5f))){val step=5.dp.toPx();val count=(size.width/step).toInt().coerceAtLeast(1);repeat(count){i->drawRect(Ink.copy(alpha=if(i.toFloat()/count<state.value)1f else .12f),androidx.compose.ui.geometry.Offset(i*step+2,2f),androidx.compose.ui.geometry.Size(2.dp.toPx(),size.height-4))}}
            })
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Mono(time(dragValue?.let{(it*duration).toLong()} ?: position),size=11);Mono(time(duration),size=11)}
        }
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(8.dp),verticalAlignment=Alignment.CenterVertically){
            PlayerButton(Icons.Default.Shuffle,"Aleatorio",false,shuffle,Modifier.weight(1f)){model.toggleShuffle()}
            PlayerButton(Icons.Default.SkipPrevious,"Canción anterior",true,false,Modifier.weight(1f)){model.previous()}
            PlayerButton(if(playing)Icons.Default.Pause else Icons.Default.PlayArrow,if(playing)"Pausar"else "Reproducir",true,false,Modifier.weight(1f)){model.toggle()}
            PlayerButton(Icons.Default.SkipNext,"Canción siguiente",true,false,Modifier.weight(1f)){model.next()}
            PlayerButton(Icons.Default.Repeat,"Repetir",false,loop,Modifier.weight(1f)){model.toggleLoop()}
        }
        Section("COLA DE REPRODUCCIÓN")
        tracks.forEach{t->key(t.id){TrackRow(t,{model.play(t)},{onAdd(t)})}}
    }
}
@Composable private fun PlayerButton(icon:androidx.compose.ui.graphics.vector.ImageVector,label:String,large:Boolean,active:Boolean,modifier:Modifier,onClick:()->Unit){Box(modifier.height(if(large)68.dp else 48.dp).background(if(active)Ink.copy(alpha=.18f)else Panel).border(1.dp,Ink.copy(alpha=.55f)).clickable(interactionSource=remember{androidx.compose.foundation.interaction.MutableInteractionSource()},indication=null,onClick=onClick),contentAlignment=Alignment.Center){Icon(icon,label,Modifier.size(if(large)34.dp else 18.dp),tint=if(active)Highlight else Ink)}}
