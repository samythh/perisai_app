package com.perisai.perisai

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.*

class PerisaiService : Service() {

    companion object {
        private const val TAG = "PERISAI/Service"
        const val ACTION_TEST_PIPELINE = "com.perisai.perisai.TEST_PIPELINE"
    }

    private val NOTIFICATION_ID   = 1
    private val CHANNEL_ID        = "perisai_service_channel"
    private val CAPTURE_INTERVAL  = 7000L    // interval screenshot 3 detik
    private val GAMBLING_COOLDOWN = 30000L   // cooldown 30 detik setelah deteksi

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var handler: Handler? = null
    private var handlerThread: HandlerThread? = null
    private var isRunning = false
    private var lastCaptureMs = 0L

    // ← TAMBAHAN: tracking cooldown & deteksi terakhir
    private var lastGamblingDetectedMs = 0L
    private var isAnalyzing = false  // cegah concurrent analysis

    // Boot heartbeat
    private var bootHeartbeatTimer: java.util.Timer? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")
        createNotificationChannel()
        handlerThread = HandlerThread("PerisaiCaptureThread")
        handlerThread?.start()
        handler = Handler(handlerThread!!.looper)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action    = intent?.action
        val fromBoot  = intent?.getBooleanExtra("from_boot", false) ?: false
        val isTest    = action == ACTION_TEST_PIPELINE
        Log.d(TAG, "onStartCommand action=$action fromBoot=$fromBoot test=$isTest")

        val resultCode = intent?.getIntExtra("resultCode", Activity.RESULT_CANCELED)
            ?: Activity.RESULT_CANCELED

