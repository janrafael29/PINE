/// TFLite inference service for Ultralytics YOLO object detection.
///
/// Runs inference in a separate isolate to avoid blocking the UI.
/// Handles preprocessing, model execution, and post-processing
/// (NMS, threshold filtering, coordinate transformation).
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/app_logger.dart';
import '../core/config.dart';
import '../models/detection_result.dart';
import '../utils/detection_coordinate_transform.dart';
import '../utils/detection_post_filters.dart';
import '../utils/image_preprocessor.dart';
import '../utils/tiled_inference.dart';

/// Service for running YOLO TFLite inference.
///
/// Optimization decisions:
/// - Isolate-based inference to prevent UI jank
/// - Limited interpreter threads for 3GB RAM devices
/// - Float16 model for smaller size and faster inference
class InferenceService {
  InferenceService({AppConfig? config})
      : _config = config ?? AppConfig.balanced();

  AppConfig _config;
  bool _initialized = false;
  /// Copy of the model on disk so the inference isolate never calls [rootBundle]
  /// (Flutter asset loading requires a prepared binding on the root isolate).
  String? _modelFilePath;

  Future<String> _prepareModelFileOnDisk() async {
    if (_modelFilePath != null) return _modelFilePath!;
    final ByteData data = await rootBundle.load(_config.modelPath);
    final Directory dir = await getTemporaryDirectory();
    final File file = File(p.join(dir.path, 'pine_detection_model.tflite'));
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    _modelFilePath = file.path;
    return _modelFilePath!;
  }

  /// Sync with [AppState] / Settings (accuracy mode).
  void updateConfig(AppConfig config) {
    _config = config;
  }

  AppConfig get config => _config;

  /// Class labels from your trained model (e.g., ['mealybug', 'aphid']).
  /// Must match the order used during training.
  List<String> classLabels = ['mealybug'];

  /// Number of classes in the model. Inferred from output shape if not set.
  int? numClasses;

  /// Initializes the TFLite interpreter. Call once before inference.
  Future<void> initialize() async {
    if (_initialized) return;
    await _prepareModelFileOnDisk();
    _initialized = true;
  }

  /// Runs inference on [imageBytes] in a **background isolate** so tiled / YOLO
  /// work cannot block the UI thread (avoids ANRs).
  ///
  /// [detectionThresholdOverride] — optional floor for returned boxes (debug).
  Future<DetectionResult> runInference(
    Uint8List imageBytes, {
    double? detectionThresholdOverride,
  }) async {
    final String modelFilePath = await _prepareModelFileOnDisk();
    final _InferenceParams params = _InferenceParams(
      imageBytes: imageBytes,
      modelFilePath: modelFilePath,
      inputSize: _config.inputSize,
      detectionThreshold:
          detectionThresholdOverride ?? _config.detectionThreshold,
      nmsThreshold: _config.nmsThreshold,
      confidenceTemperature: _config.confidenceTemperature,
      maxDetections: _config.maxDetections,
      interpreterThreads: _config.interpreterThreads,
      classLabels: List.from(classLabels),
      numClasses: numClasses,
      tiledInferenceEnabled: _config.tiledInferenceEnabled,
      tiledInferenceMinShortSide: _config.tiledInferenceMinShortSide,
      tileNativeSide: _config.tileNativeSide,
      tileOverlapFraction: _config.tileOverlapFraction,
      maxTilesPerImage: _config.maxTilesPerImage,
      maxDetectionsPerTile: _config.maxDetectionsPerTile,
      ttaEnabled: _config.ttaEnabled,
    );
    return Isolate.run(() => _runInferenceIsolate(params));
  }

  void dispose() {
    _initialized = false;
    _modelFilePath = null;
  }
}

