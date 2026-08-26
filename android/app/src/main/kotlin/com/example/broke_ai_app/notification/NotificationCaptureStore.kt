package com.example.broke_ai_app.notification

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Base64

internal data class QueuedCapture(
    val id: String,
    val sourcePackage: String,
    val notificationPostedAt: String,
    val text: String,
    val createdAt: Long,
)

internal data class CaptureConfiguration(
    val enabled: Boolean,
    val baseUrl: String?,
    val credential: String?,
    val deviceId: String?,
    val selectedSources: Set<String>,
)

internal class NotificationCaptureStore(context: Context) {
    private val applicationContext = context.applicationContext
    private val preferences = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val database = CaptureDatabase(applicationContext)

    fun configuration(): CaptureConfiguration {
        val credential = decryptPreference(CREDENTIAL_CIPHERTEXT, CREDENTIAL_IV)
        return CaptureConfiguration(
            enabled = preferences.getBoolean(ENABLED, false),
            baseUrl = preferences.getString(BASE_URL, null),
            credential = credential,
            deviceId = preferences.getString(DEVICE_ID, null),
            selectedSources = preferences.getStringSet(SOURCES, emptySet())?.toSet() ?: emptySet(),
        )
    }

    fun configure(
        enabled: Boolean,
        baseUrl: String,
        credential: String,
        deviceId: String,
        selectedSources: Set<String>,
    ) {
        val encrypted = NotificationCaptureCrypto.encrypt(credential.toByteArray(Charsets.UTF_8))
        preferences.edit()
            .putBoolean(ENABLED, enabled)
            .putString(BASE_URL, normalizeBaseUrl(baseUrl))
            .putString(DEVICE_ID, deviceId)
            .putStringSet(SOURCES, selectedSources)
            .putString(CREDENTIAL_CIPHERTEXT, Base64.encodeToString(encrypted.ciphertext, Base64.NO_WRAP))
            .putString(CREDENTIAL_IV, Base64.encodeToString(encrypted.iv, Base64.NO_WRAP))
            .putBoolean(NEEDS_RECONNECT, false)
            .remove(LAST_ERROR)
            .apply()
    }

    fun setConsent(accepted: Boolean) {
        preferences.edit().putBoolean(CONSENT, accepted).apply()
    }

    fun consentAccepted(): Boolean = preferences.getBoolean(CONSENT, false)

    fun updateSources(sources: Set<String>) {
        preferences.edit().putStringSet(SOURCES, sources).apply()
    }

    fun enqueue(capture: QueuedCapture) {
        val encrypted = NotificationCaptureCrypto.encrypt(capture.text.toByteArray(Charsets.UTF_8))
        val values = ContentValues().apply {
            put("id", capture.id)
            put("source_package", capture.sourcePackage)
            put("notification_posted_at", capture.notificationPostedAt)
            put("ciphertext", encrypted.ciphertext)
            put("iv", encrypted.iv)
            put("created_at", capture.createdAt)
        }
        database.writableDatabase.insertWithOnConflict(
            "notification_capture_queue",
            null,
            values,
            SQLiteDatabase.CONFLICT_IGNORE,
        )
        trimQueue()
    }

    fun capture(id: String): QueuedCapture? {
        val cursor = database.readableDatabase.query(
            "notification_capture_queue",
            arrayOf("id", "source_package", "notification_posted_at", "ciphertext", "iv", "created_at"),
            "id = ?",
            arrayOf(id),
            null,
            null,
            null,
            "1",
        )
        cursor.use {
            if (!it.moveToFirst()) return null
            return try {
                QueuedCapture(
                    id = it.getString(0),
                    sourcePackage = it.getString(1),
                    notificationPostedAt = it.getString(2),
                    text = NotificationCaptureCrypto.decrypt(it.getBlob(3), it.getBlob(4)).toString(Charsets.UTF_8),
                    createdAt = it.getLong(5),
                )
            } catch (_: Exception) {
                delete(id)
                null
            }
        }
    }

    fun pendingIds(): List<String> {
        purgeExpired()
        val ids = mutableListOf<String>()
        database.readableDatabase.query(
            "notification_capture_queue",
            arrayOf("id"),
            null,
            null,
            null,
            null,
            "created_at ASC",
        ).use { cursor ->
            while (cursor.moveToNext()) ids += cursor.getString(0)
        }
        return ids
    }

