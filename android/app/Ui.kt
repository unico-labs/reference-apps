// Look and shared pieces of the demo screens: colors, button shapes, cards, the bottom dock.
// Glue: the Unico calls and SDK code live in the other folders, and journey/native-sdk/ doesn't use this file.
package io.unico.reference.app

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Shapes
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val Ground = Color(0xFFF5F7FA)
val Ink = Color(0xFF17202B)
val Muted = Color(0xFF5A6573)
val Line = Color(0xFFD9DFE7)
val Accent = Color(0xFF2457D6)
val OkInk = Color(0xFF17734A)
val OkGround = Color(0xFFDFF3E8)
val BadInk = Color(0xFF9B1C12)
val BadGround = Color(0xFFFBE3E0)
val WarnInk = Color(0xFF7A4800)
val WarnGround = Color(0xFFFFF1D6)
val ExtraGround = Color(0xFFF4F7FE)
val ExtraLine = Color(0xFFC5D5F7)
val CodeGround = Color(0xFF0F1722)
val CodeInk = Color(0xFFD6E2F2)

private val ButtonShape = RoundedCornerShape(12.dp)

@Composable
fun ReferenceTheme(content: @Composable () -> Unit) = MaterialTheme(
    colorScheme = lightColorScheme(
        primary = Accent, onPrimary = Color.White, background = Ground, onBackground = Ink,
        surface = Color.White, onSurface = Ink, onSurfaceVariant = Muted, outline = Color(0xFF8C97A6),
        outlineVariant = Line, error = BadInk, surfaceContainerLow = Color.White,
    ),
    shapes = Shapes(extraSmall = RoundedCornerShape(10.dp), small = RoundedCornerShape(10.dp)),
    content = content,
)

@Composable
fun PrimaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) =
    Button(onClick, modifier.heightIn(min = 48.dp), enabled = enabled, shape = ButtonShape) {
        Text(text, fontWeight = FontWeight.Bold)
    }

@Composable
fun SecondaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier) =
    OutlinedButton(
        onClick, modifier.heightIn(min = 48.dp), shape = ButtonShape,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = Ink),
    ) { Text(text, fontWeight = FontWeight.Bold) }

// The white bar pinned to the bottom of a screen, holding its buttons.
@Composable
fun Dock(content: @Composable ColumnScope.() -> Unit) = Surface(color = Color.White) {
    Column {
        HorizontalDivider(color = Line)
        Column(
            Modifier.navigationBarsPadding().padding(16.dp, 12.dp, 16.dp, 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            content = content,
        )
    }
}

@Composable
fun Card(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) = Column(
    modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(12.dp)).border(1.dp, Line, RoundedCornerShape(12.dp))
        .padding(horizontal = 16.dp, vertical = 14.dp),
    verticalArrangement = Arrangement.spacedBy(10.dp),
    content = content,
)

// Small uppercase heading inside a card or above a block.
@Composable
fun Lab(text: String, modifier: Modifier = Modifier) = Text(
    text.uppercase(), modifier, color = Muted, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp,
)

// A field label in words, with the name of the field in the Create Process body beside it.
@Composable
fun FieldLabel(text: String, api: String? = null, required: Boolean = false) = Text(
    buildAnnotatedString {
        append(text)
        if (api != null) withStyle(SpanStyle(fontFamily = FontFamily.Monospace, fontSize = 11.sp, color = Muted)) { append("  $api") }
        if (required) withStyle(SpanStyle(color = BadInk)) { append(" *") }
    },
    fontWeight = FontWeight.SemiBold,
)

@Composable
fun Hint(text: String, modifier: Modifier = Modifier) = Text(text, modifier, color = Muted, fontSize = 13.sp)

// A link to the docs, opened in the browser.
@Composable
fun Link(text: String, url: String) {
    val uriHandler = LocalUriHandler.current
    Text(text, Modifier.clickable { uriHandler.openUri(url) }.padding(vertical = 4.dp), color = Accent, fontSize = 14.sp, fontWeight = FontWeight.Bold)
}

@Composable
fun Code(text: String) = Text(
    text,
    Modifier.fillMaxWidth().background(CodeGround, RoundedCornerShape(10.dp)).padding(horizontal = 14.dp, vertical = 12.dp),
    color = CodeInk, fontFamily = FontFamily.Monospace, fontSize = 12.sp, lineHeight = 18.sp,
)

// Label and value on one line, as in the summary cards.
@Composable
fun KeyValue(key: String, value: String) = Row(
    Modifier.fillMaxWidth().heightIn(min = 40.dp), verticalAlignment = Alignment.CenterVertically,
) {
    Text(key.uppercase(), Modifier.weight(1f), color = Muted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
    Text(value, fontFamily = FontFamily.Monospace, fontSize = 13.sp)
}

@Composable
fun Pill(text: String, ink: Color, ground: Color, modifier: Modifier = Modifier) = Text(
    text, modifier.background(ground, CircleShape).padding(horizontal = 12.dp, vertical = 4.dp),
    color = ink, fontSize = 12.sp, fontWeight = FontWeight.Bold,
)

enum class Mark { CHECK, CROSS, DASH }

// The round mark next to a heading: a check, a cross or a dash.
@Composable
fun MarkIcon(mark: Mark, ink: Color, ground: Color) = Canvas(Modifier.size(48.dp)) {
    drawCircle(ground)
    val stroke = Stroke(width = 3.2.dp.toPx(), cap = StrokeCap.Round)
    fun line(a: Offset, b: Offset) = drawLine(ink, a, b, stroke.width, StrokeCap.Round)
    val s = size.width / 44f
    when (mark) {
        Mark.CHECK -> { line(Offset(13 * s, 22.5f * s), Offset(19.5f * s, 29 * s)); line(Offset(19.5f * s, 29 * s), Offset(31 * s, 16 * s)) }
        Mark.CROSS -> { line(Offset(15 * s, 15 * s), Offset(29 * s, 29 * s)); line(Offset(29 * s, 15 * s), Offset(15 * s, 29 * s)) }
        Mark.DASH -> line(Offset(14 * s, 22 * s), Offset(30 * s, 22 * s))
    }
}

// The heading row of a result-like screen: mark, title and a line under it.
@Composable
fun Heading(mark: Mark, ink: Color, ground: Color, title: String, subtitle: String? = null) = Row(
    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
) {
    MarkIcon(mark, ink, ground)
    Column {
        Text(title, fontSize = 24.sp, fontWeight = FontWeight.ExtraBold)
        subtitle?.let { Hint(it) }
    }
}

// A row inside a card: two buttons side by side, each taking half.
@Composable
fun Split(content: @Composable RowScope.() -> Unit) = Row(horizontalArrangement = Arrangement.spacedBy(10.dp), content = content)

@Composable
fun ExtraBox(modifier: Modifier = Modifier, ground: Color = ExtraGround, line: Color = ExtraLine, content: @Composable ColumnScope.() -> Unit) = Column(
    modifier.fillMaxWidth().background(ground, RoundedCornerShape(12.dp)).border(1.dp, line, RoundedCornerShape(12.dp))
        .padding(12.dp),
    verticalArrangement = Arrangement.spacedBy(12.dp),
    content = content,
)