/// Parameters passed to the inference isolate.
class _InferenceParams {
  _InferenceParams({
    required this.imageBytes,
    required this.modelFilePath,
    required this.inputSize,
    required this.detectionThreshold,
    required this.nmsThreshold,
    required this.confidenceTemperature,
    required this.maxDetections,
    required this.interpreterThreads,
    required this.classLabels,
    this.numClasses,
    required this.tiledInferenceEnabled,
    required this.tiledInferenceMinShortSide,
    required this.tileNativeSide,
    required this.tileOverlapFraction,
    required this.maxTilesPerImage,
    required this.maxDetectionsPerTile,
    required this.ttaEnabled,
  });

  final Uint8List imageBytes;
  final String modelFilePath;
  final int inputSize;
  final double detectionThreshold;
  final double nmsThreshold;
  final double confidenceTemperature;
  final int maxDetections;
  final int interpreterThreads;
  final List<String> classLabels;
  final int? numClasses;
  final bool tiledInferenceEnabled;
  final int tiledInferenceMinShortSide;
  final int tileNativeSide;
  final double tileOverlapFraction;
  final int maxTilesPerImage;
  final int maxDetectionsPerTile;
  final bool ttaEnabled;
}

/// One forward pass: scaled raw boxes (post temperature), before NMS.
class _ScaledRawRun {
  _ScaledRawRun({
    required this.scaled,
    required this.rawCount,
    this.maxRaw,
    required this.sample,
  });

  final List<_RawDetection> scaled;
  final int rawCount;
  final double? maxRaw;
  final List<double> sample;
}

Float32List _flipNhwcFloat32Horizontal(Float32List src, int h, int w, int c) {
  final Float32List out = Float32List(src.length);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final int xMirror = w - 1 - x;
      final int baseOut = (y * w + x) * c;
      final int baseSrc = (y * w + xMirror) * c;
      for (var k = 0; k < c; k++) {
        out[baseOut + k] = src[baseSrc + k];
      }
    }
  }
  return out;
}

_RawDetection _flipRawDetectionHorizontal(_RawDetection d, int inputSize) {
  final bool norm = isLikelyNormalizedModelBox(d.cx, d.cy, d.w, d.h);
  final double span = norm ? 1.0 : inputSize.toDouble();
  return _RawDetection(
    cx: span - d.cx,
    cy: d.cy,
    w: d.w,
    h: d.h,
    confidence: d.confidence,
    classIndex: d.classIndex,
  );
}

class _ForwardOut {
  _ForwardOut({
    required this.detections,
    required this.rawCount,
    this.tileMaxRaw,
    required this.outputSample,
  });

  final List<Detection> detections;
  final int rawCount;
  final double? tileMaxRaw;
  final List<double> outputSample;
}

/// One interpreter load + reusable I/O buffers for single or tiled runs.
class _InterpreterSession {
  _InterpreterSession(this.interpreter, this.params) {
    inputTensor = interpreter.getInputTensor(0);
    outputTensor = interpreter.getOutputTensor(0);
    outputShape = List<int>.from(outputTensor.shape);
    final outputSize = outputShape.fold<int>(1, (a, b) => a * b);
    outputBuffer = Float32List(outputSize);
    final bool outputIs3d = outputShape.length == 3;
    output3d = outputIs3d
        ? List<List<List<double>>>.generate(
            outputShape[0],
            (_) => List<List<double>>.generate(
              outputShape[1],
              (_) => List<double>.filled(outputShape[2], 0.0),
            ),
          )
        : null;

    interpreter.allocateTensors();

    h = inputTensor.shape.length >= 4 ? inputTensor.shape[1] : params.inputSize;
    w = inputTensor.shape.length >= 4 ? inputTensor.shape[2] : params.inputSize;
    c = inputTensor.shape.length >= 4 ? inputTensor.shape[3] : 3;
    expected = h * w * c;
    inputType = inputTensor.type;

    numClasses = params.numClasses ??
        _inferNumClasses(outputShape, labelCount: params.classLabels.length);
    hasObjectness = _inferHasObjectness(
      outputShape,
      inferredNumClasses: numClasses,
      labelCount: params.classLabels.length,
    );
  }

  final Interpreter interpreter;
  final _InferenceParams params;

