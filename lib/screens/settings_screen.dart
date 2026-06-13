// Main settings menu with account, preferences, support, legal.
library;

import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_state.dart';
import '../core/navigation_guide_prefs.dart';
import '../core/security_prefs.dart';
import '../widgets/app_scaffold.dart';
import 'about_screen.dart';
import 'app_navigation_guide_screen.dart';
import 'privacy_screen.dart';
import 'terms_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  bool _deviceUnlockAvailable = false;
  bool _requireDeviceUnlock = false;
  bool _showNavGuideEachOpen = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _loadSecurityPrefs();
    // ignore: discarded_futures
    _loadNavGuidePrefs();
    PackageInfo.fromPlatform().then(
      (PackageInfo info) {
        if (!mounted) return;
        setState(() {
          _appVersion = info.version;
        });
      },
    );
  }

  Future<void> _loadSecurityPrefs() async {
    final bool hasLogin = await SecurityPrefs.hasSuccessfulLogin();
    final bool require = await SecurityPrefs.requireDeviceUnlock();
    if (!mounted) return;
    setState(() {
      _deviceUnlockAvailable = hasLogin;
      _requireDeviceUnlock = require;
    });
  }

  Future<void> _loadNavGuidePrefs() async {
    final bool each = await getNavigationGuideShowEachSession();
    if (!mounted) return;
    setState(() => _showNavGuideEachOpen = each);
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final appState = context.read<AppState>();
    final String selected = appState.languageCode;
    final String? result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Choose language',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('English'),
                trailing: selected == 'en'
                    ? Icon(Icons.check, color: cs.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'en'),
              ),
              ListTile(
                title: const Text('Filipino'),
                trailing: selected == 'fil'
                    ? Icon(Icons.check, color: cs.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'fil'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (result == null || result == selected) return;
    await appState.setLanguage(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'fil'
              ? 'Language set to Filipino'
              : 'Language set to English',
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final String languageLabel = appState.isFilipino ? 'Filipino' : 'English';
    return AppScaffold(
      title: 'Settings',
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _buildSection(context, 'Account', <Widget>[
              _buildTile(
                context,
                icon: Icons.person,
                title: 'Profile',
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
            ]),
            _buildSection(context, 'Preferences', <Widget>[
              if (_deviceUnlockAvailable)
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    ),
                    title: const Text('Device unlock'),
                    subtitle: const Text(
                      'Require fingerprint/face or device PIN when opening the app',
                    ),
                    value: _requireDeviceUnlock,
                    onChanged: (bool value) async {
                      setState(() => _requireDeviceUnlock = value);
                      await SecurityPrefs.setRequireDeviceUnlock(value);
                    },
                  ),
                ),
              _buildTile(
                context,
                icon: Icons.language,
                title: 'Language',
                subtitle: languageLabel,
                color: Colors.purple,
                onTap: () => _pickLanguage(context),
              ),
              Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.dark_mode_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text('Dark mode'),
                  subtitle: const Text('Easier on the eyes in low light'),
                  value: appState.darkMode,
                  onChanged: (bool value) {
                    // ignore: discarded_futures
                    context.read<AppState>().setDarkMode(value);
                  },
                ),
              ),
              Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.center_focus_strong_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text('Detection accuracy mode'),
                  subtitle: const Text(
                    'Tiled scan for tiny pests on plants only (~24 crops). '
                    'Turn off for people/indoor photos.',
                  ),
                  value: appState.inferenceAccuracyMode,
                  onChanged: (bool value) {
                    // ignore: discarded_futures
                    context.read<AppState>().setInferenceAccuracyMode(value);
                  },
                ),
              ),
              Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text('Show app guide when opening'),
                  subtitle: const Text(
                    'Navigation tour after sign-in (device unlock if enabled)',
                  ),
                  value: _showNavGuideEachOpen,
                  onChanged: (bool value) async {
                    setState(() => _showNavGuideEachOpen = value);
                    await setNavigationGuideShowEachSession(value);
                  },
                ),
              ),
              _buildTile(
                context,
                icon: Icons.menu_book_outlined,
                title: 'View app navigation guide',
                subtitle: 'Walkthrough of Home, Scan, and tabs',
                color: Colors.teal,
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AppNavigationGuideScreen(
                        showPreferenceChooser: false,
                      ),
                    ),
                  );
                },
              ),
              _buildTile(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                color: Colors.orange,
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
            ]),
            _buildSection(context, 'Support', <Widget>[
              _buildTile(
                context,
                icon: Icons.feedback,
                title: 'Feedback',
                color: Colors.blue,
                onTap: () => Navigator.pushNamed(context, '/feedback'),
              ),
              _buildTile(
                context,
                icon: Icons.help,
                title: 'FAQ',
                color: Theme.of(context).colorScheme.primary,
                onTap: () => Navigator.pushNamed(context, '/faq'),
              ),
            ]),
            _buildSection(context, 'Legal', <Widget>[
              _buildTile(
                context,
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                color: Colors.teal,
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyScreen(showAcceptButton: false),
                  ),
                ),
              ),
              _buildTile(
                context,
                icon: Icons.description,
                title: 'Terms & Conditions',
                color: Colors.indigo,
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const TermsScreen(showAcceptButton: false),
                  ),
                ),
              ),
            ]),
            _buildSection(context, 'App', <Widget>[
              _buildTile(
                context,
                icon: Icons.info,
                title: 'About',
                subtitle: _appVersion.isEmpty ? 'Version …' : 'Version $_appVersion',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () => _signOut(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.2,
                ),
          ),
        ),
        ...children,
        const Divider(height: 16),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await SupabaseClientProvider.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }
}
