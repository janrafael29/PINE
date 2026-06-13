// While the spotlight navigation guide is open, the dashboard reads this to switch tabs.
library;

import 'package:flutter/foundation.dart';

class NavigationGuideSync {
  NavigationGuideSync._();

  /// Current guide slide index, or null when the guide is not showing.
  static final ValueNotifier<int?> activeStep = ValueNotifier<int?>(null);
}
