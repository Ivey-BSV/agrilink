import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifications, _) {
        final hasUnread = notifications.unreadCount > 0;
        return IconButton(
          tooltip: 'Notifications',
          icon: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.black),
              if (hasUnread)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => context.push('/notifications'),
        );
      },
    );
  }
}
