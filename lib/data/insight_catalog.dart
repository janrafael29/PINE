// Severity-scaled next-step insights with optional sources.
library;

import 'detection_advisory_messages.dart';

/// A cited reference for an insight (extension guide, paper, etc.).
class InsightSource {
  const InsightSource({
    required this.title,
    this.organization,
    this.year,
    this.url,
  });

  final String title;
  final String? organization;
  final int? year;
  final String? url;
}

/// One insight row matched by [severity01] band.
class InsightEntry {
  const InsightEntry({
    required this.id,
    required this.severityMin,
    required this.severityMax,
    required this.titleEn,
    required this.titleFil,
    required this.bodyEn,
    required this.bodyFil,
    this.sources = const <InsightSource>[],
  });

  final String id;
  final double severityMin;
  final double severityMax;
  final String titleEn;
  final String titleFil;
  final String bodyEn;
  final String bodyFil;
  final List<InsightSource> sources;

  bool matchesSeverity(double severity01) =>
      severity01 >= severityMin && severity01 < severityMax;
}

/// Catalog ordered by severity band (low → high).
const List<InsightEntry> insightCatalog = <InsightEntry>[
  InsightEntry(
    id: 'none',
    severityMin: 0,
    severityMax: 0.001,
    titleEn: DetectionAdvisoryMessages.noDetectionInsightTitleEn,
    titleFil: DetectionAdvisoryMessages.noDetectionInsightTitleFil,
    bodyEn: DetectionAdvisoryMessages.noDetectionBodyEn,
    bodyFil: DetectionAdvisoryMessages.noDetectionBodyFil,
    sources: <InsightSource>[
      InsightSource(
        title: 'PINYA-PIC dataset & detection guidelines',
        organization: 'Project documentation',
        year: 2026,
      ),
    ],
  ),
  InsightEntry(
    id: 'low',
    severityMin: 0.001,
    severityMax: 0.25,
    titleEn: 'Low severity — monitor',
    titleFil: 'Mababang severity — bantayan',
    bodyEn:
        'Mark this spot and re-scan in 3–7 days. Remove isolated clusters by hand where practical; '
        'avoid moving infested material between fields.',
    bodyFil:
        'Tandaan ang lugar at i-scan muli sa 3–7 araw. Alisin ang iilang kumpol kung kaya; '
        'iwasang ilipat ang materyal na may peste sa ibang field.',
    sources: <InsightSource>[
      InsightSource(
        title: 'Integrated pest management for pineapple',
        organization: 'DA extension / IPM guides',
      ),
    ],
  ),
  InsightEntry(
    id: 'medium',
    severityMin: 0.25,
    severityMax: 0.55,
    titleEn: 'Medium severity — act this week',
    titleFil: 'Katamtamang severity — kumilos ngayong linggo',
    bodyEn:
        'Isolate affected rows if possible. Combine cultural control (sanitation, weed host removal) '
        'with targeted treatment per your local extension recommendation.',
    bodyFil:
        'Ihiwalay ang apektadong hanay kung kaya. Pagsamahin ang cultural control at targeted treatment '
        'ayon sa rekomendasyon ng inyong extension.',
    sources: <InsightSource>[
      InsightSource(
        title: 'Mealybug management in tropical crops',
        organization: 'Published IPM literature',
      ),
    ],
  ),
  InsightEntry(
    id: 'high',
    severityMin: 0.55,
    severityMax: 0.80,
    titleEn: 'High severity — urgent',
    titleFil: 'Mataas na severity — agaran',
    bodyEn:
        'Treat the affected block promptly and notify your technician or DA extension office. '
        'Document with another scan after treatment to track change.',
    bodyFil:
        'Gamutin agad ang block at ipaalam sa technician o DA extension. '
        'Mag-scan muli pagkatapos ng treatment para subaybayan.',
    sources: <InsightSource>[
      InsightSource(
        title: 'PINYA-PIC severity scoring',
        organization: 'App (field detection density)',
        year: 2026,
      ),
    ],
  ),
  InsightEntry(
    id: 'critical',
    severityMin: 0.80,
    severityMax: 1.01,
    titleEn: 'Critical — immediate action',
    titleFil: 'Kritikal — agad na aksyon',
    bodyEn:
        'Heavy infestation likely. Stop equipment movement from this block, begin approved control '
        'measures immediately, and schedule a follow-up scan within 48 hours.',
    bodyFil:
        'Malamang malubhang infestation. Itigil ang paglipat ng kagamitan mula sa block na ito, '
        'simulan ang aprubadong control, at mag-scan muli sa loob ng 48 oras.',
    sources: <InsightSource>[
      InsightSource(
        title: 'PINYA-PIC A Machine Learning-Driven Pineapple Pest Detection',
        organization: 'Thesis references',
        year: 2026,
      ),
    ],
  ),
];

/// Returns the best-matching insight for [severity01] in 0..1.
InsightEntry insightForSeverity(double severity01) {
  final double s = severity01.clamp(0.0, 1.0);
  for (final InsightEntry e in insightCatalog) {
    if (e.matchesSeverity(s)) return e;
  }
  return insightCatalog.last;
}
