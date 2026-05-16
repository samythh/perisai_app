package com.perisai.perisai

import android.util.Log
import org.json.JSONObject
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL

object SupabaseManager {

    private const val TAG = "PERISAI/Supabase"

    private var SUPABASE_URL = "https://dmjyqhlmswxrilofzpjx.supabase.co"
    private var SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtanlxaGxtc3d4cmlsb2Z6cGp4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3ODg3NDUxMywiZXhwIjoyMDk0NDUwNTEzfQ.cTNXMM4p_VMDyA2sd0ZysLpmOy6UYjTLmbhc0GwjOZk"

    fun initialize(url: String, key: String) {
        SUPABASE_URL = url
        SERVICE_ROLE_KEY = key
    }

    fun uploadScreenshot(childId: String, imageBytes: ByteArray): String? {
        if (childId.isBlank()) {
            Log.e(TAG, "uploadScreenshot abort — child_id blank")
            return null
        }

        val timestamp = System.currentTimeMillis() / 1000
        val filePath = "$childId/$timestamp.jpg"
        val uploadUrl = "$SUPABASE_URL/storage/v1/object/screenshots/$filePath"
        Log.d(TAG, "upload start path=$filePath bytes=${imageBytes.size}")

        var connection: HttpURLConnection? = null
        return try {
            val url = URL(uploadUrl)
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $SERVICE_ROLE_KEY")
            connection.setRequestProperty("apikey", SERVICE_ROLE_KEY)
            connection.setRequestProperty("Content-Type", "image/jpeg")
            connection.setRequestProperty("x-upsert", "true")
            connection.connectTimeout = 15000
            connection.readTimeout = 15000

            val outputStream = DataOutputStream(connection.outputStream)
            outputStream.write(imageBytes)
            outputStream.flush()
            outputStream.close()

            val code = connection.responseCode
            if (code in 200..299) {
                val publicUrl = "$SUPABASE_URL/storage/v1/object/public/screenshots/$filePath"
                Log.d(TAG, "upload OK code=$code → $publicUrl")
                publicUrl
            } else {
                val errorBody = try {
                    connection.errorStream?.bufferedReader()?.readText() ?: "<no body>"
                } catch (e: Exception) { "<err reading error: ${e.message}>" }
                Log.e(TAG, "upload FAIL code=$code body=$errorBody")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "upload exception: ${e.message}", e)
            null
        } finally {
            connection?.disconnect()
        }
    }

    fun insertDetection(data: JSONObject): Boolean {
        Log.d(TAG, "insertDetection payload=$data")

        var connection: HttpURLConnection? = null
        return try {
            val url = URL("$SUPABASE_URL/rest/v1/detections")
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $SERVICE_ROLE_KEY")
            connection.setRequestProperty("apikey", SERVICE_ROLE_KEY)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "return=minimal")
            connection.connectTimeout = 15000
            connection.readTimeout = 15000

            val outputStream = DataOutputStream(connection.outputStream)
            outputStream.write(data.toString().toByteArray(Charsets.UTF_8))
            outputStream.flush()
            outputStream.close()

            val code = connection.responseCode
            if (code in 200..299) {
                Log.d(TAG, "insertDetection OK code=$code")
                true
            } else {
                val errorBody = try {
                    connection.errorStream?.bufferedReader()?.readText() ?: "<no body>"
                } catch (e: Exception) { "<err reading error: ${e.message}>" }
                Log.e(TAG, "insertDetection FAIL code=$code body=$errorBody")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "insertDetection exception: ${e.message}", e)
            false
        } finally {
            connection?.disconnect()
        }
    }
}
