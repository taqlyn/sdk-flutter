package com.taqlyn.taqlyn_sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Flutter embedding → [TaqlynFlutterSdkBridge] → SdkCore.
 * App Dart code never sees Install Referrer types.
 */
class TaqlynSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener,
    EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context
    private var activityBinding: ActivityPluginBinding? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "taqlyn_sdk")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "taqlyn_sdk/links")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        when (call.method) {
            "configure" -> {
                try {
                    val clientId = call.argument<String>("clientId") ?: ""
                    val publicKeyId = call.argument<String>("publicKeyId") ?: ""
                    val optionsMap = call.argument<Map<String, Any?>>("options") ?: emptyMap()
                    val apiBaseUrl = optionsMap["apiBaseUrl"] as? String ?: ""
                    val modeWire = optionsMap["linkProcessingMode"] as? String
                    val env = optionsMap["env"] as? String
                    TaqlynFlutterSdkBridge.configure(
                        clientId = clientId,
                        publicKeyId = publicKeyId,
                        apiBaseUrl = apiBaseUrl,
                        linkProcessingMode = modeWire,
                        env = env,
                        context = appContext,
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("configure_failed", e.message, null)
                }
            }
            "resolveDeferred" -> {
                scope.launch {
                    try {
                        result.success(TaqlynFlutterSdkBridge.resolveDeferred())
                    } catch (e: Exception) {
                        result.error("resolve_failed", e.message, null)
                    }
                }
            }
            "consume" -> {
                val linkId = call.argument<String>("linkId") ?: ""
                TaqlynFlutterSdkBridge.consume(linkId)
                result.success(null)
            }
            "setReadyForNavigation" -> {
                val ready = call.argument<Boolean>("ready") ?: false
                TaqlynFlutterSdkBridge.setReadyForNavigation(ready)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        eventSink = events
        TaqlynFlutterSdkBridge.observeLinks(
            onLink = { eventSink?.success(it) },
            onError = { err -> eventSink?.error("observe_failed", err.message, null) },
        )
    }

    override fun onCancel(arguments: Any?) {
        TaqlynFlutterSdkBridge.stopObserving()
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        TaqlynFlutterSdkBridge.stopObserving()
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addOnNewIntentListener(this)
        TaqlynFlutterSdkBridge.onIntent(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        TaqlynFlutterSdkBridge.onIntent(intent)
        val activity: Activity? = activityBinding?.activity
        activity?.intent = intent
        return false
    }
}