  late final Tensor inputTensor;
  late final Tensor outputTensor;
  late final List<int> outputShape;
  late final Float32List outputBuffer;
  late final List<List<List<double>>>? output3d;
  late final int h;
  late final int w;
  late final int c;
  late final int expected;
  late final TensorType inputType;
  late final int numClasses;
  late final bool hasObjectness;

  _ScaledRawRun _inferScaledRaw(
    Float32List inputFloat, {
    required bool logInputStats,
  }) {
    final List<List<List<double>>>? nestedOut = output3d;

    if (logInputStats) {
      var maxIn = 0.0;
      var sumIn = 0.0;
      for (final v in inputFloat) {
        final dv = v.toDouble();
        sumIn += dv;
        if (dv > maxIn) maxIn = dv;
      }
      AppLogger.debug(
        'Inference: inputStats max=${maxIn.toStringAsFixed(3)} mean=${(sumIn / inputFloat.length).toStringAsFixed(3)}',
      );
    }

    if (inputFloat.length != expected) {
      throw StateError(
        'Model expects input size $expected (H=$h W=$w C=$c) but got ${inputFloat.length}',
      );
    }

    if (inputType == TensorType.float32) {
      final input4d = inputFloat.reshape(<int>[1, h, w, c]);
      if (nestedOut != null) {
        interpreter.run(input4d, nestedOut);
        _flatten3d(nestedOut, outputBuffer);
      } else {
        interpreter.run(input4d, outputBuffer);
      }

      var allZero = true;
      final probe = outputBuffer.length < 64 ? outputBuffer.length : 64;
      for (var i = 0; i < probe; i++) {
        if (outputBuffer[i] != 0.0) {
          allZero = false;
          break;
        }
      }
      if (allZero) {
        AppLogger.debug(
          'Inference: output all zeros with 0..1 float input; retrying 0..255 float input',
        );
        final inputFloat255 = Float32List(expected);
        for (var i = 0; i < expected; i++) {
          inputFloat255[i] = inputFloat[i] * 255.0;
        }
        final input4d255 = inputFloat255.reshape(<int>[1, h, w, c]);
        if (nestedOut != null) {
          for (var b = 0; b < nestedOut.length; b++) {
            for (var i = 0; i < nestedOut[b].length; i++) {
              final row = nestedOut[b][i];
              for (var j = 0; j < row.length; j++) {
                row[j] = 0.0;
              }
            }
          }
          interpreter.run(input4d255, nestedOut);
          _flatten3d(nestedOut, outputBuffer);
        } else {
          interpreter.run(input4d255, outputBuffer);
        }
      }
    } else if (inputType == TensorType.uint8) {
      final inputU8 = Uint8List(expected);
      for (var i = 0; i < expected; i++) {
        final v = (inputFloat[i] * 255.0).round();
        inputU8[i] = v.clamp(0, 255);
      }
      final input4d = inputU8.reshape(<int>[1, h, w, c]);
      if (nestedOut != null) {
        interpreter.run(input4d, nestedOut);
        _flatten3d(nestedOut, outputBuffer);
      } else {
        interpreter.run(input4d, outputBuffer);
      }
    } else {
      throw StateError('Unsupported input tensor type: $inputType');
    }

    final rawDetections = (outputShape.length == 3 && outputShape[2] == 6)
        ? _parseFinalDetections6(outputBuffer, outputShape)
        : _parseYoloOutput(outputBuffer, outputShape, numClasses, hasObjectness);

    final List<_RawDetection> scaledDetections =
        params.confidenceTemperature == 1.0
            ? rawDetections
            : rawDetections
                .map(
                  (_RawDetection d) => _RawDetection(
                    cx: d.cx,
                    cy: d.cy,
                    w: d.w,
                    h: d.h,
                    confidence: _temperatureScaleProbability(
                      d.confidence,
                      params.confidenceTemperature,
                    ),
                    classIndex: d.classIndex,
                  ),
                )
                .toList();

    if (logInputStats) {
      if (scaledDetections.isNotEmpty) {
        final maxC = scaledDetections
            .map((d) => d.confidence)
            .reduce((a, b) => a > b ? a : b);
        AppLogger.debug(
          'Inference: rawDetections=${scaledDetections.length} maxConf=${(maxC * 100).toStringAsFixed(1)}%',
        );
      } else {
        AppLogger.debug(
          'Inference: rawDetections=0 (outputShape=$outputShape)',
        );
        AppLogger.debug(
          'Inference: outputSample=${outputBuffer.length >= 12 ? outputBuffer.sublist(0, 12) : outputBuffer.toList()}',
        );
      }
    }

    final double? maxRaw = rawDetections.isEmpty
        ? null
        : rawDetections
            .map((d) => d.confidence)
            .reduce((a, b) => a > b ? a : b);
    final List<double> sample = outputBuffer.length >= 12
        ? outputBuffer.sublist(0, 12).map((v) => v.toDouble()).toList()
        : outputBuffer.map((v) => v.toDouble()).toList();

    return _ScaledRawRun(
      scaled: scaledDetections,
      rawCount: rawDetections.length,
      maxRaw: maxRaw,
      sample: sample,
    );
  }

