// Run a flow: the create-process form, the Customize sheet and the error screen. Same fields as web/views/form.ejs;
// buildProcessBody turns them into the request body.
package io.unico.reference.flows

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LocalMinimumInteractiveComponentSize
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.unico.reference.app.BadGround
import io.unico.reference.app.BadInk
import io.unico.reference.app.Card
import io.unico.reference.app.Code
import io.unico.reference.app.Dock
import io.unico.reference.app.ExtraBox
import io.unico.reference.app.FieldLabel
import io.unico.reference.app.Heading
import io.unico.reference.app.Hint
import io.unico.reference.app.Lab
import io.unico.reference.app.Mark
import io.unico.reference.app.Muted
import io.unico.reference.app.PrimaryButton
import io.unico.reference.app.SecondaryButton
import java.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

// https://developer.unico.io/developers/api-reference/post-processes (duiType values)
private val DUI_TYPES = listOf(
    "DUI_TYPE_BR_CPF", "DUI_TYPE_MX_CURP", "DUI_TYPE_AR_DNI", "DUI_TYPE_AR_LNC", "DUI_TYPE_AR_PASSPORT",
    "DUI_TYPE_AT_STNR", "DUI_TYPE_BE_NN", "DUI_TYPE_BR_CNPJ", "DUI_TYPE_BR_PASSPORT", "DUI_TYPE_CA_SIN",
    "DUI_TYPE_CH_AHV", "DUI_TYPE_CL_LICENCIA_CONDUCIR", "DUI_TYPE_CL_PASSPORT", "DUI_TYPE_CL_RUN", "DUI_TYPE_CO_CC",
    "DUI_TYPE_CO_LICENCIA_CONDUCCION", "DUI_TYPE_CO_NIT", "DUI_TYPE_CO_PASSPORT", "DUI_TYPE_DE_IDNR", "DUI_TYPE_DK_CPR",
    "DUI_TYPE_EC_NI", "DUI_TYPE_ES_DNI", "DUI_TYPE_ES_NIE", "DUI_TYPE_FI_HETU", "DUI_TYPE_FR_SPI", "DUI_TYPE_GB_NINO",
    "DUI_TYPE_GT_CUI", "DUI_TYPE_ID_NIK", "DUI_TYPE_IE_PPSN", "DUI_TYPE_IT_CF", "DUI_TYPE_LK_NIC",
    "DUI_TYPE_LU_MATRICULE", "DUI_TYPE_MX_LICENCIA_CONDUCIR", "DUI_TYPE_MX_RFC_PERSONA_FISICA", "DUI_TYPE_NG_BVN",
    "DUI_TYPE_NG_BVN_TOKEN", "DUI_TYPE_NG_NIN", "DUI_TYPE_NG_NIN_TOKEN", "DUI_TYPE_NL_BSN", "DUI_TYPE_NO_FNR",
    "DUI_TYPE_PE_DNI", "DUI_TYPE_PE_PASSPORT", "DUI_TYPE_PE_RUC", "DUI_TYPE_PL_PESEL", "DUI_TYPE_PT_NIF",
    "DUI_TYPE_SE_PNR", "DUI_TYPE_SE_SAMORDNINGSNUMMER", "DUI_TYPE_TR_TCKN", "DUI_TYPE_US_DRIVER_LICENSE",
    "DUI_TYPE_US_ID_CARD", "DUI_TYPE_US_PASSPORT", "DUI_TYPE_US_PASSPORT_CARD", "DUI_TYPE_US_POLYCARBONATE_PASSPORT",
    "DUI_TYPE_US_SSN", "DUI_TYPE_UY_CI", "DUI_TYPE_ZZ_EMAIL", "DUI_TYPE_ZZ_PHONE_NUMBER",
)
private val DOCUMENT_PURPOSES = listOf(
    "", "DOCUMENT_PURPOSE_ONBOARDING", "DOCUMENT_PURPOSE_CREDIT_PROCESS", "DOCUMENT_PURPOSE_CAR_PURCHASE",
    "DOCUMENT_PURPOSE_PAY_BY_PAYCHECK", "DOCUMENT_PURPOSE_FGTS",
)
// The examples in the Create Process docs.
private val USE_CASES = listOf("USE_CASE_LOGIN", "USE_CASE_FIN_TRANSACTIONS")
private val PURPOSES = listOf("", "biometryonboarding", "creditprocess", "carpurchase", "ageverification")
private val CURRENCIES = listOf("", "BRL", "MXN", "USD")
private val LOCALES = listOf("ptBr", "enUs", "esMx")

// The native SDK handles the return in-app, so the docs ask for "/" as the callbackUri.
private const val CALLBACK_URI = "/"

@OptIn(ExperimentalSerializationApi::class)
private val pretty = Json { prettyPrint = true; prettyPrintIndent = "  " }

