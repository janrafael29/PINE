/// Full-screen queue for admins to review pending DA access requests.
library;

import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';
import '../core/staff_role_labels.dart';
import '../widgets/da_access_request_admin_card.dart';

class DaAccessRequestsScreen extends StatefulWidget {
  const DaAccessRequestsScreen({super.key});

  @override
  State<DaAccessRequestsScreen> createState() => _DaAccessRequestsScreenState();
}

class _DaAccessRequestsScreenState extends State<DaAccessRequestsScreen> {
  final GlobalKey<DaAccessRequestAdminCardState> _listKey =
      GlobalKey<DaAccessRequestAdminCardState>();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: staffAccessRequestsTitle,
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _listKey.currentState?.reload(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: DaAccessRequestAdminCard(
        key: _listKey,
        fullScreen: true,
      ),
    );
  }
}
