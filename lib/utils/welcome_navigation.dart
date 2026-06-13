// Navigate back to the welcome screen (login / sign up / guest).
library;

import 'package:flutter/material.dart';

import '../screens/welcome_screen.dart';

/// Clears the stack and shows [WelcomeScreen].
void navigateBackToWelcome(BuildContext context) {
  Navigator.pushAndRemoveUntil<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
    (Route<dynamic> route) => false,
  );
}

/// AppBar leading control for auth / guest entry screens.
Widget welcomeBackButton(BuildContext context) {
  return IconButton(
    tooltip: 'Back',
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        return;
      }
      navigateBackToWelcome(context);
    },
  );
}
