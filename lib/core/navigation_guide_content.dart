// Shared copy and spotlight targets for the post-login navigation guide.
library;

import 'package:flutter/material.dart';

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

const List<NavigationGuideSlide> kNavigationGuideSlides = <
    NavigationGuideSlide>[
  (
    title: 'Home — your dashboard',
    icon: Icons.home_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.homeNav,
      NavigationGuideSpotlightTarget.homeTotalFields,
      NavigationGuideSpotlightTarget.homeRegion,
      NavigationGuideSpotlightTarget.homeSavedImages,
      NavigationGuideSpotlightTarget.homeMapPreview,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Start with ', highlight: false),
      (text: 'Home', highlight: true),
      (
        text: ', the first stop on the bottom bar. Inside you’ll see the ',
        highlight: false,
      ),
      (text: 'PINYA-PIC', highlight: true),
      (text: ' header, a ', highlight: false),
      (text: 'greeting', highlight: true),
      (
        text:
            ', and—when you’re signed in—mini cards for ',
        highlight: false,
      ),
      (text: 'Total fields', highlight: true),
      (text: ' and ', highlight: false),
      (text: 'Region', highlight: true),
      (
        text: '. Below that: ',
        highlight: false,
      ),
      (text: 'Saved Images', highlight: true),
      (
        text: ' (your latest captures), then a ',
        highlight: false,
      ),
      (text: 'Map preview', highlight: true),
      (
        text:
            ' for Polomolok—tap it when you’re online to jump into the location tools.',
        highlight: false,
      ),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Use the ', highlight: false),
        (text: 'Home', highlight: true),
        (
          text: ' tab in the bar below—this is your main overview.',
          highlight: false,
        ),
      ],
      <({String text, bool highlight})>[
        (text: 'This card is ', highlight: false),
        (text: 'Total fields', highlight: true),
        (text: ': how many plots you’ve registered.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'This card is ', highlight: false),
        (text: 'Region', highlight: true),
        (text: '—where your fields are based.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Scroll to ', highlight: false),
        (text: 'Saved Images', highlight: true),
        (text: ' for your latest pest photos.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'The ', highlight: false),
        (text: 'Map preview', highlight: true),
        (
          text: ' opens Polomolok maps when you’re online.',
          highlight: false,
        ),
      ],
    ],
  ),
  (
    title: 'Diagnose — stats & disease lookup',
    icon: Icons.shield_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.diagnoseNav,
      NavigationGuideSpotlightTarget.diagnoseSearchDiseases,
      NavigationGuideSpotlightTarget.diagnoseWeekStats,
      NavigationGuideSpotlightTarget.diagnosePestsChart,
      NavigationGuideSpotlightTarget.diagnoseMyFieldsStrip,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Next, open ', highlight: false),
      (text: 'Diagnose', highlight: true),
      (
        text:
            '. Here you can tap ',
        highlight: false,
      ),
      (text: 'Search for Diseases', highlight: true),
      (
        text: ' to browse symptoms and care info. The screen summarizes ',
        highlight: false,
      ),
      (text: 'this week’s captures', highlight: true),
      (text: ', ', highlight: false),
      (text: 'infestation', highlight: true),
      (
        text: ' trends, and a ',
        highlight: false,
      ),
      (text: 'pests chart', highlight: true),
      (
        text: ' over the last several days. Scroll down for another ',
        highlight: false,
      ),
      (text: 'My Fields', highlight: true),
      (
        text: ' strip tied to your account. (Sign in to see live numbers.)',
        highlight: false,
      ),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'Diagnose', highlight: true),
        (text: ' in the bottom bar to open this screen.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'Search for Diseases', highlight: true),
        (text: ' to browse symptoms and care info.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'These cards summarize ', highlight: false),
        (text: 'this week’s captures', highlight: true),
        (text: ' and ', highlight: false),
        (text: 'infestation', highlight: true),
        (text: ' at a glance.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'The line chart tracks ', highlight: false),
        (text: 'pests', highlight: true),
        (text: ' over recent days.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Scroll for another ', highlight: false),
        (text: 'My Fields', highlight: true),
        (text: ' strip on this screen.', highlight: false),
      ],
    ],
  ),
  (
    title: 'Scan — capture in one tap',
    icon: Icons.photo_camera,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.scanButton,
      NavigationGuideSpotlightTarget.addPhotoSync,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Tap the ', highlight: false),
      (text: 'green camera button', highlight: true),
      (
        text:
            ' to take a photo or open the gallery. After captures, use ',
        highlight: false,
      ),
      (text: 'Sync to cloud', highlight: true),
      (
        text:
            ' on the Add Photo screen to upload offline ',
        highlight: false,
      ),
      (text: 'fields', highlight: true),
      (text: ' and ', highlight: false),
      (text: 'pest photos', highlight: true),
      (text: ' when you are online.', highlight: false),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap the ', highlight: false),
        (text: 'green camera', highlight: true),
        (
          text: ' button to open Add Photo (camera or gallery).',
          highlight: false,
        ),
      ],
      <({String text, bool highlight})>[
        (text: 'On this screen, ', highlight: false),
        (text: 'Sync to cloud', highlight: true),
        (
          text:
              ' uploads fields you created offline and detections waiting in the queue.',
          highlight: false,
        ),
      ],
    ],
  ),
  (
    title: 'My Fields — plots & reminders',
    icon: Icons.landscape_outlined,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.myFieldsNav,
      NavigationGuideSpotlightTarget.myFieldsHeaderTabs,
      NavigationGuideSpotlightTarget.myFieldsGrid,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Choose ', highlight: false),
      (text: 'My Fields', highlight: true),
      (
        text: ' to manage land. At the top, switch between the ',
        highlight: false,
      ),
      (text: 'My Fields', highlight: true),
      (text: ' and ', highlight: false),
      (text: 'Reminders', highlight: true),
      (
        text: ' tabs. Your plots show up in a ',
        highlight: false,
      ),
      (text: 'grid', highlight: true),
      (
        text: '; tap any card for ',
        highlight: false,
      ),
      (text: 'field details', highlight: true),
      (
        text: ', or use ',
        highlight: false,
      ),
      (text: 'Add field', highlight: true),
      (
        text: ' to register new ground.',
        highlight: false,
      ),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'My Fields', highlight: true),
        (text: ' in the bottom bar to manage your plots.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Switch between ', highlight: false),
        (text: 'My Fields', highlight: true),
        (text: ' and ', highlight: false),
        (text: 'Reminders', highlight: true),
        (text: ' here.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Your plots appear in this ', highlight: false),
        (text: 'grid', highlight: true),
        (text: '. Tap a card for details.', highlight: false),
      ],
    ],
  ),
  (
    title: 'More — profile & learning library',
    icon: Icons.grid_view_rounded,
    spotlightTargets: <NavigationGuideSpotlightTarget>[],
    spotlightSequence: <NavigationGuideSpotlightTarget>[
      NavigationGuideSpotlightTarget.moreNav,
      NavigationGuideSpotlightTarget.moreProfile,
      NavigationGuideSpotlightTarget.moreGeneralInfo,
      NavigationGuideSpotlightTarget.moreCommonDiseases,
      NavigationGuideSpotlightTarget.moreExploreByParts,
    ],
    body: <({String text, bool highlight})>[
      (text: 'Finally, ', highlight: false),
      (text: 'More', highlight: true),
      (
        text: ' rounds out the tour. You’ll find your ',
        highlight: false,
      ),
      (text: 'profile', highlight: true),
      (
        text: ' card (tap through to account settings), horizontal ',
        highlight: false,
      ),
      (text: 'General Info', highlight: true),
      (
        text: ' articles, ',
        highlight: false,
      ),
      (text: 'Common Diseases', highlight: true),
      (
        text: ', and ',
        highlight: false,
      ),
      (text: 'Explore by plant part', highlight: true),
      (
        text: '—handy references when you’re not on a field visit.',
        highlight: false,
      ),
    ],
    bodyPerSequenceStep: <List<({String text, bool highlight})>>[
      <({String text, bool highlight})>[
        (text: 'Tap ', highlight: false),
        (text: 'More', highlight: true),
        (text: ' in the bottom bar for profile and learning content.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Your ', highlight: false),
        (text: 'profile', highlight: true),
        (text: ' card opens account settings.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Browse ', highlight: false),
        (text: 'General Info', highlight: true),
        (text: ' articles in this row.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'See ', highlight: false),
        (text: 'Common Diseases', highlight: true),
        (text: ' for quick reference.', highlight: false),
      ],
      <({String text, bool highlight})>[
        (text: 'Try ', highlight: false),
        (text: 'Explore by plant part', highlight: true),
        (text: ' when diagnosing.', highlight: false),
      ],
    ],
  ),
];

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
