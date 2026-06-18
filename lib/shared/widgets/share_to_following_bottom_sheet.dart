import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/user_profile.dart';
import 'package:cap/shared/utils/avatar_utils.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:provider/provider.dart';

class ShareSendActions {
  ShareSendActions(this.context, this.setSending);

  final BuildContext context;
  final void Function(bool sending) setSending;

  void pop() => Navigator.pop(context);

  void showSnackBar(SnackBar snackBar) {
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

typedef ShareToFollowingSendHandler = Future<void> Function(
  Set<String> userIds,
  ShareSendActions actions,
);

class ShareToFollowingBottomSheet extends StatefulWidget {
  final String sheetTitle;
  final String itemTitle;
  final ShareToFollowingSendHandler onSend;

  const ShareToFollowingBottomSheet({
    super.key,
    required this.sheetTitle,
    required this.itemTitle,
    required this.onSend,
  });

  @override
  State<ShareToFollowingBottomSheet> createState() =>
      _ShareToFollowingBottomSheetState();
}

class _ShareToFollowingBottomSheetState
    extends State<ShareToFollowingBottomSheet> {
  List<UserProfile> _following = [];
  List<UserProfile> _filteredFollowing = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isSending = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterFollowing);
    _loadFollowing();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();

      if (authProvider.userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final following =
          await profileProvider.getFollowing(authProvider.userId!);

      if (mounted) {
        setState(() {
          _following = following;
          _filteredFollowing = following;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load following: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterFollowing() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFollowing = _following;
      } else {
        _filteredFollowing = _following.where((user) {
          final name =
              (user.fullName ?? user.displayUsername ?? '').toLowerCase();
          final username = (user.displayUsername ?? '').toLowerCase();
          return name.contains(query) || username.contains(query);
        }).toList();
      }
    });
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _handleSend() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final actions = ShareSendActions(context, (sending) {
      if (mounted) {
        setState(() {
          _isSending = sending;
        });
      }
    });

    await widget.onSend(Set<String>.from(_selectedUserIds), actions);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sheetTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.itemTitle,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search following...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredFollowing.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchController.text.isEmpty
                              ? 'You\'re not following anyone yet'
                              : 'No users found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _filteredFollowing.length,
                    itemBuilder: (context, index) {
                      final user = _filteredFollowing[index];
                      final isSelected = _selectedUserIds.contains(user.id);
                      final displayName =
                          user.fullName ?? user.displayUsername ?? 'Unknown';

                      return InkWell(
                        onTap: () => _toggleUserSelection(user.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  NetworkCircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppTheme.primaryGreen
                                        .withValues(alpha: 0.1),
                                    imageUrl: user.avatarUrl,
                                    fallbackLetter: avatarInitialLetter(
                                      user.fullName ??
                                          user.displayUsername ??
                                          'U',
                                    ),
                                    fallbackTextStyle: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryGreen,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (user.displayUsername != null &&
                                        user.fullName != null)
                                      Text(
                                        '@${user.displayUsername}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
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
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    _selectedUserIds.isEmpty || _isSending ? null : _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _selectedUserIds.isEmpty
                            ? 'Select users to share'
                            : 'Send to ${_selectedUserIds.length} ${_selectedUserIds.length == 1 ? 'person' : 'people'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
