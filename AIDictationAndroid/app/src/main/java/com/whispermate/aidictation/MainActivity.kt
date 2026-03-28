package com.whispermate.aidictation

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.whispermate.aidictation.service.OverlayDictationAccessibilityService
import com.whispermate.aidictation.ui.AIDictationNavHost
import com.whispermate.aidictation.ui.theme.AIDictationTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private var shouldStartRecording by mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        handleIntent(intent)
        enableEdgeToEdge()
        setContent {
            AIDictationTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AIDictationNavHost(
                        shouldStartRecording = shouldStartRecording,
                        onRecordingStarted = { shouldStartRecording = false }
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == OverlayDictationAccessibilityService.ACTION_START_DICTATION) {
            shouldStartRecording = true
        }
    }
}
