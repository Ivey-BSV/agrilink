import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/settings/presentation/pages/about_account_page.dart';
import 'package:cap/features/settings/presentation/pages/notification_settings_page.dart';
import 'package:cap/features/settings/presentation/pages/change_password_page.dart';
import 'package:cap/features/settings/presentation/pages/contact_page.dart';
import 'package:cap/features/settings/presentation/pages/privacy_policy_page.dart';
import 'package:cap/features/settings/presentation/pages/terms_of_use_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/chat_provider.dart';
import 'package:cap/providers/farm_details_provider.dart';
import 'package:cap/providers/marketplace_provider.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/providers/reciprocity_ring_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDeletingAccount = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildClickableItem(
            context,
            'About Your Account',
            Icons.person_outline,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutAccountPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildClickableItem(
            context,
            'Change Password',
            Icons.lock_outline,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildClickableItem(
            context,
            'Notification settings',
            Icons.notifications_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildClickableItem(
            context,
            'Privacy Policy',
            Icons.privacy_tip_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildClickableItem(
            context,
            'Terms of Use',
            Icons.description_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsOfUsePage(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 20),
          _buildClickableItem(
            context,
            'Contact',
            Icons.email_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildInfoItem(
            'App Version',
            '1.0.9 (20)',
            Icons.info_outline,
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 20),
          _buildLogoutItem(context),
          const SizedBox(height: 20),
          _buildDeleteAccountItem(context),
        ],
      ),
    );
  }

  Widget _buildClickableItem(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    return InkWell(
      onTap: () => _logout(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Row(
          children: [
            Icon(
              Icons.logout,
              size: 22,
              color: AppTheme.errorRed,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Log out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.errorRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountItem(BuildContext context) {
    return InkWell(
      onTap: _isDeletingAccount ? null : () => _confirmDeleteAccount(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.delete_forever_outlined,
              size: 22,
              color: AppTheme.errorRed,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isDeletingAccount ? 'Deleting account...' : 'Delete account',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final postProvider = context.read<PostProvider>();
    final farmDetailsProvider = context.read<FarmDetailsProvider>();
    final marketplaceProvider = context.read<MarketplaceProvider>();
    final reciprocityRingProvider = context.read<ReciprocityRingProvider>();

    chatProvider.clearChats();
    postProvider.clearPosts();
    farmDetailsProvider.clearFarmDetails();
    marketplaceProvider.clearListings();
    reciprocityRingProvider.clearData();

    try {
      await DefaultCacheManager().emptyCache();
    } catch (e) {}

    await authProvider.logout();
    if (context.mounted) {
      context.go('/');
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account and all related data, including posts, comments, chats, events, listings, and profile information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Continue',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !context.mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final confirmation'),
        content: const Text(
          'Are you absolutely sure? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );

    if (secondConfirm != true || !context.mounted) return;
    await _deleteAccount(context);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    setState(() {
      _isDeletingAccount = true;
    });

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final postProvider = context.read<PostProvider>();
    final farmDetailsProvider = context.read<FarmDetailsProvider>();
    final marketplaceProvider = context.read<MarketplaceProvider>();
    final reciprocityRingProvider = context.read<ReciprocityRingProvider>();

    final error = await authProvider.deleteAccount();

    if (!context.mounted) return;

    if (error == null) {
      chatProvider.clearChats();
      postProvider.clearPosts();
      farmDetailsProvider.clearFarmDetails();
      marketplaceProvider.clearListings();
      reciprocityRingProvider.clearData();

      try {
        await DefaultCacheManager().emptyCache();
      } catch (_) {}

      if (context.mounted) {
        context.go('/');
      }
      return;
    }

    setState(() {
      _isDeletingAccount = false;
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      ),
    );
  }
}
