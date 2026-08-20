package com.mohitkoley.flutter_app_functions

import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunction
import androidx.appfunctions.AppFunctionContext
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint

/**
 * The AppFunctions entry point that this plugin exposes to the Android
 * App Functions runtime.
 *
 * As of `androidx.appfunctions` 1.0.0-alpha10 every `@AppFunction` must be
 * declared inside an abstract [AppFunctionService] annotated with
 * [AppFunctionServiceEntryPoint]. The KSP processor generates the concrete
 * `FlutterAppFunctionsService` subclass named by [AppFunctionServiceEntryPoint.serviceName]
 * (along with its `onExecuteFunction` implementation, which is why this class
 * must not implement it) and the metadata XML named by
 * [AppFunctionServiceEntryPoint.appFunctionXmlFileName]. The generated
 * service is what the plugin's `AndroidManifest.xml` declares.
 *
 * The function body itself stays in [AppFunctionsBridge] so the dispatch and
 * error-mapping logic remains independently testable.
 */
@RequiresApi(36)
@AppFunctionServiceEntryPoint(
    serviceName = "FlutterAppFunctionsService",
    appFunctionXmlFileName = "flutter_app_functions",
)
abstract class BaseFlutterAppFunctionsService : AppFunctionService() {

    private val bridge = AppFunctionsBridge()

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
    ): String = bridge.executeAppFunction(
        appFunctionContext = appFunctionContext,
        functionId = functionId,
        parametersJson = parametersJson,
    )
}
