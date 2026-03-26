import '../models/ai_message.dart';
import '../providers/ai_provider.dart';
import '../observability/ai_logger.dart';
import 'output_parser.dart';

/// A wrapper that attempts to parse an LLM output, and if it fails,
/// it prompts the LLM again with the parse error to fix its mistake.
class RetryOutputParser<T> {
  /// The underlying parser to execute.
  final OutputParser<T> parser;

  /// The provider used to ask the LLM for a correction.
  final AICompletionProvider provider;

  /// Maximum number of retry attempts before giving up.
  final int maxRetries;

  /// Optional logger for tracing retry attempts.
  final AILogger? logger;

  RetryOutputParser({
    required this.parser,
    required this.provider,
    this.maxRetries = 3,
    this.logger,
  });

  /// Attempts to parse [initialOutput]. If it fails, uses [originalContext]
  /// to request the LLM to provide a corrected output.
  Future<T> parseWithRetry(String initialOutput, List<AIMessage> originalContext) async {
    String currentOutput = initialOutput;

    for (var i = 0; i < maxRetries; i++) {
      try {
        return parser.parse(currentOutput);
      } on FormatException catch (e) {
        logger?.logTrace('⚠️ OutputParser failed on attempt ${i + 1}/$maxRetries. Retrying... Error: ${e.message}');

        // Construct a new context asking for a fix
        final retryContext = List<AIMessage>.from(originalContext)
          ..add(AIMessage.assistant(currentOutput))
          ..add(AIMessage.user(
              'The previous output was invalid and failed parsing with this error: \n\n${e.message}\n\nPlease fix the output and strictly follow these format instructions:\n${parser.formatInstructions}'));

        final response = await provider.complete(retryContext);
        currentOutput = response.content;
      }
    }

    // Final attempt outside the loop. If this fails, the exception propagates.
    logger?.logError('RetryOutputParser exhausted all $maxRetries retries.', StateError('Dangling parse failure'));
    return parser.parse(currentOutput);
  }
}
