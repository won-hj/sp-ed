import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }

    _initialized = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
      },
      onError: (error) {
        print('Speech error: $error');
      },
    );

    return _initialized;
  }

  Future<void> startListening({
    required void Function(String text) onFinalResult,
  }) async {
    final available = await initialize();

    if (!available) {
      throw Exception('Speech recognition is unavailable.');
    }

    await _speech.listen(
      onResult: (result) {
        print(
          'STT: ${result.recognizedWords}',
        );

        if (result.finalResult) {
          onFinalResult(
            result.recognizedWords,
          );
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }
}