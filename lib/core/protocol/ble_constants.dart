import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleConstants {
  static const String deviceName = 'SPIED_ESP32';

  static final Guid serviceUuid =
      Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');

  // Smartphone -> ESP32
  static final Guid rxUuid =
      Guid('6E400002-B5A3-F393-E0A9-E50E24DCCA9E');

  // ESP32 -> Smartphone
  static final Guid txUuid =
      Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');
}