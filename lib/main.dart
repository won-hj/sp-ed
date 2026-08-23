import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'services/ble_service.dart';
import 'core/protocol/device_command.dart';

void main() {
  runApp(
    const SpiedApp(),
  );
}

class SpiedApp extends StatelessWidget {
  const SpiedApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SP!ED',
      home: const BleTestPage(),
    );
  }
}

class BleTestPage
    extends StatefulWidget {
  const BleTestPage({
    super.key,
  });

  @override
  State<BleTestPage> createState() =>
      _BleTestPageState();
}

class _BleTestPageState
    extends State<BleTestPage> {
  late final BleService _bleService;

  StreamSubscription<String>?
      _messageSubscription;

  StreamSubscription<
      BluetoothConnectionState>?
      _connectionSubscription;

  bool _connected = false;

  bool _lightOn = false;

  bool _busy = false;

  bool _curtainOpen = false;

  String _status =
      'DISCONNECTED';

  String _lastMessage = '-';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _bleService =
        BleService();

    // ESP32 -> Flutter 메시지 표시
    _messageSubscription =
        _bleService.messages.listen(
      (message) {
        if (!mounted) {
          return;
        }

        setState(() {
          _lastMessage =
              message;
        });
      },
    );

    // BLE 연결 상태 감시
    _connectionSubscription =
        _bleService.connectionStates.listen(
      (state) {
        if (!mounted) {
          return;
        }

        setState(() {
          if (state ==
              BluetoothConnectionState.connected) {
            _connected = true;

            _status =
                'CONNECTED';
          } else if (
              state ==
              BluetoothConnectionState.disconnected) {
            _connected = false;

            _status =
                'DISCONNECTED';
          } else {
            _status =
                state.name.toUpperCase();
          }
        });
      },
    );
  }

  // ============================================================
  // CONNECT
  // ============================================================

  Future<void> _connect() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;

      _status =
          'CONNECTING...';
    });

    try {
      await _bleService.connect();

      if (!mounted) {
        return;
      }

      setState(() {
        _connected = true;

        _status =
            'CONNECTED';
      });
    } catch (e) {
      print(
        'BLE connect failed: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _connected = false;

        _status =
            'CONNECT FAILED';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ============================================================
  // LIGHT ON
  // ============================================================

  Future<void> _turnLightOn() async {
    if (!_connected ||
        _busy) {
      return;
    }

    setState(() {
      _busy = true;

      _status =
          'TURNING LIGHT ON...';
    });

    try {
      final response =
          await _bleService
              .sendCommandAndWaitAck(
        DeviceCommand.lightOn,
      );

      print(
        'ACK: $response',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        // LIGHT_ON_OK를 받은 경우에만
        // 실제 상태 변경
        _lightOn = true;

        _status =
            'LIGHT ON';
      });
    } catch (e) {
      print(
        'LIGHT ON failed: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'LIGHT ON FAILED';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ============================================================
  // LIGHT OFF
  // ============================================================

  Future<void> _turnLightOff() async {
    if (!_connected ||
        _busy) {
      return;
    }

    setState(() {
      _busy = true;

      _status =
          'TURNING LIGHT OFF...';
    });

    try {
      final response =
          await _bleService
              .sendCommandAndWaitAck(
        DeviceCommand.lightOff,
      );

      print(
        'ACK: $response',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        // LIGHT_OFF_OK를 받은 경우에만
        // 실제 상태 변경
        _lightOn = false;

        _status =
            'LIGHT OFF';
      });
    } catch (e) {
      print(
        'LIGHT OFF failed: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'LIGHT OFF FAILED';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _turnLightOff() async {
  ...
}

// 여기 추가

// ============================================================
// CURTAIN OPEN
// ============================================================

Future<void> _openCurtain() async {
  if (!_connected || _busy) {
    return;
  }

  setState(() {
    _busy = true;
    _status = 'OPENING CURTAIN...';
  });

  try {
    final response =
        await _bleService.sendCommandAndWaitAck(
      DeviceCommand.curtainOpen,
      timeout: const Duration(seconds: 6),
    );

    print('CURTAIN OPEN ACK: $response');

    if (!mounted) {
      return;
    }

    setState(() {
      _curtainOpen = true;
      _status = 'CURTAIN OPEN';
    });
  } catch (e) {
    print('CURTAIN OPEN failed: $e');

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'CURTAIN OPEN FAILED';
    });
  } finally {
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }
}


// ============================================================
// CURTAIN CLOSE
// ============================================================

Future<void> _closeCurtain() async {
  if (!_connected || _busy) {
    return;
  }

  setState(() {
    _busy = true;
    _status = 'CLOSING CURTAIN...';
  });

  try {
    final response =
        await _bleService.sendCommandAndWaitAck(
      DeviceCommand.curtainClose,
      timeout: const Duration(seconds: 6),
    );

    print('CURTAIN CLOSE ACK: $response');

    if (!mounted) {
      return;
    }

    setState(() {
      _curtainOpen = false;
      _status = 'CURTAIN CLOSED';
    });
  } catch (e) {
    print('CURTAIN CLOSE failed: $e');

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'CURTAIN CLOSE FAILED';
    });
  } finally {
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }
}


// ============================================================
// PING
// ============================================================







  // ============================================================
  // PING
  // ============================================================

  Future<void> _ping() async {
    if (!_connected ||
        _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final response =
          await _bleService
              .sendCommandAndWaitAck(
        DeviceCommand.ping,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'PING OK';

        _lastMessage =
            response;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'PING FAILED';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> _disconnect() async {
    await _bleService.disconnect();

    if (!mounted) {
      return;
    }

    setState(() {
      _connected = false;

      _status =
          'DISCONNECTED';
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _messageSubscription
        ?.cancel();

    _connectionSubscription
        ?.cancel();

    _bleService.dispose();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SP!ED BLE Test',
        ),
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [

            // ==============================
            // BLE STATUS
            // ==============================

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Column(
                  children: [
                    const Text(
                      'BLE STATUS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 22,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      'RX: $_lastMessage',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==============================
            // CONNECT
            // ==============================

            ElevatedButton(
              // 연결 성공하면 자동 비활성화
              onPressed:
                  _connected ||
                          _busy
                      ? null
                      : _connect,

              child: Text(
                _connected
                    ? 'CONNECTED'
                    : 'CONNECT ESP32',
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            ElevatedButton(
              onPressed:
                  !_connected ||
                          _busy
                      ? null
                      : _ping,

              child: const Text(
                'PING',
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            const Divider(),

            const SizedBox(
              height: 20,
            ),

            // ==============================
            // LIGHT STATUS
            // ==============================

            Text(
              _lightOn
                  ? 'LIGHT: ON'
                  : 'LIGHT: OFF',
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Row(
              children: [

                // ==========================
                // LIGHT ON
                // ==========================

                Expanded(
                  child:
                      ElevatedButton(
                    // 이미 ON이면 비활성화
                    onPressed:
                        !_connected ||
                                _busy ||
                                _lightOn
                            ? null
                            : _turnLightOn,

                    child:
                        const Text(
                      'LIGHT ON',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                // ==========================
                // LIGHT OFF
                // ==========================

                Expanded(
                  child:
                      ElevatedButton(
                    // 이미 OFF이면 비활성화
                    onPressed:
                        !_connected ||
                                _busy ||
                                !_lightOn
                            ? null
                            : _turnLightOff,

                    child:
                        const Text(
                      'LIGHT OFF',
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            OutlinedButton(
              onPressed:
                  !_connected ||
                          _busy
                      ? null
                      : _disconnect,

              child: const Text(
                'DISCONNECT',
              ),
            ),
          ],
        ),
      ),
    );
  }
}