import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

enum WakeState {
  sleeping,
  awake,
  unknown,
}

class WakeResult {
  final WakeState state;
  final double? verticality;

  const WakeResult({
    required this.state,
    required this.verticality,
  });
}

class WakeDetector {
  static const int inputSize = 192;

  // MoveNet keypoint indices
  static const int leftShoulder = 5;
  static const int rightShoulder = 6;
  static const int leftHip = 11;
  static const int rightHip = 12;

  static const double keypointThreshold = 0.25;

  Interpreter? _interpreter;

  /// MoveNet Lightning 모델 로드
  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/movenet_lightning.tflite',
    );

    print(
      'MoveNet input: ${_interpreter!.getInputTensor(0).shape} '
      '${_interpreter!.getInputTensor(0).type}',
    );

    print(
      'MoveNet output: ${_interpreter!.getOutputTensor(0).shape} '
      '${_interpreter!.getOutputTensor(0).type}',
    );
  }

  /// 카메라 한 프레임을 입력받아
  /// SLEEPING / AWAKE / UNKNOWN 판정
  WakeResult detect(
    CameraImage image, {
    int rotationDegrees = 0,
  }) {
    if (_interpreter == null) {
      throw StateError('MoveNet is not loaded.');
    }

    final input = _cameraImageToInput(
      image,
      rotationDegrees,
    );

    // MoveNet output:
    // [1, 1, 17, 3]
    // 각 keypoint = [y, x, confidence]
    final output = List.generate(
      1,
      (_) => List.generate(
        1,
        (_) => List.generate(
          17,
          (_) => List<double>.filled(3, 0.0),
        ),
      ),
    );

    _interpreter!.run(
      input,
      output,
    );

    final keypoints = output[0][0];

    return _classify(keypoints);
  }

  WakeResult _classify(
    List<List<double>> keypoints,
  ) {
    final ls = keypoints[leftShoulder];
    final rs = keypoints[rightShoulder];
    final lh = keypoints[leftHip];
    final rh = keypoints[rightHip];

    final scores = [
      ls[2],
      rs[2],
      lh[2],
      rh[2],
    ];

    // 어깨/골반 중 하나라도 confidence가 너무 낮으면
    // 자세를 강제로 판정하지 않음
    if (scores.any(
      (score) => score < keypointThreshold,
    )) {
      return const WakeResult(
        state: WakeState.unknown,
        verticality: null,
      );
    }

    // 양쪽 어깨의 중앙
    final shoulderY =
        (ls[0] + rs[0]) / 2.0;

    final shoulderX =
        (ls[1] + rs[1]) / 2.0;

    // 양쪽 골반의 중앙
    final hipY =
        (lh[0] + rh[0]) / 2.0;

    final hipX =
        (lh[1] + rh[1]) / 2.0;

    final dy =
        (hipY - shoulderY).abs();

    final dx =
        (hipX - shoulderX).abs();

    // 1에 가까울수록 상체가 수직
    // 0에 가까울수록 상체가 수평
    final verticality =
        dy / (dx + dy + 0.000001);

    if (verticality >= 0.65) {
      return WakeResult(
        state: WakeState.awake,
        verticality: verticality,
      );
    }

    if (verticality <= 0.35) {
      return WakeResult(
        state: WakeState.sleeping,
        verticality: verticality,
      );
    }

    return WakeResult(
      state: WakeState.unknown,
      verticality: verticality,
    );
  }

  /// Android 카메라의 YUV420 프레임을
  /// MoveNet 입력 크기 192x192 RGB로 변환
  List<List<List<List<int>>>> _cameraImageToInput(
    CameraImage image,
    int rotationDegrees,
  ) {
    if (image.planes.length < 3) {
      throw UnsupportedError(
        'Expected YUV420 camera image, '
        'but received ${image.planes.length} plane(s).',
      );
    }

    final width = image.width;
    final height = image.height;

    final normalizedRotation =
        rotationDegrees % 360;

    final rotated =
        normalizedRotation == 90 ||
        normalizedRotation == 270;

    final orientedWidth =
        rotated ? height : width;

    final orientedHeight =
        rotated ? width : height;

    // Colab에서 사용했던 resize_with_pad와 유사하게
    // aspect ratio를 유지하면서 192x192에 배치
    final scaleX =
        inputSize / orientedWidth;

    final scaleY =
        inputSize / orientedHeight;

    final scale =
        scaleX < scaleY
            ? scaleX
            : scaleY;

    final resizedWidth =
        orientedWidth * scale;

    final resizedHeight =
        orientedHeight * scale;

    final offsetX =
        (inputSize - resizedWidth) / 2.0;

    final offsetY =
        (inputSize - resizedHeight) / 2.0;

    // [1, 192, 192, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (_) => List.generate(
          inputSize,
          (_) => List<int>.filled(
            3,
            0,
          ),
        ),
      ),
    );

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yRowStride =
        yPlane.bytesPerRow;

    final uvRowStride =
        uPlane.bytesPerRow;

    final uvPixelStride =
        uPlane.bytesPerPixel ?? 1;

    for (int targetY = 0;
        targetY < inputSize;
        targetY++) {
      for (int targetX = 0;
          targetX < inputSize;
          targetX++) {
        // padding 부분은 검정색으로 유지
        if (targetX < offsetX ||
            targetX >=
                offsetX + resizedWidth ||
            targetY < offsetY ||
            targetY >=
                offsetY + resizedHeight) {
          continue;
        }

        final orientedX =
            ((targetX - offsetX) / scale)
                .floor();

        final orientedY =
            ((targetY - offsetY) / scale)
                .floor();

        int sourceX;
        int sourceY;

        // 카메라 sensor orientation 보정
        switch (normalizedRotation) {
          case 90:
            sourceX = orientedY;
            sourceY =
                height - 1 - orientedX;
            break;

          case 180:
            sourceX =
                width - 1 - orientedX;
            sourceY =
                height - 1 - orientedY;
            break;

          case 270:
            sourceX =
                width - 1 - orientedY;
            sourceY = orientedX;
            break;

          default:
            sourceX = orientedX;
            sourceY = orientedY;
        }

        sourceX = sourceX
            .clamp(0, width - 1)
            .toInt();

        sourceY = sourceY
            .clamp(0, height - 1)
            .toInt();

        final yIndex =
            sourceY * yRowStride +
            sourceX;

        final uvX =
            sourceX ~/ 2;

        final uvY =
            sourceY ~/ 2;

        final uvIndex =
            uvY * uvRowStride +
            uvX * uvPixelStride;

        if (yIndex >=
                yPlane.bytes.length ||
            uvIndex >=
                uPlane.bytes.length ||
            uvIndex >=
                vPlane.bytes.length) {
          continue;
        }

        final yValue =
            yPlane.bytes[yIndex]
                .toDouble();

        final uValue =
            uPlane.bytes[uvIndex]
                    .toDouble() -
                128.0;

        final vValue =
            vPlane.bytes[uvIndex]
                    .toDouble() -
                128.0;

        // YUV -> RGB
        final r =
            (yValue +
                    1.402 * vValue)
                .round()
                .clamp(0, 255)
                .toInt();

        final g =
            (yValue -
                    0.344136 * uValue -
                    0.714136 * vValue)
                .round()
                .clamp(0, 255)
                .toInt();

        final b =
            (yValue +
                    1.772 * uValue)
                .round()
                .clamp(0, 255)
                .toInt();

        input[0][targetY][targetX][0] =
            r;

        input[0][targetY][targetX][1] =
            g;

        input[0][targetY][targetX][2] =
            b;
      }
    }

    return input;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}