import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AboutAccountPage extends StatelessWidget {
  const AboutAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.currentProfile;

    final dateJoined = profile?.createdAt ??
        (authProvider.userId != null ? DateTime.now() : null);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('About Your Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 24),
                    _buildInfoRow(
                      context,
                      'Username',
                      authProvider.userName ?? 'Not set',
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(
                      context,
                      'Email',
                      authProvider.userEmail ?? 'Not set',
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(
                      context,
                      'Full Name',
                      profile?.fullName ?? 'Not set',
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(
                      context,
                      'Date Joined',
                      dateJoined != null
                          ? DateFormat('MMMM dd, yyyy').format(dateJoined)
                          : 'Not available',
                    ),
                    if (profile?.location != null) ...[
                      const Divider(height: 32),
                      _buildInfoRow(
                        context,
                        'Location',
                        profile!.location!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Details',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 24),
                    if (profile?.farmType != null)
                      _buildInfoRow(
                        context,
                        'Farm Type',
                        profile!.farmType!,
                      ),
                    if (profile?.experienceLevel != null) ...[
                      if (profile?.farmType != null) const Divider(height: 32),
                      _buildInfoRow(
                        context,
                        'Experience Level',
                        profile!.experienceLevel!,
                      ),
                    ],
                    if (profile?.bio != null) ...[
                      if (profile?.farmType != null ||
                          profile?.experienceLevel != null)
                        const Divider(height: 32),
                      _buildInfoRow(
                        context,
                        'Bio',
                        profile!.bio!,
                        isMultiline: true,
                      ),
                    ],
                    if (profile?.farmType == null &&
                        profile?.experienceLevel == null &&
                        profile?.bio == null)
                      Text(
                        'No additional profile details available.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isMultiline = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textPrimary,
          ),
          maxLines: isMultiline ? null : 1,
          overflow: isMultiline ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
