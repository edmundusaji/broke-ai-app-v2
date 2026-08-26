package com.example.broke_ai_app.notification

object NotificationCaptureContract {
    const val CHANNEL = "broke.ai/notification_capture"
    const val WORK_TAG = "broke-notification-capture"

    val supportedSources = linkedMapOf(
        "com.gojek.app" to "Gojek / GoPay",
        "com.gojek.gopay" to "GoPay",
        "ovo.id" to "OVO",
        "id.dana" to "DANA",
        "com.bca" to "BCA mobile",
        "com.bca.mybca.omni.android" to "myBCA",
        "src.com.bni" to "BNI mobile",
        "id.bni.wondr" to "wondr by BNI",
        "id.co.bri.brimo" to "BRImo",
    )
}
