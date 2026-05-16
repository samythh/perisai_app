package com.perisai.perisai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class UrlCheckerService : AccessibilityService() {

    private val TAG = "PERISAI/Url"

    private val gamblingKeywords = listOf(
        "slot", "togel", "judol", "judi", "casino", "poker",
        "pragmatic", "pgsoft", "spadegaming", "habanero",
        "maxwin", "scatter", "gacor", "jackpot", "bonus138",
        "slot88", "slot777", "mpo", "joker123", "sv388",
        "toto", "4d", "bandar", "taruhan", "bet365"
    )

    private val browserPackages = listOf(
        "com.android.chrome", "org.mozilla.firefox", "com.opera.browser",
        "com.brave.browser", "com.microsoft.emmx", "com.UCMobile.intl"
    )

    private var lastDetectedUrl = ""

    override fun onServiceConnected() {
        Log.d(TAG, "onServiceConnected")
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 3000
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName !in browserPackages) return

        val url = findUrlInNode(rootInActiveWindow ?: return)
        if (url != null && url != lastDetectedUrl) {
            Log.d(TAG, "url detected in $packageName → $url")
            checkUrlForGambling(url)
        }
    }

    private fun findUrlInNode(node: AccessibilityNodeInfo): String? {
        val urlBarIds = listOf(
            "com.android.chrome:id/url_bar", "com.android.chrome:id/omnibox_text_field",
            "org.mozilla.firefox:id/url_bar_title", "com.opera.browser:id/url_field",
            "com.brave.browser:id/url_bar", "com.microsoft.emmx:id/url_bar"
        )
        for (id in urlBarIds) {
            val nodes = node.findAccessibilityNodeInfosByViewId(id)
            if (nodes != null && nodes.isNotEmpty()) return nodes[0].text?.toString()
        }
        return null
    }

    private fun checkUrlForGambling(url: String) {
        val matched = gamblingKeywords.filter { url.lowercase().contains(it) }
        if (matched.isEmpty()) return

        Log.w(TAG, "GAMBLING URL detected: $url keywords=$matched")
        lastDetectedUrl = url
        Handler(Looper.getMainLooper()).post {
            val payload = JSONObject().apply {
                put("event_type", "gambling_detected")
                put("is_gambling", true)
                put("confidence", 0.95)
                put("triggered_by", "trustpositif")
                put("child_id", getChildId())
                put("screenshot_url", "")
                put("keywords", JSONArray(matched))
                put("timestamp", SimpleDateFormat(
                    "yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()
                ).format(Date()))
            }.toString()
            val sinkOk = MainActivity.eventSink != null
            Log.d(TAG, "send event sinkOk=$sinkOk")
            MainActivity.eventSink?.success(payload)
        }
    }

    private fun getChildId(): String {
        return getSharedPreferences("perisai_prefs", MODE_PRIVATE)
            .getString("child_id", "") ?: ""
    }

    override fun onInterrupt() {
        Log.w(TAG, "onInterrupt")
    }
}
