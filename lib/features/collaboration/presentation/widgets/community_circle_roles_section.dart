import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/shared/constants/circle_roles.dart';

class CommunityCircleRolesSection extends StatelessWidget {
  const CommunityCircleRolesSection({
    super.key,
    required this.rows,
    required this.isCreator,
    required this.isJoined,
    required this.currentUserId,
    required this.onRoleRowTap,
  });

  final List<Map<String, dynamic>> rows;
  final bool isCreator;
  final bool isJoined;
  final String? currentUserId;
  final void Function(String roleSlug) onRoleRowTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Circle roles',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Four seats for this community project. The creator can assign anyone '
          'in the project; members can claim open seats after they join.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _RoleRow(
                    row: rows[i],
                    isCreator: isCreator,
                    isJoined: isJoined,
                    currentUserId: currentUserId,
                    onTap: () {
                      final slug = rows[i]['role'] as String? ?? '';
                      if (slug.isEmpty) return;
                      onRoleRowTap(slug);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.row,
    required this.isCreator,
    required this.isJoined,
    required this.currentUserId,
    required this.onTap,
  });

  final Map<String, dynamic> row;
  final bool isCreator;
  final bool isJoined;
  final String? currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slug = row['role'] as String? ?? '';
    final label = kCommunityCircleRoleLabels[slug] ?? slug;
    final hint = kCommunityCircleRoleHints[slug];
    final occupantId = row['user_id'] as String?;
    final profile = row['user_profiles'];
    final isVacant = occupantId == null;
    final isSelf = occupantId != null && occupantId == currentUserId;
    final tappable =
        isCreator || (isJoined && isVacant) || (isJoined && isSelf);

    final name = profile is Map
        ? ((profile['full_name'] as String?)?.trim().isNotEmpty == true
                ? profile['full_name'] as String
                : null) ??
            (profile['username'] as String?) ??
            'Member'
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: tappable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
                backgroundImage: !isVacant &&
                        profile is Map &&
                        (profile['avatar_url'] as String?)?.isNotEmpty == true
                    ? CachedNetworkImageProvider(
                        profile['avatar_url'] as String,
                      )
                    : null,
                child: isVacant
                    ? Icon(Icons.person_outline, color: Colors.grey[600])
                    : (profile is Map &&
                            (profile['avatar_url'] as String?)?.isNotEmpty !=
                                true)
                        ? Icon(Icons.person, color: Colors.grey[700])
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      isVacant
                          ? (isJoined
                              ? 'Open — tap to volunteer'
                              : 'Open — join the project to claim')
                          : name ?? 'Member',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isVacant ? AppTheme.primaryGreen : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (tappable)
                Icon(Icons.chevron_right, color: Colors.grey[500], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
