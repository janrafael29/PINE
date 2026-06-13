library;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/image_storage_service.dart';
import '../utils/relative_time.dart';
import '../utils/severity_score.dart';
import 'capture_thumbnail.dart';

/// Field-first activity row (not a dense thumbnail grid).
class CaptureActivityCard extends StatelessWidget {
  const CaptureActivityCard({
    super.key,
    required this.fieldLabel,
    required this.mealybugCount,
    required this.confidencePct,
    required this.localImagePath,
    this.remoteImageUrl,
    required this.images,
    this.createdAtIso,
    this.filipino = false,
    this.compact = false,
  });

  final String fieldLabel;
  final int mealybugCount;
  final int confidencePct;
  final String localImagePath;
  final String? remoteImageUrl;
  final ImageStorageService images;
  final String? createdAtIso;
  final bool filipino;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double sev = severity01(
      bugCount: mealybugCount,
      confidencePct: confidencePct,
    );
    final Color sevColor = severityColor(sev);
    final String timeLabel = formatRelativeIso(createdAtIso, fil: filipino);
    final double thumb = compact ? 72.0 : 88.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: thumb,
              height: thumb,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: captureThumbnail(
                  localImagePath: localImagePath,
                  remoteImageUrl: remoteImageUrl,
                  images: images,
                  displayLogicalWidth: thumb,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    fieldLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      _ChipLabel(
                        label: mealybugCount > 0
                            ? (filipino ? 'Positibo' : 'Positive')
                            : (filipino ? 'Negatibo' : 'Negative'),
                        color: mealybugCount > 0
                            ? const Color(0xFFE74C3C)
                            : const Color(0xFF2ECC71),
                      ),
                      _ChipLabel(
                        label: filipino ? 'Kumpirma: $mealybugCount' : 'Confirmed: $mealybugCount',
                        color: sevColor,
                      ),
                      _ChipLabel(
                        label: '$confidencePct%',
                        color: AppTheme.primaryGreen,
                      ),
                      _ChipLabel(
                        label: timeLabel,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        filled: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.label,
    required this.color,
    this.filled = true,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: filled ? color : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
