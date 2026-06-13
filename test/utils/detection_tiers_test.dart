import 'package:flutter_test/flutter_test.dart';
import 'package:pine/core/constants.dart';
import 'package:pine/models/detection_result.dart';
import 'package:pine/utils/detection_tiers.dart';

Detection _d(double conf) => Detection(
      left: 0,
      top: 0,
      width: 10,
      height: 10,
      confidence: conf,
      classIndex: 0,
    );

void main() {
  group('detection_tiers', () {
    test('confirmed tier uses deploy threshold', () {
      final all = <Detection>[_d(0.30), _d(0.20), _d(0.10)];
      expect(confirmedDetections(all).length, 1);
      expect(confirmedCount(all), 1);
    });

    test('manual-check tier is between floor and deploy threshold', () {
      final all = <Detection>[
        _d(AppConstants.detectionThreshold),
        _d(AppConstants.manualCheckThreshold),
        _d(AppConstants.manualCheckThreshold - 0.01),
      ];
      expect(manualCheckDetections(all).length, 1);
      expect(overlayDetections(all).length, 2);
    });
  });
}