        val resultData: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra("resultData", Intent::class.java)
        } else {
            @Suppress("DEPRECATION") intent?.getParcelableExtra("resultData")
        }

        val hasMediaProjection = !fromBoot && !isTest &&
            resultCode != Activity.RESULT_CANCELED &&
            resultData != null

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val type = if (hasMediaProjection) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                } else {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                }
                startForeground(NOTIFICATION_ID, createNotification(), type)
                Log.d(TAG, "startForeground OK (type=$type)")
            } else {
                startForeground(NOTIFICATION_ID, createNotification())
                Log.d(TAG, "startForeground OK (basic type)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground FAIL: ${e.message}", e)
            stopSelf()
            return START_NOT_STICKY
        }

        if (fromBoot && !hasMediaProjection) {
            Log.d(TAG, "boot path — heartbeat mode (tanpa screen capture)")
            val prefs = getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
            val childId = prefs.getString("child_id", "") ?: ""
            if (childId.isNotBlank()) {
                // Update status ke online dan mulai heartbeat
                Thread {
                    try {
                        SupabaseManager.updateConnectionStatus(childId, "online")
                        Log.d(TAG, "boot: status updated to online")
                    } catch (e: Exception) {
                        Log.e(TAG, "boot: status update FAIL: ${e.message}", e)
                    }
                }.start()
                startBootHeartbeat(childId)
            }
            return START_STICKY
        }

        if (isTest) {
            Log.d(TAG, "TEST MODE → runPipelineTest")
            runPipelineTest()
            sendEventToFlutter("service_started", null)
            return START_NOT_STICKY
        }

        if (hasMediaProjection) {
            try {
                val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                    as MediaProjectionManager
                mediaProjection = manager.getMediaProjection(resultCode, resultData!!)

                mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        Log.w(TAG, "MediaProjection.onStop")
                        isRunning = false
                        virtualDisplay?.release()
                        virtualDisplay = null
                        imageReader?.close()
                        imageReader = null
                        sendEventToFlutter("service_stopped", null)
                    }
                }, Handler(Looper.getMainLooper()))

                setupScreenCapture()
                Log.d(TAG, "screen capture started")
            } catch (e: Exception) {
                Log.e(TAG, "screen capture setup FAIL: ${e.message}", e)
            }
        }

        // Register network callback untuk auto-online saat internet kembali
        val prefs = getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
        val childId = prefs.getString("child_id", "") ?: ""
        if (childId.isNotBlank()) {
            registerNetworkCallback(childId)
        }

        sendEventToFlutter("service_started", null)
        return START_STICKY
    }

    private fun setupScreenCapture() {
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION") wm.defaultDisplay.getMetrics(metrics)

            imageReader = ImageReader.newInstance(
                metrics.widthPixels,
                metrics.heightPixels,
                PixelFormat.RGBA_8888,
                2
            )

            imageReader?.setOnImageAvailableListener({ reader ->
                val now = System.currentTimeMillis()

                // Throttle screenshot
                if (now - lastCaptureMs < CAPTURE_INTERVAL) {
                    try { reader.acquireLatestImage()?.close() } catch (_: Exception) {}
                    return@setOnImageAvailableListener
                }

                // ← TAMBAHAN: skip kalau masih dalam cooldown setelah deteksi judol
                if (now - lastGamblingDetectedMs < GAMBLING_COOLDOWN) {
                    try { reader.acquireLatestImage()?.close() } catch (_: Exception) {}
                    val sisaCooldown = (GAMBLING_COOLDOWN - (now - lastGamblingDetectedMs)) / 1000
                    Log.d(TAG, "Cooldown aktif, skip capture. Sisa ${sisaCooldown}s")
                    return@setOnImageAvailableListener
                }

                // ← TAMBAHAN: skip kalau sedang analisis (cegah concurrent)
                if (isAnalyzing) {
                    try { reader.acquireLatestImage()?.close() } catch (_: Exception) {}
                    Log.d(TAG, "Sedang analisis, skip frame ini")
                    return@setOnImageAvailableListener
                }

                lastCaptureMs = now
                try { captureScreen() }
                catch (e: Exception) { Log.e(TAG, "captureScreen FAIL: ${e.message}", e) }

            }, handler)

            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "PerisaiCapture",
                metrics.widthPixels,
                metrics.heightPixels,
                metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader?.surface,
                null,
                handler
            )
            isRunning = true
            Log.d(TAG, "virtualDisplay created ${metrics.widthPixels}x${metrics.heightPixels}")
        } catch (e: Exception) {
            Log.e(TAG, "setupScreenCapture FAIL: ${e.message}", e)
        }
    }

    private fun captureScreen() {
        if (!isRunning) return
        val image = imageReader?.acquireLatestImage()
        if (image == null) {
            Log.v(TAG, "captureScreen: no image yet")
            return
        }
        try {
            val buffer      = image.planes[0].buffer
            val pixelStride = image.planes[0].pixelStride
            val rowStride   = image.planes[0].rowStride
            val rowPadding  = rowStride - pixelStride * image.width

            val bitmap = Bitmap.createBitmap(
                image.width + rowPadding / pixelStride,
                image.height,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)
            val cropped = Bitmap.createBitmap(bitmap, 0, 0, image.width, image.height)

            val stream = ByteArrayOutputStream()
            cropped.compress(Bitmap.CompressFormat.JPEG, 80, stream)
            val bytes = stream.toByteArray()
            Log.d(TAG, "captureScreen OK bytes=${bytes.size}")
            analyzeScreenshot(bytes)

            bitmap.recycle()
            cropped.recycle()
        } catch (e: Exception) {
            Log.e(TAG, "captureScreen FAIL: ${e.message}", e)
        } finally {
            image.close()
        }
    }

