import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/chat_provider.dart';
import 'package:cap/shared/widgets/share_to_following_bottom_sheet.dart';
import 'package:provider/provider.dart';

class SharePostBottomSheet extends StatelessWidget {
  final String postId;
  final String postTitle;

  const SharePostBottomSheet({
    super.key,
    required this.postId,
    required this.postTitle,
  });

  Future<void> _sendPost(
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
      int failureCount = 0;
      String? lastError;
      for (final userId in userIds) {
        try {
          await chatProvider.sharePost(
            postId: postId,
            recipientUserId: userId,
          );
          successCount++;
        } catch (e) {
          failureCount++;
          lastError = e.toString();
        }
      }

      if (successCount > 0) {
        actions.pop();
        actions.showSnackBar(
          SnackBar(
            content: Text(
              successCount == userIds.length
                  ? 'Post shared with $successCount ${successCount == 1 ? 'person' : 'people'}!'
                  : 'Post shared with $successCount of ${userIds.length} ${userIds.length == 1 ? 'person' : 'people'}.',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      } else {
        final hint = (lastError != null &&
                lastError.toLowerCase().contains('post_id'))
            ? ' (Did you run the Supabase migration to add the post_id column?)'
            : '';
        actions.showSnackBar(
          SnackBar(
            content: Text(
              'Couldn\'t share post ($failureCount failed). ${lastError ?? ''}$hint',
            ),
            backgroundColor: Colors.red,
          ),
        );
        actions.setSending(false);
      }
    } catch (e) {
      actions.showSnackBar(
        SnackBar(
          content: Text('Failed to share post: $e'),
          backgroundColor: Colors.red,
        ),
      );
      actions.setSending(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShareToFollowingBottomSheet(
      sheetTitle: 'Share Post',
      itemTitle: postTitle,
      onSend: _sendPost,
    );
  }
}
