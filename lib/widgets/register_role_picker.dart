/// Farmer vs staff choice at the start of registration.
library;

import 'package:flutter/material.dart';

import '../core/staff_role_labels.dart';
import '../core/theme.dart';

class RegisterRolePicker extends StatelessWidget {
  const RegisterRolePicker({
    super.key,
    required this.onFarmer,
    required this.onStaff,
  });

  final VoidCallback onFarmer;
  final VoidCallback onStaff;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'How will you use PineSight?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.pineTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your role to continue registration.',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        _RegisterRoleCard(
          icon: Icons.agriculture_outlined,
          title: 'I am a farmer',
          subtitle:
              'I grow pineapples and use PineSight to scan my fields, '
              'track pests, and manage my farm.',
          badge: 'Most users',
          onTap: onFarmer,
        ),
        const SizedBox(height: 12),
        _RegisterRoleCard(
          icon: Icons.badge_outlined,
          title: 'I work for $staffRoleWithOmagLgu',
          subtitle:
              'Government extension staff who review farmer reports and '
              'write expert advice. Requires admin approval.',
          onTap: onStaff,
        ),
      ],
    );
  }
}

class _RegisterRoleCard extends StatelessWidget {
  const _RegisterRoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.paleLime.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
