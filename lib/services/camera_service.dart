import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller =>
      _controller;

  bool get isInitialized =>
      _controller?.value.isInitialized ?? false;

  Future<void> initialize() async {
    final cameras =
        await availableCameras();

    if (cameras.isEmpty) {
      throw Exception(
        'No camera found.',
      );
    }

    CameraDescription selectedCamera =
        cameras.first;

    for (final camera in cameras) {
      if (camera.lensDirection ==
          CameraLensDirection.front) {
        selectedCamera = camera;
        break;
      }
    }

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
  }

  Future<void> startImageStream(
    void Function(CameraImage image)
        onImage,
  ) async {
    if (_controller == null ||
        !_controller!.value.isInitialized) {
      throw Exception(
        'Camera is not initialized.',
      );
    }

    await _controller!.startImageStream(
      onImage,
    );
  }

  Future<void> stopImageStream() async {
    if (_controller != null &&
        _controller!
            .value
            .isStreamingImages) {
      await _controller!
          .stopImageStream();
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
  }
}