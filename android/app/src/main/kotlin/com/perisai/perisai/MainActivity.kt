package com.perisai.perisai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val EVENT_CHANNEL = "com.perisai.app/detection_stream"
    private val METHOD_CHANNEL = "com.perisai.app/service_control"
    private val MEDIA_PROJECTION_REQUEST = 1001
    private val OVERLAY_PERMISSION_REQUEST = 1002

    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val childId = call.argument<String>("child_id") ?: ""
                        startPerisaiService(childId)
                        result.success(true)
                    }
                    "stopService" -> {
                        stopPerisaiService()
                        result.success(true)
                    }
                    "sendTestEvent" -> {
                        sendTestEvent()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startPerisaiService(childId: String) {
        val prefs = getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("child_id", childId).apply()
        requestAllPermissions()
    }

    private fun requestAllPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {  // Step 1: Izin notifikasi (Android 13+)
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 100)
        } else {
            requestOverlayPermission()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100) requestOverlayPermission()  // Step 2: Izin overlay
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST)
        } else {
            requestScreenCapture()  // Step 3: Izin screen capture
        }
    }

    private fun requestScreenCapture() {
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(manager.createScreenCaptureIntent(), MEDIA_PROJECTION_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            OVERLAY_PERMISSION_REQUEST -> requestScreenCapture()
            MEDIA_PROJECTION_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val intent = Intent(this, PerisaiService::class.java).apply {
                        putExtra("resultCode", resultCode)
                        putExtra("resultData", data)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                }
            }
        }
    }

    private fun stopPerisaiService() {
        stopService(Intent(this, PerisaiService::class.java))
    }

    private fun sendTestEvent() {
        val dummyJson = org.json.JSONObject().apply {
            put("event_type", "gambling_detected")
            put("is_gambling", true)
            put("confidence", 0.91)
            put("triggered_by", "combined")
            put("child_id", "test-child-dummy-id")
            put("screenshot_url", "https://test-dummy-screenshot.jpg")
            put("keywords", org.json.JSONArray(listOf("SPIN", "BET")))
            put("timestamp", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date()))
        }
        eventSink?.success(dummyJson.toString())
    }
}
