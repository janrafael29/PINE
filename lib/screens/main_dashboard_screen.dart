// Modernized main dashboard: Home, Diagnose, My Fields, More with bottom nav.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/admin_session.dart';
import '../core/app_state.dart';
import '../core/dashboard_guide_keys.dart';
import '../core/more_tab_images.dart';
import '../core/navigation_guide_sync.dart';
import '../core/network_reachability.dart';
import '../core/theme.dart';
import '../services/captured_photos_remote_sync.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';
import '../services/image_storage_service.dart';
import '../services/dashboard_stats_service.dart';
import '../utils/smooth_line_chart_path.dart';
import '../services/field_stats_service.dart';
import '../services/staff_nav_badges_service.dart';
import '../services/admin_reports_service.dart';
import '../widgets/capture_thumbnail.dart';
import '../widgets/field_preview_image.dart';
import '../widgets/pine_card.dart';
import 'disease_info_screen.dart';
import 'disease_detail_screen.dart';
import 'disease_by_category_screen.dart';
import 'educational_content_screen.dart';
import 'detections_map_screen.dart';
import '../utils/relative_time.dart';
import '../utils/scan_flow.dart';
import 'farm_details_screen.dart';
import 'field_detail_screen.dart';
import 'edit_field_screen.dart';
import 'captured_photo_detail_screen.dart';
import 'admin_reports_screen.dart';
import 'da_access_requests_screen.dart';
import '../widgets/da_access_request_card.dart';
import '../widgets/da_access_request_outcome_dialog.dart';
import '../widgets/expert_reply_notification_dialog.dart';
import '../widgets/home_map_preview_section.dart';
import '../widgets/staff_analytics_panel.dart';
import '../core/staff_role_labels.dart';
import '../utils/field_recency.dart';

