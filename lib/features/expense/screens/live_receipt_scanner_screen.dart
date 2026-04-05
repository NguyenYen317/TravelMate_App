import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/live_receipt_scanner_service.dart';

class LiveReceiptScanResult {
  const LiveReceiptScanResult({
    required this.amount,
    required this.rawText,
    this.matchedLine,
  });

  final double amount;
  final String rawText;
  final String? matchedLine;
}

class LiveReceiptScannerScreen extends StatefulWidget {
  const LiveReceiptScannerScreen({super.key});

  @override
  State<LiveReceiptScannerScreen> createState() =>
      _LiveReceiptScannerScreenState();
}

class _LiveReceiptScannerScreenState extends State<LiveReceiptScannerScreen> {
  final LiveReceiptScannerService _scannerService = LiveReceiptScannerService();
  final TextEditingController _amountCtrl = TextEditingController();

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  String? _error;
  String _rawTextPreview = '';
  String? _matchedLine;
  int _bestScore = -100000;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _stopCameraStream();
    _cameraController?.dispose();
    _scannerService.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        setState(() {
          _error = 'Tinh nang scan realtime chi ho tro Android/iOS.';
          _isInitializing = false;
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'Khong tim thay camera tren thiet bi.';
          _isInitializing = false;
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _cameraController = controller;

      await controller.initialize();
      await controller.startImageStream(_onCameraImage);

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Khong the khoi tao camera: $error';
        _isInitializing = false;
      });
    }
  }

  Future<void> _stopCameraStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isStreamingImages) {
      return;
    }
    await controller.stopImageStream();
  }

  Future<void> _onCameraImage(CameraImage image) async {
    final controller = _cameraController;
    if (controller == null || _isProcessingFrame || !mounted) {
      return;
    }

    _isProcessingFrame = true;
    try {
      final frameResult = await _scannerService.scanFrame(
        image: image,
        camera: controller.description,
        deviceOrientation: controller.value.deviceOrientation,
      );
      if (!mounted || frameResult == null) {
        return;
      }

      if (frameResult.rawText.trim().isNotEmpty) {
        _rawTextPreview = frameResult.rawText;
      }

      final amountMatch = frameResult.amountMatch;
      if (amountMatch != null &&
          (amountMatch.score > _bestScore ||
              (amountMatch.score == _bestScore &&
                  _parseAmount(_amountCtrl.text) < amountMatch.amount))) {
        _bestScore = amountMatch.score;
        _amountCtrl.text = amountMatch.amount.toStringAsFixed(0);
        _matchedLine = amountMatch.line;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Ignore single-frame errors and continue streaming.
    } finally {
      _isProcessingFrame = false;
    }
  }

  double _parseAmount(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return 0;
    }
    final plain = normalized.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(plain) ?? 0;
  }

  Future<void> _saveAndClose() async {
    final amount = _parseAmount(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('So tien khong hop le.')));
      return;
    }

    await _stopCameraStream();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      LiveReceiptScanResult(
        amount: amount,
        rawText: _rawTextPreview,
        matchedLine: _matchedLine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan hoa don')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: Text('Camera chua san sang.'));
    }

    final previewText = _rawTextPreview.trim().isEmpty
        ? 'Dua camera vao hoa don de nhan dien text...'
        : _rawTextPreview.trim();

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CameraPreview(controller),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
            ],
            decoration: const InputDecoration(
              labelText: 'So tien nhan dien',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (_matchedLine != null && _matchedLine!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Dong khop: $_matchedLine',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            previewText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dong'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saveAndClose,
                  child: const Text('Luu'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
