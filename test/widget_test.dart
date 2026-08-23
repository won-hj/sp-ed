import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/protocol/device_command.dart';

void main() {
  test('morning routine commands match the ESP32 wire protocol', () {
    expect(DeviceCommand.microwaveOn.wireValue, 'MICROWAVE_ON');
    expect(DeviceCommand.microwaveOn.expectedAck, 'MICROWAVE_ON_OK');
    expect(DeviceCommand.lightOn.wireValue, 'LIGHT_ON');
    expect(DeviceCommand.lightOn.expectedAck, 'LIGHT_ON_OK');
  });
}
