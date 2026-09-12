package com.nadhalabs.nadhaedu

import android.os.Build
import android.os.StatFs
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.learningplatform/content_protection/methods"
        private const val EVENT_CHANNEL = "com.learningplatform/content_protection/events"
        private const val STORAGE_CHANNEL = "com.learningplatform/storage"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var isProtectionEnabled: Boolean = false
    private var activePolicy: String = "none"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "enableProtection" -> {
                        val policy = call.argument<String>("policy") ?: "blockCaptureWhereSupported"
                        enableScreenProtection(policy)
                        result.success(null)
                    }
                    "disableProtection" -> {
                        disableScreenProtection()
                        result.success(null)
                    }
                    "getCaptureState" -> {
                        result.success(
                            mapOf(
                                "isCaptured" to false,
                                "isProtected" to isProtectionEnabled,
                                "policy" to activePolicy,
                                "platform" to "android"
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAvailableBytes") {
                    result.success(StatFs(filesDir.path).availableBytes)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun enableScreenProtection(policy: String) {
        runOnUiThread {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            isProtectionEnabled = true
            activePolicy = policy
        }
    }

    private fun disableScreenProtection() {
        runOnUiThread {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            isProtectionEnabled = false
            activePolicy = "none"
        }
    }
}
