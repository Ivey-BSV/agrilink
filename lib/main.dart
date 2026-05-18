import 'package:flutter/material.dart';
import 'package:cap/core/config/supabase_config.dart';
import 'package:cap/core/routes/app_router.dart';
import 'package:cap/core/theme/app_theme.dart';
import 'package:cap/providers/auth_provider.dart';
import 'package:cap/providers/chat_provider.dart';
import 'package:cap/providers/event_provider.dart';
import 'package:cap/providers/farm_details_provider.dart';
import 'package:cap/providers/marketplace_provider.dart';
import 'package:cap/providers/notification_provider.dart';
import 'package:cap/providers/post_provider.dart';
import 'package:cap/providers/profile_provider.dart';
import 'package:cap/providers/reciprocity_ring_provider.dart';
import 'package:cap/services/push_notification_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.supabaseUrl != 'YOUR_SUPABASE_URL_HERE' &&
      SupabaseConfig.supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY_HERE') {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }
  await PushNotificationService.initialize();
  runApp(const CAPApp());
}

class CAPApp extends StatelessWidget {
  const CAPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => FarmDetailsProvider()),
        ChangeNotifierProvider(create: (_) => MarketplaceProvider()),
        ChangeNotifierProvider(create: (_) => ReciprocityRingProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
      ],
      child: Builder(builder: (context) {
        final auth = context.watch<AuthProvider>();
        final router = AppRouter.createRouter(auth);

        return MaterialApp.router(
          title: 'CAP',
          theme: AppTheme.lightTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      }),
    );
  }
}
