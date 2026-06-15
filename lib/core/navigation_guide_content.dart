// Shared copy and spotlight targets for the post-login navigation guide.
library;

import 'package:flutter/material.dart';

import 'admin_session.dart';
import 'theme.dart';

/// Real widgets to cut out during the spotlight tour (nav + on-screen regions).
enum NavigationGuideSpotlightTarget {
  homeNav,
  homeBranding,
  homeGreeting,
  homeTotalFields,
  homeRegion,
  homeSavedImages,
  homeMyFieldsSection,
  homeMapPreview,
  diagnoseNav,
  diagnoseSearchDiseases,
  diagnoseWeekStats,
  diagnosePestsChart,
  diagnoseMyFieldsStrip,
  scanButton,
  myFieldsNav,
  myFieldsHeaderTabs,
  myFieldsGrid,
  moreNav,
  moreProfile,
  moreGeneralInfo,
  moreCommonDiseases,
  moreExploreByParts,
  bottomNavBar,
  /// Add Photo screen — sync offline fields + queued detections to cloud.
  addPhotoSync,
}

typedef NavigationGuideSlide = ({
  String title,
  IconData icon,
  List<({String text, bool highlight})> body,
  List<NavigationGuideSpotlightTarget> spotlightTargets,
  /// When non-empty, one target at a time; advances every 4s (silent) or when the user taps Next.
  List<NavigationGuideSpotlightTarget> spotlightSequence,
  /// Short copy for each [spotlightSequence] step; when null, [body] is used every time.
  List<List<({String text, bool highlight})>>? bodyPerSequenceStep,
});

const TextStyle kNavigationGuideBodyHighlightStyle = TextStyle(
  fontWeight: FontWeight.w700,
  decoration: TextDecoration.underline,
  decorationThickness: 1.25,
  color: AppTheme.primaryGreen,
);

const List<NavigationGuideSlide> kFarmerNavigationGuideSlides =
    <NavigationGuideSlide>[
  (
    title: 'Home',
    icon: Icons.home_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.homeNav,
      NavigationGuideSpotlightTarget.homeTotalFields,
      NavigationGuideSpotlightTarget.homeSavedImages,
      NavigationGuideSpotlightTarget.homeMapPreview,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Your ', highlight: false),
      (text: 'Home', highlight: true),
      (text: ' tab shows field stats, ', highlight: false),
      (text: 'saved images', highlight: true),
      (text: ', and a ', highlight: false),
      (text: 'map preview', highlight: true),
      (text: ' of positive sightings.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'Home', highlight: true),
        (text: ' for your dashboard.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'See ', highlight: false),
        (text: 'Total fields', highlight: true),
        (text: ' and region at a glance.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Open ', highlight: false),
        (text: 'Saved Images', highlight: true),
        (text: ' for recent captures.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Use the ', highlight: false),
        (text: 'map preview', highlight: true),
        (text: ' to view sightings.', highlight: false),
      ],
    ],
  ),
  (
    title: 'Diagnose',
    icon: Icons.shield_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.diagnoseNav,
      NavigationGuideSpotlightTarget.diagnoseSearchDiseases,
      NavigationGuideSpotlightTarget.diagnoseWeekStats,
    ],
    body: <({String text, bool highlight})>[
      (text: 'On ', highlight: false),
      (text: 'Diagnose', highlight: true),
      (text: ', search diseases, check weekly stats, and view pest trends.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Open ', highlight: false),
        (text: 'Diagnose', highlight: true),
        (text: ' from the bottom bar.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'Search for Diseases', highlight: true),
        (text: ' for care info.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Review ', highlight: false),
        (text: 'weekly stats', highlight: true),
        (text: ' and charts here.', highlight: false),
      ],
    ],
  ),
  (
    title: 'Scan',
    icon: Icons.photo_camera,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.scanButton,
      NavigationGuideSpotlightTarget.addPhotoSync,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Tap the ', highlight: false),
      (text: 'camera', highlight: true),
      (text: ' to capture pests. ', highlight: false),
      (text: 'Sync to cloud', highlight: true),
      (text: ' uploads offline photos when online.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Use the ', highlight: false),
        (text: 'camera button', highlight: true),
        (text: ' to scan a field.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'Sync to cloud', highlight: true),
        (text: ' after capturing offline.', highlight: false),
      ],
    ],
  ),
  (
    title: 'My Fields',
    icon: Icons.landscape_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.myFieldsNav,
      NavigationGuideSpotlightTarget.myFieldsGrid,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Manage plots in ', highlight: false),
      (text: 'My Fields', highlight: true),
      (text: '. Tap a card for details or add a new field.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Open ', highlight: false),
        (text: 'My Fields', highlight: true),
        (text: ' from the bar.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Your fields appear in this ', highlight: false),
        (text: 'grid', highlight: true),
        (text: '.', highlight: false),
      ],
    ],
  ),
  (
    title: 'More',
    icon: Icons.grid_view_rounded,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.moreNav,
      NavigationGuideSpotlightTarget.moreProfile,
    ],
    body: <({String text, bool highlight})>[
      (text: 'In ', highlight: false),
      (text: 'More', highlight: true),
      (text: ', open your profile, learning articles, and settings.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'More', highlight: true),
        (text: ' for account and help.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Your ', highlight: false),
        (text: 'profile', highlight: true),
        (text: ' opens account settings.', highlight: false),
      ],
    ],
  ),
];

