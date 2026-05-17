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

        // Baca dari Flutter SharedPreferences (bukan perisai_prefs)
        val flutterPrefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        val childId = flutterPrefs.getString("flutter.child_id", "") ?: ""
        val role = flutterPrefs.getString("flutter.role", "") ?: ""

        if (role != "child" || childId.isBlank()) {
            Log.w(TAG, "boot: bukan mode anak atau child_id kosong — skip")
            return
        }

        try {
            Log.d(TAG, "boot: starting PerisaiService (heartbeat mode)")
            val serviceIntent = Intent(context, PerisaiService::class.java).apply {
                putExtra("from_boot", true)
                putExtra("child_id_boot", childId)
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