  _ForwardOut forward(
    PreprocessResult preprocessResult, {
    required int maxDetectionsThisPass,
    bool logInputStats = false,
  }) {
    final _ScaledRawRun run1 =
        _inferScaledRaw(preprocessResult.input, logInputStats: logInputStats);
    final List<_RawDetection> combined = List<_RawDetection>.from(run1.scaled);
    var totalRaw = run1.rawCount;
    double? maxRaw = run1.maxRaw;
    final List<double> sample = run1.sample;

    if (params.ttaEnabled) {
      final Float32List flipped = _flipNhwcFloat32Horizontal(
        preprocessResult.input,
        h,
        w,
        c,
      );
      final _ScaledRawRun run2 =
          _inferScaledRaw(flipped, logInputStats: false);
      totalRaw += run2.rawCount;
      if (run2.maxRaw != null) {
        maxRaw = maxRaw == null
            ? run2.maxRaw
            : math.max(maxRaw, run2.maxRaw!);
      }
      for (final _RawDetection d in run2.scaled) {
        combined.add(_flipRawDetectionHorizontal(d, params.inputSize));
      }
      if (logInputStats) {
        AppLogger.debug('Inference: TTA enabled (identity + horizontal flip)');
      }
    }

    final int nmsCap = params.ttaEnabled
        ? math.min(200, maxDetectionsThisPass * 2)
        : maxDetectionsThisPass;

    final filtered = _applyNms(
      combined,
      params.nmsThreshold,
      nmsCap,
    );

    final List<Detection> displayDetections = transformModelBoxesToOriginal(
      filtered
          .map(
            (_RawDetection r) => ModelBox(
              cx: r.cx,
              cy: r.cy,
              w: r.w,
              h: r.h,
              confidence: r.confidence,
              classIndex: r.classIndex,
            ),
          )
          .toList(),
      preprocessResult,
      params.inputSize,
      params.classLabels,
    );

    return _ForwardOut(
      detections: displayDetections,
      rawCount: totalRaw,
      tileMaxRaw: maxRaw,
      outputSample: sample,
    );
  }
}

