/// List of defined land boundaries. Navigate to map to add/edit.
library;

import 'package:flutter/material.dart';

import '../models/land.dart';
import '../services/database_service.dart';
import '../widgets/app_scaffold.dart';
import 'land_map_screen.dart';
import 'fields_dashboard_screen.dart';
import '../widgets/online_required_dialog.dart';

/// Screen listing all lands. Tap to edit, FAB to add new.
class LandsScreen extends StatefulWidget {
  const LandsScreen({super.key});

  @override
  State<LandsScreen> createState() => _LandsScreenState();
}

class _LandsScreenState extends State<LandsScreen> {
  final _database = DatabaseService();
  List<Land> _lands = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLands();
  }

  Future<void> _loadLands() async {
    await _database.initialize();
    final lands = await _database.getAllLands();
    if (mounted) {
      setState(() {
        _lands = lands;
        _isLoading = false;
      });
    }
  }

  Future<void> _addLand() async {
    if (!await ensureOnline(context)) return;
    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const LandMapScreen(),
      ),
    );
    if (result == true) _loadLands();
  }

  Future<void> _editLand(Land land) async {
    if (!await ensureOnline(context)) return;
    if (!mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => LandMapScreen(land: land),
      ),
    );
    if (result == true) _loadLands();
  }

  Future<void> _deleteLand(Land land) async {
    if (land.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Land'),
        content: Text(
          'Delete "${land.landName}"? Detections will be unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _database.deleteLand(land.id!);
      _loadLands();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppScaffold(
        title: 'Land Boundaries',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return AppScaffold(
      title: 'Land Boundaries',
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.dashboard),
          tooltip: 'Field Dashboard',
          onPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const FieldsDashboardScreen(),
              ),
            );
          },
        ),
      ],
      body: _lands.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No lands defined',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to add a land boundary on the map',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lands.length,
              itemBuilder: (BuildContext context, int i) {
                final land = _lands[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: cs.primary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.terrain,
                        color: cs.primary,
                      ),
                    ),
                    title: Text(
                      land.landName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      '${land.polygonCoordinates.length} points',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String value) {
                        if (value == 'edit') _editLand(land);
                        if (value == 'delete') _deleteLand(land);
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuItem<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                    onTap: () => _editLand(land),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLand,
        child: const Icon(Icons.add),
      ),
    );
  }
}
