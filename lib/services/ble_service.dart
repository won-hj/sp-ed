import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/protocol/device_command.dart';


class BleService {
  // Nordic UART Service 방식
  static final Guid serviceUuid = Guid(
    '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
  );

  // Flutter -> ESP32
  static final Guid rxUuid = Guid(
    '6E400002-B5A3-F393-E0A9-E50E24DCCA9E',
  );

  // ESP32 -> Flutter
  static final Guid txUuid = Guid(
    '6E400003-B5A3-F393-E0A9-E50E24DCCA9E',
  );

  static const String deviceName = 'SPIED_ESP32';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;

  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>?
      _connectionSubscription;

  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  final StreamController<BluetoothConnectionState>
      _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();

  Stream<String> get messages => _messageController.stream;

  Stream<BluetoothConnectionState> get connectionStates =>
      _connectionStateController.stream;

  bool get isConnected => _device?.isConnected ?? false;

  // ============================================================
  // CONNECT
  // ============================================================

Future<void> connect() async {
  if (_device?.isConnected == true) {
    print('ESP32 already connected');
    return;
  }

  // Bluetooth가 실제 ON 상태가 될 때까지 기다림
  await FlutterBluePlus.adapterState
      .where(
        (state) =>
            state == BluetoothAdapterState.on,
      )
      .first;

  // 혹시 이전 scan이 남아 있으면 종료
  if (FlutterBluePlus.isScanningNow) {
    await FlutterBluePlus.stopScan();
  }

  final completer =
      Completer<BluetoothDevice>();

  late StreamSubscription<List<ScanResult>>
      scanSubscription;

  scanSubscription =
      FlutterBluePlus.onScanResults.listen(
    (results) {
      for (final result in results) {
        final advName =
            result.advertisementData.advName;

        final platformName =
            result.device.platformName;

        print(
          'FOUND: '
          'adv="$advName", '
          'platform="$platformName", '
          'id=${result.device.remoteId}, '
          'rssi=${result.rssi}',
        );

        if (advName == deviceName ||
            platformName == deviceName) {
          if (!completer.isCompleted) {
            print('SPIED_ESP32 FOUND');

            completer.complete(
              result.device,
            );
          }
        }
      }
    },
    onError: (error) {
      print(
        'BLE SCAN ERROR: $error',
      );

      if (!completer.isCompleted) {
        completer.completeError(
          error,
        );
      }
    },
  );

  try {
    print('BLE scan started...');

    // 필터 없음
    await FlutterBluePlus.startScan(
      timeout:
          const Duration(seconds: 15),
      androidScanMode:
          AndroidScanMode.lowLatency,
    );

    final device =
        await completer.future.timeout(
      const Duration(seconds: 16),
      onTimeout: () {
        throw Exception(
          'SPIED_ESP32 was not found during BLE scan.',
        );
      },
    );

    await FlutterBluePlus.stopScan();

    _device = device;

    print(
      'Found ESP32: ${device.remoteId}',
    );

    await _setupConnectionListener(
      device,
    );

    print('Connecting...');

    await device.connect(
      license: License.nonprofit,
      timeout:
          const Duration(seconds: 30),
    );

    print('CONNECTED');

    await _prepareGatt(
      device,
    );

    print(
      'BLE communication READY',
    );
  } finally {
    await scanSubscription.cancel();

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }
}

  // ============================================================
  // CONNECTION STATE
  // ============================================================

  Future<void> _setupConnectionListener(
    BluetoothDevice device,
  ) async {
    await _connectionSubscription?.cancel();

    _connectionSubscription =
        device.connectionState.listen(
      (state) {
        print(
          'BLE connection state: $state',
        );

        _connectionStateController.add(
          state,
        );

        if (state ==
            BluetoothConnectionState.connected) {
          print(
            'ESP32 connection alive',
          );
        }

        if (state ==
            BluetoothConnectionState.disconnected) {
          print(
            'ESP32 DISCONNECTED',
          );

          print(
            'Disconnect reason: '
            '${device.disconnectReason?.code} '
            '${device.disconnectReason?.description}',
          );

          _rx = null;
          _tx = null;
        }
      },
    );
  }

