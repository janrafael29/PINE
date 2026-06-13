// Fields dashboard with field-level infestation stats.
library;

import 'package:flutter/material.dart';

import '../models/field_plot_models.dart';
import '../widgets/app_scaffold.dart';
import 'farm_details_screen.dart';
import 'field_selection_screen.dart';

class FieldsDashboardScreen extends StatefulWidget {
  const FieldsDashboardScreen({super.key});

  @override
  State<FieldsDashboardScreen> createState() => _FieldsDashboardScreenState();
}

class _FieldsDashboardScreenState extends State<FieldsDashboardScreen> {
  final List<FieldData> _fields = const <FieldData>[
    FieldData(name: 'Field 001', infestationPercentage: 52, imageCount: 145),
    FieldData(name: 'Field 002', infestationPercentage: 28, imageCount: 89),
  ];

  String _selectedField = 'Field 001';

  FieldData? _getSelectedField() {
    try {
      return _fields.firstWhere((FieldData f) => f.name == _selectedField);
    } catch (_) {
      return null;
    }
  }

  static Color _progressColor(double percentage) {
    if (percentage < 30) return Colors.green;
    if (percentage < 60) return Colors.orange;
    return Colors.red;
  }

  static Color _progressLabelColor(Color bg, ColorScheme cs) {
    return bg.computeLuminance() > 0.55 ? cs.onSurface : cs.surface;
  }

  @override
  Widget build(BuildContext context) {
    final FieldData? selected = _getSelectedField();
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Field Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.camera_alt),
          tooltip: 'Take photo',
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const FieldSelectionScreen(),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const FarmDetailsScreen(),
              ),
            );
          },
        ),
      ],
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: [
                Text(
                  'Field:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedField,
                    isExpanded: true,
                    items: _fields
                        .map((FieldData field) => DropdownMenuItem<String>(
                              value: field.name,
                              child: Text(field.name),
                            ))
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() => _selectedField = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: selected == null
                ? Center(
                    child: Text(
                      'No field selected',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildFieldCard(context, selected),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard(BuildContext context, FieldData field) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.45),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  field.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _progressColor(field.infestationPercentage),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${field.infestationPercentage.toInt()}%',
                    style: TextStyle(
                      color: _progressLabelColor(
                        _progressColor(field.infestationPercentage),
                        cs,
                      ),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.image, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${field.imageCount} images taken',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: field.infestationPercentage / 100,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _progressColor(field.infestationPercentage),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mealybug infestation (field average)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