const List<NavigationGuideSlide> kDaNavigationGuideSlides = <NavigationGuideSlide>[
  (
    title: 'Home — staff view',
    icon: Icons.home_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.homeNav,
      NavigationGuideSpotlightTarget.homeGreeting,
      NavigationGuideSpotlightTarget.homeMapPreview,
    ],
    body: <({String text, bool highlight})>[
      (text: 'As ', highlight: false),
      (text: 'Agriculturist staff', highlight: true),
      (text: ', Home shows shortcuts, org map, and pending work.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Start on ', highlight: false),
        (text: 'Home', highlight: true),
        (text: ' for your staff dashboard.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'The greeting summarizes your ', highlight: false),
        (text: 'review tasks', highlight: true),
        (text: '.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'The ', highlight: false),
        (text: 'map', highlight: true),
        (text: ' shows org-wide positive sightings.', highlight: false),
      ],
    ],
  ),
  (
    title: 'Analytics',
    icon: Icons.insights_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.diagnoseNav,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Open ', highlight: false),
      (text: 'Diagnose', highlight: true),
      (text: ' for org-wide charts: positive vs negative, trends, and top farms.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'Diagnose', highlight: true),
        (text: ' for analytics (not farmer disease search).', highlight: false),
      ],
    ],
  ),
  (
    title: 'Farmer reports',
    icon: Icons.rate_review_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.scanButton,
    ],
    body: <({String text, bool highlight})>[
      (text: 'The center button opens ', highlight: false),
      (text: 'Farmer reports', highlight: true),
      (text: '. Review positive scans and write agriculturist / OMAG advice.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap the center ', highlight: false),
        (text: 'reports', highlight: true),
        (text: ' button. Red badges mean pending replies.', highlight: false),
      ],
    ],
  ),
  (
    title: 'My Fields',
    icon: Icons.landscape_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.myFieldsNav,
      NavigationGuideSpotlightTarget.myFieldsGrid,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Browse all registered fields and open maps from ', highlight: false),
      (text: 'My Fields', highlight: true),
      (text: '.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Open ', highlight: false),
        (text: 'My Fields', highlight: true),
        (text: ' to see farmer plots.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Tap a field card for details or map.', highlight: false),
      ],
    ],
  ),
  (
    title: 'More',
    icon: Icons.grid_view_rounded,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.moreNav,
      NavigationGuideSpotlightTarget.moreProfile,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Use ', highlight: false),
      (text: 'More', highlight: true),
      (text: ' for profile, settings, and help content.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'More', highlight: true),
        (text: ' for account options.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Open ', highlight: false),
        (text: 'profile', highlight: true),
        (text: ' to manage your account.', highlight: false),
      ],
    ],
  ),
];

