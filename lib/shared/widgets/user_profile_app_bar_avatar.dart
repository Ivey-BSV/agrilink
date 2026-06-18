import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/profile/presentation/pages/profile_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/shared/utils/avatar_utils.dart';
import 'package:cap/shared/widgets/network_circle_avatar.dart';
import 'package:provider/provider.dart';

class UserProfileAppBarAvatar extends StatelessWidget {
  const UserProfileAppBarAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.currentProfile;
    final String? avatarUrl = profile?.avatarUrl;
    final displayName = (profile?.fullName ?? auth.userName ?? 'U').trim();
    final displayLetter =
        displayName.isNotEmpty ? avatarInitialLetter(displayName) : 'U';

    if (auth.userId != null &&
        (profile == null || profile.id != auth.userId) &&
        !profileProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        profileProvider.loadProfile(auth.userId!);
      });
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        },
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
          ),
          child: NetworkCircleAvatar(
            avatarKey: ValueKey('avatar_${auth.userId}_${avatarUrl ?? 'none'}'),
            radius: 18,
            imageUrl: avatarUrl,
            cacheBustKey: auth.userId ?? 'none',
            fallbackLetter: displayLetter,
            fallbackTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}
