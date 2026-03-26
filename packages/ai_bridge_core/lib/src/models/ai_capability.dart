/// Capabilities that an AI provider may support.
enum AICapability {
  /// Text completion / chat.
  textCompletion,

  /// Streaming text responses.
  streaming,

  /// Image understanding (vision).
  vision,

  /// Image generation.
  imageGeneration,

  /// Text embeddings.
  embeddings,

  /// Function/tool calling.
  functionCalling,

  /// Audio input (speech-to-text).
  audioInput,

  /// Audio output (text-to-speech).
  audioOutput,

  /// Code execution.
  codeExecution,

  /// JSON mode / structured output.
  structuredOutput,
}
