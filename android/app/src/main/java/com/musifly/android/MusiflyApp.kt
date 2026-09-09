package com.musifly.android
import android.app.Application
import com.musifly.android.data.LibraryRepository
class MusiflyApp: Application() { val library by lazy { LibraryRepository(this) } }
