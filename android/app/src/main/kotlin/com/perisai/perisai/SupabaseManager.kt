package com.perisai.perisai

import org.json.JSONObject
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL

object SupabaseManager {

    private var SUPABASE_URL = "https://YOUR_PROJECT.supabase.co"  // TODO: Ganti dengan Project URL dari SHEVA, contoh: "https://abcdefg.supabase.co"
    private var SERVICE_ROLE_KEY = "YOUR_SERVICE_ROLE_KEY"          // TODO: Ganti dengan Service Role Key dari SHEVA, contoh: "eyJhbGciOiJIUz..." (JANGAN commit ke Git!)

    fun initialize(url: String, key: String) { SUPABASE_URL = url; SERVICE_ROLE_KEY = key }

    fun uploadScreenshot(childId: String, imageBytes: ByteArray): String? {
        return try {
            val timestamp = System.currentTimeMillis() / 1000
            val filePath = "$childId/$timestamp.jpg"
            val url = URL("$SUPABASE_URL/storage/v1/object/screenshots/$filePath")

            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $SERVICE_ROLE_KEY")
            connection.setRequestProperty("Content-Type", "image/jpeg")
            connection.connectTimeout = 15000
            connection.readTimeout = 15000

            val outputStream = DataOutputStream(connection.outputStream)
            outputStream.write(imageBytes)
            outputStream.flush()
            outputStream.close()

            if (connection.responseCode in 200..299) {
                "$SUPABASE_URL/storage/v1/object/public/screenshots/$filePath"
            } else { null }
        } catch (e: Exception) { e.printStackTrace(); null }
    }

    fun insertDetection(data: JSONObject): Boolean {
        return try {
            val url = URL("$SUPABASE_URL/rest/v1/detections")

            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $SERVICE_ROLE_KEY")
            connection.setRequestProperty("apikey", SERVICE_ROLE_KEY)
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "return=minimal")
            connection.connectTimeout = 15000
            connection.readTimeout = 15000

            val outputStream = DataOutputStream(connection.outputStream)
            outputStream.writeBytes(data.toString())
            outputStream.flush()
            outputStream.close()

            connection.responseCode in 200..299
        } catch (e: Exception) { e.printStackTrace(); false }
    }
}
