import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/protocol/device_command.dart';
import '../services/ble_service.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';
import '../services/wake_detector.dart';
import '../services/weather_service.dart';

enum _PagePhase {
  starting,
  monitoring,
  routine,
  complete,
  error,
}

enum _StepState {
  waiting,
  running,
  done,
  failed,
}

class MorningRoutinePage extends StatefulWidget {
  const MorningRoutinePage({super.key});

  @override
  State<MorningRoutinePage> createState() => _MorningRoutinePageState();
}

class _MorningRoutinePageState extends State<MorningRoutinePage> {
  static const int _requiredAwakeFrames = 3;
  static const Duration _inferenceInterval = Duration(milliseconds: 600);

  final BleService _bleService = BleService();
  final CameraService _cameraService = CameraService();
  final TtsService _ttsService = TtsService();
  final WakeDetector _wakeDetector = WakeDetector();
  final WeatherService _weatherService = WeatherService();

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final Map<String, _StepState> _steps = <String, _StepState>{
    'Greeting': _StepState.waiting,
    'Weather briefing': _StepState.waiting,
    'Microwave ON': _StepState.waiting,
    'LED ON': _StepState.waiting,
  };

  _PagePhase _phase = _PagePhase.starting;
  WakeState _wakeState = WakeState.unknown;
  WeatherSnapshot? _weather;
  DateTime _lastInference = DateTime.fromMillisecondsSinceEpoch(0);

  bool _processingFrame = false;
  bool _routineStarted = false;
  bool _bleConnected = false;
  bool _bleConnecting = false;
  int _awakeFrames = 0;
  double? _verticality;
  String _bleStatus = 'Searching for ESP32...';
  String? _error;

