package com.mohitkoley.flutter_app_functions

import androidx.annotation.VisibleForTesting
import androidx.appfunctions.AppFunctionAppUnknownException
import androidx.appfunctions.AppFunctionContext
import androidx.appfunctions.AppFunctionDisabledException
import androidx.appfunctions.AppFunctionElementNotFoundException
import androidx.appfunctions.AppFunctionException
import androidx.appfunctions.AppFunctionFunctionNotFoundException
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionNotSupportedException
import androidx.appfunctions.AppFunctionPermissionRequiredException
import androidx.appfunctions.AppFunction
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The single App Function entry point that this plugin exposes to the
 * Android App Functions runtime.
 *
 * The Dart side of the plugin maintains a registry of `functionId`s and
 * their corresponding handlers. When the agent (e.g. Gemini) invokes this
 * function, the requested [functionId] and a JSON-encoded [parametersJson]
 * blob are forwarded to Dart. The Dart handler decodes the parameters
 * against its declared schema, executes the user's logic, and returns a
 * JSON-encoded result (or the string `null` for `void` returns).
 *
 * KSP does not permit `AppFunctionData` to be used as a parameter type on
 * a `@AppFunction` (only primitives and `List<String>` are allowed), so
 * the wire format is JSON-in / JSON-out strings. The Dart side is
 * responsible for all parameter/return value type marshaling.
 *
 * Errors thrown on the Dart side are mapped to typed
 * `androidx.appfunctions.AppFunction*Exception` subclasses so the
 * platform sees the same error model it would for a native App Function.
 */
class AppFunctionsBridge {

    /**
     * Dispatch an App Function call to the Flutter side.
     *
     * @param appFunctionContext The context of this App Function call.
     * @param functionId The id of the Flutter-registered function to invoke.
     *   Must match a function previously registered via
     *   `FlutterAppFunctions.instance.register(...)`.
     * @param parametersJson A JSON object string whose keys are the
     *   declared parameter names of the target function and whose values
     *   are the JSON-encoded parameter values. May be `{}` for functions
     *   that take no parameters.
     * @return A JSON-encoded scalar value, array, or `null` if the target
     *   function returns `void`.
     */
    @AppFunction(isDescribedByKDoc = true)
    suspend fun executeAppFunction(
        appFunctionContext: AppFunctionContext,
        functionId: String,
        parametersJson: String,
    ): String {
        if (functionId.isBlank()) {
            throw AppFunctionInvalidArgumentException("functionId must not be blank")
        }

        val deferredResult = CompletableDeferred<String?>()

        withContext(Dispatchers.Main) {
            val activeChannel = FlutterAppFunctionsPlugin.channel
            if (activeChannel == null) {
                deferredResult.completeExceptionally(
                    AppFunctionDisabledException(
                        "Flutter engine channel is not active or has been detached",
                    ),
                )
                return@withContext
            }

            val arguments = mapOf<String, Any?>(
                "functionId" to functionId,
                "parametersJson" to parametersJson,
            )

            activeChannel.invokeMethod(
                "invokeAppFunction",
                arguments,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        deferredResult.complete(result as? String)
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                        deferredResult.completeExceptionally(
                            mapErrorCodeToException(
                                errorCode = errorCode,
                                errorMessage = errorMessage,
                            ),
                        )
                    }

                    override fun notImplemented() {
                        deferredResult.completeExceptionally(
                            AppFunctionNotSupportedException(
                                "The Flutter app did not implement the invokeAppFunction method",
                            ),
                        )
                    }
                },
            )
        }

        return try {
            deferredResult.await() ?: NULL_RESULT
        } catch (e: AppFunctionException) {
            throw e
        } catch (e: Exception) {
            throw AppFunctionAppUnknownException(e.message ?: e::class.java.simpleName)
        }
    }

    /**
     * Maps a `PlatformException` error code thrown by the Dart side to
     * the matching `androidx.appfunctions.AppFunction*Exception` subclass.
     *
     * Exposed at `internal` visibility for future instrumentation tests.
     * Plain-JVM unit tests cannot exercise this helper because the
     * alpha08 `AppFunction*Exception` constructors touch
     * `android.os.Bundle.EMPTY`, which is only initialised inside a real
     * Android runtime; the integration test in `example/integration_test`
     * covers the full Dart -> Kotlin mapping on a running device.
     */
    @VisibleForTesting
    internal fun mapErrorCodeToException(
        errorCode: String,
        errorMessage: String?,
    ): AppFunctionException {
        val message = errorMessage ?: errorCode
        return when (errorCode) {
            "AppFunctionInvalidArgument" ->
                AppFunctionInvalidArgumentException(message)
            "AppFunctionElementNotFound" ->
                AppFunctionElementNotFoundException(message)
            "AppFunctionFunctionNotFound" ->
                AppFunctionFunctionNotFoundException(message)
            "AppFunctionNotSupported" ->
                AppFunctionNotSupportedException(message)
            "AppFunctionPermissionRequired" ->
                AppFunctionPermissionRequiredException(message)
            "AppFunctionDisabled" ->
                AppFunctionDisabledException(message)
            "AppFunctionAppUnknown" ->
                AppFunctionAppUnknownException(message)
            else -> AppFunctionAppUnknownException(
                "Unhandled error from Dart side [$errorCode]: $message",
            )
        }
    }

    private companion object {
        const val NULL_RESULT = "null"
    }
}
