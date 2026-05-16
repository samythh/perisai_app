package com.perisai.perisai

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import android.util.DisplayMetrics
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.*

class PerisaiService : Service() {

    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "perisai_service_channel"
    private val CAPTURE_INTERVAL = 10000L  // TODO: Ubah interval screenshot kalau perlu, sekarang 10 detik (10000ms). Diskusi dengan TIM

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var handler: Handler? = null
    private var handlerThread: HandlerThread? = null
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        handlerThread = HandlerThread("PerisaiCaptureThread")
        handlerThread?.start()
        handler = Handler(handlerThread!!.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())

        val resultCode = intent?.getIntExtra("resultCode", Activity.RESULT_CANCELED) ?: Activity.RESULT_CANCELED
        val resultData: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra("resultData", Intent::class.java)
        } else {
            @Suppress("DEPRECATION") intent?.getParcelableExtra("resultData")
        }

        if (resultCode != Activity.RESULT_CANCELED && resultData != null) {
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = manager.getMediaProjection(resultCode, resultData)
            setupScreenCapture()
            startPeriodicCapture()
            sendEventToFlutter("service_started", null)
        }

        return START_STICKY
    }

    private fun setupScreenCapture() {
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION") wm.defaultDisplay.getMetrics(metrics)

        imageReader = ImageReader.newInstance(metrics.widthPixels, metrics.heightPixels, PixelFormat.RGBA_8888, 2)
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "PerisaiCapture", metrics.widthPixels, metrics.heightPixels, metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, imageReader?.surface, null, handler
        )
    }

    private fun startPeriodicCapture() {
        isRunning = true
        handler?.post(object : Runnable {
            override fun run() {
                if (!isRunning) return
                captureScreen()
                handler?.postDelayed(this, CAPTURE_INTERVAL)
            }
        })
    }

    private fun captureScreen() {
        val image = imageReader?.acquireLatestImage() ?: return
        try {
            val buffer = image.planes[0].buffer
            val pixelStride = image.planes[0].pixelStride
            val rowStride = image.planes[0].rowStride
            val rowPadding = rowStride - pixelStride * image.width

            val bitmap = Bitmap.createBitmap(image.width + rowPadding / pixelStride, image.height, Bitmap.Config.ARGB_8888)
            bitmap.copyPixelsFromBuffer(buffer)
            val cropped = Bitmap.createBitmap(bitmap, 0, 0, image.width, image.height)

            val stream = ByteArrayOutputStream()
            cropped.compress(Bitmap.CompressFormat.JPEG, 80, stream)
            analyzeScreenshot(stream.toByteArray())

            bitmap.recycle()
            cropped.recycle()
        } catch (e: Exception) { e.printStackTrace() }
        finally { image.close() }
    }

    private fun analyzeScreenshot(screenshotBytes: ByteArray) {
        Thread {
            try {
                val aiResponse = AiServerManager.analyzeScreenshot(screenshotBytes)
                if (aiResponse != null && aiResponse.getBoolean("is_gambling")) {
                    handleGamblingDetected(screenshotBytes, aiResponse)  // JUDOL → simpan & kirim event
                }
                // BUKAN JUDOL → screenshot otomatis hilang dari memory, tidak disimpan
            } catch (e: Exception) { e.printStackTrace() }
        }.start()
    }

    private fun handleGamblingDetected(screenshotBytes: ByteArray, aiResponse: JSONObject) {
        val prefs = getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
        val childId = prefs.getString("child_id", "") ?: ""
        val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date())

        val screenshotUrl = SupabaseManager.uploadScreenshot(childId, screenshotBytes)

        if (screenshotUrl != null) {
            SupabaseManager.insertDetection(JSONObject().apply {
                put("child_id", childId)
                put("screenshot_url", screenshotUrl)
                put("confidence", aiResponse.getDouble("confidence"))
                put("triggered_by", aiResponse.getString("triggered_by"))
                put("keywords", aiResponse.optJSONObject("details")?.optJSONArray("ocr_keywords") ?: JSONArray())
                put("details", aiResponse.optJSONObject("details") ?: JSONObject())
            })
        }

        sendEventToFlutter("gambling_detected", JSONObject().apply {
            put("event_type", "gambling_detected")
            put("is_gambling", true)
            put("confidence", aiResponse.getDouble("confidence"))
            put("triggered_by", aiResponse.getString("triggered_by"))
            put("child_id", childId)
            put("screenshot_url", screenshotUrl ?: "")
            put("keywords", aiResponse.optJSONObject("details")?.optJSONArray("ocr_keywords") ?: JSONArray())
            put("timestamp", timestamp)
        })
    }

    private fun sendEventToFlutter(eventType: String, data: JSONObject?) {
        val event = data ?: JSONObject()
        if (!event.has("event_type")) event.put("event_type", eventType)
        val prefs = getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
        if (!event.has("child_id")) event.put("child_id", prefs.getString("child_id", "") ?: "")
        if (!event.has("timestamp")) event.put("timestamp", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).format(Date()))
        Handler(Looper.getMainLooper()).post { MainActivity.eventSink?.success(event.toString()) }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "PERISAI Protection", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PERISAI sedang aktif 🛡️")
            .setContentText("Sedang melindungi dari konten berbahaya")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        isRunning = false
        virtualDisplay?.release()
        imageReader?.close()
        mediaProjection?.stop()
        handlerThread?.quitSafely()
        sendEventToFlutter("service_stopped", null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
