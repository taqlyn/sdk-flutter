package com.taqlyn.taqlyn_sdk

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/** Smoke test: unknown methods report notImplemented. */
internal class TaqlynSdkPluginTest {
    @Test
    fun onMethodCall_unknown_reportsNotImplemented() {
        val plugin = TaqlynSdkPlugin()
        val call = MethodCall("getPlatformVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)
        Mockito.verify(mockResult).notImplemented()
    }
}