  @override
  void initState() {
    super.initState();

    _connectionSubscription = _bleService.connectionStates.listen((state) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bleConnected = state == BluetoothConnectionState.connected;
        _bleStatus = _bleConnected ? 'ESP32 connected' : 'ESP32 disconnected';
      });
    });

    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _ttsService.initialize();
      await _wakeDetector.load();
      await _cameraService.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _phase = _PagePhase.monitoring;
      });

      await _cameraService.startImageStream(_processFrame);
      unawaited(_connectBle());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _phase = _PagePhase.error;
      });
    }
  }

  Future<bool> _connectBle() async {
    if (_bleConnected || _bleConnecting) {
      return _bleConnected;
    }

    if (mounted) {
      setState(() {
        _bleConnecting = true;
        _bleStatus = 'Connecting to SPIED_ESP32...';
      });
    }

    try {
      await _bleService.connect();

      if (mounted) {
        setState(() {
          _bleConnected = true;
          _bleStatus = 'ESP32 connected';
        });
      }

      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _bleConnected = false;
          _bleStatus = 'ESP32 unavailable';
        });
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _bleConnecting = false;
        });
      }
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processingFrame || _routineStarted) {
      return;
    }

    final now = DateTime.now();

    if (now.difference(_lastInference) < _inferenceInterval) {
      return;
    }

    _processingFrame = true;
    _lastInference = now;

    try {
      final controller = _cameraService.controller;
      final rotation = controller?.description.sensorOrientation ?? 0;
      final result = _wakeDetector.detect(
        image,
        rotationDegrees: rotation,
      );

      if (result.state == WakeState.awake) {
        _awakeFrames += 1;
      } else {
        _awakeFrames = 0;
      }

      if (mounted) {
        setState(() {
          _wakeState = result.state;
          _verticality = result.verticality;
        });
      }

      if (_awakeFrames >= _requiredAwakeFrames) {
        unawaited(_beginRoutine());
      }
    } catch (error) {
      debugPrint('Wake inference failed: $error');
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _beginRoutine() async {
    if (_routineStarted) {
      return;
    }

    _routineStarted = true;

    if (mounted) {
      setState(() {
        _phase = _PagePhase.routine;
      });
    }

    await _cameraService.stopImageStream();
    await _cameraService.dispose();

    await _runSpeechStep(
      'Greeting',
      'GOOD MORNING MASTER.',
    );

    _setStep('Weather briefing', _StepState.running);

    try {
      final weather = await _weatherService.fetchToday();

      if (mounted) {
        setState(() {
          _weather = weather;
        });
      }

      await _ttsService.speak(weather.briefing);
      _setStep('Weather briefing', _StepState.done);
    } catch (error) {
      _setStep('Weather briefing', _StepState.failed);
      await _ttsService.speak(
        'I could not retrieve today\'s weather information.',
      );
    }

    if (!_bleConnected) {
      await _connectBle();
    }

    await _runDeviceStep(
      'Microwave ON',
      DeviceCommand.microwaveOn,
    );

    await Future<void>.delayed(const Duration(seconds: 1));

    await _runDeviceStep(
      'LED ON',
      DeviceCommand.lightOn,
    );

    if (mounted) {
      setState(() {
        _phase = _PagePhase.complete;
      });
    }
  }

  Future<void> _runSpeechStep(String name, String message) async {
    _setStep(name, _StepState.running);

    try {
      await _ttsService.speak(message);
      _setStep(name, _StepState.done);
    } catch (_) {
      _setStep(name, _StepState.failed);
    }
  }

  Future<void> _runDeviceStep(String name, DeviceCommand command) async {
    _setStep(name, _StepState.running);

    if (!_bleConnected) {
      _setStep(name, _StepState.failed);
      return;
    }

    try {
      await _bleService.sendCommandAndWaitAck(
        command,
        timeout: const Duration(seconds: 6),
      );
      _setStep(name, _StepState.done);
    } catch (error) {
      debugPrint('${command.wireValue} failed: $error');
      _setStep(name, _StepState.failed);
    }
  }

  Future<void> _sendManual(DeviceCommand command) async {
    if (!_bleConnected && !await _connectBle()) {
      return;
    }

    try {
      await _bleService.sendCommandAndWaitAck(
        command,
        timeout: const Duration(seconds: 6),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Command failed: $error')),
      );
    }
  }

  void _setStep(String name, _StepState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _steps[name] = state;
    });
  }

  @override
  void dispose() {
    unawaited(_connectionSubscription?.cancel());
    unawaited(_cameraService.dispose());
    unawaited(_bleService.dispose());
    unawaited(_ttsService.stop());
    _weatherService.dispose();
    _wakeDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_phase) {
          _PagePhase.starting => _buildStarting(),
          _PagePhase.monitoring => _buildMonitoring(),
          _PagePhase.routine || _PagePhase.complete => _buildRoutine(),
          _PagePhase.error => _buildError(),
        },
      ),
    );
  }

  Widget _buildStarting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 18),
          Text('Preparing camera and AI...'),
        ],
      ),
    );
  }

  Widget _buildMonitoring() {
    final controller = _cameraService.controller;

    if (controller == null || !controller.value.isInitialized) {
      return _buildStarting();
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CameraPreview(controller),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x99000000),
                Colors.transparent,
                Color(0xCC000000),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'SP!ED',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _StatusPill(
                    label: _bleStatus,
                    active: _bleConnected,
                  ),
                ],
              ),
              const Spacer(),
              Card(
                color: const Color(0xDD111827),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      const Icon(Icons.visibility, size: 34),
                      const SizedBox(height: 10),
                      const Text(
                        'Watching for wake-up',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_wakeState.name.toUpperCase()}  ·  '
                        'confidence ${_awakeFrames.clamp(0, _requiredAwakeFrames)}/$_requiredAwakeFrames',
                      ),
                      Text(
                        _verticality == null
                            ? 'Verticality: -'
                            : 'Verticality: ${_verticality!.toStringAsFixed(3)}',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _beginRoutine,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('RUN DEMO NOW'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutine() {
    final complete = _phase == _PagePhase.complete;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Text(
          complete ? 'Morning routine complete' : 'Good morning, Master',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(_bleStatus),
        const SizedBox(height: 24),
        if (_weather != null) _WeatherCard(weather: _weather!),
        if (_weather != null) const SizedBox(height: 20),
        ..._steps.entries.map(
          (entry) => _RoutineStepTile(
            title: entry.key,
            state: entry.value,
          ),
        ),
        const SizedBox(height: 24),
        if (!_bleConnected)
          FilledButton.icon(
            onPressed: _bleConnecting ? null : _connectBle,
            icon: const Icon(Icons.bluetooth),
            label: const Text('RECONNECT ESP32'),
          ),
        if (complete) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            'Manual controls',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => _sendManual(DeviceCommand.microwaveOn),
                child: const Text('MICROWAVE ON'),
              ),
              OutlinedButton(
                onPressed: () => _sendManual(DeviceCommand.microwaveOff),
                child: const Text('MICROWAVE OFF'),
              ),
              OutlinedButton(
                onPressed: () => _sendManual(DeviceCommand.lightOn),
                child: const Text('LED ON'),
              ),
              OutlinedButton(
                onPressed: () => _sendManual(DeviceCommand.lightOff),
                child: const Text('LED OFF'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'The app could not start.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xCC166534) : const Color(0xCC7F1D1D),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather});

  final WeatherSnapshot weather;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Today · ${weather.locationLabel}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _Metric(
                  icon: Icons.thermostat,
                  value: '${weather.temperatureCelsius.toStringAsFixed(1)}°C',
                  label: 'Temperature',
                ),
                _Metric(
                  icon: Icons.water_drop,
                  value: '${weather.humidityPercent}%',
                  label: 'Humidity',
                ),
                _Metric(
                  icon: Icons.umbrella,
                  value: '${weather.precipitationProbabilityPercent}%',
                  label: 'Rain',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RoutineStepTile extends StatelessWidget {
  const _RoutineStepTile({required this.title, required this.state});

  final String title;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (state) {
      _StepState.waiting => (Icons.circle_outlined, Colors.grey, 'Waiting'),
      _StepState.running => (Icons.sync, Colors.amber, 'Running'),
      _StepState.done => (Icons.check_circle, Colors.green, 'Done'),
      _StepState.failed => (Icons.error, Colors.redAccent, 'Failed'),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: Text(text, style: TextStyle(color: color)),
      ),
    );
  }
}