    fun queueCount(): Int {
        purgeExpired()
        database.readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM notification_capture_queue",
            null,
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }
    }

    fun delete(id: String) {
        database.writableDatabase.delete("notification_capture_queue", "id = ?", arrayOf(id))
    }

    fun markTerminal(result: String, error: String? = null) {
        preferences.edit()
            .putString(LAST_RESULT, result)
            .putLong(LAST_SUCCESS_AT, System.currentTimeMillis())
            .apply {
                if (error == null) remove(LAST_ERROR) else putString(LAST_ERROR, error)
            }
            .apply()
    }

    fun markReconnect(error: String) {
        preferences.edit()
            .putBoolean(NEEDS_RECONNECT, true)
            .putString(LAST_ERROR, error)
            .apply()
    }

    fun markError(error: String) {
        preferences.edit().putString(LAST_ERROR, error).apply()
    }

    fun status(): Map<String, Any?> = mapOf(
        "enabled" to configuration().enabled,
        "consentAccepted" to consentAccepted(),
        "selectedSources" to configuration().selectedSources.toList(),
        "queueCount" to queueCount(),
        "lastSuccessAt" to preferences.getLong(LAST_SUCCESS_AT, 0L).takeIf { it > 0 },
        "lastResult" to preferences.getString(LAST_RESULT, null),
        "lastError" to preferences.getString(LAST_ERROR, null),
        "needsReconnect" to preferences.getBoolean(NEEDS_RECONNECT, false),
        "deviceId" to configuration().deviceId,
    )

    fun clear(clearConsent: Boolean = false) {
        database.writableDatabase.delete("notification_capture_queue", null, null)
        val editor = preferences.edit().clear()
        if (!clearConsent && consentAccepted()) editor.putBoolean(CONSENT, true)
        editor.apply()
        NotificationCaptureCrypto.deleteKey()
    }

    private fun decryptPreference(ciphertextKey: String, ivKey: String): String? {
        val ciphertext = preferences.getString(ciphertextKey, null) ?: return null
        val iv = preferences.getString(ivKey, null) ?: return null
        return try {
            NotificationCaptureCrypto.decrypt(
                Base64.decode(ciphertext, Base64.NO_WRAP),
                Base64.decode(iv, Base64.NO_WRAP),
            ).toString(Charsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    private fun normalizeBaseUrl(value: String): String = if (value.endsWith('/')) value else "$value/"

    private fun purgeExpired() {
        val oldest = System.currentTimeMillis() - MAX_AGE_MILLIS
        database.writableDatabase.delete("notification_capture_queue", "created_at < ?", arrayOf(oldest.toString()))
    }

    private fun trimQueue() {
        database.writableDatabase.execSQL(
            "DELETE FROM notification_capture_queue WHERE id IN (" +
                "SELECT id FROM notification_capture_queue ORDER BY created_at DESC LIMIT -1 OFFSET $MAX_QUEUE_SIZE)",
        )
    }

    private class CaptureDatabase(context: Context) :
        SQLiteOpenHelper(context, "notification_capture.db", null, 1) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE notification_capture_queue (
                    id TEXT PRIMARY KEY,
                    source_package TEXT NOT NULL,
                    notification_posted_at TEXT NOT NULL,
                    ciphertext BLOB NOT NULL,
                    iv BLOB NOT NULL,
                    created_at INTEGER NOT NULL
                )
                """.trimIndent(),
            )
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    }

    companion object {
        private const val PREFS = "notification_capture_preferences"
        private const val ENABLED = "enabled"
        private const val CONSENT = "consent"
        private const val BASE_URL = "base_url"
        private const val DEVICE_ID = "device_id"
        private const val SOURCES = "sources"
        private const val CREDENTIAL_CIPHERTEXT = "credential_ciphertext"
        private const val CREDENTIAL_IV = "credential_iv"
        private const val NEEDS_RECONNECT = "needs_reconnect"
        private const val LAST_SUCCESS_AT = "last_success_at"
        private const val LAST_RESULT = "last_result"
        private const val LAST_ERROR = "last_error"
        private const val MAX_QUEUE_SIZE = 100
        private const val MAX_AGE_MILLIS = 7L * 24L * 60L * 60L * 1000L
    }
}