  // ============================================================
  // GATT SETUP
  // ============================================================

  Future<void> _prepareGatt(
    BluetoothDevice device,
  ) async {
    _rx = null;
    _tx = null;

    print(
      'Discovering BLE services...',
    );

    final services =
        await device.discoverServices();

    for (final service in services) {
      print(
        'Service: ${service.uuid}',
      );

      if (service.uuid != serviceUuid) {
        continue;
      }

      print(
        'SPIED service found',
      );

      for (final characteristic
          in service.characteristics) {
        print(
          'Characteristic: '
          '${characteristic.uuid}',
        );

        if (characteristic.uuid ==
            rxUuid) {
          _rx = characteristic;

          print(
            'RX characteristic found',
          );
        }

        if (characteristic.uuid ==
            txUuid) {
          _tx = characteristic;

          print(
            'TX characteristic found',
          );
        }
      }
    }

    if (_rx == null) {
      throw Exception(
        'RX characteristic not found',
      );
    }

    if (_tx == null) {
      throw Exception(
        'TX characteristic not found',
      );
    }

    // 이전 listener가 있으면 제거
    await _notificationSubscription
        ?.cancel();

    // ESP32 -> Flutter Notify 수신
    _notificationSubscription =
        _tx!.onValueReceived.listen(
      (value) {
        final message = utf8.decode(
          value,
          allowMalformed: true,
        );

        print(
          'ESP32 -> Flutter: $message',
        );

        _messageController.add(
          message,
        );
      },
    );

    // ESP32 연결이 끊기면 notification listener 정리
    device.cancelWhenDisconnected(
      _notificationSubscription!,
    );

    // Notify 활성화
    final notifyEnabled =
        await _tx!.setNotifyValue(
      true,
    );

    print(
      'TX notification enabled: '
      '$notifyEnabled',
    );
  }

  // ============================================================
  // SEND
  // ============================================================

  Future<void> send(
    String command,
  ) async {
    final device = _device;
    final rx = _rx;

    if (device == null ||
        !device.isConnected) {
      throw Exception(
        'ESP32 is not connected.',
      );
    }

    if (rx == null) {
      throw Exception(
        'RX characteristic is not ready.',
      );
    }

    print(
      'Flutter -> ESP32: $command',
    );

    await rx.write(
      utf8.encode(command),

      // Write With Response
      // 속도보다 안정성 우선
      withoutResponse: false,
    );
  }

  Future<void> sendCommand(
    DeviceCommand command,
  ) async {
    await send(command.wireValue);
  }
  Future<String> sendCommandAndWaitAck(
  DeviceCommand command, {
  Duration timeout =
      const Duration(seconds: 3),
}) async {
  final completer = Completer<String>();

  StreamSubscription<String>? subscription;
  Timer? timer;

  subscription = messages.listen(
    (message) {
      final received = message.trim();

      if (received == command.expectedAck &&
          !completer.isCompleted) {
        completer.complete(received);
      }
    },
  );

  timer = Timer(
    timeout,
    () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException(
            'No ACK received for ${command.wireValue}',
          ),
        );
      }
    },
  );

  try {
    await sendCommand(command);

    return await completer.future;
  } finally {
    timer.cancel();
    await subscription.cancel();
  }
}
  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> disconnect() async {
    print(
      'Disconnecting ESP32...',
    );

    await _notificationSubscription
        ?.cancel();

    _notificationSubscription = null;

    await _device?.disconnect();

    _device = null;
    _rx = null;
    _tx = null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await _notificationSubscription
        ?.cancel();

    await _connectionSubscription
        ?.cancel();

    await _device?.disconnect();

    await _messageController.close();

    await _connectionStateController
        .close();

    _device = null;
    _rx = null;
    _tx = null;
  }
}