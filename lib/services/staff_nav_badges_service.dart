/// Badge counts for staff navigation and DA request notifications.
library;

import '../core/admin_session.dart';
import '../core/da_request_notification_prefs.dart';
import '../services/admin_reports_service.dart';
import '../services/da_access_request_service.dart';
import '../services/farmer_expert_reply_notifications_service.dart';

class StaffNavBadges {
  const StaffNavBadges({
    this.adminPendingDaRequests = 0,
    this.staffPendingReports = 0,
    this.farmerDaRequestUnseen = false,
    this.farmerExpertReplyUnseenCount = 0,
  });

  final int adminPendingDaRequests;
  final int staffPendingReports;
  final bool farmerDaRequestUnseen;
  final int farmerExpertReplyUnseenCount;

  int get centerBadgeCount {
    if (currentUserJwtFullAdmin()) return adminPendingDaRequests;
    if (currentUserJwtDa()) return staffPendingReports;
    return 0;
  }

  bool get showCenterBadge => centerBadgeCount > 0;

  int get moreBadgeCount {
    int count = farmerExpertReplyUnseenCount;
    if (farmerDaRequestUnseen) count += 1;
    return count;
  }

  bool get showMoreBadge => moreBadgeCount > 0;
}

class StaffNavBadgesService {
  StaffNavBadgesService({
    DaAccessRequestService? daService,
    AdminReportsService? reportsService,
    FarmerExpertReplyNotificationsService? farmerReplyService,
  })  : _daService = daService ?? DaAccessRequestService(),
        _reportsService = reportsService ?? AdminReportsService(),
        _farmerReplyService =
            farmerReplyService ?? FarmerExpertReplyNotificationsService();

  final DaAccessRequestService _daService;
  final AdminReportsService _reportsService;
  final FarmerExpertReplyNotificationsService _farmerReplyService;

  StaffNavBadges? _cached;

  /// Last loaded badge snapshot for stale-while-revalidate UI.
  StaffNavBadges? peekCached() => _cached;

  Future<StaffNavBadges> load() async {
    int adminPending = 0;
    int staffPending = 0;
    bool farmerUnseen = false;
    int farmerReplyUnseen = 0;

    if (currentUserJwtFullAdmin()) {
      try {
        final List<DaAccessRequestRow> rows =
            await _daService.fetchPendingForAdmin();
        adminPending = rows.length;
      } catch (_) {}
    }

    if (currentUserJwtStaff()) {
      try {
        staffPending = await _reportsService.countPendingReplyReports();
      } catch (_) {}
    }

    if (!currentUserJwtStaff()) {
      try {
        final row = await _daService.fetchLatestForCurrentUser();
        if (row != null) {
          farmerUnseen = await isDaRequestStatusUnseen(
            status: row.status.name,
            reviewedAt: row.reviewedAt?.toUtc().toIso8601String(),
          );
        }
        farmerReplyUnseen = await _farmerReplyService.countUnseenForCurrentUser();
      } catch (_) {}
    }

    final StaffNavBadges badges = StaffNavBadges(
      adminPendingDaRequests: adminPending,
      staffPendingReports: staffPending,
      farmerDaRequestUnseen: farmerUnseen,
      farmerExpertReplyUnseenCount: farmerReplyUnseen,
    );
    _cached = badges;
    return badges;
  }
}
