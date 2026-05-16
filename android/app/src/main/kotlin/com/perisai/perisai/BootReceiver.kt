package com.perisai.perisai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
            val childId = prefs.getString("child_id", "") ?: ""
            if (childId.isNotEmpty()) {  // Hanya auto-start kalau sudah pernah di-setup (ada child_id)
                val serviceIntent = Intent(context, PerisaiService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}
