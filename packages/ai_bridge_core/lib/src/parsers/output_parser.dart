/// Abstract base class for structured output parsing.
///
/// Implementations of this class translate raw text from an LLM
/// into a specific structured Dart type [T].
abstract class OutputParser<T> {
  /// Formatting instructions to be appended to the LLM's system prompt.
  String get formatInstructions;

  /// Parses the raw output from the language model into type [T].
  /// Throws a [FormatException] if the text cannot be parsed.
  T parse(String text);
}
