package com.perisai.perisai

import org.json.JSONObject
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL

object AiServerManager {

    private var SERVER_URL = "http://YOUR_AI_SERVER_IP:5000/analyze"  // TODO: Ganti dengan URL server AI dari HABIB, contoh: "http://192.168.1.100:5000/analyze"
    private var USE_DUMMY = true  // TODO: Set false kalau server HABIB sudah siap

    fun setServerUrl(url: String) { SERVER_URL = url; USE_DUMMY = false }

    fun analyzeScreenshot(screenshotBytes: ByteArray): JSONObject? {
        if (USE_DUMMY) return getDummyResponse()  // Pakai dummy kalau Habib belum siapp

        return try {
            val url = URL(SERVER_URL)
            val connection = url.openConnection() as HttpURLConnection

            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.connectTimeout = 30000
            connection.readTimeout = 30000

            val base64Image = android.util.Base64.encodeToString(screenshotBytes, android.util.Base64.NO_WRAP)
            val requestBody = JSONObject().apply { put("image", base64Image) }

            val outputStream = DataOutputStream(connection.outputStream)
            outputStream.writeBytes(requestBody.toString())
            outputStream.flush()
            outputStream.close()

            if (connection.responseCode == 200) {
                JSONObject(connection.inputStream.bufferedReader().readText())
            } else { null }
        } catch (e: Exception) { e.printStackTrace(); null }
    }

    private fun getDummyResponse(): JSONObject {  // Dummy response untuk testing tanpa server Habib
        return JSONObject().apply {
            put("is_gambling", true)
            put("confidence", 0.91)
            put("triggered_by", "mobilenet")
            put("details", JSONObject().apply {
                put("trustpositif", false)
                put("mobilenet_confidence", 0.91)
                put("ocr_keywords", org.json.JSONArray(listOf("SPIN", "BET")))
            })
        }
    }
}
