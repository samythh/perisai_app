package com.perisai.perisai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    private val TAG = "PERISAI/Boot"

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive action=${intent.action}")
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
        val childId = prefs.getString("child_id", "") ?: ""

        if (childId.isBlank()) {
            Log.w(TAG, "boot: child_id blank — skip auto-start")
            return
        }

        try {
            Log.d(TAG, "boot: starting PerisaiService (idle mode — no MediaProjection token)")
            val serviceIntent = Intent(context, PerisaiService::class.java).apply {
                putExtra("from_boot", true)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "boot start FAIL: ${e.message}", e)
        }
    }
}
