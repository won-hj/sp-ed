import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import 'services/ble_service.dart';
import 'package:flutter_application_1/services/wake_detector.dart';
import 'core/protocol/device_command.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 데모 중 orientation이 바뀌어서
  // verticality가 뒤집히는 것을 막음.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WakeTestPage(),
    );
  }
}

class WakeTestPage extends StatefulWidget {
  const WakeTestPage({super.key});

  @override
  State<WakeTestPage> createState() =>
      _WakeTestPageState();
}

class _WakeTestPageState
    extends State<WakeTestPage> {
  CameraController? _cameraController;

  final BleService _bleService =
      BleService();

  String _bleStatus =
      'DISCONNECTED';

  String _bleMessage =
      '-';





  //+++++++++++++++++++++++++++++++

  final WakeDetector _wakeDetector =
      WakeDetector();

  WakeState _state =
      WakeState.unknown;

  double? _verticality;

  bool _processing = false;

  DateTime _lastInference =
      DateTime.fromMillisecondsSinceEpoch(0);

  String? _error;

  @override
  void initState() {
    super.initState();

    _bleService.messages.listen(
    (message) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bleMessage =
            message;
      });
    },
  );


    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _wakeDetector.load();

      final cameras =
          await availableCameras();

      if (cameras.isEmpty) {
        throw Exception(
          'No camera available.',
        );
      }

      // 일단 후면 카메라 사용
      final camera =
          cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller =
          CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      _cameraController = controller;

      if (mounted) {
        setState(() {});
      }

      await controller.startImageStream(
        _processFrame,
      );
    } catch (e) {
      print(e);

      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _processFrame(
    CameraImage image,
  ) async {
    if (_processing) {
      return;
    }

    final now = DateTime.now();

    // 0.5초마다 한 번만 inference
    if (now.difference(_lastInference) <
        const Duration(
          milliseconds: 500,
        )) {
      return;
    }

    _processing = true;
    _lastInference = now;

    try {
      final rotation =
          _cameraController
                  ?.description
                  .sensorOrientation ??
              0;

      final result =
          _wakeDetector.detect(
        image,
        rotationDegrees: rotation,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _state = result.state;
        _verticality =
            result.verticality;
      });
    } catch (e) {
      print(
        'Inference error: $e',
      );
    } finally {
      _processing = false;
    }
  }

  String get _stateText {
    switch (_state) {
      case WakeState.sleeping:
        return 'SLEEPING';

      case WakeState.awake:
        return 'AWAKE';

      case WakeState.unknown:
        return 'UNKNOWN';
    }
  }

  @override
  void dispose() {
    final controller =
        _cameraController;

    if (controller != null) {
      if (controller
          .value
          .isStreamingImages) {
        controller.stopImageStream();
      }

      controller.dispose();
    }

    _wakeDetector.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(20),
            child: Text(
              _error!,
            ),
          ),
        ),
      );
    }

    final controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(
            controller,
          ),

          Positioned(
            left: 20,
            right: 20,
            top: 50,
            child: Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      _stateText,
                      style:
                          const TextStyle(
                        fontSize: 30,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      _verticality == null
                          ? 'Verticality: -'
                          : 'Verticality: '
                              '${_verticality!.toStringAsFixed(3)}',
                    ),
                  ],
                ),
              ),
            ),
          ),

          //++++
          Positioned(
  left: 20,
  right: 20,
  bottom: 30,
  child: Card(
    child: Padding(
      padding:
          const EdgeInsets.all(
        16,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Text(
            'BLE: $_bleStatus',
          ),

          Text(
            'RX: $_bleMessage',
          ),

          const SizedBox(
            height: 10,
          ),

          ElevatedButton(
            onPressed: () async {
              try {
                setState(() {
                  _bleStatus =
                      'CONNECTING';
                });

                await _bleService
                    .connect();

                setState(() {
                  _bleStatus =
                      'CONNECTED';
                });
              } catch (e) {
                setState(() {
                  _bleStatus =
                      'ERROR: $e';
                });
              }
            },
            child:
                const Text(
              'Connect ESP32',
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              await _bleService
                  .send('PING');
            },
            child:
                const Text(
              'Send PING',
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              await _bleService
                  .send('LIGHT_ON');
            },
            child:
                const Text(
              'Send LED ON',
            ),
          ),


        ],
      ),
    ),
  ),
)

//++++
          
        ],
      ),
    );
  }
}