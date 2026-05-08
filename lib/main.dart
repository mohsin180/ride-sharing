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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            scaffoldBackgroundColor: Consonants.scaffoldBackgroundColor,
            fontFamily: Consonants.fontFamily,
            textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme),
            primaryTextTheme: GoogleFonts.poppinsTextTheme(baseTextTheme),
          ),
        );
      },
    );
  }
}
