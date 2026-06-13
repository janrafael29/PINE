// GlobalKeys so the navigation spotlight can measure real UI regions.
library;

import 'package:flutter/material.dart';

import 'navigation_guide_content.dart';

class DashboardGuideKeys {
  DashboardGuideKeys._();

  static final GlobalKey homeNavKey = GlobalKey(debugLabel: 'guideHomeNav');
  static final GlobalKey homeBrandingKey =
      GlobalKey(debugLabel: 'guideHomeBranding');
  static final GlobalKey homeGreetingKey =
      GlobalKey(debugLabel: 'guideHomeGreeting');
  static final GlobalKey homeTotalFieldsKey =
      GlobalKey(debugLabel: 'guideHomeTotalFields');
  static final GlobalKey homeRegionKey =
      GlobalKey(debugLabel: 'guideHomeRegion');
  static final GlobalKey homeSavedImagesKey =
      GlobalKey(debugLabel: 'guideHomeSavedImages');
  static final GlobalKey homeMyFieldsSectionKey =
      GlobalKey(debugLabel: 'guideHomeMyFieldsSection');
  static final GlobalKey homeMapPreviewKey =
      GlobalKey(debugLabel: 'guideHomeMapPreview');

  static final GlobalKey diagnoseNavKey =
      GlobalKey(debugLabel: 'guideDiagnoseNav');
  static final GlobalKey diagnoseSearchDiseasesKey =
      GlobalKey(debugLabel: 'guideDiagnoseSearch');
  static final GlobalKey diagnoseWeekStatsKey =
      GlobalKey(debugLabel: 'guideDiagnoseWeekStats');
  static final GlobalKey diagnosePestsChartKey =
      GlobalKey(debugLabel: 'guideDiagnosePestsChart');
  static final GlobalKey diagnoseMyFieldsStripKey =
      GlobalKey(debugLabel: 'guideDiagnoseMyFieldsStrip');

  static final GlobalKey scanButtonKey =
      GlobalKey(debugLabel: 'guideScanButton');
  /// Add Photo → sync queued uploads + offline-created fields.
  static final GlobalKey addPhotoSyncKey =
      GlobalKey(debugLabel: 'guideAddPhotoSync');
  static final GlobalKey myFieldsNavKey =
      GlobalKey(debugLabel: 'guideMyFieldsNav');
  static final GlobalKey myFieldsHeaderTabsKey =
      GlobalKey(debugLabel: 'guideMyFieldsHeaderTabs');
  static final GlobalKey myFieldsGridKey =
      GlobalKey(debugLabel: 'guideMyFieldsGrid');

  static final GlobalKey moreNavKey = GlobalKey(debugLabel: 'guideMoreNav');
  static final GlobalKey moreProfileKey =
      GlobalKey(debugLabel: 'guideMoreProfile');
  static final GlobalKey moreGeneralInfoKey =
      GlobalKey(debugLabel: 'guideMoreGeneralInfo');
  static final GlobalKey moreCommonDiseasesKey =
      GlobalKey(debugLabel: 'guideMoreCommonDiseases');
  static final GlobalKey moreExploreByPartsKey =
      GlobalKey(debugLabel: 'guideMoreExploreByParts');

  static final GlobalKey bottomNavBarKey =
      GlobalKey(debugLabel: 'guideBottomNavBar');

  static List<GlobalKey> keysForTargets(
    List<NavigationGuideSpotlightTarget> targets,
  ) {
    return targets.map(_keyFor).toList(growable: false);
  }

  static GlobalKey _keyFor(NavigationGuideSpotlightTarget t) {
    return switch (t) {
      NavigationGuideSpotlightTarget.homeNav => homeNavKey,
      NavigationGuideSpotlightTarget.homeBranding => homeBrandingKey,
      NavigationGuideSpotlightTarget.homeGreeting => homeGreetingKey,
      NavigationGuideSpotlightTarget.homeTotalFields => homeTotalFieldsKey,
      NavigationGuideSpotlightTarget.homeRegion => homeRegionKey,
      NavigationGuideSpotlightTarget.homeSavedImages => homeSavedImagesKey,
      NavigationGuideSpotlightTarget.homeMyFieldsSection =>
        homeMyFieldsSectionKey,
      NavigationGuideSpotlightTarget.homeMapPreview => homeMapPreviewKey,
      NavigationGuideSpotlightTarget.diagnoseNav => diagnoseNavKey,
      NavigationGuideSpotlightTarget.diagnoseSearchDiseases =>
        diagnoseSearchDiseasesKey,
      NavigationGuideSpotlightTarget.diagnoseWeekStats => diagnoseWeekStatsKey,
      NavigationGuideSpotlightTarget.diagnosePestsChart =>
        diagnosePestsChartKey,
      NavigationGuideSpotlightTarget.diagnoseMyFieldsStrip =>
        diagnoseMyFieldsStripKey,
      NavigationGuideSpotlightTarget.scanButton => scanButtonKey,
      NavigationGuideSpotlightTarget.addPhotoSync => addPhotoSyncKey,
      NavigationGuideSpotlightTarget.myFieldsNav => myFieldsNavKey,
      NavigationGuideSpotlightTarget.myFieldsHeaderTabs =>
        myFieldsHeaderTabsKey,
      NavigationGuideSpotlightTarget.myFieldsGrid => myFieldsGridKey,
      NavigationGuideSpotlightTarget.moreNav => moreNavKey,
      NavigationGuideSpotlightTarget.moreProfile => moreProfileKey,
      NavigationGuideSpotlightTarget.moreGeneralInfo => moreGeneralInfoKey,
      NavigationGuideSpotlightTarget.moreCommonDiseases =>
        moreCommonDiseasesKey,
      NavigationGuideSpotlightTarget.moreExploreByParts =>
        moreExploreByPartsKey,
      NavigationGuideSpotlightTarget.bottomNavBar => bottomNavBarKey,
    };
  }
}
