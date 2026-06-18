import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/chat_provider.dart';
import 'package:cap/shared/models/event.dart';
import 'package:cap/shared/widgets/share_to_following_bottom_sheet.dart';
import 'package:provider/provider.dart';

void showShareEventBottomSheet(BuildContext context, Event event) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ShareEventBottomSheet(
      eventId: event.id,
      eventTitle: event.title,
    ),
  );
}

class ShareEventBottomSheet extends StatelessWidget {
  final String eventId;
  final String eventTitle;

  const ShareEventBottomSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  Future<void> _sendEvent(
    Set<String> userIds,
    ShareSendActions actions,
  ) async {
    try {
      final chatProvider = actions.context.read<ChatProvider>();
      final authProvider = actions.context.read<AuthProvider>();

      if (authProvider.userId == null) {
        throw Exception('Not authenticated');
      }

      int successCount = 0;
      for (final userId in userIds) {
        try {
          await chatProvider.shareEvent(
            eventId: eventId,
            recipientUserId: userId,
          );
          successCount++;
        } catch (_) {}
      }

      actions.pop();
      actions.showSnackBar(
        SnackBar(
          content: Text(
            successCount == userIds.length
                ? 'Event shared with $successCount ${successCount == 1 ? 'person' : 'people'}!'
                : 'Event shared with $successCount of ${userIds.length} ${userIds.length == 1 ? 'person' : 'people'}.',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      actions.showSnackBar(
        SnackBar(
          content: Text('Failed to share event: $e'),
          backgroundColor: Colors.red,
        ),
      );
      actions.setSending(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShareToFollowingBottomSheet(
      sheetTitle: 'Share Event',
      itemTitle: eventTitle,
      onSend: _sendEvent,
    );
  }
}
