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
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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

// `sdkKey` comes from Unico's Onboarding team, linked to this build's application ID (activity.packageName).
// `flow` and `processId` are only shown on the page behind the camera.
@Composable
fun NativeSdkJourney(
    webAppToken: String,
    flow: String,
    processId: String,
    sdkKey: String,
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

    val unicoConfig = UnicoConfig(activity.packageName, sdkKey)

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

    // The page behind the SDK's camera: what the person sees while the journey runs, and after it stops.
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            when (val current = state) {
                JourneyState.Opening -> {
                    Status("In progress", Color(0xFF1B45AB), Color(0xFFE4ECFC))
                    Title("Journey in progress", "Finish the journey on the camera screen. This page moves to the result when you are done.")
                }
                // Once the user denies the camera for good, Android stops asking, so the way back is the app's settings.
                JourneyState.CameraDenied -> {
                    Status("Camera blocked", MaterialTheme.colorScheme.onSurfaceVariant, Color.White, outlined = true)
                    Title("Camera access needed", "The journey takes a selfie. Allow the camera in Settings, then try again.")
                }
                is JourneyState.Ended -> {
                    Status("Camera closed", MaterialTheme.colorScheme.onSurfaceVariant, Color.White, outlined = true)
                    Title("Journey not finished", current.message)
                }
            }
            Column(
                Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(12.dp))
                    .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(12.dp))
                    .padding(horizontal = 16.dp, vertical = 4.dp),
            ) {
                InfoRow("Flow", flow)
                InfoRow("Process ID", processId)
                InfoRow("Opened with", "Native SDK")
            }
        }

        if (state != JourneyState.Opening) {
            Surface(color = Color.White) {
                Column {
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    Column(
                        Modifier.navigationBarsPadding().padding(16.dp, 12.dp, 16.dp, 16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        if (state == JourneyState.CameraDenied) {
                            Action("Open Settings", primary = true) {
                                activity.startActivity(
                                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", activity.packageName, null)),
                                )
                            }
                            Action("Try again", primary = false, onClick = ::start)
                        } else {
                            // The process stays where the journey stopped, so a new test creates a new one.
                            Action("Start a new test", primary = true, onClick = onBack)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Status(text: String, ink: Color, ground: Color, outlined: Boolean = false) = Text(
    text,
    Modifier.background(ground, CircleShape)
        .border(1.dp, if (outlined) MaterialTheme.colorScheme.outlineVariant else ground, CircleShape)
        .padding(horizontal = 12.dp, vertical = 4.dp),
    color = ink, fontSize = 12.sp, fontWeight = FontWeight.Bold,
)

@Composable
private fun Title(title: String, text: String) = Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
    Text(title, fontSize = 24.sp, fontWeight = FontWeight.ExtraBold)
    Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 14.sp)
}

@Composable
private fun InfoRow(key: String, value: String) = Row(
    Modifier.fillMaxWidth().heightIn(min = 44.dp), verticalAlignment = Alignment.CenterVertically,
) {
    Text(key.uppercase(), Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    Text(value, fontFamily = FontFamily.Monospace, fontSize = 13.sp)
}

@Composable
private fun Action(text: String, primary: Boolean, onClick: () -> Unit) {
    val modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
    val shape = RoundedCornerShape(12.dp)
    if (primary) Button(onClick, modifier, shape = shape) { Text(text, fontWeight = FontWeight.Bold) }
    else OutlinedButton(onClick, modifier, shape = shape) { Text(text, fontWeight = FontWeight.Bold) }
}
