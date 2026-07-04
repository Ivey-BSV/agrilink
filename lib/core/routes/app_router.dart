import 'package:cap/features/auth/presentation/pages/login_page.dart';
import 'package:cap/features/auth/presentation/pages/register_page.dart';
import 'package:cap/features/auth/presentation/pages/reset_password_page.dart';
import 'package:cap/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:cap/features/home/presentation/pages/home_page.dart';
import 'package:cap/features/notifications/presentation/pages/notifications_page.dart';
import 'package:cap/features/polls/presentation/pages/poll_detail_page.dart';
import 'package:cap/features/post/presentation/pages/post_detail_page.dart';
import 'package:cap/features/profile/presentation/pages/followers_following_list_page.dart';
import 'package:cap/features/profile/presentation/pages/user_profile_page.dart';
import 'package:cap/features/resources/presentation/pages/knowledge_repository_page.dart';
import 'package:cap/features/resources/presentation/pages/workshops_page.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static const _publicPaths = {'/login', '/register', '/reset-password'};

  /// Latest router instance, used for navigation from push notification taps.
  static GoRouter? current;

  static GoRouter createRouter(AuthProvider auth) {
    return current = GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (context, state) {
        final loggedIn = auth.isAuthenticated;
        final path = state.uri.path;

        if (path == '/') {
          return null;
        }
        if (_publicPaths.contains(path)) {
          if (loggedIn && (path == '/login' || path == '/register')) {
            return '/';
          }
          return null;
        }
        if (!loggedIn) {
          return '/login';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final loggedIn = auth.isAuthenticated;
            return loggedIn ? const HomePage() : const LoginPage();
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => const ResetPasswordPage(),
        ),
        GoRoute(
          path: '/chat/:chatId',
          builder: (context, state) {
            final chatId = state.pathParameters['chatId']!;
            return ChatDetailPage(chatId: chatId);
          },
        ),
        GoRoute(
          path: '/user-profile/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return UserProfilePage(userId: userId);
          },
        ),
        GoRoute(
          path: '/followers-following/:userId/:isFollowers',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            final isFollowersStr = state.pathParameters['isFollowers']!;
            return FollowersFollowingListPage(
              userId: userId,
              isFollowersList: isFollowersStr == 'true',
            );
          },
        ),
        GoRoute(
          path: '/post/:postId',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            return PostDetailPage(postId: postId);
          },
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsPage(),
        ),
        GoRoute(
          path: '/poll/:pollId',
          builder: (context, state) {
            final pollId = state.pathParameters['pollId']!;
            return PollDetailPage(pollId: pollId);
          },
        ),
        GoRoute(
          path: '/repository',
          builder: (context, state) => KnowledgeRepositoryPage(
            initialFolderId: state.uri.queryParameters['folder'],
          ),
        ),
        GoRoute(
          path: '/workshops',
          builder: (context, state) => WorkshopsPage(
            initialFolderId: state.uri.queryParameters['folder'],
          ),
        ),
      ],
    );
  }
}
