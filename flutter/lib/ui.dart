// Look and shared pieces of the demo screens: colors, buttons, cards, fields, the bottom dock.
// Glue: the Unico calls and SDK code live in the other folders, and journey/native-sdk/ doesn't use this file.
import 'package:flutter/material.dart';

const ground = Color(0xFFF5F7FA);
const ink = Color(0xFF17202B);
const muted = Color(0xFF5A6573);
const line = Color(0xFFD9DFE7);
const outline = Color(0xFF8C97A6);
const accent = Color(0xFF2457D6);
const okInk = Color(0xFF17734A);
const okGround = Color(0xFFDFF3E8);
const badInk = Color(0xFF9B1C12);
const badGround = Color(0xFFFBE3E0);
const warnInk = Color(0xFF7A4800);
const warnGround = Color(0xFFFFF1D6);
const extraGround = Color(0xFFF4F7FE);
const extraLine = Color(0xFFC5D5F7);
const codeGround = Color(0xFF0F1722);
const codeInk = Color(0xFFD6E2F2);

final _buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
const _buttonText = TextStyle(fontWeight: FontWeight.bold, fontSize: 15);

ThemeData referenceTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: accent, surface: Colors.white, onSurface: ink),
  scaffoldBackgroundColor: ground,
  appBarTheme: const AppBarTheme(
    // The title sits on the left on both platforms, so both apps look the same.
    centerTitle: false,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    foregroundColor: ink,
    titleTextStyle: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800),
    shape: Border(bottom: BorderSide(color: line)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      shape: _buttonShape,
      textStyle: _buttonText,
      backgroundColor: accent,
      disabledBackgroundColor: line,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      shape: _buttonShape,
      textStyle: _buttonText,
      foregroundColor: ink,
      backgroundColor: Colors.white,
      side: const BorderSide(color: outline),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: outline),
    ),
  ),
);

// A screen: scrolling content on the light ground, with its buttons pinned to the bottom.
class Screen extends StatelessWidget {
  const Screen({super.key, required this.content, required this.dock});

  final List<Widget> content;
  final List<Widget> dock;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (i, child) in content.indexed) ...[if (i > 0) const SizedBox(height: 14), child],
          ],
        ),
      ),
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: line)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SafeArea(top: false, child: Column(spacing: 10, children: dock)),
      ),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.children, this.center = false});

  final List<Widget> children;
  final bool center;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      spacing: 10,
      children: children,
    ),
  );
}

// The box that holds the fields of a switched-on extra.
class ExtraBox extends StatelessWidget {
  const ExtraBox({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: extraGround,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: extraLine),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: children),
  );
}

// Small uppercase heading inside a card or above a block.
class Lab extends StatelessWidget {
  const Lab(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
  );
}

// A field label in words, with the name of the field in the Create Process body beside it.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.api, this.required = false});

  final String text;
  final String? api;
  final bool required;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: text,
      style: const TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 15),
      children: [
        if (api != null)
          TextSpan(
            text: '  $api',
            style: const TextStyle(
              color: muted,
              fontFamily: 'monospace',
              fontFamilyFallback: ['Menlo'],
              fontSize: 11,
              fontWeight: FontWeight.normal,
            ),
          ),
        if (required)
          const TextSpan(
            text: ' *',
            style: TextStyle(color: badInk),
          ),
      ],
    ),
  );
}

class Hint extends StatelessWidget {
  const Hint(this.text, {super.key, this.align});

  final String text;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: const TextStyle(color: muted, fontSize: 13),
  );
}

class CodeBlock extends StatelessWidget {
  const CodeBlock(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: codeGround, borderRadius: BorderRadius.circular(10)),
    child: SelectableText(
      text,
      style: const TextStyle(
        color: codeInk,
        fontFamily: 'monospace',
        fontFamilyFallback: ['Menlo'],
        fontSize: 12,
        height: 1.5,
      ),
    ),
  );
}

// Label and value on one line, as in the summary cards.
class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: ink, fontFamily: 'monospace', fontFamilyFallback: ['Menlo'], fontSize: 13),
        ),
      ],
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.ink = okInk, this.ground = okGround});

  final String text;
  final Color ink;
  final Color ground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: ground, borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

// The heading row of a result-like screen: a round mark, the title and a line under it.
class Heading extends StatelessWidget {
  const Heading({
    super.key,
    required this.icon,
    required this.ink,
    required this.ground,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final Color ink;
  final Color ground;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 14,
    children: [
      CircleAvatar(
        radius: 24,
        backgroundColor: ground,
        child: Icon(icon, color: ink, size: 28),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The title keeps the page's ink; `ink` here is the mark's color.
            Text(
              title,
              style: const TextStyle(color: Color(0xFF17202B), fontSize: 24, fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) Hint(subtitle!),
          ],
        ),
      ),
    ],
  );
}

// A labelled text field.
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    this.api,
    this.required = false,
    this.placeholder,
    this.hint,
    this.mono = false,
    this.keyboard,
    this.lines = 1,
    this.controller,
    this.initial,
    required this.onChanged,
  });

  final String label;
  final String? api;
  final bool required;
  final String? placeholder;
  final String? hint;
  final bool mono;
  final TextInputType? keyboard;
  final int lines;
  final TextEditingController? controller;
  final String? initial;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 6,
    children: [
      FieldLabel(label, api: api, required: required),
      TextFormField(
        controller: controller,
        initialValue: controller == null ? initial : null,
        onChanged: onChanged,
        keyboardType: keyboard,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 4,
        autocorrect: false,
        style: TextStyle(
          fontFamily: mono ? 'monospace' : null,
          fontFamilyFallback: mono ? const ['Menlo'] : null,
          fontSize: mono && lines > 1 ? 12 : 16,
        ),
        decoration: InputDecoration(hintText: placeholder),
      ),
      if (hint != null) Hint(hint!),
    ],
  );
}

// A labelled select.
class Select extends StatelessWidget {
  const Select({
    super.key,
    required this.label,
    this.api,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? api;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 6,
    children: [
      FieldLabel(label, api: api),
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more, color: muted),
        style: const TextStyle(color: ink, fontFamily: 'monospace', fontFamilyFallback: ['Menlo'], fontSize: 14),
        items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o.isEmpty ? 'Not set' : o))],
        onChanged: (v) => onChanged(v ?? ''),
      ),
    ],
  );
}