List<Detection> _finalizeDetections(
  List<Detection> detections,
  int imageWidth,
  int imageHeight,
  double threshold,
) {
  final List<Detection> aboveThreshold = detections
      .where((Detection d) => d.confidence >= threshold)
      .toList();
  return filterPlausibleMealybugBoxes(
    aboveThreshold,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}

/// Top-level function for isolate (must be top-level or static).
Future<DetectionResult> _runInferenceIsolate(_InferenceParams params) async {
  final stopwatch = Stopwatch()..start();

  Interpreter? interpreter;
  try {
    AppLogger.debug('Inference: Loading model from ${params.modelFilePath}');
    final options = InterpreterOptions()..threads = params.interpreterThreads;
    try {
      interpreter = Interpreter.fromFile(
        File(params.modelFilePath),
        options: options,
      );
    } catch (e) {
      // Most common field failure: shipping a float16-input TFLite (or otherwise
      // unsupported input tensor type) that cannot be prepared by the CPU TFLite
      // runtime on some devices. Surface a clear, actionable message.
      final msg = e.toString();
      final looksLikeTypeMismatch = msg.contains('failed precondition') ||
          msg.contains('CONV_2D') ||
          msg.contains('failed to prepare') ||
          msg.contains('input_type');
      if (looksLikeTypeMismatch) {
        throw StateError(
          'Model failed to initialize on this device. This usually means the bundled TFLite model uses an unsupported input tensor type '
          '(common case: float16-input export). Re-export a float32 TFLite and replace `${params.modelFilePath}` source asset '
          '(`assets/model/best.tflite`), then rebuild the app.',
        );
      }
      rethrow;
    }

    final inputTensors = interpreter.getInputTensors();
    AppLogger.debug(
      'Inference: Model loaded. Inputs=${inputTensors.length} Outputs=${interpreter.getOutputTensors().length}',
    );

    final session = _InterpreterSession(interpreter, params);
    final sessionShape = session.outputShape;
    AppLogger.debug(
      'Inference: Input shape=${session.inputTensor.shape} Output shape=$sessionShape',
    );
    AppLogger.debug(
      'Inference: Input type=${session.inputTensor.type} Output type=${session.outputTensor.type}',
    );

    final preprocessor = ImagePreprocessor(inputSize: params.inputSize);

    final decoded = img.decodeImage(params.imageBytes);
    if (decoded == null) {
      throw StateError('Failed to decode image for inference');
    }
    final oriented = img.bakeOrientation(decoded);

    final bool useTiles = params.tiledInferenceEnabled &&
        math.min(oriented.width, oriented.height) >=
            params.tiledInferenceMinShortSide;

    if (!useTiles) {
      final preprocessResult =
          await preprocessor.preprocessFromImage(oriented);
      final out = session.forward(
        preprocessResult,
        maxDetectionsThisPass: params.maxDetections,
        logInputStats: true,
      );
      final List<Detection> displayDetections = _finalizeDetections(
        out.detections,
        preprocessResult.originalWidth,
        preprocessResult.originalHeight,
        params.detectionThreshold,
      );
      stopwatch.stop();
      AppLogger.debug(
        'Inference: Done in ${stopwatch.elapsedMilliseconds}ms, '
        'detections=${displayDetections.length} (raw=${out.rawCount}, '
        'threshold=${params.detectionThreshold})',
      );
      return DetectionResult(
        detections: displayDetections,
        inferenceTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
        originalWidth: preprocessResult.originalWidth,
        originalHeight: preprocessResult.originalHeight,
        rawDetectionsCount: out.rawCount,
        maxRawConfidence: out.tileMaxRaw,
        outputShape: sessionShape,
        outputSample: out.outputSample,
      );
    }

    final tiles = planImageTiles(
      imageWidth: oriented.width,
      imageHeight: oriented.height,
      tileSide: params.tileNativeSide,
      overlapFraction: params.tileOverlapFraction,
      maxTiles: params.maxTilesPerImage,
    );

    AppLogger.debug(
      'Inference: tiled mode tiles=${tiles.length} '
      'image=${oriented.width}x${oriented.height} nativeTile=${params.tileNativeSide}',
    );

    final merged = <Detection>[];
    var rawSum = 0;
    double? globalMaxRaw;
    List<double>? firstSample;

    for (var i = 0; i < tiles.length; i++) {
      final spec = tiles[i];
      final crop = img.copyCrop(
        oriented,
        x: spec.x,
        y: spec.y,
        width: spec.width,
        height: spec.height,
      );
      final pre = await preprocessor.preprocessFromImage(crop);
      final out = session.forward(
        pre,
        maxDetectionsThisPass: params.maxDetectionsPerTile,
        logInputStats: i == 0,
      );
      rawSum += out.rawCount;
      if (out.tileMaxRaw != null) {
        globalMaxRaw = globalMaxRaw == null
            ? out.tileMaxRaw
            : math.max(globalMaxRaw, out.tileMaxRaw!);
      }
      firstSample ??= out.outputSample;
      for (final d in out.detections) {
        merged.add(
          d.copyWith(
            left: d.left + spec.x,
            top: d.top + spec.y,
          ),
        );
      }
    }

    final List<Detection> mergedNms = nmsMergedDetections(
      merged,
      params.nmsThreshold,
      params.maxDetections,
    );
    final List<Detection> displayDetections = _finalizeDetections(
      mergedNms,
      oriented.width,
      oriented.height,
      params.detectionThreshold,
    );

    stopwatch.stop();
    AppLogger.debug(
      'Inference: tiled done in ${stopwatch.elapsedMilliseconds}ms '
      'detections=${displayDetections.length} rawTotal=$rawSum tiles=${tiles.length}',
    );

    return DetectionResult(
      detections: displayDetections,
      inferenceTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
      originalWidth: oriented.width,
      originalHeight: oriented.height,
      rawDetectionsCount: rawSum,
      maxRawConfidence: globalMaxRaw,
      outputShape: sessionShape,
      outputSample: firstSample ?? const <double>[],
    );
  } catch (e, stack) {
    AppLogger.error('InferenceService', e, stack);
    rethrow;
  } finally {
    interpreter?.close();
  }
}

int _inferNumClasses(List<int> outputShape, {required int labelCount}) {
  // YOLO output is typically one of:
  // - [1, 4+nc, num_boxes]  (channels-first)
  // - [1, num_boxes, 4+nc]  (boxes-first)
  //
  // The (4/5+nc) dimension is usually "small" (<= ~256), while num_boxes is large.
  if (outputShape.length < 3) return 1;
  final dim1 = outputShape[1];
  final dim2 = outputShape[2];

  final small = dim1 < dim2 ? dim1 : dim2;
  final large = dim1 < dim2 ? dim2 : dim1;

  // If labels are known and match common layouts, trust them.
  if (labelCount > 0) {
    if (small == 5 + labelCount || small == 4 + labelCount) {
      return labelCount;
    }
    if (large == 5 + labelCount || large == 4 + labelCount) {
      return labelCount;
    }
  }

  // Prefer using the small dimension as (5+nc) or (4+nc) when it looks plausible.
  if (small > 4 && small <= 256) {
    // Try objectness layout first (5+nc) because it's common for YOLO.
    if (small - 5 >= 1) return small - 5;
    return small - 4;
  }
  if (large > 4 && large <= 256) {
    if (large - 5 >= 1) return large - 5;
    return large - 4;
  }
  // Fallback: assume dim1 is (4+nc)
  return (dim1 > 4 ? dim1 - 4 : 1);
}

bool _inferHasObjectness(
  List<int> shape, {
  required int inferredNumClasses,
  required int labelCount,
}) {
  // Many YOLO exports are (cx,cy,w,h,obj, classes...) => 5+nc.
  // Some exports omit objectness => 4+nc.
  if (shape.length < 3) return true;
  final dim1 = shape[1];
  final dim2 = shape[2];
  final small = dim1 < dim2 ? dim1 : dim2;

  if (labelCount > 0) {
    if (small == 5 + labelCount) return true;
    if (small == 4 + labelCount) return false;
  }

  final total4 = 4 + inferredNumClasses;
  final total5 = 5 + inferredNumClasses;
  if (dim1 == total5 || dim2 == total5) return true;
  if (dim1 == total4 || dim2 == total4) return false;

  // Default to objectness (safer for most YOLO models).
  return true;
}

List<_RawDetection> _parseYoloOutput(
  Float32List output,
  List<int> shape,
  int numClasses,
  bool hasObjectness,
) {
  final detections = <_RawDetection>[];
  final totalElements = (hasObjectness ? 5 : 4) + numClasses;

  if (shape.length < 3) return detections;

  final dim1 = shape[1];
  final dim2 = shape[2];
  // Determine layout by matching the (4+nc) dimension.
  // If dim2 == totalElements -> [1, num_boxes, 4+nc] (boxes-first)
  // If dim1 == totalElements -> [1, 4+nc, num_boxes] (channels-first)
  final bool boxesFirst = dim2 == totalElements
      ? true
      : dim1 == totalElements
          ? false
          : (dim1 > dim2); // heuristic fallback

  final numBoxes = boxesFirst ? dim1 : dim2;
  final stride = numBoxes;

  // Layout: [1, 4+nc, num_boxes] -> for box k: values at k, stride+k, 2*stride+k, ...
  // Layout: [1, num_boxes, 4+nc] -> for box k: values at k*totalElements, k*totalElements+1, ...
  final isTransposed = boxesFirst;

  for (var k = 0; k < numBoxes; k++) {
    double cx, cy, w, h;
    double obj = 1.0;
    if (isTransposed) {
      final offset = k * totalElements;
      cx = output[offset];
      cy = output[offset + 1];
      w = output[offset + 2];
      h = output[offset + 3];
      if (hasObjectness) obj = output[offset + 4];
    } else {
      cx = output[k];
      cy = output[stride + k];
      w = output[2 * stride + k];
      h = output[3 * stride + k];
      if (hasObjectness) obj = output[4 * stride + k];
    }

    var maxScore = 0.0;
    var maxClass = 0;
    for (var c = 0; c < numClasses; c++) {
      final classOffset = hasObjectness ? 5 : 4;
      final score = isTransposed
          ? output[k * totalElements + classOffset + c]
          : output[(classOffset + c) * stride + k];
      if (score > maxScore) {
        maxScore = score;
        maxClass = c;
      }
    }

    final confidence = obj * maxScore;
    if (confidence > 0.01) {
      detections.add(_RawDetection(
        cx: cx,
        cy: cy,
        w: w,
        h: h,
        confidence: confidence,
        classIndex: maxClass,
      ));
    }
  }

  return detections;
}

List<_RawDetection> _parseFinalDetections6(
  Float32List output,
  List<int> shape,
) {
  // Shape is expected to be [1, N, 6]
  if (shape.length != 3 || shape[0] != 1 || shape[2] != 6) return <_RawDetection>[];
  final n = shape[1];
  final out = <_RawDetection>[];
  for (var i = 0; i < n; i++) {
    final off = i * 6;
    if (off + 5 >= output.length) break;

    final a0 = output[off];
    final a1 = output[off + 1];
    final a2 = output[off + 2];
    final a3 = output[off + 3];
    final v4 = output[off + 4];
    final v5 = output[off + 5];

    // Auto-detect score vs class columns.
    // Common layouts:
    // - [x1,y1,x2,y2,score,class]
    // - [x1,y1,x2,y2,class,score]
    // - score might be 0..1, 0..100, 0..255, or logits.
    final bool v4LooksInt = (v4.isFinite && (v4 - v4.round()).abs() < 1e-3);
    final bool v5LooksInt = (v5.isFinite && (v5 - v5.round()).abs() < 1e-3);
    final bool v4Prob = v4.isFinite && v4 >= 0 && v4 <= 1;
    final bool v5Prob = v5.isFinite && v5 >= 0 && v5 <= 1;

    double rawScore;
    double clsRaw;
    if (v4Prob && v5LooksInt && !v4LooksInt) {
      rawScore = v4;
      clsRaw = v5;
    } else if (v5Prob && v4LooksInt && !v5LooksInt) {
      rawScore = v5;
      clsRaw = v4;
    } else if (v4Prob && !v5Prob) {
      rawScore = v4;
      clsRaw = v5;
    } else if (v5Prob && !v4Prob) {
      rawScore = v5;
      clsRaw = v4;
    } else {
      // Fall back: treat the larger magnitude as score.
      if (v4.abs() >= v5.abs()) {
        rawScore = v4;
        clsRaw = v5;
      } else {
        rawScore = v5;
        clsRaw = v4;
      }
    }

    final score = _normalizeScore(rawScore);

    // Skip empty rows (common padding)
    if (score <= 0.001) continue;

    // Heuristic: if a2>a0 and a3>a1 treat as xyxy, else treat as cxcywh.
    final bool isXyxy = (a2 > a0) && (a3 > a1);
    double cx, cy, w, h;
    if (isXyxy) {
      final x1 = a0;
      final y1 = a1;
      final x2 = a2;
      final y2 = a3;
      w = (x2 - x1);
      h = (y2 - y1);
      cx = x1 + w / 2;
      cy = y1 + h / 2;
    } else {
      cx = a0;
      cy = a1;
      w = a2;
      h = a3;
    }

    final classIndex =
        clsRaw.isFinite ? clsRaw.round().clamp(0, 9999) : 0;
    out.add(
      _RawDetection(
        cx: cx.toDouble(),
        cy: cy.toDouble(),
        w: w.toDouble(),
        h: h.toDouble(),
        confidence: score.clamp(0.0, 1.0),
        classIndex: classIndex,
      ),
    );
  }
  return out;
}

double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

/// Temperature scaling on a scalar probability (Platt-style logit rescale).
double _temperatureScaleProbability(double p, double temperature) {
  if (!p.isFinite) return 0.0;
  if (temperature <= 0 || temperature == 1.0) return p.clamp(0.0, 1.0);
  final double pc = p.clamp(1e-6, 1.0 - 1e-6);
  final double logit = math.log(pc / (1.0 - pc));
  return _sigmoid(logit / temperature).clamp(0.0, 1.0);
}

double _normalizeScore(double raw) {
  if (!raw.isFinite) return 0.0;
  // If already probability.
  if (raw >= 0.0 && raw <= 1.0) return raw;
  // If looks like percent.
  if (raw > 1.0 && raw <= 100.0) return raw / 100.0;
  // If looks like 0..255.
  if (raw > 1.0 && raw <= 255.0) return raw / 255.0;
  // If logits (can be negative/positive large), sigmoid it.
  if (raw < 0.0 || raw > 1.0) return _sigmoid(raw);
  return 0.0;
}

void _flatten3d(
  List<List<List<double>>> src,
  Float32List dst,
) {
  var k = 0;
  for (final b in src) {
    for (final row in b) {
      for (final v in row) {
        if (k >= dst.length) return;
        dst[k++] = v.toDouble();
      }
    }
  }
}

List<_RawDetection> _applyNms(
  List<_RawDetection> detections,
  double iouThreshold,
  int maxDetections,
) {
  detections.sort((a, b) => b.confidence.compareTo(a.confidence));
  final kept = <_RawDetection>[];

  for (final d in detections) {
    if (kept.length >= maxDetections) break;
    var overlap = false;
    for (final k in kept) {
      if (_iou(d, k) > iouThreshold) {
        overlap = true;
        break;
      }
    }
    if (!overlap) kept.add(d);
  }

  return kept;
}

double _iou(_RawDetection a, _RawDetection b) {
  final aLeft = a.cx - a.w / 2;
  final aTop = a.cy - a.h / 2;
  final aRight = a.cx + a.w / 2;
  final aBottom = a.cy + a.h / 2;

  final bLeft = b.cx - b.w / 2;
  final bTop = b.cy - b.h / 2;
  final bRight = b.cx + b.w / 2;
  final bBottom = b.cy + b.h / 2;

  final interLeft = aLeft > bLeft ? aLeft : bLeft;
  final interTop = aTop > bTop ? aTop : bTop;
  final interRight = aRight < bRight ? aRight : bRight;
  final interBottom = aBottom < bBottom ? aBottom : bBottom;

  final interW = (interRight - interLeft).clamp(0.0, double.infinity);
  final interH = (interBottom - interTop).clamp(0.0, double.infinity);
  final interArea = interW * interH;

  final aArea = a.w * a.h;
  final bArea = b.w * b.h;
  final unionArea = aArea + bArea - interArea;

  return unionArea > 0 ? interArea / unionArea : 0;
}

class _RawDetection {
  _RawDetection({
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.confidence,
    required this.classIndex,
  });
  final double cx, cy, w, h, confidence;
  final int classIndex;
}
