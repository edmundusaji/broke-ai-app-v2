package com.example.broke_ai_app

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.example.broke_ai_app.notification.NotificationCaptureContract
import com.example.broke_ai_app.notification.NotificationCaptureStore
import com.example.broke_ai_app.notification.NotificationUploadWorker
import com.example.broke_ai_app.notification.WalletNotificationListenerService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NotificationCaptureContract.CHANNEL,
        ).setMethodCallHandler { call, result ->
            val store = NotificationCaptureStore(applicationContext)
            try {
                when (call.method) {
                    "getStatus" -> result.success(
                        store.status() + mapOf(
                            "supported" to true,
                            "accessGranted" to listenerAccessGranted(),
                            "supportedSources" to NotificationCaptureContract.supportedSources.map {
                                mapOf("packageName" to it.key, "name" to it.value)
                            },
                        ),
                    )
                    "setConsent" -> {
                        store.setConsent(call.argument<Boolean>("accepted") == true)
                        result.success(null)
                    }
                    "openSettings" -> {
                        openNotificationListenerSettings()
                        result.success(null)
                    }
                    "configure" -> {
                        val sources = call.argument<List<String>>("selectedSources").orEmpty()
                            .filter { it in NotificationCaptureContract.supportedSources }
                            .toSet()
                        store.configure(
                            enabled = call.argument<Boolean>("enabled") == true,
                            baseUrl = requireNotNull(call.argument<String>("baseUrl")),
                            credential = requireNotNull(call.argument<String>("credential")),
                            deviceId = requireNotNull(call.argument<String>("deviceId")),
                            selectedSources = sources,
                        )
                        NotificationUploadWorker.enqueuePending(applicationContext)
                        result.success(null)
                    }
                    "updateSources" -> {
                        val sources = call.argument<List<String>>("selectedSources").orEmpty()
                            .filter { it in NotificationCaptureContract.supportedSources }
                            .toSet()
                        store.updateSources(sources)
                        result.success(null)
                    }
                    "retryPending" -> {
                        NotificationUploadWorker.enqueuePending(applicationContext)
                        result.success(null)
                    }
                    "clear" -> {
                        NotificationUploadWorker.cancelAll(applicationContext)
                        store.clear(clearConsent = call.argument<Boolean>("clearConsent") == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("NOTIFICATION_CAPTURE_ERROR", error.message, null)
            }
        }
    }

    private fun listenerAccessGranted(): Boolean {
        val component = ComponentName(this, WalletNotificationListenerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val manager = getSystemService(NotificationManager::class.java)
            return manager.isNotificationListenerAccessGranted(component)
        }
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ).orEmpty()
        return enabled.split(':')
            .mapNotNull(ComponentName::unflattenFromString)
            .any { it == component }
    }

    private fun openNotificationListenerSettings() {
        val component = ComponentName(this, WalletNotificationListenerService::class.java)
        val detailIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, component.flattenToString())
            }
        } else null
        val fallback = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        val selected = detailIntent?.takeIf { it.resolveActivity(packageManager) != null }
            ?: fallback.takeIf { it.resolveActivity(packageManager) != null }
            ?: Intent(Settings.ACTION_SETTINGS)
        startActivity(selected)
    }
}
