package com.mohitkoley.flutter_app_functions

import androidx.appfunctions.AppFunctionContext
import androidx.appfunctions.service.AppFunction
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AgentTools {

    /**
     * Executes a dynamic tool mapping down into the Flutter engine runtime environment.
     * @param toolName The identity matching the targeted tool implementation.
     * @param parametersJson Structured attributes serialized to string formats.
     */
    @AppFunction(isDescribedByKDoc = true)
    suspend fun executeDartTool(
        context: AppFunctionContext, 
        toolName: String, 
        parametersJson: String
    ): String {
        // Create a deferred promise to coordinate between thread bounds
        val deferredResult = CompletableDeferred<String>()

        // Switch execution context strictly over to the Main/UI thread for the Flutter Engine
        withContext(Dispatchers.Main) {
            val activeChannel = FlutterAppFunctionsPlugin.channel
            if (activeChannel == null) {
                deferredResult.complete("Error: Flutter Engine channel is not active or detached.")
                return@withContext
            }

            val arguments = mapOf(
                "toolName" to toolName,
                "parametersJson" to parametersJson
            )

            // Invoke the Dart side channel implementation
            activeChannel.invokeMethod("onInvokeAgentTool", arguments, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    deferredResult.complete(result?.toString() ?: "Success")
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    deferredResult.complete("Error [$errorCode]: $errorMessage")
                }

                override fun notImplemented() {
                    deferredResult.complete("Error: Method not implemented on Dart layer.")
                }
            })
        }

        // Suspend execution until the deferred promise resolves via Dart return
        return deferredResult.await()
    }
}
