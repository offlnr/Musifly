package com.musifly.android.ui
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp
val Background=Color(0xFF050805)
val Panel=Color(0xFF071007)
val Ink=Color(0xFF33FF66)
val Highlight=Color(0xFFAAFFC4)
@Composable fun MusiflyTheme(content:@Composable ()->Unit){MaterialTheme(shapes=Shapes(extraSmall=androidx.compose.foundation.shape.RoundedCornerShape(0),small=androidx.compose.foundation.shape.RoundedCornerShape(0),medium=androidx.compose.foundation.shape.RoundedCornerShape(0),large=androidx.compose.foundation.shape.RoundedCornerShape(0),extraLarge=androidx.compose.foundation.shape.RoundedCornerShape(0)),colorScheme=darkColorScheme(primary=Ink,onPrimary=Background,background=Background,onBackground=Ink,surface=Panel,onSurface=Ink,secondary=Highlight),typography=Typography(bodyLarge=TextStyle(fontFamily=FontFamily.Monospace,fontSize=14.sp),bodyMedium=TextStyle(fontFamily=FontFamily.Monospace,fontSize=12.sp),labelLarge=TextStyle(fontFamily=FontFamily.Monospace)),content=content)}
