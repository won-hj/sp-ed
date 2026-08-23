enum DeviceCommand {
  ping,

  lightOn,
  lightOff,

  curtainOpen,
  curtainClose,

  microwaveOn,
  microwaveOff,

  ovenOn,
  ovenOff,
}

extension DeviceCommandWire on DeviceCommand {
  String get wireValue {
    switch (this) {
      case DeviceCommand.ping:
        return 'PING';

      case DeviceCommand.lightOn:
        return 'LIGHT_ON';

      case DeviceCommand.lightOff:
        return 'LIGHT_OFF';

      case DeviceCommand.curtainOpen:
        return 'CURTAIN_OPEN';

      case DeviceCommand.curtainClose:
        return 'CURTAIN_CLOSE';

      case DeviceCommand.microwaveOn:
        return 'MICROWAVE_ON';

      case DeviceCommand.microwaveOff:
        return 'MICROWAVE_OFF';

      case DeviceCommand.ovenOn:
        return 'OVEN_ON';

      case DeviceCommand.ovenOff:
        return 'OVEN_OFF';
    }
  }

  String get expectedAck {
    switch (this) {
      case DeviceCommand.ping:
        return 'PONG';

      case DeviceCommand.lightOn:
        return 'LIGHT_ON_OK';

      case DeviceCommand.lightOff:
        return 'LIGHT_OFF_OK';

      case DeviceCommand.curtainOpen:
        return 'CURTAIN_OPEN_OK';

      case DeviceCommand.curtainClose:
        return 'CURTAIN_CLOSE_OK';

      case DeviceCommand.microwaveOn:
        return 'MICROWAVE_ON_OK';

      case DeviceCommand.microwaveOff:
        return 'MICROWAVE_OFF_OK';

      case DeviceCommand.ovenOn:
        return 'OVEN_ON_OK';

      case DeviceCommand.ovenOff:
        return 'OVEN_OFF_OK';
    }
  }
}