// `onSubmit` creates the process and opens the journey. It returns an error to show, or null when it went on.
// `reference` is the last process: it fills the reference field, turned on when `stepUp` asks for it.
@Composable
fun FormScreen(reference: String?, stepUp: Boolean, onSubmit: suspend (body: JsonObject) -> String?) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val fields = remember {
        mutableStateMapOf(
            "duiType" to DUI_TYPES.first(), "useCase" to USE_CASES.first(), "locale" to LOCALES.first(),
            "referenceProcessId" to reference.orEmpty(), "withReferences" to stepUp.toString(),
        )
    }
    val documents = remember { mutableStateListOf<Uri>() }
    var error by remember { mutableStateOf<String?>(null) }
    var sending by remember { mutableStateOf(false) }
    var customizing by remember { mutableStateOf(false) }

    // On the error screen the form waits behind, still filled in. Try again brings it back.
    error?.let { return Failed(fields["flow"].orEmpty(), it) { error = null } }

    val pickDocuments = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) {
        documents.clear()
        documents.addAll(it)
    }
    // The preview shows the body the app will send; files stand in as placeholders.
    val preview = buildProcessBody(fields, documents.map { "<file as base64>" }, CALLBACK_URI)

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Column {
                Text("Which flow do you want to test?", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
                Hint("Type the flow name Unico gave you. If your account doesn't have it, the test fails and we show the API error.")
            }
            Field(fields, "flow", "Flow", "flow", required = true, placeholder = "e.g. id", mono = true,
                hint = "Flow names are listed on the Flows page of the Unico docs.")
            Labelled("Document type", "person.duiType") { Picker(DUI_TYPES, fields.getValue("duiType")) { fields["duiType"] = it } }
            Field(fields, "duiValue", "Document number", "person.duiValue", placeholder = "Numbers only, no formatting",
                hint = "The person's own document. Leave it empty if the flow doesn't ask for one.")
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Lab("Request your backend sends")
                Code("POST /client/v1/process\n${pretty.encodeToString(JsonElement.serializer(), preview)}")
            }
        }

        Dock {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                SecondaryButton("Customize", { customizing = true })
                PrimaryButton(
                    if (sending) "Starting…" else "Start test",
                    enabled = !sending && !fields["flow"].isNullOrBlank(),
                    onClick = {
                        sending = true
                        scope.launch {
                            val files = runCatching {
                                withContext(Dispatchers.IO) {
                                    documents.map { uri ->
                                        val bytes = context.contentResolver.openInputStream(uri)!!.use { it.readBytes() }
                                        Base64.getEncoder().encodeToString(bytes)
                                    }
                                }
                            }
                            error = files.fold(
                                onSuccess = { onSubmit(buildProcessBody(fields, it, CALLBACK_URI)) },
                                onFailure = { "Could not read a document file: $it" },
                            )
                            sending = false
                        }
                    },
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }

    if (customizing) {
        Customize(fields, documents.size, { pickDocuments.launch(arrayOf("image/*", "application/pdf")) }, filledFromLastTest = reference != null) {
            customizing = false
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Customize(
    fields: MutableMap<String, String>,
    documentCount: Int,
    onPickDocuments: () -> Unit,
    filledFromLastTest: Boolean,
    onDone: () -> Unit,
) = ModalBottomSheet(onDismissRequest = onDone, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
    Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("Customize request", Modifier.weight(1f), fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
        TextButton(onClick = onDone) { Text("×", fontSize = 22.sp, color = Muted) }
    }
    Column(
        Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Field(fields, "friendlyName", "Name", "person.friendlyName", placeholder = "Full name (optional)")
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Field(fields, "email", "Email", "person.email", keyboard = KeyboardType.Email, modifier = Modifier.weight(1f))
            Field(fields, "phone", "Phone", "person.phone", placeholder = "5511999999999", keyboard = KeyboardType.Phone, modifier = Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Field(fields, "expiresIn", "Expires in", "expiresIn", placeholder = "3600s", modifier = Modifier.weight(1f))
            Labelled("Purpose", "purpose", Modifier.weight(1f)) { Picker(PURPOSES, fields["purpose"].orEmpty()) { fields["purpose"] = it } }
        }

        Lab("Extra fields this flow needs", Modifier.padding(top = 4.dp))
        Extra(fields, "withDocument", "Document image", "document", "Flows with Face Document Match.") {
            Labelled("Document files", "document.files") {
                SecondaryButton(if (documentCount == 0) "Pick document images" else "$documentCount file(s) picked", onPickDocuments, Modifier.fillMaxWidth())
                Hint("Image of the person's document, used by Face Document Match.")
            }
            Labelled("Document purpose", "document.purpose") {
                Picker(DOCUMENT_PURPOSES, fields["documentPurpose"].orEmpty()) { fields["documentPurpose"] = it }
            }
        }
        Extra(fields, "withReferences", "Use case and reference", "useCase, references", "Step-up flows that revalidate an earlier process.") {
            Labelled("Use case", "useCase") { Picker(USE_CASES, fields.getValue("useCase")) { fields["useCase"] = it } }
            Field(fields, "referenceProcessId", "Reference process ID", "references",
                hint = if (filledFromLastTest) "Filled from your last test. Change it if you want another process." else null)
        }
        Extra(fields, "withContextualization", "Contextualization", "contextualization", "Company, price and reason shown to the person in the journey.") {
            Field(fields, "companyName", "Company name", "company_name")
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Labelled("Currency", "currency", Modifier.weight(1f)) { Picker(CURRENCIES, fields["currency"].orEmpty()) { fields["currency"] = it } }
                Field(fields, "price", "Price", "price", keyboard = KeyboardType.Decimal, modifier = Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Labelled("Reason language", "locale", Modifier.weight(1f)) { Picker(LOCALES, fields.getValue("locale")) { fields["locale"] = it } }
                Field(fields, "reason", "Reason", "locale.{language}.reason", modifier = Modifier.weight(1f))
            }
        }
        Hint("Not sure? Leave them off. If the API asks for more, the error names the missing field.")
    }
    Dock { PrimaryButton("Done", onDone, Modifier.fillMaxWidth()) }
}

@Composable
private fun Failed(flow: String, error: String, onTryAgain: () -> Unit) = Column(Modifier.fillMaxSize()) {
    Column(
        Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Heading(Mark.CROSS, BadInk, BadGround, "Couldn't start the test", "$flow · process was not created")
        Card {
            Lab("API response")
            Code(error)
        }
        Card {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { Lab("What you can do") }
            Text(
                "Check the information you entered and confirm the flow is active on your account.",
                Modifier.fillMaxWidth(), textAlign = TextAlign.Center, fontSize = 14.sp,
            )
        }
    }
    Dock { PrimaryButton("Try again", onTryAgain, Modifier.fillMaxWidth()) }
}

// A switch for a group of extra fields, and the fields themselves while it's on.
@Composable
private fun Extra(
    fields: MutableMap<String, String>,
    name: String,
    label: String,
    api: String,
    hint: String,
    content: @Composable () -> Unit,
) {
    val on = fields[name] == "true"
    Row(Modifier.fillMaxWidth().clickable { fields[name] = (!on).toString() }, verticalAlignment = Alignment.Top) {
        // The whole row toggles, so the box doesn't need its own touch margin.
        CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
            Checkbox(on, { fields[name] = it.toString() }, Modifier.padding(top = 10.dp, end = 12.dp))
        }
        Column(Modifier.padding(top = 8.dp)) {
            FieldLabel(label, api)
            Hint(hint)
        }
    }
    if (on) ExtraBox { content() }
}

@Composable
private fun Labelled(label: String, api: String?, modifier: Modifier = Modifier, content: @Composable () -> Unit) =
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        FieldLabel(label, api)
        content()
    }

@Composable
private fun Field(
    fields: MutableMap<String, String>,
    name: String,
    label: String,
    api: String,
    modifier: Modifier = Modifier,
    required: Boolean = false,
    placeholder: String = "",
    hint: String? = null,
    mono: Boolean = false,
    keyboard: KeyboardType = KeyboardType.Text,
) = Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
    FieldLabel(label, api, required)
    OutlinedTextField(
        fields[name].orEmpty(), { fields[name] = it },
        placeholder = { Text(placeholder) }, singleLine = true,
        textStyle = if (mono) TextStyle(fontFamily = FontFamily.Monospace, fontSize = 16.sp) else TextStyle.Default,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard), modifier = Modifier.fillMaxWidth(),
    )
    hint?.let { Hint(it) }
}

// A read-only field that opens a menu, standing in for a select.
@Composable
private fun Picker(options: List<String>, selected: String, onSelect: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        OutlinedTextField(
            selected.ifEmpty { "Not set" }, {}, readOnly = true, singleLine = true,
            textStyle = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 14.sp),
            trailingIcon = { Chevron() }, modifier = Modifier.fillMaxWidth(),
        )
        Box(Modifier.matchParentSize().clickable { open = true })
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(option.ifEmpty { "Not set" }) }, onClick = { onSelect(option); open = false })
            }
        }
    }
}

@Composable
private fun Chevron() = Canvas(Modifier.size(12.dp, 8.dp)) {
    val w = 1.6.dp.toPx()
    drawLine(Muted, Offset(1.dp.toPx(), 1.5.dp.toPx()), Offset(6.dp.toPx(), 6.5.dp.toPx()), w, StrokeCap.Round)
    drawLine(Muted, Offset(6.dp.toPx(), 6.5.dp.toPx()), Offset(11.dp.toPx(), 1.5.dp.toPx()), w, StrokeCap.Round)
}
