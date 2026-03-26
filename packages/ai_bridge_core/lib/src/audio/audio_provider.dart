/// Core interface for Audio capabilities.
///
/// Providers that support Audio must implement this interface natively
/// or through separate endpoints (like OpenAI Whisper/TTS).
abstract class AIAudioProvider {
  /// Transcribes spoken audio bytes into text.
  ///
  /// [audioBytes] Raw or encoded audio data (e.g. mp3, wav).
  /// [mimeType] The MIME type of the audio.
  /// [language] Optional ISO code to force parsing in a specific language (e.g., 'en', 'ar').
  Future<String> speechToText(
    List<int> audioBytes, {
    String? mimeType,
    String? language,
  });

  /// Synthesizes spoken audio from text.
  ///
  /// [text] The text to synthesize.
  /// [voice] The identifier for the voice to use.
  /// Returns the raw audio bytes (usually MP3).
  Future<List<int>> textToSpeech(
    String text, {
    String? voice,
  });
}