private fun analyzeScreenshot(screenshotBytes: ByteArray) {
        // ← TAMBAHAN: set flag analisis aktif
        isAnalyzing = true

        Thread {
            try {
                Log.d(TAG, "analyzeScreenshot → calling AI server")
                val aiResponse = AiServerManager.analyzeScreenshot(screenshotBytes)

                if (aiResponse == null) {
                    Log.w(TAG, "AI server returned null — skip")
                    return@Thread
                }

                val isGambling = aiResponse.optBoolean("is_gambling", false)
                Log.d(TAG, "AI verdict is_gambling=$isGambling")

                if (isGambling) {
                    // ← TAMBAHAN: set waktu deteksi terakhir
                    lastGamblingDetectedMs = System.currentTimeMillis()

                    // =================================================================
                    // EKSEKUSI HUKUMAN: KELUARKAN ANAK DARI SITUS SECARA PAKSA!
                    // =================================================================
                    
                    // 1. Munculkan Pop-up Toast Peringatan (Wajib berjalan di UI Thread)
                    Handler(Looper.getMainLooper()).post {
                        android.widget.Toast.makeText(
                            applicationContext,
                            "⚠️ PERINGATAN! PERISAI MEMBLOKIR SITUS TERLARANG!",
                            android.widget.Toast.LENGTH_LONG
                        ).show()
                    }

                    // 2. Tendang anak ke Home Screen (Minimalkan browser secara paksa)
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        // FLAG_ACTIVITY_NEW_TASK wajib ada karena dipanggil dari dalam Service
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK 
                    }
                    startActivity(homeIntent)
                    Log.d(TAG, "Hukuman dieksekusi: Anak ditendang ke Home Screen!")
                    // =================================================================

                    handleGamblingDetected(screenshotBytes, aiResponse)
                }
            } catch (e: Exception) {
                Log.e(TAG, "analyzeScreenshot FAIL: ${e.message}", e)
            } finally {
                // ← TAMBAHAN: selalu reset flag setelah analisis selesai
                isAnalyzing = false
            }
        }.start()
    }

    private fun handleGamblingDetected(screenshotBytes: ByteArray, aiResponse: JSONObject) {
        try {
            val prefs   = getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
            val childId = prefs.getString("child_id", "") ?: ""

            if (childId.isBlank()) {
                Log.e(TAG, "handleGamblingDetected ABORT — child_id blank")
                return
            }

            val timestamp = SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()
            ).format(Date())

            Log.d(TAG, "handleGamblingDetected → upload screenshot child=$childId")
            val screenshotUrl = SupabaseManager.uploadScreenshot(childId, screenshotBytes)

            if (screenshotUrl != null) {
                val confidence  = aiResponse.optDouble("confidence", 0.0)
                val triggeredBy = aiResponse.optString("triggered_by", "mobilenet")
                val keywords    = aiResponse.optJSONObject("details")
                    ?.optJSONArray("ocr_keywords") ?: JSONArray()
                val details     = aiResponse.optJSONObject("details") ?: JSONObject()

                val inserted = SupabaseManager.insertDetection(JSONObject().apply {
                    put("child_id",       childId)
                    put("screenshot_url", screenshotUrl)
                    put("confidence",     confidence)
                    put("triggered_by",   triggeredBy)
                    put("keywords",       keywords)
                    put("details",        details)
                })

                Log.d(TAG, "insertDetection result=$inserted")

                sendEventToFlutter("gambling_detected", JSONObject().apply {
                    put("event_type",     "gambling_detected")
                    put("is_gambling",    true)
                    put("confidence",     confidence)
                    put("triggered_by",   triggeredBy)
                    put("child_id",       childId)
                    put("screenshot_url", screenshotUrl)
                    put("keywords",       keywords)
                    put("timestamp",      timestamp)
                })
                Log.d(TAG, "pipeline COMPLETE ✅")
            } else {
                Log.e(TAG, "uploadScreenshot returned null — pipeline gagal")
            }
        } catch (e: Exception) {
            Log.e(TAG, "handleGamblingDetected FAIL: ${e.message}", e)
        }
    }

    private fun runPipelineTest() {
        Thread {
            try {
                val dummy = generateDummyJpeg()
                Log.d(TAG, "runPipelineTest dummy bytes=${dummy.size}")

                val aiResponse = AiServerManager.analyzeScreenshot(dummy)
                Log.d(TAG, "runPipelineTest aiResponse=$aiResponse")

                val forced = JSONObject().apply {
                    put("is_gambling", true)
                    put("confidence", 0.95)
                    put("triggered_by", "combined")
                    put("details", JSONObject().apply {
                        put("trustpositif", false)
                        put("mobilenet_confidence", 0.95)
                        put("ocr_keywords", JSONArray(listOf("TEST", "DUMMY")))
                        put("label", "JUDI")
                    })
                }
                handleGamblingDetected(dummy, forced)
            } catch (e: Exception) {
                Log.e(TAG, "runPipelineTest FAIL: ${e.message}", e)
            }
        }.start()
    }

    private fun generateDummyJpeg(): ByteArray {
        val bmp    = Bitmap.createBitmap(800, 600, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(Color.WHITE)
        val paint = Paint().apply {
            color     = Color.BLACK
            textSize  = 48f
            isAntiAlias = true
        }
        canvas.drawText("PERISAI TEST", 100f, 300f, paint)
        val stream = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, 80, stream)
        bmp.recycle()
        return stream.toByteArray()
    }

    private fun sendEventToFlutter(eventType: String, data: JSONObject?) {
        try {
            val event = data ?: JSONObject()
            if (!event.has("event_type")) event.put("event_type", eventType)
            val prefs = getSharedPreferences("perisai_prefs", Context.MODE_PRIVATE)
            if (!event.has("child_id")) {
                event.put("child_id", prefs.getString("child_id", "") ?: "")
            }
            if (!event.has("timestamp")) {
                event.put("timestamp", SimpleDateFormat(
                    "yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()
                ).format(Date()))
            }
            val sinkOk = MainActivity.eventSink != null
            Log.d(TAG, "sendEventToFlutter type=$eventType sinkOk=$sinkOk")
            Handler(Looper.getMainLooper()).post {
                MainActivity.eventSink?.success(event.toString())
            }
        } catch (e: Exception) {
            Log.e(TAG, "sendEventToFlutter FAIL: ${e.message}", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "PERISAI Protection",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
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

    // ─── Boot heartbeat — kirim status online tiap 30 detik ───
    private fun startBootHeartbeat(childId: String) {
        bootHeartbeatTimer?.cancel()
        bootHeartbeatTimer = java.util.Timer()
        bootHeartbeatTimer?.scheduleAtFixedRate(object : java.util.TimerTask() {
            override fun run() {
                try {
                    SupabaseManager.updateConnectionStatus(childId, "online")
                    Log.d(TAG, "boot heartbeat OK")
                } catch (e: Exception) {
                    Log.e(TAG, "boot heartbeat FAIL: ${e.message}")
                }
            }
        }, 30000L, 30000L)

        // Register network callback — auto-online saat internet kembali
        registerNetworkCallback(childId)
    }

    // ─── Network callback — deteksi internet kembali ───────────
    private fun registerNetworkCallback(childId: String) {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.d(TAG, "Internet tersedia — update status online")
                    Thread {
                        try {
                            SupabaseManager.updateConnectionStatus(childId, "online")
                        } catch (e: Exception) {
                            Log.e(TAG, "network callback update FAIL: ${e.message}")
                        }
                    }.start()
                }

                override fun onLost(network: Network) {
                    Log.d(TAG, "Internet hilang")
                }
            }

            cm.registerNetworkCallback(request, networkCallback!!)
            Log.d(TAG, "network callback registered")
        } catch (e: Exception) {
            Log.e(TAG, "registerNetworkCallback FAIL: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        isRunning = false
        bootHeartbeatTimer?.cancel()
        bootHeartbeatTimer = null

        // Unregister network callback
        if (networkCallback != null) {
            try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                cm.unregisterNetworkCallback(networkCallback!!)
            } catch (_: Exception) {}
            networkCallback = null
        }

        virtualDisplay?.release()
        imageReader?.close()
        mediaProjection?.stop()
        handlerThread?.quitSafely()
        sendEventToFlutter("service_stopped", null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}