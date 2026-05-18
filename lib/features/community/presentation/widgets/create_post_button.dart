import 'package:flutter/material.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/features/events/presentation/pages/create_event_page.dart';
import 'package:cap/features/post/presentation/pages/create_post_page.dart';

class CreatePostButton extends StatefulWidget {
  final int currentTabIndex;

  const CreatePostButton({super.key, required this.currentTabIndex});

  @override
  State<CreatePostButton> createState() => _CreatePostButtonState();
}

class _CreatePostButtonState extends State<CreatePostButton> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'fab_create',
      onPressed: () {
        if (widget.currentTabIndex == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreatePostPage(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateEventPage(),
            ),
          );
        }
      },
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      child: const Icon(Icons.add, size: 28),
    );
  }
}
