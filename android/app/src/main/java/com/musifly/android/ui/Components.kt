@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
package com.musifly.android.ui
import android.graphics.BitmapFactory
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import com.musifly.android.data.Track
import com.musifly.android.data.time
import com.musifly.android.playback.SpectrumLevels
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.exp

@Composable fun Mono(text:String,modifier:Modifier=Modifier,size:Int=12,bright:Boolean=false,lines:Int=Int.MAX_VALUE){Text(text,modifier,color=if(bright)Highlight else Ink,fontFamily=FontFamily.Monospace,fontSize=size.sp,maxLines=lines,overflow=TextOverflow.Ellipsis)}
@Composable fun TerminalButton(text:String,modifier:Modifier=Modifier,active:Boolean=false,onClick:()->Unit){Box(modifier.heightIn(min=44.dp).background(if(active)Ink.copy(alpha=.16f) else Panel).border(1.dp,Ink.copy(alpha=if(active)1f else .5f)).clickable(interactionSource=remember{MutableInteractionSource()},indication=null,onClick=onClick).padding(horizontal=8.dp),contentAlignment=Alignment.Center){Mono(text,size=11,bright=active,lines=1)}}
@Composable fun Header(title:String,subtitle:String){Column(verticalArrangement=Arrangement.spacedBy(8.dp)){Mono(title,size=24,bright=true);Mono(subtitle,size=10);HorizontalDivider(color=Ink.copy(alpha=.4f))}}
@Composable fun Section(text:String){Mono(text,size=10,modifier=Modifier.padding(top=8.dp))}
@Composable fun Artwork(path:String?,modifier:Modifier=Modifier){
    val bitmap by produceState<androidx.compose.ui.graphics.ImageBitmap?>(null,path){value=withContext(Dispatchers.IO){path?.let{BitmapFactory.decodeFile(it)?.asImageBitmap()}}}
    if(bitmap!=null) Image(bitmap!!,contentDescription="Carátula del álbum",modifier=modifier,contentScale=ContentScale.Crop)
    else Canvas(modifier.clipToBounds().background(Panel)){val step=12.dp.toPx();var x=-size.height;while(x<size.width){drawLine(Ink.copy(alpha=.25f),Offset(x,size.height),Offset(x+size.height,0f),1f);x+=step}}
}
@Composable fun TrackRow(track:Track,onPlay:()->Unit,onAdd:()->Unit){
    var menu by remember{mutableStateOf(false)}
    Box{Row(Modifier.fillMaxWidth().combinedClickable(onClick=onPlay,onLongClick={menu=true}).padding(vertical=10.dp),verticalAlignment=Alignment.CenterVertically,horizontalArrangement=Arrangement.spacedBy(12.dp)){
        Artwork(track.artwork,Modifier.size(36.dp));Column(Modifier.weight(1f)){Mono(track.title,lines=2);Mono(track.artist,size=10,lines=1)};Mono(if(track.duration>0)time(track.duration)else "--:--",size=10)
    };DropdownMenu(expanded=menu,onDismissRequest={menu=false}){DropdownMenuItem(text={Mono("Agregar a playlist")},onClick={menu=false;onAdd()})}}
}
@Composable fun CRTOverlay(){Canvas(Modifier.fillMaxSize()){var y=0f;while(y<size.height){drawLine(androidx.compose.ui.graphics.Color.Black.copy(alpha=.12f),Offset(0f,y),Offset(size.width,y),1f);y+=4.dp.toPx()};for(i in 0..12){drawRect(androidx.compose.ui.graphics.Color.Black.copy(alpha=.015f),topLeft=Offset(i.toFloat(),i.toFloat()),size=Size(size.width-2*i,size.height-2*i),style=androidx.compose.ui.graphics.drawscope.Stroke(2f))}}}
@Composable fun Spectrum(playing:Boolean,modifier:Modifier=Modifier){
    var bars by remember{mutableStateOf(FloatArray(32))}
    LaunchedEffect(playing){if(!playing){bars=FloatArray(32);return@LaunchedEffect};var previous=0L;while(true){withFrameNanos{frame->val dt=if(previous==0L)1f/60 else ((frame-previous)/1e9f).coerceAtMost(.05f);previous=frame;val fresh=android.os.SystemClock.elapsedRealtime()-SpectrumLevels.updated<300;val target=SpectrumLevels.values;bars=FloatArray(32){i->val value=if(fresh)target[i]else 0f;val response=if(value>bars[i]).005f else .028f;bars[i]+(value-bars[i])*(1-exp(-dt/response))}}}}
    Canvas(modifier){val gap=2.dp.toPx();val width=(size.width-gap*31)/32;bars.forEachIndexed{i,v->val height=maxOf(2f,v*size.height);val left=i*(width+gap);drawRect(Ink.copy(alpha=.88f),Offset(left,size.height-height),Size(width,height));drawRect(Highlight,Offset(left,size.height-height),Size(width,2f))}}
}
