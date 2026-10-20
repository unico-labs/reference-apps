// The evidence set: one GET when the user opens it, rendered in the app with the platform's PdfRenderer.
// It holds biometric data, so it isn't handed to another app and no copy is kept: the temporary file that
// PdfRenderer needs is deleted as soon as the pages are drawn.
package io.unico.reference.result

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import io.unico.reference.api.Unico
import java.io.File
import java.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.jsonPrimitive

@Composable
fun EvidenceSetScreen(unico: Unico, processId: String) {
    val context = LocalContext.current
    var pages by remember { mutableStateOf<List<ImageBitmap>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(processId) {
        runCatching {
            // `contentType` comes back as `x-pdf`; `fileContents` is a base64 PDF.
            val pdf = Base64.getDecoder().decode(unico.getEvidenceSet(processId).getValue("fileContents").jsonPrimitive.content)
            render(context, pdf)
        }.fold({ pages = it }, { error = describe(it) })
    }

    LazyColumn(Modifier.padding(16.dp)) {
        item { Text("Evidence set", style = MaterialTheme.typography.headlineMedium) }
        error?.let { item { Text(it, fontFamily = FontFamily.Monospace) } }
        if (pages == null && error == null) item { CircularProgressIndicator() }
        items(pages.orEmpty()) { page ->
            Image(page, contentDescription = "Evidence set page", Modifier.fillMaxWidth().padding(vertical = 8.dp))
        }
    }
}

// Judgment call: 2x the PDF's point size reads well on a phone without large bitmaps.
private const val SCALE = 2

private suspend fun render(context: Context, pdf: ByteArray): List<ImageBitmap> = withContext(Dispatchers.IO) {
    val file = File.createTempFile("evidence-set", ".pdf", context.cacheDir)
    try {
        file.writeBytes(pdf)
        PdfRenderer(ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)).use { renderer ->
            (0 until renderer.pageCount).map { index ->
                renderer.openPage(index).use { page ->
                    val bitmap = Bitmap.createBitmap(page.width * SCALE, page.height * SCALE, Bitmap.Config.ARGB_8888)
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    bitmap.asImageBitmap()
                }
            }
        }
    } finally {
        file.delete()
    }
}
