package com.example.broke_ai_app.notification

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationCaptureFilterTest {
    @Test
    fun acceptsPaymentNotificationWithAmount() {
        assertTrue(
            NotificationCaptureFilter.looksLikeTransaction(
                "Pembayaran QRIS Rp75.000 ke KFC berhasil",
            ),
        )
    }

    @Test
    fun rejectsPromotionAndAmountlessNotification() {
        assertFalse(NotificationCaptureFilter.looksLikeTransaction("Cashback spesial untukmu"))
        assertFalse(NotificationCaptureFilter.looksLikeTransaction("Pembayaran berhasil"))
    }

    @Test
    fun captureIdIsStableForARepostedNotification() {
        val first = NotificationCaptureFilter.captureId(
            "com.gojek.app",
            "notification-key",
            1_777_000_000L,
            "Pembayaran  Rp25.000 BERHASIL",
        )
        val second = NotificationCaptureFilter.captureId(
            "com.gojek.app",
            "notification-key",
            1_777_000_000L,
            "pembayaran rp25.000 berhasil",
        )
        assertEquals(first, second)
    }
}
