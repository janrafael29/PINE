/// Diagnose-tab analytics for DA / admin (compact layout + web-style charts).
library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../core/theme.dart';
import '../screens/detections_map_screen.dart';
import '../services/staff_analytics_service.dart';
import '../utils/friendly_datetime.dart';
import '../widgets/online_required_dialog.dart';
import '../widgets/pine_card.dart';
import '../widgets/staff_analytics_charts.dart';

class StaffAnalyticsPanel extends StatefulWidget {
  const StaffAnalyticsPanel({
    super.key,
    required this.snapshot,
    required this.fil,
  });

  final StaffAnalyticsSnapshot snapshot;
  final bool fil;

  @override
  State<StaffAnalyticsPanel> createState() => _StaffAnalyticsPanelState();
}

class _StaffAnalyticsPanelState extends State<StaffAnalyticsPanel> {
  StaffTrendRange _trendRange = StaffTrendRange.days7;

  StaffAnalyticsSnapshot get snapshot => widget.snapshot;
  bool get fil => widget.fil;

  String _trendTitle() {
    return fil ? 'Positibong trend' : 'Positive trend';
  }

  Future<void> _openFieldOnMap(String fieldId, String fieldName) async {
    if (!await ensureOnline(context)) return;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DetectionsMapScreen(
          fieldId: fieldId,
          fieldName: fieldName,
          initialShowGeoFence: true,
        ),
      ),
    );
  }

  Widget _donutCard(int pct) {
    return _AnalyticsCard(
      title: fil ? 'Positibo vs negatibo' : 'Positive vs negative',
      tag: fil ? 'Donut' : 'Donut',
      child: SizedBox(
        height: 148,
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: StaffDonutChart(
                positive: snapshot.totalPositive,
                negative: snapshot.totalNegative,
                centerValue: '$pct%',
                centerLabel: fil ? 'positibo' : 'positive',
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _LegendRow(
                    color: kStaffAnalyticsOlive,
                    label: fil ? 'Positibo' : 'Positive',
                    value: '${snapshot.totalPositive}',
                  ),
                  const SizedBox(height: 8),
                  _LegendRow(
                    color: kStaffAnalyticsTaupe,
                    label: fil ? 'Negatibo' : 'Negative',
                    value: '${snapshot.totalNegative}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fil
                        ? '${snapshot.totalReports} kabuuang ulat'
                        : '${snapshot.totalReports} total reports',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.pineTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barCard() {
    return _AnalyticsCard(
      title: fil ? 'Top 5 farms' : 'Top 5 farms',
      tag: 'Bar',
      child: StaffHorizontalBarChart(
        labels: snapshot.topFarms
            .map((StaffTopFarmRow r) => r.fieldName)
            .toList(),
        values: snapshot.topFarms
            .map((StaffTopFarmRow r) => r.positiveCount)
            .toList(),
        accentColor: kStaffAnalyticsOlive,
        emptyLabel: fil
            ? 'Wala pang positibong ulat.'
            : 'No positive reports yet.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final StaffTrendSeries trend = snapshot.trendFor(_trendRange);
    final int pct = (snapshot.positiveRate * 100).round();

    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  fil ? 'ANALITIKA' : 'ANALYTICS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.pineTextPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fil
                      ? 'Buod ng lahat ng ulat ng magsasaka.'
                      : 'Org-wide farmer reports overview.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.pineTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _KpiTile(
                        value: '${snapshot.totalPositive}',
                        label: fil ? 'Positibo' : 'Positive',
                        color: cs.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KpiTile(
                        value: '${snapshot.totalNegative}',
                        label: fil ? 'Negatibo' : 'Negative',
                        color: kStaffAnalyticsTaupe,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _KpiTile(
                        value: '${snapshot.positive7d}',
                        label: fil ? '7 araw' : '7 days',
                        color: kStaffAnalyticsOlive,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _KpiTile(
                        value: '${snapshot.positive30d}',
                        label: fil ? '30 araw' : '30 days',
                        color: cs.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _AnalyticsCard(
              title: _trendTitle(),
              tag: fil ? 'Linya' : 'Line',
              trailing: SegmentedButton<StaffTrendRange>(
                segments: <ButtonSegment<StaffTrendRange>>[
                  ButtonSegment<StaffTrendRange>(
                    value: StaffTrendRange.days7,
                    label: Text(fil ? '7A' : '7D'),
                  ),
                  ButtonSegment<StaffTrendRange>(
                    value: StaffTrendRange.days30,
                    label: Text(fil ? '1B' : '1M'),
                  ),
                  ButtonSegment<StaffTrendRange>(
                    value: StaffTrendRange.year1,
                    label: Text(fil ? '1T' : '1Y'),
                  ),
                ],
                selected: <StaffTrendRange>{_trendRange},
                onSelectionChanged: (Set<StaffTrendRange> next) {
                  if (next.isEmpty) return;
                  setState(() => _trendRange = next.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStatePropertyAll<TextStyle>(
                    TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              child: StaffLineTrendChart(
                counts: trend.counts,
                labels: trend.labels,
                accentColor: kStaffAnalyticsOlive,
                emptyLabel: fil
                    ? 'Wala pang positibong ulat sa panahong ito.'
                    : 'No positive reports in this period.',
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 520;
                final Widget donut = _donutCard(pct);
                if (snapshot.topFarms.isEmpty) {
                  return donut;
                }
                final Widget bar = _barCard();
                if (wide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: donut),
                        const SizedBox(width: 10),
                        Expanded(child: bar),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    donut,
                    const SizedBox(height: 10),
                    bar,
                  ],
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              fil ? 'Top 5 (detalye)' : 'Top 5 (table)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.pineTextPrimary,
              ),
            ),
          ),
        ),
        if (snapshot.topFarms.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Text(
                fil ? 'Wala pang positibong ulat.' : 'No positive reports yet.',
                style: TextStyle(color: context.pineTextSecondary),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            sliver: SliverToBoxAdapter(
              child: _TopFarmsTable(
                rows: snapshot.topFarms,
                fil: fil,
                onViewMap: _openFieldOnMap,
              ),
            ),
          ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PineCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: color.withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.pineTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.child,
    this.tag,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? tag;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PineCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.pineTextPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
              if (tag != null) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: trailing!,
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: context.pineTextSecondary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.pineTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _TopFarmsTable extends StatelessWidget {
  const _TopFarmsTable({
    required this.rows,
    required this.fil,
    required this.onViewMap,
  });

  final List<StaffTopFarmRow> rows;
  final bool fil;
  final Future<void> Function(String fieldId, String fieldName) onViewMap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PineCard(
      padding: EdgeInsets.zero,
      borderRadius: 12,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Text(
                    fil ? 'Field' : 'Field',
                    style: _headerStyle(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    fil ? 'May-ari' : 'Owner',
                    style: _headerStyle(context),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '+',
                    textAlign: TextAlign.center,
                    style: _headerStyle(context),
                  ),
                ),
                const SizedBox(width: 72),
              ],
            ),
          ),
          ...rows.asMap().entries.map((MapEntry<int, StaffTopFarmRow> e) {
            final StaffTopFarmRow row = e.value;
            final bool last = e.key == rows.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: last
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          row.fieldName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (row.lastSightingIso != null)
                          Text(
                            formatFriendlyIso(row.lastSightingIso!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              color: context.pineTextSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      row.ownerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.pineTextSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${row.positiveCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kStaffAnalyticsOlive,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: TextButton(
                      onPressed: () {
                        // ignore: discarded_futures
                        onViewMap(row.fieldId, row.fieldName);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        fil ? 'Mapa' : 'Map',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  TextStyle _headerStyle(BuildContext context) {
    return TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: context.pineTextSecondary,
    );
  }
}

/// Loads org-wide detections + fields and renders [StaffAnalyticsPanel].
class StaffAnalyticsTab extends StatefulWidget {
  const StaffAnalyticsTab({super.key, required this.fil});

  final bool fil;

  @override
  State<StaffAnalyticsTab> createState() => _StaffAnalyticsTabState();
}

class _StaffAnalyticsTabState extends State<StaffAnalyticsTab> {
  Map<String, String> _ownerLabels = <String, String>{};
  List<Map<String, dynamic>> _fields = <Map<String, dynamic>>[];
  bool _metaLoaded = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    try {
      final List<Map<String, dynamic>> fields =
          await fieldsSelectForSession();
      final List<String> ownerIds =
          fieldRowOwnerIdsForProfileFetch(fields);
      final Map<String, String> labels =
          await fetchProfileOwnerLabelsForUserIds(ownerIds);
      if (!mounted) return;
      setState(() {
        _fields = fields;
        _ownerLabels = labels;
        _metaLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _metaLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_metaLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: detectionsRealtimeStream(),
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final StaffAnalyticsSnapshot data =
            StaffAnalyticsCalculator.fromDetections(
          detections: snapshot.data!,
          fields: _fields,
          ownerLabels: _ownerLabels,
        );

        return StaffAnalyticsPanel(snapshot: data, fil: widget.fil);
      },
    );
  }
}
