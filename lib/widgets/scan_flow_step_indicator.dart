library;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Shows scan progress: Field → Capture → Results.
class ScanFlowStepIndicator extends StatelessWidget {
  const ScanFlowStepIndicator({
    super.key,
    required this.currentStep,
    this.filipino = false,
  });

  /// 1 = field chosen, 2 = capture, 3 = results.
  final int currentStep;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    final List<String> labels = filipino
        ? <String>['Field', 'Larawan', 'Resulta']
        : <String>['Field', 'Capture', 'Results'];

    return Row(
      children: <Widget>[
        for (int i = 0; i < labels.length; i++) ...<Widget>[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  height: 2,
                  color: currentStep > i
                      ? AppTheme.primaryGreen
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          Expanded(
            child: _StepNode(
              number: i + 1,
              label: labels[i],
              active: currentStep == i + 1,
              done: currentStep > i + 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.number,
    required this.label,
    required this.active,
    required this.done,
  });

  final int number;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final Color fg = done || active
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircleAvatar(
          radius: 15,
          backgroundColor: done || active
              ? AppTheme.primaryGreen
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active
                ? AppTheme.primaryGreen
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
