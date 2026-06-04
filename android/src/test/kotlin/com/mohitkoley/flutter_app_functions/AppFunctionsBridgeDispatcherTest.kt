package com.mohitkoley.flutter_app_functions

import android.content.Context
import androidx.appfunctions.AppFunctionContext
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import java.nio.ByteBuffer
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

@OptIn(ExperimentalCoroutinesApi::class)
internal class AppFunctionsBridgeDispatcherTest {
    private val dispatcher = StandardTestDispatcher()

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @AfterTest
    fun tearDown() {
        FlutterAppFunctionsPlugin.channel = null
        Dispatchers.resetMain()
    }

    @Test
    fun executeAppFunction_dispatchesThroughMainDispatcherToFlutterChannel() = runTest(dispatcher) {
        val messenger = FakeBinaryMessenger()
        val methodChannel = MethodChannel(messenger, "flutter_app_functions_channel")
        FlutterAppFunctionsPlugin.channel = methodChannel

        val bridge = AppFunctionsBridge()
        val appFunctionContext = object : AppFunctionContext {
            override val context: Context
                get() = throw UnsupportedOperationException("Context is not used by this test")
        }

        val response = bridge.executeAppFunction(
            appFunctionContext = appFunctionContext,
            functionId = "createTask",
            parametersJson = """{"title":"Buy milk"}""",
        )

        assertEquals(""""created"""", response)
        assertEquals(1, messenger.callCount)
    }

    private class FakeBinaryMessenger : BinaryMessenger {
        var callCount = 0

        override fun send(channel: String, message: ByteBuffer?) {
            send(channel, message, null)
        }

        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?,
        ) {
            callCount += 1
            assertEquals("flutter_app_functions_channel", channel)

            val encodedCall = requireNotNull(message)
            encodedCall.rewind()
            val call: MethodCall = StandardMethodCodec.INSTANCE.decodeMethodCall(encodedCall)
            assertEquals("invokeAppFunction", call.method)

            val arguments = (call.arguments as Map<*, *>)
            assertEquals("createTask", arguments["functionId"])
            assertEquals("""{"title":"Buy milk"}""", arguments["parametersJson"])

            val reply = StandardMethodCodec.INSTANCE.encodeSuccessEnvelope(""""created"""")
            reply.rewind()
            callback?.reply(reply)
        }

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
        ) {
            // Incoming host-to-Flutter messages are not used by this dispatcher test.
        }
    }
}
