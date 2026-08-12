package com.taqlyn.taqlyn_sdk

import android.content.Intent
import android.net.Uri
import com.google.common.truth.Truth.assertThat
import com.taqlyn.sdk.Campaign
import com.taqlyn.sdk.DeferredLink
import com.taqlyn.sdk.MatchType
import com.taqlyn.sdk.SdkCore
import com.taqlyn.sdk.adapters.InMemoryKeyValueStore
import com.taqlyn.sdk.adapters.InstallReferrer
import com.taqlyn.sdk.adapters.IntentIncomingLink
import com.taqlyn.sdk.adapters.ResolveClient
import com.taqlyn.sdk.adapters.ResolveOutcome
import com.taqlyn.sdk.adapters.ResolveRequest
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Closes Phase 08 deferred/warm risk for the Flutter Android bridge:
 * fake Install Referrer + sandbox-shaped ResolveClient → SdkCore.
 */
@RunWith(RobolectricTestRunner::class)
class TaqlynFlutterSdkBridgeTest {
    private val store = InMemoryKeyValueStore()
    private val incoming = IntentIncomingLink()

    @After
    fun tearDown() {
        TaqlynFlutterSdkBridge.stopObserving()
        SdkCore.resetForTests()
    }

    @Test
    fun deferredResolve_sandboxPayload_readyGate_andConsume() =
        runTest {
            configureBridge(
                referrer = "click_id=clk_sandbox",
                resolve = { ResolveOutcome.Matched(sampleLink("lnk_sandbox")) },
            )

            val received = CopyOnWriteArrayList<Map<String, Any?>>()
            TaqlynFlutterSdkBridge.observeLinks(onLink = { received.add(it) })

            val resolved = TaqlynFlutterSdkBridge.resolveDeferred()
            assertThat(resolved?.get("linkId")).isEqualTo("lnk_sandbox")
            assertThat(resolved?.get("matchType")).isEqualTo("install_referrer")
            assertThat(resolved?.get("isDeferred")).isEqualTo(true)
            assertThat(received).isEmpty()

            TaqlynFlutterSdkBridge.setReadyForNavigation(true)
            withTimeout(2_000) {
                while (received.isEmpty()) {
                    kotlinx.coroutines.yield()
                }
            }
            assertThat(received).hasSize(1)
            assertThat(received[0]["path"]).isEqualTo("/offer")

            TaqlynFlutterSdkBridge.consume("lnk_sandbox")
            assertThat(SdkCore.pendingForTests()).isNull()
        }

    @Test
    fun warmAppLink_deliveredWithoutReadyGate() =
        runTest {
            configureBridge(
                referrer = null,
                resolve = { error("warm must not resolve") },
            )

            val latch = CountDownLatch(1)
            val received = CopyOnWriteArrayList<Map<String, Any?>>()
            TaqlynFlutterSdkBridge.observeLinks(onLink = {
                received.add(it)
                latch.countDown()
            })

            val uri = Uri.parse("https://links.example.com/product/9?linkId=warm_1")
            TaqlynFlutterSdkBridge.onIntent(Intent(Intent.ACTION_VIEW, uri))

            assertThat(latch.await(2, TimeUnit.SECONDS)).isTrue()
            assertThat(received).hasSize(1)
            assertThat(received[0]["isDeferred"]).isEqualTo(false)
            assertThat(received[0]["path"]).isEqualTo("/product/9")
        }

    private fun configureBridge(
        referrer: String?,
        resolve: suspend (ResolveRequest) -> ResolveOutcome,
    ) {
        TaqlynFlutterSdkBridge.configure(
            clientId = "app_test",
            publicKeyId = "pk_test",
            apiBaseUrl = "https://api.sandbox.example.com",
            linkProcessingMode = "all",
            env = "sandbox",
            context = null,
            installReferrer = InstallReferrer { referrer },
            resolveClient = ResolveClient { resolve(it) },
            store = store,
            incomingLink = incoming,
        )
    }

    private fun sampleLink(id: String) =
        DeferredLink(
            url = "https://app.example.com/offer?id=1",
            path = "/offer",
            params = mapOf("id" to "1"),
            linkId = id,
            matchType = MatchType.INSTALL_REFERRER,
            isDeferred = true,
            campaign = Campaign(mapOf("utm_source" to "sandbox")),
        )
}