List<Map<String, dynamic>> _fieldDisplayMapsFromRows(
  List<Map<String, dynamic>> docs, {
  required bool showOwner,
  Map<String, String> ownerLabels = const <String, String>{},
}) {
  return docs.map((Map<String, dynamic> data) {
    final String? rowOwner = data['user_id'] as String?;
    final Map<String, dynamic> m = <String, dynamic>{
      'fieldId': data['id'] as String,
      'name': data['name'] as String? ?? 'Field',
      'address': data['address'] as String? ?? '',
      'previewImagePath': data['preview_image_path'] as String?,
      'imageCount': (data['image_count'] as num?)?.toInt() ?? 0,
    };
    if (showOwner && rowOwner != null && rowOwner.isNotEmpty) {
      m['ownerUserId'] = rowOwner;
      m['ownerLabel'] = ownerDisplayLabel(rowOwner, ownerLabels);
    }
    return m;
  }).toList();
}

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with WidgetsBindingObserver {
  /// 0=Home, 1=Diagnose, 2=My Fields, 3=More. Bottom bar has 5 items; index 2 is Scan (action).
  int _pageIndex = 0;

  late final DashboardGuideKeyHolder _guideKeys = DashboardGuideKeyHolder();

  AppState? _appState;
  final StaffNavBadgesService _badgeService = StaffNavBadgesService();
  StaffNavBadges _badges = const StaffNavBadges();

  int get _navIndex => _pageIndex <= 1 ? _pageIndex : _pageIndex + 1;

  @override
  void initState() {
    super.initState();
    DashboardGuideKeyHolder.attach(_guideKeys);
    WidgetsBinding.instance.addObserver(this);
    NavigationGuideSync.activeStep.addListener(_syncDashboardTabToGuideStep);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNickname());
    if (!currentUserJwtStaff()) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _pullCapturedPhotosFromCloud());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmFieldsCache());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CloudSyncService().syncInBackground();
    });
    // ignore: discarded_futures
    _reloadBadges();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: discarded_futures
      _reloadBadges();
    }
  }

  Future<void> _reloadBadges() async {
    final StaffNavBadges? cached = _badgeService.peekCached();
    if (cached != null && mounted) {
      setState(() => _badges = cached);
    }
    final StaffNavBadges next = await _badgeService.load();
    if (!mounted) return;
    setState(() => _badges = next);
    if (next.farmerDaRequestUnseen) {
      await showDaAccessRequestOutcomeDialogIfNeeded(context);
      if (!mounted) return;
    }
    if (next.farmerExpertReplyUnseenCount > 0) {
      await showExpertReplyNotificationsIfNeeded(context);
      if (!mounted) return;
    }
    if (next.farmerDaRequestUnseen || next.farmerExpertReplyUnseenCount > 0) {
      final StaffNavBadges refreshed = await _badgeService.load();
      if (!mounted) return;
      setState(() => _badges = refreshed);
    }
  }

  Future<void> _onCenterNavTap() async {
    if (currentUserJwtFullAdmin()) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const DaAccessRequestsScreen(),
        ),
      );
    } else if (currentUserJwtDa()) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const AdminReportsScreen(
            initialFilter: AdminReportFilter.pendingReply,
          ),
        ),
      );
    } else {
      await startFieldFirstScan(context);
    }
    if (!mounted) return;
    // ignore: discarded_futures
    _reloadBadges();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppState appState = context.read<AppState>();
    if (!identical(_appState, appState)) {
      _appState?.removeListener(_onAppStateChanged);
      _appState = appState;
      _appState!.addListener(_onAppStateChanged);
    }
  }

  Future<void> _warmFieldsCache() async {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (!await NetworkReachability.isOnline()) return;
    try {
      final List<Map<String, dynamic>> rows = await fieldsSelectForSession();
      final DatabaseService db = DatabaseService();
      await db.initialize();
      await db.cacheFieldsForUser(userId: uid, fields: rows);
      await db.importFieldBoundariesFromSupabaseRows(rows);
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  void dispose() {
    DashboardGuideKeyHolder.detach(_guideKeys);
    WidgetsBinding.instance.removeObserver(this);
    NavigationGuideSync.activeStep.removeListener(_syncDashboardTabToGuideStep);
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    final AppState appState = context.read<AppState>();

    if (appState.dashboardHomeTabRequested) {
      appState.clearDashboardHomeTabRequest();
      if (_pageIndex != 0) {
        setState(() => _pageIndex = 0);
      }
    }

    final ({String fieldId, String fieldName, double? pinLat, double? pinLng})?
        pending = appState.takePendingScanFieldNavigation();
    if (pending == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _pageIndex = 2);
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DetectionsMapScreen(
            fieldId: pending.fieldId,
            fieldName: pending.fieldName,
            initialMapCenter: pending.pinLat != null && pending.pinLng != null
                ? LatLng(pending.pinLat!, pending.pinLng!)
                : null,
            focusInitialCenter: true,
          ),
        ),
      );
    });
  }

  void _syncDashboardTabToGuideStep() {
    final int? step = NavigationGuideSync.activeStep.value;
    if (step == null || !mounted) return;
    final int newPage = switch (step) {
      0 => 0,
      1 => 1,
      2 => 0,
      3 => 2,
      _ => 3,
    };
    if (_pageIndex != newPage) {
      setState(() => _pageIndex = newPage);
    }
  }

  Future<void> _pullCapturedPhotosFromCloud() async {
    final int n = await CapturedPhotosRemoteSync().pullIntoLocalIfSignedIn();
    if (!mounted) return;
    if (n > 0) {
      context.read<AppState>().bumpCapturedPhotos();
    }
  }

  Future<void> _checkNickname() async {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final Map<String, dynamic>? row = await SupabaseClientProvider
          .instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', uid)
          .maybeSingle();
      final String? displayName = row?['display_name'] as String?;
      if (!mounted) return;
      if (displayName == null || displayName.trim().isEmpty) {
        Navigator.pushNamed(context, '/nickname-prompt');
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.mainContentGradient(context),
                  ),
                  child: IndexedStack(
                    index: _pageIndex,
                    children: <Widget>[
                      _HomeTab(
                        key: const ValueKey<int>(0),
                        guideKeys: _guideKeys,
                        badges: _badges,
                        onOpenStaffQueue: _onCenterNavTap,
                      ),
                      _DiagnoseTab(
                        key: const ValueKey<int>(1),
                        guideKeys: _guideKeys,
                      ),
                      _MyFieldsTab(
                        key: const ValueKey<int>(2),
                        guideKeys: _guideKeys,
                      ),
                      _MoreTab(
                        key: const ValueKey<int>(3),
                        guideKeys: _guideKeys,
                        onBadgesRefresh: _reloadBadges,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      key: _guideKeys.bottomNavBarKey,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _NavItem(
            key: _guideKeys.homeNavKey,
            icon: Icons.home_outlined,
            label: 'Home',
            selected: _navIndex == 0,
            onTap: () => setState(() => _pageIndex = 0),
          ),
          _NavItem(
            key: _guideKeys.diagnoseNavKey,
            icon: Icons.shield_outlined,
            label: 'Diagnose',
            selected: _navIndex == 1,
            onTap: () => setState(() => _pageIndex = 1),
          ),
          _CenterActionButton(
            key: _guideKeys.scanButtonKey,
            icon: currentUserJwtFullAdmin()
                ? Icons.how_to_reg_outlined
                : currentUserJwtDa()
                    ? Icons.rate_review_outlined
                    : Icons.photo_camera,
            badgeCount: _badges.centerBadgeCount,
            onTap: () {
              // ignore: discarded_futures
              _onCenterNavTap();
            },
          ),
          _NavItem(
            key: _guideKeys.myFieldsNavKey,
            icon: Icons.landscape_outlined,
            label: 'My Fields',
            selected: _navIndex == 3,
            onTap: () => setState(() => _pageIndex = 2),
          ),
          _NavItem(
            key: _guideKeys.moreNavKey,
            icon: Icons.grid_view_rounded,
            label: 'More',
            selected: _navIndex == 4,
            badgeCount: _badges.moreBadgeCount,
            onTap: () {
              setState(() => _pageIndex = 3);
              // ignore: discarded_futures
              _reloadBadges();
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color inactiveIcon = dark ? Colors.white : cs.onSurfaceVariant;
    final Color inactiveLabel = dark ? Colors.white : cs.onSurfaceVariant;
    final Color labelColor = selected ? cs.primary : inactiveLabel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? (dark
                            ? cs.primary.withValues(alpha: 0.22)
                            : cs.primaryContainer.withValues(alpha: 0.92))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: selected
                        ? Border.all(
                            color: cs.primary.withValues(alpha: 0.28),
                          )
                        : null,
                    boxShadow: selected && !dark
                        ? <BoxShadow>[
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: selected ? cs.primary : inactiveIcon,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: _NavBadge(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: labelColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label = count > 9 ? '9+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _CenterActionButton extends StatelessWidget {
  const _CenterActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 28,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: _NavBadge(count: badgeCount),
            ),
        ],
      ),
    );
  }
}

// --- Home tab: logo, greeting, Saved Images, Map Overview ---
class _HomeTab extends StatelessWidget {
  const _HomeTab({
    super.key,
    required this.guideKeys,
    required this.badges,
    required this.onOpenStaffQueue,
  });

  final DashboardGuideKeyHolder guideKeys;
  final StaffNavBadges badges;
  final Future<void> Function() onOpenStaffQueue;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    final String user =
        SupabaseClientProvider.instance.client.auth.currentUser?.phone ??
            'User';
    final String greeting = _greeting();
    final bool fil = appState.isFilipino;
    final bool staff = currentUserJwtStaff();
    final bool fullAdmin = currentUserJwtFullAdmin();
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                KeyedSubtree(
                  key: guideKeys.homeBrandingKey,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.pest_control,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'PINYA-PIC',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: guideKeys.homeGreetingKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        appState.isLoggedIn ? '$greeting, $user' : greeting,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: context.pineTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        staff
                            ? (fil
                                ? 'Suriin ang mga ulat ng magsasaka at tugunan ang mga kahilingan.'
                                : 'Review farmer reports and respond to access requests.')
                            : (fil
                                ? 'Bantayan ang inyong pinya at panatilihing malusog ang taniman.'
                                : 'Monitor your pineapple crops and keep them healthy.'),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.pineTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!staff)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _HomeStatHeader(
                uid: uid,
                fil: fil,
                guideKeys: guideKeys,
              ),
            ),
          ),
        if (staff)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: _StaffHomePanel(
                badges: badges,
                fullAdmin: fullAdmin,
                onOpenStaffQueue: onOpenStaffQueue,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: guideKeys.homeSavedImagesKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      fil ? 'Mga Larawang Nai-save' : 'Saved Images',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.pineTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RecentCapturesStrip(uid: uid, fil: fil),
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: guideKeys.homeMapPreviewKey,
            child: HomeMapPreviewSection(
              uid: uid,
              fil: fil,
              staffMode: staff,
            ),
          ),
        ),
      ],
    );
  }

  static String _greeting() {
    final int h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _StaffHomePanel extends StatelessWidget {
  const _StaffHomePanel({
    required this.badges,
    required this.fullAdmin,
    required this.onOpenStaffQueue,
  });

  final StaffNavBadges badges;
  final bool fullAdmin;
  final Future<void> Function() onOpenStaffQueue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Staff dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.pineTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (fullAdmin)
          _StaffHomeTile(
            icon: Icons.how_to_reg_outlined,
            title: staffAccessRequestsTitle,
            subtitle: badges.adminPendingDaRequests > 0
                ? '${badges.adminPendingDaRequests} pending review'
                : 'Review staff access applications',
            badgeCount: badges.adminPendingDaRequests,
            onTap: () {
              // ignore: discarded_futures
              onOpenStaffQueue();
            },
          ),
        if (fullAdmin) const SizedBox(height: 10),
        _StaffHomeTile(
          icon: Icons.rate_review_outlined,
          title: 'Farmer reports',
          subtitle: badges.staffPendingReports > 0
              ? '${badges.staffPendingReports} awaiting your advice'
              : 'Review positive scans and write expert advice',
          badgeCount: fullAdmin ? 0 : badges.staffPendingReports,
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => AdminReportsScreen(
                  initialFilter: fullAdmin
                      ? AdminReportFilter.all
                      : AdminReportFilter.pendingReply,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Use the center button in the bottom bar for your main queue.',
          style: TextStyle(fontSize: 13, color: context.pineTextSecondary, height: 1.35),
        ),
      ],
    );
  }
}

