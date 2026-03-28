package com.whispermate.aidictation

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.whispermate.aidictation.service.OverlayDictationAccessibilityService

/**
 * A receiver that can be triggered directly via Intent to toggle dictation.
 */
class ShortcutReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val serviceIntent = Intent(context, OverlayDictationAccessibilityService::class.java)
        serviceIntent.action = OverlayDictationAccessibilityService.ACTION_START_DICTATION
        context.startService(serviceIntent)
    }
}
