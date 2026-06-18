import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/models/user_profile.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class FollowersFollowingListPage extends StatefulWidget {
  final String userId;
  final bool isFollowersList;

  const FollowersFollowingListPage({
    super.key,
    required this.userId,
    required this.isFollowersList,
  });

  @override
  State<FollowersFollowingListPage> createState() =>
      _FollowersFollowingListPageState();
}

class _FollowersFollowingListPageState
    extends State<FollowersFollowingListPage> {
  List<UserProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    final profileProvider = context.read<ProfileProvider>();

    try {
      final users = widget.isFollowersList
          ? await profileProvider.getFollowers(widget.userId)
          : await profileProvider.getFollowing(widget.userId);

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToUserProfile(String userId) {
    context.push('/user-profile/$userId');
  }

  Future<void> _handleFollowAction(UserProfile user, bool shouldFollow) async {
    final profileProvider = context.read<ProfileProvider>();

    try {
      if (shouldFollow) {
        await profileProvider.followUser(user.id);
      } else {
        await profileProvider.unfollowUser(user.id);
      }

      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to ${shouldFollow ? 'follow' : 'unfollow'} user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserTile(UserProfile user) {
    return ListTile(
      leading: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.primaryGradient,
        ),
        child: NetworkCircleAvatar(
          radius: 28,
          imageUrl: user.avatarUrl,
          fallbackLetter:
              _getInitialLetter(user.fullName ?? user.displayUsername ?? 'U'),
          fallbackTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        user.fullName ?? 'Unknown User',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '@${user.displayUsername ?? 'username'}',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      trailing: _buildTrailingWidget(user),
      onTap: () => _navigateToUserProfile(user.id),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget? _buildTrailingWidget(UserProfile user) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.userId;

    if (currentUserId != null && user.id == currentUserId) {
      return null;
    }

    Widget? statusBadge;

    if (widget.isFollowersList) {
      statusBadge = user.isFollowing
          ? _buildStatusBadge(
              'Following',
              AppTheme.primaryGreen,
              onTap: () => _handleFollowAction(user, false),
            )
          : _buildStatusBadge(
              'Follow Back',
              Colors.grey[600]!,
              onTap: () => _handleFollowAction(user, true),
            );
    } else {
      statusBadge = _buildStatusBadge(
        'Following',
        AppTheme.primaryGreen,
        onTap: () => _handleFollowAction(user, false),
      );
    }

    return statusBadge;
  }

  String _getInitialLetter(String name) {
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  Widget _buildStatusBadge(String text, Color color, {VoidCallback? onTap}) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: badge,
      );
    }

    return badge;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        title: Text(
          widget.isFollowersList ? 'Followers' : 'Following',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            )
          : _users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.isFollowersList
                          ? 'No followers yet'
                          : 'Not following anyone yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return _buildUserTile(user);
                  },
                ),
    );
  }
}
