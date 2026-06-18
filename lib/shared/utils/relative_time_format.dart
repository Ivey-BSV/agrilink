String formatFriendlyRelativeTime(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);
  if (difference.inDays > 0) return '${difference.inDays}d ago';
  if (difference.inHours > 0) return '${difference.inHours}h ago';
  if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
  return 'Just now';
}

String formatFriendlyRelativeTimeFromIso(
  String timestamp, {
  String fallback = 'Recently',
}) {
  try {
    return formatFriendlyRelativeTime(DateTime.parse(timestamp));
  } catch (_) {
    return fallback;
  }
}
