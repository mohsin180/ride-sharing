import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/widgets/consonants/env.dart';
import 'package:ride_sharing/url_strategy/url_strategy_stub.dart'
    if (dart.library.js_interop) 'package:ride_sharing/url_strategy/url_strategy_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  configureUrlStrategy();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Password-reset mail links land on a backend page that redirects to
    // saferide://reset-password?token=... — this is where the app picks that
    // up, both on a cold start and while it's already running.
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
  }

  void _handleLink(Uri uri) {
    if (uri.scheme != 'saferide') return;
    // saferide://reset-password?token=... — the target is the URI's host,
    // since a custom scheme has no leading path segment.
    if (uri.host != 'reset-password') return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    appRouter.go('${Approutes.resetPassword}?token=$token');
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final baseTextTheme = Theme.of(context).textTheme;
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: Consonants.canvas,
            // Inter carries everything inside the app; Fraunces is applied
            // per-widget on onboarding and identity moments only.
            textTheme: GoogleFonts.interTextTheme(baseTextTheme),
            primaryTextTheme: GoogleFonts.interTextTheme(baseTextTheme),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Consonants.indigo,
              primary: Consonants.indigo,
              secondary: Consonants.violet,
              surface: Consonants.surface,
            ),
            dividerColor: Consonants.divider,
            // Text selection / cursors pick up the focus hue rather than
            // Material's default teal.
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Consonants.violet,
              selectionHandleColor: Consonants.violet,
            ),
            splashFactory: InkRipple.splashFactory,
          ),
        );
      },
    );
  }
}
