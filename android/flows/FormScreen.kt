// The create-process form. Same fields as web/views/form.ejs; buildProcessBody turns them into the request body.
package io.unico.reference.flows

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import java.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
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
    "DOCUMENT_PURPOSE_ONBOARDING", "DOCUMENT_PURPOSE_CREDIT_PROCESS", "DOCUMENT_PURPOSE_CAR_PURCHASE",
    "DOCUMENT_PURPOSE_PAY_BY_PAYCHECK", "DOCUMENT_PURPOSE_FGTS",
)
private val USE_CASES = listOf("USE_CASE_LOGIN", "USE_CASE_FIN_TRANSACTIONS")
private val PURPOSES = listOf("", "biometryonboarding", "creditprocess", "carpurchase", "ageverification")
private val CURRENCIES = listOf("", "BRL", "MXN", "USD")
private val LOCALES = listOf("ptBr", "enUs", "esMx")

// The native SDK handles the return in-app, so the docs ask for "/" as the callbackUri.
private const val CALLBACK_URI = "/"

// `onSubmit` creates the process and opens the journey. It returns an error to show, or null when it went on.
@Composable
fun FormScreen(flow: Flow, onSubmit: suspend (body: JsonObject) -> String?) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val fields = remember {
        mutableStateMapOf(
            "duiType" to DUI_TYPES.first(), "documentPurpose" to DOCUMENT_PURPOSES.first(),
            "useCase" to USE_CASES.first(), "locale" to LOCALES.first(),
        )
    }
    val documents = remember { mutableStateListOf<Uri>() }
    var error by remember { mutableStateOf<String?>(null) }
    var sending by remember { mutableStateOf(false) }

    val pickDocuments = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) {
        documents.clear()
        documents.addAll(it)
    }

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(flow.id, style = MaterialTheme.typography.headlineMedium, fontFamily = FontFamily.Monospace)
        Text(flow.capabilities.joinToString(" · "), style = MaterialTheme.typography.bodySmall)
        Text("Use your own document. There are no test documents: the journey checks a real face against it.")
        error?.let { Text(it, fontFamily = FontFamily.Monospace, color = MaterialTheme.colorScheme.error) }

        Text("Person", style = MaterialTheme.typography.titleMedium)
        Picker("Document type", DUI_TYPES, fields.getValue("duiType")) { fields["duiType"] = it }
        TextInput(fields, "duiValue", "Your document", "Numbers only, no formatting")
        TextInput(fields, "friendlyName", "Name", "Optional")
        TextInput(fields, "email", "Email", "Optional", KeyboardType.Email)
        TextInput(fields, "phone", "Phone", "Optional, e.g. 5511999999999", KeyboardType.Phone)

        if ("document" in flow.extraFields) {
            Text("Document for Face Document Match", style = MaterialTheme.typography.titleMedium)
            OutlinedButton(onClick = { pickDocuments.launch(arrayOf("image/*", "application/pdf")) }) {
                Text(if (documents.isEmpty()) "Pick document images (optional)" else "${documents.size} file(s) picked")
            }
            Picker("Document purpose", DOCUMENT_PURPOSES, fields.getValue("documentPurpose")) { fields["documentPurpose"] = it }
        }

        if ("useCase" in flow.extraFields) {
            Text("Smart Revalidation", style = MaterialTheme.typography.titleMedium)
            Picker("useCase", USE_CASES, fields.getValue("useCase")) { fields["useCase"] = it }
            TextInput(fields, "referenceProcessId", "Onboarding process ID", "Process to revalidate against")
        }

        Text("Advanced", style = MaterialTheme.typography.titleMedium)
        TextInput(fields, "expiresIn", "expiresIn", "3600s (default: 7 days)")
        Picker("purpose", PURPOSES, fields["purpose"].orEmpty()) { fields["purpose"] = it }
        TextInput(fields, "companyName", "contextualization.company_name")
        Picker("contextualization.currency", CURRENCIES, fields["currency"].orEmpty()) { fields["currency"] = it }
        TextInput(fields, "price", "contextualization.price", keyboard = KeyboardType.Decimal)
        Picker("reason locale", LOCALES, fields.getValue("locale")) { fields["locale"] = it }
        TextInput(fields, "reason", "contextualization reason")

        Text("Create process and open with", style = MaterialTheme.typography.bodySmall)
        Button(
            enabled = !sending && !fields["duiValue"].isNullOrBlank(),
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
                        onSuccess = { onSubmit(buildProcessBody(flow, fields, it, CALLBACK_URI)) },
                        onFailure = { "Could not read a document file: $it" },
                    )
                    sending = false
                }
            },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Native SDK") }
    }
}

@Composable
private fun TextInput(
    fields: MutableMap<String, String>,
    name: String,
    label: String,
    hint: String = "",
    keyboard: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        fields[name].orEmpty(), { fields[name] = it },
        label = { Text(label) }, placeholder = { Text(hint) }, singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard), modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun Picker(label: String, options: List<String>, selected: String, onSelect: (String) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        TextButton(onClick = { open = true }) { Text("$label: ${selected.ifEmpty { "Not set" }}") }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(option.ifEmpty { "Not set" }) }, onClick = { onSelect(option); open = false })
            }
        }
    }
}
