library;

/// Short relative time for activity lists (e.g. "5 min ago").
String formatRelativeTime(DateTime dt, {bool fil = false}) {
  final DateTime local = dt.toLocal();
  final Duration diff = DateTime.now().difference(local);
  if (diff.isNegative || diff.inSeconds < 45) {
    return fil ? 'Ngayon lang' : 'Just now';
  }
  if (diff.inMinutes < 60) {
    final int m = diff.inMinutes;
    return fil ? '$m min ang nakalipas' : '$m min ago';
  }
  if (diff.inHours < 24) {
    final int h = diff.inHours;
    return fil ? '$h oras ang nakalipas' : '$h hr ago';
  }
  if (diff.inDays < 7) {
    final int d = diff.inDays;
    return fil ? '$d araw ang nakalipas' : '$d d ago';
  }
  return fil
      ? '${local.month}/${local.day}/${local.year}'
      : '${local.month}/${local.day}/${local.year}';
}

String formatRelativeIso(String? iso, {bool fil = false}) {
  if (iso == null || iso.trim().isEmpty) return fil ? 'Walang petsa' : 'No date';
  final DateTime? dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return formatRelativeTime(dt, fil: fil);
}
