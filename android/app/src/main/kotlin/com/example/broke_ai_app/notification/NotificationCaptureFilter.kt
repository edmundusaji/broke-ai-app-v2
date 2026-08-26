package com.example.broke_ai_app.notification

import java.nio.charset.StandardCharsets
import java.util.UUID

internal object NotificationCaptureFilter {
    fun looksLikeTransaction(text: String): Boolean {
        if (text.isBlank()) return false
        val hasAmount = Regex("(?i)(?:rp\\s*)?\\d[\\d.,]{2,}").containsMatchIn(text)
        val hasTransactionLanguage = Regex(
            "(?i)bayar|pembayaran|transaksi|transfer|purchase|payment|debit|kredit|berhasil|success|spent|charged|qris|saldo",
        ).containsMatchIn(text)
        return hasAmount && hasTransactionLanguage
    }

    fun captureId(packageName: String, key: String, postTime: Long, text: String): String {
        val fingerprint = listOf(
            packageName,
            key,
            postTime.toString(),
            text.lowercase().replace(Regex("\\s+"), " "),
        ).joinToString("|")
        return UUID.nameUUIDFromBytes(fingerprint.toByteArray(StandardCharsets.UTF_8)).toString()
    }
}
