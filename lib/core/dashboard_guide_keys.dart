// Keys for the navigation spotlight to measure real UI regions.
//
// Each [MainDashboardScreen] owns a [DashboardGuideKeyHolder] so rebuilds never
// attach the same GlobalKey to two widgets in the tree at once.
library;

import 'package:flutter/material.dart';

import 'navigation_guide_content.dart';

class DashboardGuideKeyHolder {
  DashboardGuideKeyHolder() {
    homeNavKey = GlobalKey(debugLabel: 'guideHomeNav');
    homeBrandingKey = GlobalKey(debugLabel: 'guideHomeBranding');
    homeGreetingKey = GlobalKey(debugLabel: 'guideHomeGreeting');
    homeTotalFieldsKey = GlobalKey(debugLabel: 'guideHomeTotalFields');
    homeRegionKey = GlobalKey(debugLabel: 'guideHomeRegion');
    homeSavedImagesKey = GlobalKey(debugLabel: 'guideHomeSavedImages');
    homeMyFieldsSectionKey = GlobalKey(debugLabel: 'guideHomeMyFieldsSection');
    homeMapPreviewKey = GlobalKey(debugLabel: 'guideHomeMapPreview');
    diagnoseNavKey = GlobalKey(debugLabel: 'guideDiagnoseNav');
    diagnoseSearchDiseasesKey = GlobalKey(debugLabel: 'guideDiagnoseSearch');
    diagnoseWeekStatsKey = GlobalKey(debugLabel: 'guideDiagnoseWeekStats');
    diagnosePestsChartKey = GlobalKey(debugLabel: 'guideDiagnosePestsChart');
    diagnoseMyFieldsStripKey = GlobalKey(debugLabel: 'guideDiagnoseMyFieldsStrip');
    scanButtonKey = GlobalKey(debugLabel: 'guideScanButton');
    myFieldsNavKey = GlobalKey(debugLabel: 'guideMyFieldsNav');
    myFieldsHeaderTabsKey = GlobalKey(debugLabel: 'guideMyFieldsHeaderTabs');
    myFieldsGridKey = GlobalKey(debugLabel: 'guideMyFieldsGrid');
    moreNavKey = GlobalKey(debugLabel: 'guideMoreNav');
    moreProfileKey = GlobalKey(debugLabel: 'guideMoreProfile');
    moreGeneralInfoKey = GlobalKey(debugLabel: 'guideMoreGeneralInfo');
    moreCommonDiseasesKey = GlobalKey(debugLabel: 'guideMoreCommonDiseases');
    moreExploreByPartsKey = GlobalKey(debugLabel: 'guideMoreExploreByParts');
    bottomNavBarKey = GlobalKey(debugLabel: 'guideBottomNavBar');
  }

  /// Only one dashboard should be mounted; the tour reads this holder.
  static DashboardGuideKeyHolder? _attached;
  static DashboardGuideKeyHolder? get attached => _attached;

  static void attach(DashboardGuideKeyHolder holder) {
    _attached = holder;
  }

  static void detach(DashboardGuideKeyHolder holder) {
    if (_attached == holder) _attached = null;
  }

  /// Add Photo → sync (lives on [PhotoSourcePicker] when the tour opens it).
  static final GlobalKey addPhotoSyncKey =
      GlobalKey(debugLabel: 'guideAddPhotoSync');

  late final GlobalKey homeNavKey;
  late final GlobalKey homeBrandingKey;
  late final GlobalKey homeGreetingKey;
  late final GlobalKey homeTotalFieldsKey;
  late final GlobalKey homeRegionKey;
  late final GlobalKey homeSavedImagesKey;
  late final GlobalKey homeMyFieldsSectionKey;
  late final GlobalKey homeMapPreviewKey;
  late final GlobalKey diagnoseNavKey;
  late final GlobalKey diagnoseSearchDiseasesKey;
  late final GlobalKey diagnoseWeekStatsKey;
  late final GlobalKey diagnosePestsChartKey;
  late final GlobalKey diagnoseMyFieldsStripKey;
  late final GlobalKey scanButtonKey;
  late final GlobalKey myFieldsNavKey;
  late final GlobalKey myFieldsHeaderTabsKey;
  late final GlobalKey myFieldsGridKey;
  late final GlobalKey moreNavKey;
  late final GlobalKey moreProfileKey;
  late final GlobalKey moreGeneralInfoKey;
  late final GlobalKey moreCommonDiseasesKey;
  late final GlobalKey moreExploreByPartsKey;
  late final GlobalKey bottomNavBarKey;

  List<GlobalKey> keysForTargets(
    List<NavigationGuideSpotlightTarget>targets,
  ) {
    return targets.map(keyFor).toList(growable: false);
  }

  GlobalKey keyFor(NavigationGuideSpotlightTarget target) {
    return switch (target) {
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
      NavigationGuideSpotlightTarget.diagnosePestsChart => diagnosePestsChartKey,
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
