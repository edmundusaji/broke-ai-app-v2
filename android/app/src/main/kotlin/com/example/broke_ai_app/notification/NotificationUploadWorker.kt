package com.example.broke_ai_app.notification

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class NotificationUploadWorker(
    appContext: Context,
    parameters: WorkerParameters,
) : CoroutineWorker(appContext, parameters) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val captureId = inputData.getString(KEY_CAPTURE_ID) ?: return@withContext Result.failure()
        val store = NotificationCaptureStore(applicationContext)
        val capture = store.capture(captureId) ?: return@withContext Result.success()
        val configuration = store.configuration()
        if (!configuration.enabled) return@withContext Result.failure()
        val baseUrl = configuration.baseUrl
        val credential = configuration.credential
        if (baseUrl.isNullOrBlank() || credential.isNullOrBlank()) {
            store.markReconnect("Open Broke.AI to reconnect notification capture.")
            return@withContext Result.failure()
        }

        var connection: HttpURLConnection? = null
        try {
            connection = URL("${baseUrl}expense/notification").openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $credential")
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            val body = JSONObject()
                .put("text", capture.text)
                .put("captureId", capture.id)
                .put("captureMode", "AUTOMATIC")
                .put("sourcePackage", capture.sourcePackage)
                .put("notificationPostedAt", capture.notificationPostedAt)
                .toString()
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }

            val statusCode = connection.responseCode
            val responseText = runCatching {
                val stream = if (statusCode in 200..299) connection.inputStream else connection.errorStream
                stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            }.getOrDefault("")
            when {
                statusCode in 200..299 -> {
                    val status = runCatching { JSONObject(responseText).optString("status") }
                        .getOrDefault("SAVED")
                        .ifBlank { "SAVED" }
                    store.delete(capture.id)
                    store.markTerminal(status)
                    Result.success()
                }
                statusCode == HttpURLConnection.HTTP_UNAUTHORIZED -> {
                    store.markReconnect(errorMessage(responseText) ?: "Open Broke.AI to reconnect notification capture.")
                    Result.failure()
                }
                statusCode == 408 || statusCode == 429 || statusCode >= 500 -> {
                    store.markError(errorMessage(responseText) ?: "Capture upload will retry automatically.")
                    Result.retry()
                }
                else -> {
                    store.delete(capture.id)
                    store.markTerminal("FAILED", errorMessage(responseText) ?: "This notification could not be processed.")
                    Result.failure()
                }
            }
        } catch (_: Exception) {
            store.markError("Waiting for a connection to upload captured expenses.")
            Result.retry()
        } finally {
            connection?.disconnect()
        }
    }

    private fun errorMessage(body: String): String? = runCatching {
        val json = JSONObject(body)
        json.optJSONObject("error")?.optString("message")?.takeIf { it.isNotBlank() }
            ?: json.optString("message").takeIf { it.isNotBlank() }
    }.getOrNull()

    companion object {
        private const val KEY_CAPTURE_ID = "capture_id"

        fun enqueue(context: Context, captureId: String) {
            val request = OneTimeWorkRequestBuilder<NotificationUploadWorker>()
                .setInputData(Data.Builder().putString(KEY_CAPTURE_ID, captureId).build())
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .addTag(NotificationCaptureContract.WORK_TAG)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                "${NotificationCaptureContract.WORK_TAG}-$captureId",
                ExistingWorkPolicy.KEEP,
                request,
            )
        }

        fun enqueuePending(context: Context) {
            NotificationCaptureStore(context).pendingIds().forEach { enqueue(context, it) }
        }

        fun cancelAll(context: Context) {
            WorkManager.getInstance(context).cancelAllWorkByTag(NotificationCaptureContract.WORK_TAG)
        }
    }
}
