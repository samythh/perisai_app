package com.perisai.perisai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val TAG = "PERISAI/Main"

    private val EVENT_CHANNEL = "com.perisai.app/detection_stream"
    private val METHOD_CHANNEL = "com.perisai.app/service_control"
    private val MEDIA_PROJECTION_REQUEST = 1001
    private val OVERLAY_PERMISSION_REQUEST = 1002

    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine")

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "EventChannel onListen — sink ready")
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "EventChannel onCancel — sink released")
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "MethodChannel call=${call.method}")
                when (call.method) {
                    "startService" -> {
                        val childId = call.argument<String>("child_id") ?: ""
                        Log.d(TAG, "startService childId=$childId")
                        startPerisaiService(childId)
                        result.success(true)
                    }
                    "stopService" -> {
                        stopPerisaiService()
                        result.success(true)
                    }
                    "sendTestEvent" -> {
                        // Dual purpose: kirim dummy event ke Flutter + trigger pipeline test
                        sendTestEvent()
                        triggerPipelineTest()
                        result.success(true)
                    }
                    else -> {
                        Log.w(TAG, "method not implemented: ${call.method}")
                        result.notImplemented()
                    }
                }
            }
    }

    private fun startPerisaiService(childId: String) {
        if (childId.isBlank()) {
            Log.e(TAG, "startPerisaiService ABORT — childId blank, tidak menyimpan ke prefs")
            return
        }
        val prefs = getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("child_id", childId).apply()
        Log.d(TAG, "child_id tersimpan di prefs → request permission chain")
        requestAllPermissions()
    }

    private fun requestAllPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Log.d(TAG, "step 1 → request POST_NOTIFICATIONS")
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 100)
        } else {
            requestOverlayPermission()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        Log.d(TAG, "onRequestPermissionsResult code=$requestCode results=${grantResults.toList()}")
        if (requestCode == 100) requestOverlayPermission()
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            Log.d(TAG, "step 2 → request SYSTEM_ALERT_WINDOW")
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST)
        } else {
            requestScreenCapture()
        }
    }

    private fun requestScreenCapture() {
        Log.d(TAG, "step 3 → request MEDIA_PROJECTION")
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(manager.createScreenCaptureIntent(), MEDIA_PROJECTION_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        Log.d(TAG, "onActivityResult code=$requestCode resultCode=$resultCode")
        when (requestCode) {
            OVERLAY_PERMISSION_REQUEST -> requestScreenCapture()
            MEDIA_PROJECTION_REQUEST -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    Log.d(TAG, "MediaProjection granted → starting PerisaiService")
                    val intent = Intent(this, PerisaiService::class.java).apply {
                        putExtra("resultCode", resultCode)
                        putExtra("resultData", data)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                } else {
                    Log.w(TAG, "MediaProjection denied — service NOT started")
                }
            }
        }
    }

    private fun stopPerisaiService() {
        Log.d(TAG, "stopPerisaiService")
        stopService(Intent(this, PerisaiService::class.java))
    }

    private fun sendTestEvent() {
        Log.d(TAG, "sendTestEvent → dummy gambling_detected event")
        val dummyJson = org.json.JSONObject().apply {
            put("event_type", "gambling_detected")
            put("is_gambling", true)
            put("confidence", 0.91)
            put("triggered_by", "combined")
            put("child_id", "test-child-dummy-id")
            put("screenshot_url", "https://test-dummy-screenshot.jpg")
            put("keywords", org.json.JSONArray(listOf("SPIN", "BET")))
            put("timestamp", java.text.SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.getDefault()
            ).format(java.util.Date()))
        }
        val sinkOk = eventSink != null
        Log.d(TAG, "sendTestEvent sinkOk=$sinkOk")
        eventSink?.success(dummyJson.toString())
    }

    // Trigger full pipeline test (AI server + Supabase upload + Supabase insert + event)
    private fun triggerPipelineTest() {
        Log.d(TAG, "triggerPipelineTest → start PerisaiService with TEST action")
        val intent = Intent(this, PerisaiService::class.java).apply {
            action = PerisaiService.ACTION_TEST_PIPELINE
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "triggerPipelineTest FAIL: ${e.message}", e)
        }
    }
}
