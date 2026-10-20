// The first screen on a device with no settings: what the app does and what setup will ask for.
package io.unico.reference.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.unico.reference.app.Accent
import io.unico.reference.app.Card
import io.unico.reference.app.Dock
import io.unico.reference.app.ExtraGround
import io.unico.reference.app.Hint
import io.unico.reference.app.Lab
import io.unico.reference.app.Link
import io.unico.reference.app.PrimaryButton

@Composable
fun WelcomeScreen(onStart: () -> Unit) = Column(Modifier.fillMaxSize()) {
    Column(
        Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("Unico reference app", color = Accent, fontSize = 13.sp, fontWeight = FontWeight.Bold)
        Text("See how a Unico integration works", fontSize = 26.sp, fontWeight = FontWeight.ExtraBold, lineHeight = 32.sp)
        Text("Run a real flow in UAT. You see the request a backend would send and the result that comes back.")

        Lab("How it works", Modifier.padding(top = 8.dp))
        Step(1, "Set up this app", "Add your API credentials and SDK settings once.")
        Step(2, "Run a flow", "Type the flow name and the person's document.")
        Step(3, "Read the result", "See the response, the selfie and the evidence set.")

        Lab("What you'll need", Modifier.padding(top = 8.dp))
        Need(
            "API credentials",
            "Service account, Tenant ID and private key. They let this app create the process when you start a test.",
            "In your own app this runs on your backend.",
            "Authentication guide ↗", AUTHENTICATION_GUIDE,
        )
        Need(
            "SDK settings",
            "SDK key and app ID. They let the camera experience open.",
            "Unico issues the SDK key for your app's application ID.",
            "Android setup ↗", ANDROID_SETUP,
        )
    }
    Dock { PrimaryButton("Get started", onStart, Modifier.fillMaxWidth()) }
}

@Composable
private fun Step(number: Int, title: String, text: String) = Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
    Text(
        "$number", Modifier.size(28.dp).background(ExtraGround, CircleShape).wrapContentSize(),
        color = Accent, fontWeight = FontWeight.Bold,
    )
    Column {
        Text(title, fontWeight = FontWeight.Bold)
        Hint(text)
    }
}

@Composable
private fun Need(title: String, text: String, muted: String, link: String, url: String) = Card {
    Text(title, fontWeight = FontWeight.Bold)
    Text(text, fontSize = 14.sp)
    Hint(muted)
    Link(link, url)
}
