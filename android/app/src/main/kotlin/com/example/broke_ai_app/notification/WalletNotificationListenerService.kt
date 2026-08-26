package com.example.broke_ai_app.notification

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class WalletNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(notification: StatusBarNotification) {
        val store = NotificationCaptureStore(applicationContext)
        val configuration = store.configuration()
        if (!configuration.enabled || notification.packageName !in configuration.selectedSources) return
        if (notification.packageName == packageName) return

        val extras = notification.notification.extras ?: return
        val text = listOf(
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString(),
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
        )
            .mapNotNull { it?.trim()?.takeIf(String::isNotEmpty) }
            .distinct()
            .joinToString("\n")
            .take(4000)
        if (!NotificationCaptureFilter.looksLikeTransaction(text)) return

        val captureId = NotificationCaptureFilter.captureId(
            notification.packageName,
            notification.key,
            notification.postTime,
            text,
        )
        store.enqueue(
            QueuedCapture(
                id = captureId,
                sourcePackage = notification.packageName,
                notificationPostedAt = isoTimestamp(notification.postTime),
                text = text,
                createdAt = System.currentTimeMillis(),
            ),
        )
        NotificationUploadWorker.enqueue(applicationContext, captureId)
    }

    private fun isoTimestamp(milliseconds: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(milliseconds))

}
