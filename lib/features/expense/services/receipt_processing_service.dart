import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'ocr_service.dart';

class ReceiptScanResult {
  ReceiptScanResult({
    required this.rawText,
    this.storeName,
    this.totalAmount,
    this.date,
    this.summary,
    this.suggestedType,
    this.cloudinaryUrl,
  });

  final String rawText;
  final String? storeName;
  final double? totalAmount;
  final DateTime? date;
  final String? summary;
  final String? suggestedType;
  final String? cloudinaryUrl;
}

class ReceiptProcessingService {
  ReceiptProcessingService({OCRService? ocrService})
    : _ocrService = ocrService ?? OCRService();

  static const String _cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  final ImagePicker _picker = ImagePicker();
  final OCRService _ocrService;

  Future<XFile?> pickReceiptImage({required ImageSource source}) {
    return _picker.pickImage(source: source, imageQuality: 85);
  }

  Future<ReceiptScanResult> scanReceiptByPath(String imagePath) async {
    final extracted = await _ocrService.processImage(imagePath);
    return ReceiptScanResult(
      rawText: extracted.rawText,
      storeName: extracted.storeName,
      totalAmount: extracted.totalAmount,
      date: extracted.date,
      summary: extracted.summary,
      suggestedType: extracted.suggestedType,
    );
  }

  Future<ReceiptScanResult?> scanReceipt({required ImageSource source}) async {
    final file = await pickReceiptImage(source: source);
    if (file == null) {
      return null;
    }

    final extracted = await _ocrService.processImage(file.path);
    return ReceiptScanResult(
      rawText: extracted.rawText,
      storeName: extracted.storeName,
      totalAmount: extracted.totalAmount,
      date: extracted.date,
      summary: extracted.summary,
      suggestedType: extracted.suggestedType,
      cloudinaryUrl: await uploadToCloudinary(file),
    );
  }

  Future<String?> uploadToCloudinary(XFile file) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final body = await response.stream.bytesToString();
    final secureUrlMatch = RegExp(
      r'"secure_url"\s*:\s*"([^"]+)"',
    ).firstMatch(body);
    if (secureUrlMatch == null) {
      return null;
    }

    return secureUrlMatch.group(1);
  }

  void dispose() {
    _ocrService.dispose();
  }
}
