// Main settings menu with account, preferences, support, legal.
library;

import 'package:flutter/material.dart';
import '../core/supabase_client.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_state.dart';
import '../core/demo_accounts.dart';
import '../core/navigation_guide_prefs.dart';
import '../core/security_prefs.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/demo_account_switcher.dart';
import '../widgets/pine_card.dart';
import '../widgets/show_pine_bottom_sheet.dart';
import 'about_screen.dart';
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
    final String? result = await showPineBottomSheet<String>(
      context: context,
      title: 'Choose language',
      builder: (BuildContext sheetContext) {
        final ColorScheme cs = Theme.of(sheetContext).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            _buildSection(context, 'Account', <Widget>[
              _buildTile(
                context,
                icon: Icons.person,
                title: 'Profile',
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
            ]),
            _buildSection(context, 'Preferences', <Widget>[
              if (_deviceUnlockAvailable)
                _buildSwitchTile(
                  context,
                  icon: Icons.lock,
                  title: 'Device unlock',
                  value: _requireDeviceUnlock,
                  onChanged: (bool value) async {
                    setState(() => _requireDeviceUnlock = value);
                    await SecurityPrefs.setRequireDeviceUnlock(value);
                  },
                ),
              _buildTile(
                context,
                icon: Icons.language,
                title: 'Language',
                subtitle: languageLabel,
                onTap: () => _pickLanguage(context),
              ),
              _buildSwitchTile(
                context,
                icon: Icons.dark_mode_outlined,
                title: 'Dark mode',
                subtitle: 'Easier on the eyes in low light',
                value: appState.darkMode,
                onChanged: (bool value) {
                  // ignore: discarded_futures
                  context.read<AppState>().setDarkMode(value);
                },
              ),
              _buildSwitchTile(
                context,
                icon: Icons.center_focus_strong_outlined,
                title: 'Tiled pest scan',
                value: appState.inferenceAccuracyMode,
                onChanged: (bool value) {
                  // ignore: discarded_futures
                  context.read<AppState>().setInferenceAccuracyMode(value);
                },
              ),
              _buildSwitchTile(
                context,
                icon: Icons.school_outlined,
                title: 'Navigation guide on open',
                value: _showNavGuideEachOpen,
                onChanged: (bool value) async {
                  setState(() => _showNavGuideEachOpen = value);
                  await setNavigationGuideShowEachSession(value);
                },
              ),
              _buildTile(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
            ]),
            _buildSection(context, 'Support', <Widget>[
              _buildTile(
                context,
                icon: Icons.feedback,
                title: 'Feedback',
                onTap: () => Navigator.pushNamed(context, '/feedback'),
              ),
              _buildTile(
                context,
                icon: Icons.help,
                title: 'FAQ',
                onTap: () => Navigator.pushNamed(context, '/faq'),
              ),
            ]),
            _buildSection(context, 'Legal', <Widget>[
              _buildTile(
                context,
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
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
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                  );
                },
              ),
            ]),
            if (demoAccountSwitcherEnabled())
              _buildSection(context, 'Developer', <Widget>[
                const DemoAccountSwitcher(),
              ]),
            const SizedBox(height: 12),
            ElevatedButton(
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
            const SizedBox(height: 8),
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
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
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
    required VoidCallback onTap,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PineCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: _SettingsIcon(icon: icon, color: cs.primary),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Icon(
          Icons.chevron_right,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PineCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        secondary: _SettingsIcon(icon: icon, color: cs.primary),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        value: value,
        onChanged: onChanged,
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

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
