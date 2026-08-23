import '../core/protocol/device_command.dart';
import '../services/ble_service.dart';

class DeviceController {
  final BleService bleService;

  DeviceController(this.bleService);

  Future<void> execute(DeviceCommand command) async {
    await bleService.sendCommand(command);
  }
}