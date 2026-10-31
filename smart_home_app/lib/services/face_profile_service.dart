import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceProfileService {
  static final FaceProfileService _instance = FaceProfileService._internal();
  factory FaceProfileService() => _instance;
  FaceProfileService._internal();

  static const String modelAsset = 'assets/mobilefacenet.tflite';
  static const String _keyTemplates = 'enrolled_face_templates_v6';
  static const String _keyEnrollmentDate = 'face_enrollment_date_v6';
  static const String _keyLivenessEnabled = 'face_liveness_enabled_v6';

  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  List<List<double>> _enrolledTemplates = [];
  bool _isInitialized = false;

  /// Strict security threshold: 0.72 - 0.78 ensures only authorized user matches
  /// and strangers (typically 0.15 - 0.45) are reliably rejected.
  static const double matchThreshold = 0.72;

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadEnrolledTemplates();
    await _loadModel();
    _isInitialized = true;
  }

  Future<bool> _loadModel() async {
    if (_isModelLoaded && _interpreter != null) return true;
    try {
      final options = InterpreterOptions()..threads = 2;
      final appDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDir.path}/mobilefacenet.tflite');
      if (!modelFile.existsSync() || modelFile.lengthSync() < 1000) {
        final rawAsset = await rootBundle.load(modelAsset);
        await modelFile.writeAsBytes(rawAsset.buffer.asUint8List(), flush: true);
      }
      _interpreter = Interpreter.fromFile(modelFile, options: options);
      
      final inTensors = _interpreter!.getInputTensors();
      final outTensors = _interpreter!.getOutputTensors();
      debugPrint('TFLITE_LOAD: inCount=${inTensors.length}, outCount=${outTensors.length}');
      for (var t in inTensors) {
        debugPrint('TFLITE_IN: shape=${t.shape}, type=${t.type}');
      }
      for (var t in outTensors) {
        debugPrint('TFLITE_OUT: shape=${t.shape}, type=${t.type}');
      }

      // Test inference with the model's native batch size 2 [2, 112, 112, 3] -> [2, 192]
      final dummyInput = Float32List(2 * 112 * 112 * 3).reshape([2, 112, 112, 3]);
      final dummyOutput = List.generate(2, (_) => List.filled(192, 0.0));
      _interpreter!.run(dummyInput, dummyOutput);
      debugPrint('TFLITE_TEST_RUN: SUCCESS! Output length=${dummyOutput[0].length}, firstVal=${dummyOutput[0][0]}');

      _isModelLoaded = true;
      return true;
    } catch (e, stack) {
      debugPrint('TFLITE_LOAD_ERROR: $e\n$stack');
      return false;
    }
  }

  Future<void> _loadEnrolledTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyTemplates);
      if (list != null && list.isNotEmpty) {
        _enrolledTemplates = list.map((str) {
          return str.split(',').map((s) => double.parse(s.trim())).toList();
        }).toList();
        debugPrint('ENROLLED_TEMPLATES_LOADED: count=${_enrolledTemplates.length}');
      } else {
        _enrolledTemplates = [];
      }
    } catch (e) {
      debugPrint('Error loading enrolled templates: $e');
      _enrolledTemplates = [];
    }
  }

  bool get isFaceEnrolled => _enrolledTemplates.isNotEmpty;

  List<List<double>> get enrolledTemplates => _enrolledTemplates;

  Future<void> saveEnrolledTemplates(List<List<double>> templates) async {
    _enrolledTemplates = List<List<double>>.from(templates);
    final prefs = await SharedPreferences.getInstance();
    final stringList = templates.map((t) => t.join(',')).toList();
    await prefs.setStringList(_keyTemplates, stringList);
    await prefs.setString(_keyEnrollmentDate, DateTime.now().toIso8601String());
    debugPrint('ENROLLED_TEMPLATES_SAVED: count=${templates.length}');
  }

  Future<void> clearOwnerProfile() async {
    _enrolledTemplates = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTemplates);
    await prefs.remove(_keyEnrollmentDate);
  }

  Future<String?> getEnrollmentDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyEnrollmentDate);
    if (str == null) return null;
    try {
      final dt = DateTime.parse(str);
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} at $hour:$min';
    } catch (_) {
      return str;
    }
  }

  Future<bool> isLivenessEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLivenessEnabled) ?? true;
  }

  Future<void> setLivenessEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLivenessEnabled, enabled);
  }

  /// Extracts 192-d MobileFaceNet embedding from CameraImage + Face bounding box
  Future<List<double>?> extractFaceEmbedding(
    CameraImage cameraImage,
    Face face, {
    int rotationDegrees = 0,
  }) async {
    if (!_isModelLoaded || _interpreter == null) {
      final ok = await _loadModel();
      if (!ok || _interpreter == null) return null;
    }

    try {
      final box = face.boundingBox;
      final double marginX = box.width * 0.12;
      final double marginY = box.height * 0.12;
      final double cropLeft = box.left - marginX;
      final double cropTop = box.top - marginY;
      final double cropW = box.width + (2 * marginX);
      final double cropH = box.height + (2 * marginY);

      if (cropW <= 10 || cropH <= 10) return null;

      // Sample 112x112 normalized floats directly (<5ms)
      final singleFaceFloats = Float32List(112 * 112 * 3);
      final sampled = _sampleUprightFacePixels(
        cameraImage,
        singleFaceFloats,
        cropLeft,
        cropTop,
        cropW,
        cropH,
        rotationDegrees,
      );

      if (!sampled) {
        debugPrint('SAMPLE_PIXELS_FAILED');
        return null;
      }

      // Model expects batch size 2 [2, 112, 112, 3] -> [2, 192]
      final batchFloats = Float32List(2 * 112 * 112 * 3);
      batchFloats.setRange(0, 37632, singleFaceFloats);
      batchFloats.setRange(37632, 75264, singleFaceFloats);

      final input = batchFloats.reshape([2, 112, 112, 3]);
      final output = List.generate(2, (_) => List.filled(192, 0.0));

      _interpreter!.run(input, output);

      final List<double> raw = output[0];
      return _l2Normalize(raw);
    } catch (e, stack) {
      debugPrint('EMBEDDING_INFERENCE_ERROR: $e\n$stack');
      return null;
    }
  }

  /// Verifies a probe embedding against all enrolled templates.
  /// Returns best similarity and whether it meets the security threshold.
  ({bool isMatch, double similarity}) verifyFace(List<double> probe) {
    if (_enrolledTemplates.isEmpty) {
      return (isMatch: false, similarity: 0.0);
    }
    double bestSim = -1.0;
    for (final template in _enrolledTemplates) {
      final sim = cosineSimilarity(probe, template);
      if (sim > bestSim) {
        bestSim = sim;
      }
    }
    final bool match = bestSim >= matchThreshold;
    return (isMatch: match, similarity: bestSim);
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    if (denom == 0) return 0.0;
    return (dot / denom).clamp(-1.0, 1.0);
  }

  List<double> _l2Normalize(List<double> v) {
    double sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = sqrt(sum);
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }

  /// Direct pixel sampler: reads Y and UV bytes directly from sensor image
  /// and samples upright 112x112 normalized floats in <5ms.
  bool _sampleUprightFacePixels(
    CameraImage image,
    Float32List outFloats,
    double cropLeft,
    double cropTop,
    double cropW,
    double cropH,
    int rotationDegrees,
  ) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int planeCount = image.planes.length;

      final yBuffer = image.planes[0].bytes;
      final int yRowStride = image.planes[0].bytesPerRow;
      final int yPixelStride = image.planes[0].bytesPerPixel ?? 1;

      final bool isSingleBufferNV21 = planeCount == 1;
      final bool isThreePlaneYUV = planeCount >= 3;

      Uint8List? uBuffer;
      Uint8List? vBuffer;
      int uvRowStride = 0;
      int uvPixelStride = 1;
      int vuBaseOffset = 0;

      if (isSingleBufferNV21) {
        vuBaseOffset = yRowStride * height;
      } else if (isThreePlaneYUV) {
        uBuffer = image.planes[1].bytes;
        vBuffer = image.planes[2].bytes;
        uvRowStride = image.planes[1].bytesPerRow;
        uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
      } else {
        return false;
      }

      int outIdx = 0;
      for (int dy = 0; dy < 112; dy++) {
        final double sy = cropTop + (dy * cropH / 112.0);
        for (int dx = 0; dx < 112; dx++) {
          final double sx = cropLeft + (dx * cropW / 112.0);

          int srcX;
          int srcY;

          switch (rotationDegrees) {
            case 90:
              srcX = (width - 1 - sy).round();
              srcY = sx.round();
              break;
            case 180:
              srcX = (width - 1 - sx).round();
              srcY = (height - 1 - sy).round();
              break;
            case 270:
              srcX = sy.round();
              srcY = (height - 1 - sx).round();
              break;
            case 0:
            default:
              srcX = sx.round();
              srcY = sy.round();
              break;
          }

          srcX = srcX.clamp(0, width - 1);
          srcY = srcY.clamp(0, height - 1);

          final int yIndex = srcY * yRowStride + srcX * yPixelStride;
          if (yIndex >= yBuffer.length) return false;
          final int yVal = yBuffer[yIndex] & 0xFF;

          int uVal = 128;
          int vVal = 128;

          if (isSingleBufferNV21) {
            final int uvIndex = vuBaseOffset + (srcY >> 1) * yRowStride + (srcX & ~1);
            if (uvIndex + 1 < yBuffer.length) {
              vVal = yBuffer[uvIndex] & 0xFF;
              uVal = yBuffer[uvIndex + 1] & 0xFF;
            }
          } else if (isThreePlaneYUV && uBuffer != null && vBuffer != null) {
            final int uvIndex = (srcY >> 1) * uvRowStride + (srcX >> 1) * uvPixelStride;
            if (uvIndex < uBuffer.length && uvIndex < vBuffer.length) {
              uVal = uBuffer[uvIndex] & 0xFF;
              vVal = vBuffer[uvIndex] & 0xFF;
            }
          }

          final int c = yVal - 16;
          final int d = uVal - 128;
          final int e = vVal - 128;

          final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
          final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
          final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

          outFloats[outIdx++] = (r - 127.5) / 127.5;
          outFloats[outIdx++] = (g - 127.5) / 127.5;
          outFloats[outIdx++] = (b - 127.5) / 127.5;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error sampling upright pixels: $e');
      return false;
    }
  }
}
