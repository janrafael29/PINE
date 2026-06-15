/// Finishes registration metadata after delayed email confirmation login.
library;

import '../core/account_intent.dart';
import '../core/registration_setup_prefs.dart';
import '../services/da_access_request_service.dart';

Future<void> completePendingRegistration(
  PendingRegistrationSetup pending,
) async {
  await AccountIntentService().setCurrent(pending.intent);
  if (pending.intent != AccountIntent.staff) return;

  final String fullName = pending.fullName?.trim() ?? '';
  final String organization = pending.organization?.trim() ?? '';
  final String location = pending.companyLocation?.trim() ?? '';
  final String position = pending.position?.trim() ?? '';
  if (fullName.isEmpty ||
      organization.isEmpty ||
      location.isEmpty ||
      position.isEmpty) {
    return;
  }

  try {
    await DaAccessRequestService().submitRequest(
      fullName: fullName,
      organization: organization,
      companyLocation: location,
      position: position,
      note: pending.note,
    );
  } on StateError {
    // Request may already exist if user retried login.
  }
}
