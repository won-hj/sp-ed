import '../core/protocol/device_command.dart';
import '../services/tts_service.dart';
import 'device_controller.dart';

class VoiceCommandController {
  final DeviceController deviceController;
  final TtsService ttsService;

  VoiceCommandController({
    required this.deviceController,
    required this.ttsService,
  });

  DeviceCommand? parse(String text) {
    final command = text
        .toLowerCase()
        .trim();

    if (command.contains('microwave')) {
      if (command.contains('turn on') ||
          command.contains('start')) {
        return DeviceCommand.microwaveOn;
      }

      if (command.contains('turn off') ||
          command.contains('stop')) {
        return DeviceCommand.microwaveOff;
      }
    }

    if (command.contains('light')) {
      if (command.contains('turn on') ||
          command.contains('switch on')) {
        return DeviceCommand.lightOn;
      }

      if (command.contains('turn off') ||
          command.contains('switch off')) {
        return DeviceCommand.lightOff;
      }
    }

    if (command.contains('curtain')) {
      if (command.contains('open')) {
        return DeviceCommand.curtainOpen;
      }

      if (command.contains('close')) {
        return DeviceCommand.curtainClose;
      }
    }

    if (command.contains('oven')) {
      if (command.contains('turn on') ||
          command.contains('start')) {
        return DeviceCommand.ovenOn;
      }

      if (command.contains('turn off') ||
          command.contains('stop')) {
        return DeviceCommand.ovenOff;
      }
    }

    return null;
  }

  Future<void> handleText(
    String text,
  ) async {
    final command = parse(text);

    if (command == null) {
      await ttsService.speak(
        'I did not understand the command.',
      );

      return;
    }

    await deviceController.execute(command);
  }
}