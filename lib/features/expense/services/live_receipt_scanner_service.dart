import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_amount_parser.dart';

class LiveReceiptScanFrameResult {
  const LiveReceiptScanFrameResult({
    required this.rawText,
    this.amountMatch,
  });

  final String rawText;
  final ReceiptAmountMatch? amountMatch;
}

class LiveReceiptScannerService {
  LiveReceiptScannerService()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<LiveReceiptScanFrameResult?> scanFrame({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    final inputImage = _toInputImage(
      image: image,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (inputImage == null) {
      return null;
    }

    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;
    if (rawText.trim().isEmpty) {
      return const LiveReceiptScanFrameResult(rawText: '');
    }

    return LiveReceiptScanFrameResult(
      rawText: rawText,
      amountMatch: ReceiptAmountParser.extractBestMatch(rawText),
    );
  }

  InputImage? _toInputImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final rotation = _imageRotation(
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (rotation == null) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }

    final bytes = _cameraImageToBytes(image);
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _cameraImageToBytes(CameraImage image) {
    if (Platform.isIOS) {
      return image.planes.first.bytes;
    }

    final buffer = WriteBuffer();
    for (final plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  InputImageRotation? _imageRotation({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    final deviceRotation = _orientationToDegrees[deviceOrientation];
    if (deviceRotation == null) {
      return null;
    }

    final rotationCompensation = camera.lensDirection == CameraLensDirection.front
        ? (sensorOrientation + deviceRotation) % 360
        : (sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  static const Map<DeviceOrientation, int> _orientationToDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  void dispose() {
    _recognizer.close();
  }
}
