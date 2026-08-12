package com.taqlyn.taqlyn_sdk

import android.content.Context
import com.taqlyn.sdk.DeferredLink
import com.taqlyn.sdk.LinkProcessingMode
import com.taqlyn.sdk.SdkCore
import com.taqlyn.sdk.SdkOptions
import com.taqlyn.sdk.adapters.IncomingLink
import com.taqlyn.sdk.adapters.InstallReferrer
import com.taqlyn.sdk.adapters.KeyValueStore
import com.taqlyn.sdk.adapters.ResolveClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

/**
 * Flutter MethodChannel/EventChannel → [SdkCore] (Nitro-free).
 * Matching / Install Referrer stay in SdkCore.
 */
object TaqlynFlutterSdkBridge {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var observeJob: Job? = null

    fun configure(
        clientId: String,
        publicKeyId: String,
        apiBaseUrl: String,
        linkProcessingMode: String?,
        env: String?,
        context: Context? = null,
        installReferrer: InstallReferrer? = null,
        resolveClient: ResolveClient? = null,
        store: KeyValueStore? = null,
        incomingLink: IncomingLink? = null,
    ) {
        SdkCore.configure(
            clientId = clientId,
            publicKeyId = publicKeyId,
            options =
                SdkOptions(
                    apiBaseUrl = apiBaseUrl,
                    linkProcessingMode = modeFromWire(linkProcessingMode),
                    env = env,
                ),
            context = context,
            installReferrer = installReferrer,
            resolveClient = resolveClient,
            store = store,
            incomingLink = incomingLink,
        )
    }

    suspend fun resolveDeferred(): Map<String, Any?>? =
        SdkCore.resolveDeferred()?.let { linkToMap(it) }

    fun observeLinks(
        onLink: (Map<String, Any?>) -> Unit,
        onError: (Throwable) -> Unit = {},
    ) {
        observeJob?.cancel()
        observeJob =
            SdkCore
                .observeLinks()
                .onEach { onLink(linkToMap(it)) }
                .catch { onError(it) }
                .launchIn(scope)
    }

    fun stopObserving() {
        observeJob?.cancel()
        observeJob = null
    }

    fun consume(linkId: String) {
        SdkCore.consume(linkId)
    }

    fun setReadyForNavigation(ready: Boolean) {
        SdkCore.setReadyForNavigation(ready)
    }

    fun onIntent(intent: android.content.Intent?) {
        SdkCore.onIntent(intent)
    }

    fun modeFromWire(value: String?): LinkProcessingMode =
        when (value) {
            "webOnly", "web-only", "WEB_ONLY" -> LinkProcessingMode.WEB_ONLY
            "deferredOnly", "deferred-only", "DEFERRED_ONLY" -> LinkProcessingMode.DEFERRED_ONLY
            else -> LinkProcessingMode.ALL
        }

    fun linkToMap(link: DeferredLink): Map<String, Any?> =
        mapOf(
            "url" to link.url,
            "path" to link.path,
            "params" to link.params,
            "linkId" to link.linkId,
            "matchType" to link.matchType.toWire(),
            "isDeferred" to link.isDeferred,
            "campaign" to link.campaign?.values,
        )
}
