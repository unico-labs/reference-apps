// Native SDK: https://developer.unico.io/developers/sdks-and-tools/android/capture-flow/user-journeys
// Opens Unico's journey with the process's webAppToken and hands back the processId from onSuccess.
// The journey always runs in the SDK: never in a WebView, Custom Tabs or the system browser.
// Self-contained: the mode imports nothing from the other folders. It takes the SDK built at app load and plain values,
// and returns a processId.
package io.unico.reference.journey.nativesdk

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.LocalActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.acesso.acessobio_android.AcessoBioListener
import com.acesso.acessobio_android.iAcessoBioSelfie
import com.acesso.acessobio_android.onboarding.AcessoBio
import com.acesso.acessobio_android.onboarding.AcessoBioConfigDataSource
import com.acesso.acessobio_android.onboarding.LocaleTypes
import com.acesso.acessobio_android.onboarding.camera.CameraListener
import com.acesso.acessobio_android.onboarding.camera.UnicoCheckCamera
import com.acesso.acessobio_android.onboarding.camera.UnicoCheckCameraOpener
import com.acesso.acessobio_android.onboarding.models.Environment
import com.acesso.acessobio_android.services.dto.ErrorBio
import com.acesso.acessobio_android.services.dto.ResultCamera
import com.acesso.acessobio_android.services.dto.SuccessResult
import kotlinx.coroutines.launch

// https://developer.unico.io/developers/sdks-and-tools/android/error-handling
private const val CAMERA_PERMISSION_DENIED = 73002

private sealed interface JourneyState {
    data object Opening : JourneyState
    data object CameraDenied : JourneyState
    data class Ended(val message: String) : JourneyState
}

// https://developer.unico.io/developers/sdks-and-tools/android/initialization
// Build this once when the app loads, not when the user taps to start: the SDK's authentication with the backend
// takes a few seconds, and doing it together with the camera opening reads as lag. MainActivity builds it in onCreate.
// `environment` must match the hosts the process was created on: Environment.UAT or Environment.PROD.
class NativeSdk(activity: Activity, environment: Environment) {
    // AcessoBio keeps one session listener for its whole life, so it forwards to whichever journey is on screen.
    internal var sessionListener: AcessoBioListener? = null

    internal val camera: UnicoCheckCamera = AcessoBio(activity, object : AcessoBioListener {
        override fun onErrorAcessoBio(errorBio: ErrorBio?) { sessionListener?.onErrorAcessoBio(errorBio) }
        override fun onUserClosedCameraManually() { sessionListener?.onUserClosedCameraManually() }
        override fun onSystemClosedCameraTimeoutSession() { sessionListener?.onSystemClosedCameraTimeoutSession() }
        override fun onSystemChangedTypeCameraTimeoutFaceInference() { sessionListener?.onSystemChangedTypeCameraTimeoutFaceInference() }
    })
        .setEnvironment(environment)
        // https://developer.unico.io/developers/sdks-and-tools/android/initialization (Configuring camera mode)
        .setAutoCapture(true)
        .setSmartFrame(true)
        .setLocale(LocaleTypes.EN_US)
        .build()
}

// https://developer.unico.io/developers/sdks-and-tools/android/initialization (Configuration via AcessoBioConfigDataSource)
class UnicoConfig(private val bundleIdentifier: String, private val sdkKey: String) : AcessoBioConfigDataSource {
    override fun getBundleIdentifier(): String = bundleIdentifier
    override fun getHostKey(): String = sdkKey
}

// `sdkKey` comes from Unico's Onboarding team, linked to `bundleIdentifier`. In a real app that's your own
// application ID (activity.packageName); this demo lets Settings override it.
@Composable
fun NativeSdkJourney(
    webAppToken: String,
    sdkKey: String,
    bundleIdentifier: String,
    sdk: NativeSdk,
    onFinished: (processId: String) -> Unit,
    onBack: () -> Unit,
) {
    val activity = LocalActivity.current ?: return
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf<JourneyState>(JourneyState.Opening) }

    // The SDK calls back on its own threads; state changes and navigation go back to the main thread.
    fun end(message: String) = scope.launch { state = JourneyState.Ended(message) }
    fun describe(errorBio: ErrorBio?) = "SDK error ${errorBio?.code}: ${errorBio?.description}"

    val unicoConfig = UnicoConfig(bundleIdentifier, sdkKey)

    val callback = object : AcessoBioListener {
        override fun onErrorAcessoBio(errorBio: ErrorBio?) {
            if (errorBio?.code == CAMERA_PERMISSION_DENIED) scope.launch { state = JourneyState.CameraDenied }
            else end(describe(errorBio))
        }
        override fun onUserClosedCameraManually() { end("The journey was closed before it finished.") }
        override fun onSystemClosedCameraTimeoutSession() { end("The capture session timed out.") }
        // The SDK switches to manual capture and the journey goes on.
        override fun onSystemChangedTypeCameraTimeoutFaceInference() {}
    }

    // https://developer.unico.io/developers/sdks-and-tools/android/capture-flow/receiving-the-result
    val cameraListener = object : iAcessoBioSelfie {
        override fun onSuccess(result: SuccessResult) { scope.launch { onFinished(result.processId) } }
        override fun onErrorSelfie(errorBio: ErrorBio?) { end(describe(errorBio)) }
        // Required by the SDK interface, never called in this journey: the result comes in onSuccess.
        override fun onSuccessSelfie(result: ResultCamera?) {}
    }

    DisposableEffect(sdk) {
        sdk.sessionListener = callback
        onDispose { sdk.sessionListener = null }
    }

    fun openJourney() {
        state = JourneyState.Opening
        sdk.camera.prepareCamera(unicoConfig, object : CameraListener {
            override fun onCameraReady(cameraOpener: UnicoCheckCameraOpener.Camera?) {
                cameraOpener?.open(cameraListener, webAppToken)
            }
            override fun onCameraFailed(message: String?) { end("Camera failed: $message") }
        })
    }

    // The app asks for the camera before opening the SDK: https://developer.unico.io/developers/sdks-and-tools/android/installation
    val requestCamera = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) openJourney() else state = JourneyState.CameraDenied
    }
    fun start() {
        val granted = activity.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        if (granted) openJourney() else requestCamera.launch(Manifest.permission.CAMERA)
    }

    LaunchedEffect(Unit) { start() }

    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        when (val current = state) {
            JourneyState.Opening -> {
                Text("Opening the journey", style = MaterialTheme.typography.headlineMedium)
                CircularProgressIndicator()
            }
            // Once the user denies the camera for good, Android stops asking, so the way back is the app's settings.
            JourneyState.CameraDenied -> {
                Text("Camera access needed", style = MaterialTheme.typography.headlineMedium)
                Text("The journey takes a selfie. Allow the camera in Settings, then try again.")
                Button(onClick = {
                    activity.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", activity.packageName, null)),
                    )
                }) { Text("Open Settings") }
                OutlinedButton(onClick = ::start) { Text("Try again") }
                OutlinedButton(onClick = onBack) { Text("Back") }
            }
            is JourneyState.Ended -> {
                Text("Journey not finished", style = MaterialTheme.typography.headlineMedium)
                Text(current.message)
                OutlinedButton(onClick = onBack) { Text("Back") }
            }
        }
    }
}
