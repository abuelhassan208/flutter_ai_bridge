import 'dart:convert';
import 'output_parser.dart';

/// Parses a string output from the LLM into a JSON Map.
///
/// It gracefully extracts JSON from markdown code blocks if the LLM
/// mistakenly wraps its response.
class JsonOutputParser implements OutputParser<Map<String, dynamic>> {
  @override
  String get formatInstructions =>
      'Output MUST be a valid, raw JSON object. Do not include markdown formatting like ```json or any conversational filler text. Only output the JSON object.';

  @override
  Map<String, dynamic> parse(String text) {
    try {
      final cleanText = _stripMarkdown(text);
      return jsonDecode(cleanText) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException(
          'Failed to parse JSON from response. Error: $e\n\nRaw Text:\n$text');
    }
  }

  /// Removes markdown code blocks if present.
  String _stripMarkdown(String text) {
    var rawText = text.trim();
    if (rawText.startsWith('```')) {
      // Find the first newline after the opening ticks
      final firstNewline = rawText.indexOf('\n');
      if (firstNewline != -1) {
        rawText = rawText.substring(firstNewline + 1);
      }
    }
    if (rawText.endsWith('```')) {
      rawText = rawText.substring(0, rawText.length - 3);
    }
    return rawText.trim();
  }
}
