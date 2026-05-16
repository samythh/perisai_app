package com.perisai.perisai

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL

object AiServerManager {

    private const val TAG = "PERISAI/AI"

    // URL endpoint Habib
    private const val SERVER_URL = "https://api-judol.habibdev.site/predict"

    fun analyzeScreenshot(screenshotBytes: ByteArray): JSONObject? {
        Log.d(TAG, "analyzeScreenshot start — bytes=${screenshotBytes.size}")

        var connection: HttpURLConnection? = null
        return try {
            val url = URL(SERVER_URL)
            val boundary = "Boundary-${System.currentTimeMillis()}"

            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
            connection.connectTimeout = 30000
            connection.readTimeout = 30000

            // Multipart body — field name "file"
            val outputStream = DataOutputStream(connection.outputStream)
            outputStream.writeBytes("--$boundary\r\n")
            outputStream.writeBytes("Content-Disposition: form-data; name=\"file\"; filename=\"screenshot.jpg\"\r\n")
            outputStream.writeBytes("Content-Type: image/jpeg\r\n")
            outputStream.writeBytes("\r\n")
            outputStream.write(screenshotBytes)
            outputStream.writeBytes("\r\n")
            outputStream.writeBytes("--$boundary--\r\n")
            outputStream.flush()
            outputStream.close()

            val code = connection.responseCode
            Log.d(TAG, "AI response code=$code")

            if (code in 200..299) {
                val responseText = connection.inputStream.bufferedReader().readText()
                Log.d(TAG, "AI response body=$responseText")
                val raw = JSONObject(responseText)
                parseResponse(raw)
            } else {
                val errorText = try {
                    connection.errorStream?.bufferedReader()?.readText() ?: "<no error body>"
                } catch (e: Exception) {
                    "<error reading error stream: ${e.message}>"
                }
                Log.e(TAG, "AI server error code=$code body=$errorText")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "analyzeScreenshot exception: ${e.message}", e)
            null
        } finally {
            connection?.disconnect()
        }
    }

    // Convert response Habib → format internal PerisaiService
    private fun parseResponse(raw: JSONObject): JSONObject {
        val verdict = raw.optJSONObject("verdict") ?: JSONObject()

        val isGambling       = verdict.optBoolean("is_gambling", false)
        val visualLabel      = verdict.optString("visual_label", "")
        val visualConfidence = verdict.optDouble("visual_confidence", 0.0) / 100.0
        val ocrWords         = verdict.optJSONArray("ocr_detected_words") ?: JSONArray()

        // FIX: triggered_by harus berbasis visualLabel="JUDI", bukan sekadar confidence > 0
        val visualPositive = visualLabel.equals("JUDI", ignoreCase = true) 
        val ocrPositive    = ocrWords.length() > 0

        val triggeredBy = when {
            visualPositive && ocrPositive -> "combined"
            ocrPositive                   -> "ocr"
            visualPositive                -> "mobilenet"
            else                          -> "none"
        }

        Log.d(TAG, "parseResponse → is_gambling=$isGambling label=$visualLabel " +
                   "conf=$visualConfidence ocr_words=${ocrWords.length()} trigger=$triggeredBy")

        return JSONObject().apply {
            put("is_gambling",  isGambling)
            put("confidence",   visualConfidence)
            put("triggered_by", triggeredBy)
            put("details", JSONObject().apply {
                put("trustpositif",         false)
                put("mobilenet_confidence", visualConfidence)
                put("ocr_keywords",         ocrWords)
                put("label",                visualLabel)
            })
        }
    }
}