class _StaffHomeTile extends StatelessWidget {
  const _StaffHomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PineCard(
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: cs.primary),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: _NavBadge(count: badgeCount),
              ),
          ],
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: context.pineTextSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _HomeStatHeader extends StatelessWidget {
  const _HomeStatHeader({
    required this.uid,
    required this.fil,
    required this.guideKeys,
  });

  final String? uid;
  final bool fil;
  final DashboardGuideKeyHolder guideKeys;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fieldsRealtimeStream(),
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        final fieldsCount = snapshot.data?.length ?? 0;
        return Row(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: guideKeys.homeTotalFieldsKey,
                child: _HomeMiniStat(
                  icon: Icons.landscape_outlined,
                  label: fil ? 'Kabuuang sakahan' : 'Total fields',
                  value: '$fieldsCount',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KeyedSubtree(
                key: guideKeys.homeRegionKey,
                child: const _HomeMiniStat(
                  icon: Icons.map_outlined,
                  label: 'Region',
                  value: 'Polomolok',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeMiniStat extends StatelessWidget {
  const _HomeMiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PineCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.pineTextPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.pineTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCapturesStrip extends StatefulWidget {
  const _RecentCapturesStrip({required this.uid, required this.fil});

  final String? uid;
  final bool fil;

  @override
  State<_RecentCapturesStrip> createState() => _RecentCapturesStripState();
}

class _RecentCapturesStripState extends State<_RecentCapturesStrip> {
  final DatabaseService _db = DatabaseService();
  final ImageStorageService _images = ImageStorageService();

  @override
  void initState() {
    super.initState();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    await _db.initialize();
    // When offline, Supabase may not expose a current user. Still show local captures.
    return _db.getCapturedPhotos(limit: 12, userId: widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when new captures are saved locally.
    context.select<AppState, int>((s) => s.capturedPhotosRevision);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 108,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.pineCardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Text(
              widget.fil
                  ? 'Wala pang nai-save na larawan.'
                  : 'No saved captures yet.',
              style: TextStyle(color: context.pineTextSecondary),
            ),
          );
        }
        return SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final row = rows[i];
              final int id = (row['id'] as num?)?.toInt() ?? -1;
              final String? localPath = row['local_image_path'] as String?;
              final String? remoteUrl = row['remote_image_url'] as String?;
              final String fieldName =
                  (row['field_name'] as String?)?.trim() ?? '';
              final int count = (row['count'] as num?)?.toInt() ?? 0;
              final int confidence =
                  (row['confidence'] as num?)?.toInt() ?? 0;
              final String? createdAt = row['created_at'] as String?;
              final bool canExpand = id >= 0 &&
                  ((remoteUrl != null && remoteUrl.trim().isNotEmpty) ||
                      (localPath != null &&
                          localPath.isNotEmpty &&
                          localPath != DatabaseService.remoteOnlyLocalPath));
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: !canExpand
                    ? null
                    : () async {
                        File? file;
                        if (localPath != null &&
                            localPath != DatabaseService.remoteOnlyLocalPath) {
                          file = await _images.getImageFile(localPath);
                        }
                        if (!context.mounted) return;
                        if (file == null &&
                            (remoteUrl == null || remoteUrl.isEmpty)) {
                          return;
                        }
                        await showDialog<void>(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return Dialog(
                              insetPadding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  children: <Widget>[
                                    AspectRatio(
                                      aspectRatio: 1,
                                      child: InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: file != null
                                            ? Image.file(
                                                file,
                                                fit: BoxFit.cover,
                                              )
                                            : LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  final int cacheW = (constraints
                                                              .maxWidth *
                                                          MediaQuery
                                                              .devicePixelRatioOf(
                                                                  context))
                                                      .round()
                                                      .clamp(96, 4096);
                                                  return Image.network(
                                                    maybeSupabaseRenderUrl(
                                                      remoteUrl!,
                                                      width: cacheW,
                                                    ),
                                                    fit: BoxFit.cover,
                                                    cacheWidth: cacheW,
                                                    loadingBuilder: (context,
                                                        child, progress) {
                                                      if (progress == null) {
                                                        return child;
                                                      }
                                                      return Container(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        child: const Center(
                                                          child: SizedBox(
                                                            width: 22,
                                                            height: 22,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder:
                                                        (BuildContext ctx, _,
                                                            __) {
                                                      return Container(
                                                        color: Theme.of(ctx)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        child: Icon(
                                                          Icons.image_outlined,
                                                          color: ctx
                                                              .pineTextSecondary,
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: IconButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black
                                              .withValues(alpha: 0.45),
                                          foregroundColor:
                                              Theme.of(dialogContext)
                                                  .colorScheme
                                                  .onPrimary,
                                        ),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ),
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 12,
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: () {
                                                Navigator.of(dialogContext)
                                                    .pop();
                                                Navigator.push<void>(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        CapturedPhotoDetailScreen(
                                                      capturedPhotoId: id,
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.black
                                                    .withValues(alpha: 0.55),
                                                foregroundColor:
                                                    Theme.of(dialogContext)
                                                        .colorScheme
                                                        .onPrimary,
                                              ),
                                              child: Text(
                                                widget.fil ? 'Buksan' : 'Open',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                child: SizedBox(
                  width: 128,
                  child: PineCard(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        localPath == null
                            ? const Center(
                                child: Icon(Icons.image_not_supported),
                              )
                            : captureThumbnail(
                                localImagePath: localPath,
                                remoteImageUrl: remoteUrl,
                                images: _images,
                                displayLogicalWidth: 128,
                              ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  fieldName.isEmpty
                                      ? (widget.fil ? 'Field' : 'Field')
                                      : fieldName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  widget.fil
                                      ? '$count · $confidence%'
                                      : '$count · $confidence%',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  formatRelativeIso(createdAt, fil: widget.fil),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            },
          ),
        );
      },
    );
  }
}

// --- Diagnose tab: real stats from detections, line chart, My Fields ---
class _DiagnoseTab extends StatelessWidget {
  const _DiagnoseTab({
    super.key,
    required this.guideKeys,
  });

  final DashboardGuideKeyHolder guideKeys;

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) {
      return Center(
        child: Text(
          'Sign in to see diagnose data',
          style: TextStyle(color: context.pineTextPrimary),
        ),
      );
    }
    if (currentUserJwtStaff()) {
      return StaffAnalyticsTab(fil: fil);
    }
    final DatabaseService localDb = DatabaseService();

    Future<DashboardStats> loadLocalStats() async {
      await localDb.initialize();
      final List<Map<String, dynamic>> rows =
          await localDb.getCapturedPhotos(limit: 500, userId: uid);
      return DashboardStatsCalculator.fromCapturedPhotos(rows);
    }

    Widget buildDiagnose(DashboardStats stats) {
      final String fieldsSubtitle = fil
          ? 'Mga imahe na nakuha sa ${stats.fieldCount} '
              '${stats.fieldCount == 1 ? 'field' : 'mga field'}'
          : 'Images captured in ${stats.fieldCount} '
              '${stats.fieldCount == 1 ? 'field' : 'fields'}';
      final String infestationSubtitle = fil
          ? 'ng iyong mga field na may mealybugs'
          : 'of your fields infested with mealybugs';

      return CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: guideKeys.diagnoseSearchDiseasesKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'DIAGNOSE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.pineTextPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PineCard(
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const DiseaseInfoScreen()),
                        );
                      },
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.search,
                              color: context.pineTextSecondary, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            'Search for Diseases',
                            style: TextStyle(
                              fontSize: 15,
                              color: context.pineTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: guideKeys.diagnoseWeekStatsKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      fil ? 'Ngayong Linggo' : 'This Week, You Have',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.pineTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PineCard(
                      padding: const EdgeInsets.all(14),
                      borderColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          Icon(Icons.photo_library_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              fil
                                  ? 'Kabuuang images na nakuhanan ngayong linggo: ${stats.imageCount}'
                                  : 'Overall images captured this week: ${stats.imageCount}',
                              style: TextStyle(
                                color: context.pineTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _StatCircle(
                            value: '${stats.imageCount}',
                            subtitle: fieldsSubtitle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCircle(
                            value: '${stats.infestationRate}%',
                            subtitle: infestationSubtitle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: guideKeys.diagnosePestsChartKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      fil ? 'Kabuuang pests' : 'Total pests count',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.pineTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PestsChartFromData(
                      fil: fil,
                      dailyCounts: stats.dailyCounts,
                      dates: stats.last7Days,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: guideKeys.diagnoseMyFieldsStripKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      fil ? 'Ang Aking mga Bukid' : 'My Fields',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.pineTextPrimary,
                      ),
                    ),
                  ),
                  _FieldsHorizontalList(uid: uid),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    }

    final int photosRevision = context.watch<AppState>().capturedPhotosRevision;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: detectionsRealtimeStream(),
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        return FutureBuilder<DashboardStats>(
          key: ValueKey<int>(photosRevision),
          future: loadLocalStats(),
          builder: (BuildContext context, AsyncSnapshot<DashboardStats> localSnap) {
            if (!localSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final DashboardStats localStats = localSnap.data!;
            if (snapshot.hasError) {
              return buildDiagnose(localStats);
            }
            final List<Map<String, dynamic>> docs =
                snapshot.data ?? const <Map<String, dynamic>>[];
            if (docs.isEmpty) {
              return buildDiagnose(localStats);
            }
            final DashboardStats remoteStats =
                DashboardStatsCalculator.fromDetectionMaps(docs);
            return buildDiagnose(
              DashboardStatsCalculator.farmerWeeklyStats(
                local: localStats,
                remote: remoteStats,
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCircle extends StatelessWidget {
  const _StatCircle({required this.value, required this.subtitle});

  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PineCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: context.pineTextPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PestsChartFromData extends StatelessWidget {
  const _PestsChartFromData({
    required this.fil,
    required this.dailyCounts,
    required this.dates,
  });

  final bool fil;
  final List<int> dailyCounts;
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    final bool hasData = dailyCounts.any((int c) => c > 0);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PineCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 168,
        child: hasData
          ? RepaintBoundary(
              child: CustomPaint(
                painter: _RealLineChartPainter(
                  dailyCounts: dailyCounts,
                  dates: dates,
                  fil: fil,
                  dark: dark,
                  labelColor: context.pineTextPrimary,
                  accentColor: Theme.of(context).colorScheme.primary,
                  lightGridLineColor: cs.outline.withValues(alpha: 0.22),
                  lightTickLabelColor: cs.onSurfaceVariant,
                  lightPeakGuideColor: cs.outlineVariant,
                  chartDotInnerColor:
                      dark ? cs.surfaceContainerHighest : cs.surface,
                  peakMarkerRingColor: cs.surface,
                ),
                size: Size.infinite,
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.show_chart,
                    size: 48,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fil ? 'Wala pang data' : 'No data yet',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fil
                        ? 'Simulan ang scan para makita ang trends'
                        : 'Start detecting to see trends',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class _RealLineChartPainter extends CustomPainter {
  _RealLineChartPainter({
    required this.dailyCounts,
    required this.dates,
    required this.fil,
    required this.dark,
    required this.labelColor,
    required this.accentColor,
    required this.lightGridLineColor,
    required this.lightTickLabelColor,
    required this.lightPeakGuideColor,
    required this.chartDotInnerColor,
    required this.peakMarkerRingColor,
  });

  final List<int> dailyCounts;
  final List<DateTime> dates;
  final bool fil;
  final bool dark;
  final Color labelColor;
  final Color accentColor;
  final Color lightGridLineColor;
  final Color lightTickLabelColor;
  final Color lightPeakGuideColor;
  final Color chartDotInnerColor;
  final Color peakMarkerRingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0 || dailyCounts.isEmpty) return;

    final int maxY = dailyCounts.fold<int>(0, (int a, int b) => a > b ? a : b);
    final double rangeY = maxY > 0 ? maxY.toDouble() : 1.0;

    const double padLeft = 44;
    const double padRight = 10;
    const double padTop = 14;
    const double padBottom = 34;

    final double chartW = w - padLeft - padRight;
    final double chartH = h - padTop - padBottom;
    final double baseY = padTop + chartH;

    final int count = dailyCounts.length;
    final int pointCount = dates.length < count ? dates.length : count;
    if (pointCount < 2) return;

    final double xStep = chartW / (pointCount - 1);

    final List<Offset> points = <Offset>[];
    for (int i = 0; i < pointCount; i++) {
      final double x = padLeft + i * xStep;
      final double y =
          padTop + chartH - (dailyCounts[i].toDouble() / rangeY) * chartH;
      points.add(Offset(x, y));
    }

    // Grid + y labels
    const int yTicks = 4;
    for (int i = 0; i <= yTicks; i++) {
      final double t = i / yTicks;
      final double yValue = rangeY * t;
      final double y = padTop + chartH - t * chartH;

      final Paint gridPaint = Paint()
        ..color =
            dark ? Colors.white.withValues(alpha: 0.08) : lightGridLineColor
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
      );

      final String label = yValue == 0 ? '0' : yValue.round().toString();
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 11,
            color: dark
                ? Colors.white.withValues(alpha: 0.45)
                : lightTickLabelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(padLeft - tp.width - 6, y - tp.height / 2));
    }

    // X labels
    String dayLabel(DateTime d) {
      // Monday=1 ... Sunday=7
      const List<String> en = <String>[
        '',
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun'
      ];
      const List<String> filLabels = <String>[
        '',
        'Lun',
        'Mar',
        'Miy',
        'Hul',
        'Biy',
        'Sab',
        'Lin'
      ];
      final int wday = d.weekday;
      return fil ? filLabels[wday] : en[wday];
    }

    for (int i = 0; i < pointCount; i++) {
      final DateTime d = dates[i];
      final String label = dayLabel(d);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 11,
            color: dark
                ? Colors.white.withValues(alpha: 0.55)
                : lightTickLabelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double x = points[i].dx;
      tp.paint(canvas, Offset(x - tp.width / 2, baseY + 6));
    }

    // Find peak point to highlight (latest max)
    int peakIndex = 0;
    for (int i = 1; i < pointCount; i++) {
      if (dailyCounts[i] >= dailyCounts[peakIndex]) peakIndex = i;
    }
    final Offset peakPoint = points[peakIndex];

    // Vertical peak guide
    final Paint peakGuidePaint = Paint()
      ..color =
          dark ? Colors.white.withValues(alpha: 0.12) : lightPeakGuideColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(peakPoint.dx, padTop),
      Offset(peakPoint.dx, baseY),
      peakGuidePaint,
    );

    // Smooth monotonic line + area (no baseline overshoot)
    final Path linePath = buildMonotonicSmoothLinePath(points);
    final Path areaPath = buildMonotonicSmoothAreaPath(points, baseY);

    final Paint areaPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: <Color>[
          accentColor.withValues(alpha: 0.18),
          accentColor.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(areaPath, areaPaint);

    // Glow + stroke
    final Paint glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, glowPaint);

    final Paint strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    // Dots for each day
    for (int i = 0; i < pointCount; i++) {
      final Offset p = points[i];
      final bool isPeak = i == peakIndex;
      if (isPeak) continue;

      final Paint outer = Paint()
        ..color = accentColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, 5.5, outer);

      final Paint inner = Paint()
        ..color = chartDotInnerColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p, 3, inner);

      final Paint ring = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(p, 3.2, ring);
    }

    // Peak dot
    final Paint peakFill = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(peakPoint, 8, peakFill);
    final Paint peakRing = Paint()
      ..color = peakMarkerRingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(peakPoint, 8, peakRing);

    final TextPainter peakValuePainter = TextPainter(
      text: TextSpan(
        text: dailyCounts[peakIndex].toString(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: labelColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    peakValuePainter.paint(
      canvas,
      Offset(peakPoint.dx - peakValuePainter.width / 2, peakPoint.dy - 7),
    );
  }

  @override
  bool shouldRepaint(covariant _RealLineChartPainter oldDelegate) =>
      oldDelegate.dailyCounts != dailyCounts ||
      oldDelegate.dates != dates ||
      oldDelegate.fil != fil ||
      oldDelegate.dark != dark ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.lightGridLineColor != lightGridLineColor ||
      oldDelegate.lightTickLabelColor != lightTickLabelColor ||
      oldDelegate.lightPeakGuideColor != lightPeakGuideColor ||
      oldDelegate.chartDotInnerColor != chartDotInnerColor ||
      oldDelegate.peakMarkerRingColor != peakMarkerRingColor;
}

// --- My Fields tab: tabs (My Fields | Reminders), grid + Add New Field ---
class _MyFieldsTab extends StatelessWidget {
  const _MyFieldsTab({
    super.key,
    required this.guideKeys,
  });

  final DashboardGuideKeyHolder guideKeys;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          KeyedSubtree(
            key: guideKeys.myFieldsHeaderTabsKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: <Widget>[
                      Text(
                        'MY FIELDS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.pineTextPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (currentUserJwtStaff()) ...<Widget>[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            currentUserJwtDa()
                                ? '$staffRoleSingular • all farms'
                                : 'Admin • all farms',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.pineMutedFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: context.pineCardSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.5),
                            width: 1.5),
                      ),
                      labelColor: context.pineTextPrimary,
                      unselectedLabelColor: context.pineTextSecondary,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      tabs: const <Tab>[
                        Tab(text: 'My Fields'),
                        Tab(text: 'Reminders'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: KeyedSubtree(
              key: guideKeys.myFieldsGridKey,
              child: const TabBarView(
                children: <Widget>[_MyFieldsGrid(), _RemindersPlaceholder()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyFieldsGrid extends StatelessWidget {
  const _MyFieldsGrid();

  static final DatabaseService _db = DatabaseService();

  static Future<List<Map<String, dynamic>>> _loadCached(String uid) async {
    await _db.initialize();
    final bool jwtStaff = currentUserJwtStaff();
    final List<Map<String, dynamic>> docs = jwtStaff
        ? await _db.getCachedFieldsAll(limit: 2000)
        : await _db.getCachedFields(userId: uid);
    return mergeFieldDocsWithLocalCaptureCounts(
      db: _db,
      userId: uid,
      fieldRows: docs,
      applyLocalCaptureCounts: !jwtStaff,
    );
  }

  static Widget _buildGridFromDocsWithRecency(
    BuildContext context,
    List<Map<String, dynamic>> docs,
    int recencyRev,
  ) {
    return FutureBuilder<Map<String, int>>(
      key: ValueKey<int>(recencyRev),
      future: loadFieldRecencyMillis(),
      builder: (BuildContext context, AsyncSnapshot<Map<String, int>> snap) {
        final Map<String, int> recency = snap.data ?? const <String, int>{};
        final List<Map<String, dynamic>> sorted =
            sortFieldDocsByRecency(docs, recency);
        return _buildGridFromDocs(context, sorted);
      },
    );
  }

  static Widget _buildGridFromDocs(
    BuildContext context,
    List<Map<String, dynamic>> docs,
  ) {
    final bool showOwner = currentUserJwtStaff();
    if (docs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const _EmptyFieldsMessage(),
          const SizedBox(height: 16),
          _AddFieldCard(onTap: () => _openAddField(context)),
        ],
      );
    }
    if (!showOwner) {
      final List<Map<String, dynamic>> fields =
          _fieldDisplayMapsFromRows(docs, showOwner: false);
      return _buildGridViewForFields(context, fields);
    }
    final List<String> ownerIds = fieldRowOwnerIdsForProfileFetch(docs);
    final String ownerKey = ownerIds.join('|');
    final String docKey =
        docs.map((Map<String, dynamic> e) => e['id']).join(',');
    return FutureBuilder<Map<String, String>>(
      key: ValueKey<String>('own|$ownerKey|$docKey'),
      future: fetchProfileOwnerLabelsForUserIds(ownerIds),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, String>> labelSnap) {
        final Map<String, String> labels =
            labelSnap.data ?? const <String, String>{};
        final List<Map<String, dynamic>> fields = _fieldDisplayMapsFromRows(
            docs,
            showOwner: true,
            ownerLabels: labels);
        return _buildGridViewForFields(context, fields);
      },
    );
  }

  static Widget _buildGridViewForFields(
    BuildContext context,
    List<Map<String, dynamic>> fields,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FieldPreviewImage.precacheNetworkUrls(
        context,
        fields.map((Map<String, dynamic> f) => f['previewImagePath'] as String?),
        logicalWidth: 220,
      );
    });
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        // Slightly taller cells so title / owner / address + photo line fit
        // under large text scale without clipping the footer.
        childAspectRatio: 0.72,
      ),
      itemCount: fields.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == fields.length) {
          return _AddFieldCard(onTap: () => _openAddField(context));
        }
        return _FieldGridCard(
          field: fields[index],
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FieldDetailScreen(
                  fieldId: fields[index]['fieldId'] as String,
                  fieldName: fields[index]['name'] as String,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _EmptyFieldsMessage(),
      );
    }
    final int capturesRev =
        context.select<AppState, int>((AppState s) => s.capturedPhotosRevision);
    final int recencyRev =
        context.select<AppState, int>((AppState s) => s.fieldRecencyRevision);
    return RefreshIndicator(
      onRefresh: () async {
        // Best-effort refresh: fetch once and update cache.
        if (!await NetworkReachability.isOnline()) return;
        try {
          final List<Map<String, dynamic>> rows =
              await fieldsSelectForSession();
          await _db.initialize();
          await _db.cacheFieldsForUser(userId: uid, fields: rows);
        } catch (_) {}
      },
      child: FutureBuilder<bool>(
        future: NetworkReachability.isOnline(),
        builder: (context, onlineSnap) {
          final bool online = onlineSnap.data == true;
          final bool jwtStaff = currentUserJwtStaff();
          if (!online) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey<int>(capturesRev),
              future: _loadCached(uid),
              builder: (context, snap) {
                final docs = snap.data ?? const <Map<String, dynamic>>[];
                return _buildGridFromDocsWithRecency(context, docs, recencyRev);
              },
            );
          }
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: fieldsRealtimeStream(),
            builder: (BuildContext context,
                AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
              final List<Map<String, dynamic>> docs =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              if (docs.isNotEmpty) {
                // ignore: discarded_futures
                _db.initialize().then((_) {
                  // ignore: discarded_futures
                  _db.cacheFieldsForUser(userId: uid, fields: docs);
                });
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return FutureBuilder<List<Map<String, dynamic>>>(
                  key: ValueKey<int>(capturesRev),
                  future: _loadCached(uid),
                  builder: (context, snap) {
                    final cached = snap.data ?? const <Map<String, dynamic>>[];
                    return _buildGridFromDocsWithRecency(
                      context,
                      cached,
                      recencyRev,
                    );
                  },
                );
              }
              final String mergeKey =
                  '$capturesRev|$recencyRev|${docs.length}|${docs.map((Map<String, dynamic> e) => e['id']).join(',')}';
              return FutureBuilder<List<Map<String, dynamic>>>(
                key: ValueKey<String>(mergeKey),
                future: mergeFieldDocsWithLocalCaptureCounts(
                  db: _db,
                  userId: uid,
                  fieldRows: docs,
                  applyLocalCaptureCounts: !jwtStaff,
                ),
                builder: (context, mergeSnap) {
                  final List<Map<String, dynamic>> merged =
                      mergeSnap.data ?? docs;
                  return _buildGridFromDocsWithRecency(
                    context,
                    merged,
                    recencyRev,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static void _openAddField(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const FarmDetailsScreen()),
    );
  }
}

/// Shown on top of the field thumbnail so the count stays visible even when
/// the lower metadata block is clipped (tight grid cells, large text scale).
class _FieldPhotoCountPill extends StatelessWidget {
  const _FieldPhotoCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final String imageLabel =
        count == 1 ? '1 image in this field' : '$count images in this field';
    return Semantics(
      label: imageLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.photo_library_outlined,
                size: 13,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldGridCard extends StatelessWidget {
  const _FieldGridCard({required this.field, required this.onTap});

  final Map<String, dynamic> field;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? ownerLine = field['ownerLabel'] as String?;
    return PineCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fill(
                  child: FieldPreviewImage(
                    previewPath: field['previewImagePath'] as String?,
                    fallbackLogicalWidth: 220,
                    placeholderIconSize: 48,
                  ),
                ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: _FieldPhotoCountPill(
                    count: (field['imageCount'] as num?)?.toInt() ?? 0,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  field['name'] as String,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.pineTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ownerLine != null && ownerLine.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Owner: $ownerLine',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.pineTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if ((field['address'] as String).isNotEmpty) ...[
                  const SizedBox(height: 2),
                    Text(
                      'Address: ${field['address']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.pineTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _AddFieldCard extends StatelessWidget {
  const _AddFieldCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PineCard(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.add,
                size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Add New Field',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemindersPlaceholder extends StatelessWidget {
  const _RemindersPlaceholder();

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;
    final bool staff = currentUserJwtStaff();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.notifications_none,
                size: 56, color: context.pineTextSecondary),
            const SizedBox(height: 16),
            Text(
              'You Have No Reminders',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.pineTextPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              staff
                  ? (fil
                      ? 'Dito lalabas ang mga paalala sa mga ulat ng magsasaka at kahilingan sa access.'
                      : 'Reminders for farmer reports and access requests will appear here.')
                  : (fil
                      ? 'Dito lalabas ang mga paalala sa field checks, susunod na pagkuha ng larawan, at mga follow-up na dapat gawin.'
                      : 'This page shows reminders for field checks, next capture schedule, and pending follow-up surveys.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.pineTextSecondary),
            ),
            if (!staff) ...<Widget>[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  // ignore: discarded_futures
                  startFieldFirstScan(context);
                },
                icon: const Icon(Icons.add_photo_alternate, size: 20),
                label: const Text('Add Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- More tab: profile card, General Info, Common Diseases, Explore by parts ---
class _MoreTab extends StatelessWidget {
  const _MoreTab({
    super.key,
    required this.guideKeys,
    required this.onBadgesRefresh,
  });

  final DashboardGuideKeyHolder guideKeys;
  final Future<void> Function() onBadgesRefresh;

  @override
  Widget build(BuildContext context) {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    return FutureBuilder<Map<String, dynamic>>(
      future: AssetManifestCache.ensure(context),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic> manifest =
            snapshot.data ?? const <String, dynamic>{};
        String? imageForTitle(String title) =>
            moreTabImageForTitle(manifest, title);
        return CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: <Widget>[
                    Text(
                      'MORE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.pineTextPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: guideKeys.moreProfileKey,
                child: uid == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: _ProfileCard(
                          username: 'User',
                          email: '',
                          photoUrl: null,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: SupabaseClientProvider.instance.client
                              .from('profiles')
                              .stream(primaryKey: const <String>['id']).eq(
                                  'id', uid),
                          builder: (BuildContext context,
                              AsyncSnapshot<List<Map<String, dynamic>>>
                                  snapshot) {
                            final Map<String, dynamic>? data =
                                snapshot.data != null &&
                                        snapshot.data!.isNotEmpty
                                    ? snapshot.data!.first
                                    : null;
                            final User? authUser = SupabaseClientProvider
                                .instance.client.auth.currentUser;
                            final String username =
                                data?['display_name'] as String? ??
                                    authUser?.phone ??
                                    'User';
                            final String email =
                                data?['email'] as String? ?? '';
                            final String? photoUrl =
                                data?['photo_url'] as String?;
                            return _ProfileCard(
                              username: username,
                              email: email,
                              photoUrl: photoUrl,
                            );
                          },
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: DaAccessRequestCard(
                onRequestStatusSeen: () {
                  // ignore: discarded_futures
                  onBadgesRefresh();
                },
              ),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: guideKeys.moreGeneralInfoKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        'General Info',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.pineTextPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: <Widget>[
                          _InfoCard(
                            title: 'How to identify pineapples',
                            imageAsset:
                                imageForTitle('How to identify pineapples'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => EducationalContentScreen
                                      .identifyingPineapples()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _InfoCard(
                            title: 'Difference between species of Pineapples',
                            imageAsset: imageForTitle(
                                'Difference between species of Pineapples'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => EducationalContentScreen
                                      .speciesDifferences()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _InfoCard(
                            title: 'Why pineapples look different',
                            imageAsset:
                                imageForTitle('Why pineapples look different'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      EducationalContentScreen.whyDifferent()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: guideKeys.moreCommonDiseasesKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        'Common Diseases',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.pineTextPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: <Widget>[
                          _DiseaseCard(
                            title: 'Heart Rot',
                            imageAsset: imageForTitle('Heart Rot'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DiseaseDetailScreen.heartRot()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _DiseaseCard(
                            title: 'Fusariosis',
                            imageAsset: imageForTitle('Fusariosis'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DiseaseDetailScreen.fusariosis()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _DiseaseCard(
                            title: 'Anthracnose',
                            imageAsset: imageForTitle('Anthracnose'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DiseaseDetailScreen.anthracnose()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: guideKeys.moreExploreByPartsKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        'Explore Diseases by parts',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.pineTextPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.1,
                        children: <Widget>[
                          _ExploreCard(
                            title: 'Disease of the whole Plant',
                            imageAsset:
                                imageForTitle('Disease of the whole Plant'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DiseaseByCategoryScreen.wholePlant()),
                            ),
                          ),
                          _ExploreCard(
                            title: 'Disease by Fruit',
                            imageAsset: imageForTitle('Disease by Fruit'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DiseaseByCategoryScreen.fruit()),
                            ),
                          ),
                          _ExploreCard(
                            title: 'Disease caused by Pests',
                            imageAsset:
                                imageForTitle('Disease caused by Pests'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DiseaseByCategoryScreen.pests()),
                            ),
                          ),
                          _ExploreCard(
                            title: 'Disease by Leaves',
                            imageAsset: imageForTitle('Disease by Leaves'),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DiseaseByCategoryScreen.leaves()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.username,
    required this.email,
    this.photoUrl,
  });

  final String username;
  final String email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            context.pineProfileCream,
            Color.lerp(
                context.pineProfileCream, context.pineCardSurface, 0.55)!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.taupe.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.olive.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: CircleAvatar(
              radius: 35,
              backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                  ? NetworkImage(photoUrl!)
                  : null,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              child: photoUrl == null || photoUrl!.isEmpty
                  ? Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 28,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.pineTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.pineTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.settings,
                  color: Theme.of(context).colorScheme.primary),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.onTap,
    this.imageAsset,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: _MoreTileCard(
        title: title,
        imageAsset: imageAsset,
        fallbackIcon: Icons.auto_stories,
        onTap: onTap,
      ),
    );
  }
}

class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({
    required this.title,
    required this.onTap,
    this.imageAsset,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: _MoreTileCard(
        title: title,
        imageAsset: imageAsset,
        fallbackIcon: Icons.medical_services,
        onTap: onTap,
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.title,
    required this.onTap,
    this.imageAsset,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return _MoreTileCard(
      title: title,
      imageAsset: imageAsset,
      fallbackIcon: Icons.explore,
      onTap: onTap,
    );
  }
}

class _MoreTileCard extends StatelessWidget {
  const _MoreTileCard({
    required this.title,
    required this.onTap,
    required this.fallbackIcon,
    this.imageAsset,
  });

  final String title;
  final VoidCallback onTap;
  final IconData fallbackIcon;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    Widget badge() {
      final Widget child = imageAsset != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                imageAsset!,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  color: cs.primary,
                  size: 22,
                ),
              ),
            )
          : Icon(
              fallbackIcon,
              color: cs.primary,
              size: 22,
            );

      return Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.18),
          ),
        ),
        child: child,
      );
    }

    return PineCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      borderRadius: 12,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          badge(),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.12,
                fontWeight: FontWeight.w700,
                color: context.pineTextPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Shared: horizontal field list and empty message ---
class _FieldsHorizontalList extends StatelessWidget {
  const _FieldsHorizontalList({required this.uid});

  final String uid;
  static final DatabaseService _db = DatabaseService();

  static Future<List<Map<String, dynamic>>> _loadCached(String uid) async {
    await _db.initialize();
    final bool jwtStaff = currentUserJwtStaff();
    final List<Map<String, dynamic>> docs = jwtStaff
        ? await _db.getCachedFieldsAll(limit: 200)
        : await _db.getCachedFields(userId: uid, limit: 50);
    return mergeFieldDocsWithLocalCaptureCounts(
      db: _db,
      userId: uid,
      fieldRows: docs,
      applyLocalCaptureCounts: !jwtStaff,
    );
  }

  static Widget _buildFromDocsWithRecency(
    BuildContext context,
    List<Map<String, dynamic>> docs,
    int recencyRev,
  ) {
    return FutureBuilder<Map<String, int>>(
      key: ValueKey<int>(recencyRev),
      future: loadFieldRecencyMillis(),
      builder: (BuildContext context, AsyncSnapshot<Map<String, int>> snap) {
        final Map<String, int> recency = snap.data ?? const <String, int>{};
        final List<Map<String, dynamic>> sorted =
            sortFieldDocsByRecency(docs, recency);
        return _buildFromDocs(context, sorted);
      },
    );
  }

  static Widget _buildFromDocs(
    BuildContext context,
    List<Map<String, dynamic>> docs,
  ) {
    final bool showOwner = currentUserJwtStaff();
    if (docs.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: _EmptyFieldsMessage()),
      );
    }
    if (!showOwner) {
      final List<Map<String, dynamic>> fields =
          _fieldDisplayMapsFromRows(docs, showOwner: false);
      return _buildHorizontalListForFields(context, fields);
    }
    final List<String> ownerIds = fieldRowOwnerIdsForProfileFetch(docs);
    final String ownerKey = ownerIds.join('|');
    final String docKey =
        docs.map((Map<String, dynamic> e) => e['id']).join(',');
    return FutureBuilder<Map<String, String>>(
      key: ValueKey<String>('ownh|$ownerKey|$docKey'),
      future: fetchProfileOwnerLabelsForUserIds(ownerIds),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, String>> labelSnap) {
        final Map<String, String> labels =
            labelSnap.data ?? const <String, String>{};
        final List<Map<String, dynamic>> fields = _fieldDisplayMapsFromRows(
            docs,
            showOwner: true,
            ownerLabels: labels);
        return _buildHorizontalListForFields(context, fields);
      },
    );
  }

  static Widget _buildHorizontalListForFields(
    BuildContext context,
    List<Map<String, dynamic>> fields,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FieldPreviewImage.precacheNetworkUrls(
        context,
        fields.map((Map<String, dynamic> f) => f['previewImagePath'] as String?),
      );
    });
    return SizedBox(
      height: 196,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: fields.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> field = fields[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _FieldHorizontalCard(
              field: field,
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FieldDetailScreen(
                      fieldId: field['fieldId'] as String,
                      fieldName: field['name'] as String,
                    ),
                  ),
                );
              },
              onEdit: () {
                final String? fieldId = field['fieldId'] as String?;
                if (fieldId == null) return;
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => EditFieldScreen(fieldId: fieldId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int capturesRev =
        context.select<AppState, int>((AppState s) => s.capturedPhotosRevision);
    final int recencyRev =
        context.select<AppState, int>((AppState s) => s.fieldRecencyRevision);
    final bool jwtStaff = currentUserJwtStaff();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: fieldsRealtimeStream(),
      builder: (BuildContext context,
          AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey<int>(capturesRev),
            future: _loadCached(uid),
            builder: (context, snap) {
              final docs = snap.data ?? const <Map<String, dynamic>>[];
              return _buildFromDocsWithRecency(context, docs, recencyRev);
            },
          );
        }
        final List<Map<String, dynamic>> docs = snapshot.data!;
        if (docs.isEmpty) {
          return const SizedBox(
            height: 140,
            child: Center(child: _EmptyFieldsMessage()),
          );
        }
        // ignore: discarded_futures
        _db.initialize().then((_) {
          // ignore: discarded_futures
          _db.cacheFieldsForUser(userId: uid, fields: docs);
        });
        final String mergeKey =
            '$capturesRev|$recencyRev|${docs.length}|${docs.map((Map<String, dynamic> e) => e['id']).join(',')}';
        return FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey<String>(mergeKey),
          future: mergeFieldDocsWithLocalCaptureCounts(
            db: _db,
            userId: uid,
            fieldRows: docs,
            applyLocalCaptureCounts: !jwtStaff,
          ),
          builder: (context, mergeSnap) {
            final List<Map<String, dynamic>> merged = mergeSnap.data ?? docs;
            return _buildFromDocsWithRecency(context, merged, recencyRev);
          },
        );
      },
    );
  }
}

class _FieldHorizontalCard extends StatelessWidget {
  const _FieldHorizontalCard({
    required this.field,
    required this.onTap,
    required this.onEdit,
  });

  final Map<String, dynamic> field;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String? ownerLine = field['ownerLabel'] as String?;
    return SizedBox(
      width: 160,
      child: PineCard(
        padding: EdgeInsets.zero,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Positioned.fill(
                            child: FieldPreviewImage(
                              previewPath:
                                  field['previewImagePath'] as String?,
                              fallbackLogicalWidth: 160,
                              placeholderIconSize: 40,
                            ),
                          ),
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: _FieldPhotoCountPill(
                              count:
                                  (field['imageCount'] as num?)?.toInt() ?? 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            field['name'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.pineTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ownerLine != null &&
                              ownerLine.isNotEmpty) ...<Widget>[
                            Text(
                              'Owner: $ownerLine',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.pineTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if ((field['address'] as String).isNotEmpty)
                            Text(
                              field['address'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.pineTextSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit field',
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFieldsMessage extends StatelessWidget {
  const _EmptyFieldsMessage();

  @override
  Widget build(BuildContext context) {
    return PineCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.landscape_outlined,
                size: 48, color: context.pineTextSecondary),
            const SizedBox(height: 12),
            Text(
              'No fields yet',
              style: TextStyle(
                fontSize: 16,
                color: context.pineTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a field from My Fields or open map to pin a location.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.pineTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