const List<NavigationGuideSlide> kAdminNavigationGuideSlides = <NavigationGuideSlide>[
  (
    title: 'Home — admin view',
    icon: Icons.home_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.homeNav,
      NavigationGuideSpotlightTarget.homeGreeting,
      NavigationGuideSpotlightTarget.homeMapPreview,
    ],
    body: <({String text, bool highlight})>[
      (text: 'As ', highlight: false),
      (text: 'admin', highlight: true),
      (text: ', Home links to access requests, reports, and the org map.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Start on ', highlight: false),
        (text: 'Home', highlight: true),
        (text: ' for staff shortcuts.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Review ', highlight: false),
        (text: 'agriculturist access', highlight: true),
        (text: ' and farmer report tiles here.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'The ', highlight: false),
        (text: 'map', highlight: true),
        (text: ' shows all positive sightings.', highlight: false),
      ],
    ],
  ),
  (
    title: 'Analytics',
    icon: Icons.insights_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.diagnoseNav,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Open ', highlight: false),
      (text: 'Diagnose', highlight: true),
      (text: ' for org-wide KPIs, trends, and top 5 farms.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'Diagnose', highlight: true),
        (text: ' for the analytics dashboard.', highlight: false),
      ],
    ],
  ),
  (
    title: 'Agriculturist access requests',
    icon: Icons.how_to_reg_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.scanButton,
    ],
    body: <({String text, bool highlight})>[
      (text: 'The center button opens ', highlight: false),
      (text: 'agriculturist access requests', highlight: true),
      (text: '. Approve or reject staff applications.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap the center ', highlight: false),
        (text: 'requests', highlight: true),
        (text: ' button. Badges show pending items.', highlight: false),
      ],
    ],
  ),
  (
    title: 'My Fields',
    icon: Icons.landscape_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.myFieldsNav,
      NavigationGuideSpotlightTarget.myFieldsGrid,
    ],
    body: <({String text, bool highlight})>[
      (text: 'View every registered field in ', highlight: false),
      (text: 'My Fields', highlight: true),
      (text: '.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Open ', highlight: false),
        (text: 'My Fields', highlight: true),
        (text: ' for the full field list.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Tap a card to inspect or open the map.', highlight: false),
      ],
    ],
  ),
  (
    title: 'More',
    icon: Icons.grid_view_rounded,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.moreNav,
      NavigationGuideSpotlightTarget.moreProfile,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Use ', highlight: false),
      (text: 'More', highlight: true),
      (text: ' for profile, settings, and help.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'More', highlight: true),
        (text: ' for account tools.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Open ', highlight: false),
        (text: 'profile', highlight: true),
        (text: ' or Settings from here.', highlight: false),
      ],
    ],
  ),
];

/// Farmer tour (legacy name).
const List<NavigationGuideSlide> kNavigationGuideSlides =
    kFarmerNavigationGuideSlides;

/// Role-aware slides: farmer, DA reporter, or full admin.
List<NavigationGuideSlide> navigationGuideSlidesForCurrentUser() {
  if (currentUserJwtFullAdmin()) return kAdminNavigationGuideSlides;
  if (currentUserJwtDa()) return kDaNavigationGuideSlides;
  return kFarmerNavigationGuideSlides;
}

/// Body text for the current spotlight step (or full [slide.body] as fallback).
List<({String text, bool highlight})> navigationGuideBodyForSpotlightStep(
  NavigationGuideSlide slide, {
  required bool sequenceActive,
  required int sequenceIndex,
}) {
  final List<List<({String text, bool highlight})>>? per =
      slide.bodyPerSequenceStep;
  if (sequenceActive &&
      per != null &&
      sequenceIndex >= 0 &&
      sequenceIndex < per.length) {
    return per[sequenceIndex];
  }
  return slide.body;
}

/// Centered rich body used by the modal guide and the spotlight card.
class NavigationGuideBodyText extends StatelessWidget {
  const NavigationGuideBodyText({
    super.key,
    required this.segments,
    this.baseStyle,
  });

  final List<({String text, bool highlight})> segments;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolvedBase = baseStyle ??
        TextStyle(
          fontSize: 16,
          height: 1.45,
          color: Theme.of(context).colorScheme.onSurface,
        );
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: resolvedBase,
        children: <TextSpan>[
          for (final ({String text, bool highlight}) seg in segments)
            TextSpan(
              text: seg.text,
              style: seg.highlight ? kNavigationGuideBodyHighlightStyle : null,
            ),
        ],
      ),
    );
  }
}
