import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../models/poster.dart';

class ImageRecognitionService {
  final Map<String, _PosterSignature> _posterSignatures = {};

  ImageRecognitionService();

  Future<void> loadPosterImages() async {
    _posterSignatures.clear();
    final posters = Poster.getPosters();
    for (final poster in posters) {
      try {
        final data = await rootBundle.load(poster.assetPath);
        final bytes = data.buffer.asUint8List();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          continue;
        }

        _posterSignatures[poster.id] = _createSignature(decoded);
      } catch (e) {
        // Keep loading the rest of the poster templates.
      }
    }
  }

  Future<String?> recognizePoster(File imageFile) async {
    try {
      return await _matchPosterTemplate(imageFile);
    } catch (e) {
      return await _matchPosterTemplate(imageFile);
    }
  }

  Future<String?> _matchPosterTemplate(File imageFile) async {
    try {
      if (_posterSignatures.isEmpty) {
        await loadPosterImages();
      }

      final capturedBytes = await imageFile.readAsBytes();
      final capturedImage = img.decodeImage(capturedBytes);
      if (capturedImage == null) return null;

      final candidates = _buildCandidateCrops(
        capturedImage,
      ).map(_createSignature).toList();

      String? bestMatch;
      double bestScore = 0.78;

      for (final entry in _posterSignatures.entries) {
        final posterSig = entry.value;
        var candidateBest = 0.0;

        for (final candidateSig in candidates) {
          final similarity = _compareSignatures(candidateSig, posterSig);
          if (similarity > candidateBest) {
            candidateBest = similarity;
          }
        }

        if (candidateBest > bestScore) {
          bestScore = candidateBest;
          bestMatch = entry.key;
        }
      }

      return bestMatch;
    } catch (e) {
      return null;
    }
  }

  List<img.Image> _buildCandidateCrops(img.Image source) {
    final result = <img.Image>[source];

    final center80 = _centerCrop(source, 0.8);
    final center60 = _centerCrop(source, 0.6);
    if (center80 != null) result.add(center80);
    if (center60 != null) result.add(center60);

    return result;
  }

  img.Image? _centerCrop(img.Image source, double factor) {
    final cropW = (source.width * factor).round();
    final cropH = (source.height * factor).round();
    if (cropW <= 0 || cropH <= 0) return null;

    final x = ((source.width - cropW) / 2).round();
    final y = ((source.height - cropH) / 2).round();
    return img.copyCrop(source, x: x, y: y, width: cropW, height: cropH);
  }

  _PosterSignature _createSignature(img.Image image) {
    final resized = img.copyResize(image, width: 64, height: 64);
    final gray = img.grayscale(resized);

    final hashSample = img.copyResize(gray, width: 16, height: 16);
    var totalLum = 0.0;
    final luminance = <double>[];
    for (var y = 0; y < hashSample.height; y++) {
      for (var x = 0; x < hashSample.width; x++) {
        final p = hashSample.getPixel(x, y);
        final lum = p.r.toDouble();
        luminance.add(lum);
        totalLum += lum;
      }
    }
    final avgLum = totalLum / luminance.length;
    final hashBits = luminance.map((v) => v >= avgLum).toList(growable: false);

    final bins = List<double>.filled(24, 0.0);
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final p = resized.getPixel(x, y);
        final hsv = _rgbToHsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        final hue = hsv.$1;
        final sat = hsv.$2;
        final val = hsv.$3;
        if (sat < 0.08 || val < 0.08) {
          continue;
        }

        final bucket = ((hue / 360.0) * bins.length).floor().clamp(
          0,
          bins.length - 1,
        );
        bins[bucket] += 1;
      }
    }

    final sum = bins.fold<double>(0, (acc, n) => acc + n);
    if (sum > 0) {
      for (var i = 0; i < bins.length; i++) {
        bins[i] = bins[i] / sum;
      }
    }

    return _PosterSignature(hashBits: hashBits, hueHistogram: bins);
  }

  double _compareSignatures(_PosterSignature a, _PosterSignature b) {
    final hashLength = a.hashBits.length;
    if (hashLength == 0 || hashLength != b.hashBits.length) {
      return 0;
    }

    var equalBits = 0;
    for (var i = 0; i < hashLength; i++) {
      if (a.hashBits[i] == b.hashBits[i]) {
        equalBits++;
      }
    }
    final hashScore = equalBits / hashLength;

    final binsLength = a.hueHistogram.length;
    if (binsLength == 0 || binsLength != b.hueHistogram.length) {
      return hashScore;
    }

    var histogramDistance = 0.0;
    for (var i = 0; i < binsLength; i++) {
      histogramDistance += (a.hueHistogram[i] - b.hueHistogram[i]).abs();
    }
    final histogramScore = (1 - (histogramDistance / 2)).clamp(0.0, 1.0);

    return (hashScore * 0.7) + (histogramScore * 0.3);
  }

  (double, double, double) _rgbToHsv(double r, double g, double b) {
    final rn = r / 255.0;
    final gn = g / 255.0;
    final bn = b / 255.0;

    final maxVal = [rn, gn, bn].reduce((a, b) => a > b ? a : b).toDouble();
    final minVal = [rn, gn, bn].reduce((a, b) => a < b ? a : b).toDouble();
    final delta = maxVal - minVal;

    double hue;
    if (delta == 0) {
      hue = 0;
    } else if (maxVal == rn) {
      hue = 60 * (((gn - bn) / delta) % 6);
    } else if (maxVal == gn) {
      hue = 60 * (((bn - rn) / delta) + 2);
    } else {
      hue = 60 * (((rn - gn) / delta) + 4);
    }
    if (hue < 0) {
      hue += 360;
    }

    final saturation = maxVal == 0 ? 0.0 : (delta / maxVal).toDouble();
    final value = maxVal.toDouble();

    return (hue, saturation, value);
  }

  void dispose() {
    _posterSignatures.clear();
  }
}

class _PosterSignature {
  final List<bool> hashBits;
  final List<double> hueHistogram;

  const _PosterSignature({required this.hashBits, required this.hueHistogram});
}
