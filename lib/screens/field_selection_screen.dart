// Choose a field before taking photos or viewing field details.
library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import 'field_detail_screen.dart';
import 'edit_field_screen.dart';

class FieldSelectionScreen extends StatelessWidget {
  const FieldSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a field'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: uid == null
          ? _buildEmpty(context)
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: fieldsRealtimeStream(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                if (!snapshot.hasData || snapshot.hasError) {
                  return _buildEmpty(context);
                }
                final List<Map<String, dynamic>> docs = snapshot.data!;
                if (docs.isEmpty) {
                  return _buildEmpty(context);
                }

                Widget listForLabels(Map<String, String> ownerLabels) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> data = docs[index];
                      final String fieldId = data['id'] as String;
                      final String name =
                          data['name'] as String? ?? 'Field ${index + 1}';
                      final String address =
                          data['address'] as String? ?? '';
                      final String? ou = data['user_id'] as String?;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: <Widget>[
                            ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                name,
                                style:
                                    (textTheme.titleMedium ?? const TextStyle())
                                        .copyWith(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const SizedBox(height: 4),
                                  if (currentUserJwtStaff() &&
                                      ou != null &&
                                      ou.isNotEmpty)
                                    Text(
                                      'Owner: ${ownerDisplayLabel(ou, ownerLabels)}',
                                      style: (textTheme.bodySmall ??
                                              const TextStyle())
                                          .copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  if (address.isNotEmpty)
                                    Text(
                                      address,
                                      style: (textTheme.bodySmall ??
                                              const TextStyle())
                                          .copyWith(
                                        fontSize: 13,
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).hintColor,
                              ),
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => FieldDetailScreen(
                                      fieldId: fieldId,
                                      fieldName: name,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: currentUserJwtFullAdmin()
                                  ? Builder(
                                      builder: (BuildContext editContext) {
                                        return IconButton(
                                          icon: const Icon(Icons.edit),
                                          tooltip: 'Edit field',
                                          onPressed: () {
                                            Navigator.push<void>(
                                              editContext,
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    EditFieldScreen(
                                                        fieldId: fieldId),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                if (!currentUserJwtStaff()) {
                  return listForLabels(const <String, String>{});
                }
                return FutureBuilder<Map<String, String>>(
                  future: fetchProfileOwnerLabelsForUserIds(
                    fieldRowOwnerIdsForProfileFetch(docs),
                  ),
                  builder: (BuildContext context,
                      AsyncSnapshot<Map<String, String>> labelSnap) {
                    return listForLabels(
                      labelSnap.data ?? const <String, String>{},
                    );
                  },
                );
              },
            ),
    );
  }

  static Widget _buildEmpty(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.landscape_outlined,
              size: 64,
              color: hint,
            ),
            const SizedBox(height: 16),
            const Text(
              'No fields yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a field from the location picker in More.',
              textAlign: TextAlign.center,
              style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                fontSize: 14,
                color: hint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
