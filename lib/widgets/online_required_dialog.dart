/// Dialog when a feature needs network access.
library;

import 'package:flutter/material.dart';

import '../core/network_reachability.dart';
import '../core/theme.dart';

const String kOnlineRequiredMessage =
    'You must be online to utilize this feature.';

/// Shows the standard online-required dialog. Returns after the user dismisses.
Future<void> showOnlineRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Connection required'),
        content: const Text(kOnlineRequiredMessage),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

/// Returns `true` if the device appears online; otherwise shows
/// [showOnlineRequiredDialog] and returns `false`.
Future<bool> ensureOnline(BuildContext context) async {
  final bool hasInterface = await NetworkReachability.hasUsableConnectivity();
  if (!hasInterface) {
    if (context.mounted) {
      await showOnlineRequiredDialog(context);
    }
    return false;
  }

  // Do not hard-block UI actions on DNS lookup failures.
  // Some devices/networks block direct lookups while HTTPS still works.
  // Keep strict reachability checks in background sync paths instead.
  return true;
}
