// User-facing detection advisories — decision-support wording, not diagnosis.
library;

/// Centralized copy for scan results and popups (panel guidance #8).
abstract final class DetectionAdvisoryMessages {
  DetectionAdvisoryMessages._();

  // --- No detection (negative scan) ---

  static const String noDetectionPopupTitleEn =
      'No mealybug detected in this image';
  static const String noDetectionPopupTitleFil =
      'Walang mealybug na natuklasan sa larawang ito';

  static const String noDetectionResultLabelEn =
      'No mealybug detected in this image';
  static const String noDetectionResultLabelFil =
      'Walang mealybug na natuklasan sa larawang ito';

  static const String noDetectionInsightTitleEn =
      'No mealybug detected in this image';
  static const String noDetectionInsightTitleFil =
      'Walang mealybug na natuklasan sa larawang ito';

  static const String noDetectionBodyEn =
      'This scan did not show mealybugs. Capture another close-up from a different '
      'angle, especially under leaves and near clustered areas, or inspect the plant '
      'manually. The app supports scouting — it is not a final diagnosis.';

  static const String noDetectionBodyFil =
      'Walang mealybug na nakita sa scan na ito. Kumuha ng mas malapit na larawan mula '
      'sa ibang anggulo, lalo na sa ilalim ng dahon at malapit sa kumpol, o suriin '
      'ang halaman nang manual. Suporta lang ng app ang scouting — hindi ito final na diagnosis.';

  static const String noDetectionPopupDetailEn =
      'No mealybug detected in this image. Please capture another image from a closer '
      'angle or inspect the plant manually, especially under leaves and near clustered areas.\n\n'
      'For higher sensitivity, try Detection accuracy mode in Settings.';

  static const String noDetectionPopupDetailFil =
      'Walang mealybug na natuklasan sa larawang ito. Kumuha ng mas malapit na larawan '
      'mula sa ibang anggulo o suriin ang halaman nang manual, lalo na sa ilalim ng dahon '
      'at malapit sa kumpol.\n\n'
      'Para mas sensitibo ang deteksyon, subukan ang Detection accuracy mode sa Settings.';

  // --- Positive detection ---

  static const String possibleDetectionResultLabelEn =
      'Possible mealybug detected';
  static const String possibleDetectionResultLabelFil =
      'Posibleng may mealybug';

  static const String possibleDetectionVerifyEn =
      'Please verify visually before applying control measures.';
  static const String possibleDetectionVerifyFil =
      'Suriin muna nang visual bago mag-control measures.';

  /// Dashed amber boxes on the preview (manual-check tier, not counted).
  static const String manualCheckLegendEn =
      'Dashed amber boxes: low-confidence hints — inspect manually; not counted.';
  static const String manualCheckLegendFil =
      'Dashed amber: mababang kumpiyansa — suriin nang manual; hindi kasama sa bilang.';

  static String noDetectionNextSteps({required bool fil}) {
    return fil ? _noDetectionNextStepsFil : _noDetectionNextStepsEn;
  }

  static String possibleDetectionNextSteps({required bool fil}) {
    return fil ? _possibleDetectionNextStepsFil : _possibleDetectionNextStepsEn;
  }

  static const String _noDetectionNextStepsEn =
      '• Capture another close-up (good light, steady hand)\n'
      '• Focus on leaf bases, undersides, and clustered areas\n'
      '• Inspect the plant manually if pests are still suspected\n'
      '• Try Accuracy mode in Settings for higher sensitivity';

  static const String _noDetectionNextStepsFil =
      '• Kumuha ng mas malapit na larawan (maliwanag na ilaw, steady)\n'
      '• Tumingin sa base ng dahon, ilalim, at mga kumpol\n'
      '• Suriin nang manual ang halaman kung may hinala pa ring peste\n'
      '• Subukan ang Accuracy mode sa Settings para mas sensitibo';

  static const String _possibleDetectionNextStepsEn =
      '• Verify visually before applying control measures\n'
      '• Isolate the affected plant/area to reduce spread\n'
      '• Remove heavily infested leaves and dispose properly (do not compost)\n'
      '• Control ants (they often protect/spread mealybugs)\n'
      '• Use insecticidal soap / neem (follow the label) after visual confirmation';

  static const String _possibleDetectionNextStepsFil =
      '• Suriin muna nang visual bago mag-control measures\n'
      '• Ihiwalay ang apektadong halaman/parte para hindi kumalat\n'
      '• Alisin ang heavily infested na dahon at itapon nang maayos (huwag i-compost)\n'
      '• Kontrolin ang langgam (madalas silang nagpoprotekta ng mealybugs)\n'
      '• Gamitin ang insecticidal soap / neem (sundin ang label) pagkatapos ng visual confirmation';
}
