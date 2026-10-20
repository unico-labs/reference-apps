// Look and shared pieces of the demo screens: colors, button styles, cards, fields, the bottom dock.
// Glue: the Unico calls and SDK code live in the other folders, and journey/native-sdk/ doesn't use this file.
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    static let ground = Color(hex: 0xF5F7FA)
    static let ink = Color(hex: 0x17202B)
    static let muted = Color(hex: 0x5A6573)
    static let line = Color(hex: 0xD9DFE7)
    static let outline = Color(hex: 0x8C97A6)
    static let accent = Color(hex: 0x2457D6)
    static let okInk = Color(hex: 0x17734A)
    static let okGround = Color(hex: 0xDFF3E8)
    static let badInk = Color(hex: 0x9B1C12)
    static let badGround = Color(hex: 0xFBE3E0)
    static let warnInk = Color(hex: 0x7A4800)
    static let warnGround = Color(hex: 0xFFF1D6)
    static let extraGround = Color(hex: 0xF4F7FE)
    static let extraLine = Color(hex: 0xC5D5F7)
    static let codeGround = Color(hex: 0x0F1722)
    static let codeInk = Color(hex: 0xD6E2F2)
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.bold())
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(enabled ? .white : Color.muted)
            .background(enabled ? Color.accent : Color.line, in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var fill = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.bold())
            .padding(.horizontal, 16)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: 48)
            .foregroundStyle(Color.ink)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.outline))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// The white bar pinned to the bottom of a screen, holding its buttons.
struct Dock<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 10) { content }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.white)
            .overlay(alignment: .top) { Divider().overlay(Color.line) }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line))
    }
}

// The box that holds the fields of a switched-on extra.
struct ExtraBox<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(12)
            .background(Color.extraGround, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.extraLine))
    }
}

// Small uppercase heading inside a card or above a block.
struct Lab: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(.caption.bold()).tracking(1).foregroundStyle(Color.muted)
    }
}

// A field label in words, with the name of the field in the Create Process body beside it.
struct FieldLabel: View {
    let text: String
    var api: String?
    var required = false
    var body: some View {
        (Text(text).fontWeight(.semibold)
            + Text(api.map { "  \($0)" } ?? "").font(.caption2.monospaced()).foregroundStyle(Color.muted)
            + Text(required ? " *" : "").foregroundStyle(Color.badInk))
            .foregroundStyle(Color.ink)
    }
}

struct Hint: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.footnote).foregroundStyle(Color.muted) }
}

struct CodeBlock: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(Color.codeInk)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.codeGround, in: RoundedRectangle(cornerRadius: 10))
    }
}

// Label and value on one line, as in the summary cards.
struct KeyValue: View {
    let key: String
    let value: String
    var body: some View {
        HStack {
            Text(key.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(Color.muted)
            Spacer()
            Text(value).font(.footnote.monospaced()).foregroundStyle(Color.ink)
        }
        .frame(minHeight: 40)
    }
}

// A link to a docs page, opened in the browser.
struct DocLink: View {
    let title: String
    let url: String
    var body: some View {
        Link(title, destination: URL(string: url)!).font(.subheadline.bold()).foregroundStyle(Color.accent)
    }
}

struct Pill: View {
    let text: String
    let ink: Color
    let ground: Color
    var body: some View {
        Text(text).font(.caption.bold()).foregroundStyle(ink)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(ground, in: Capsule())
    }
}

// The heading row of a result-like screen: a round mark, the title and a line under it.
struct Heading: View {
    let symbol: String
    let ink: Color
    let ground: Color
    let title: String
    var subtitle: String?
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2.bold()).foregroundStyle(ink)
                .frame(width: 48, height: 48).background(ground, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.heavy)).foregroundStyle(Color.ink)
                if let subtitle { Hint(subtitle) }
            }
        }
    }
}

extension View {
    // The outlined look of a text field or a select.
    func fieldStyle() -> some View {
        padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.outline))
    }

    // A screen: scrolling content on the light ground, with its buttons pinned to the bottom.
    func screen<Buttons: View>(@ViewBuilder dock: () -> Buttons) -> some View {
        ScrollView {
            frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
        .background(Color.ground)
        .safeAreaInset(edge: .bottom, spacing: 0) { Dock { dock() } }
    }
}

// A labelled text field.
struct Field: View {
    let label: String
    var api: String?
    var required = false
    var placeholder = ""
    var hint: String?
    var mono = false
    var keyboard: UIKeyboardType = .default
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label, api: api, required: required)
            TextField(placeholder, text: $text)
                .font(mono ? .body.monospaced() : .body)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()
            if let hint { Hint(hint) }
        }
    }
}

// A labelled menu that looks like a field, standing in for a select.
struct Select: View {
    let label: String
    var api: String?
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label, api: api)
            Menu {
                ForEach(options, id: \.self) { option in Button(option.isEmpty ? "Not set" : option) { selection = option } }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Not set" : selection).font(.subheadline.monospaced()).foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.footnote.bold()).foregroundStyle(Color.muted)
                }
                .fieldStyle()
            }
        }
    }
}
