package com.whispermate.aidictation

import android.app.Application
import com.whispermate.aidictation.data.preferences.ApiConfigManager
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class AIDictationApp : Application() {
    @Inject lateinit var apiConfigManager: ApiConfigManager
}
