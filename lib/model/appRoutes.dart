import 'package:go_router/go_router.dart';
import 'package:ride_sharing/view/homepage.dart';
import 'package:ride_sharing/view/loginScreen.dart';
import 'package:ride_sharing/view/registerScreen.dart';
import 'package:ride_sharing/view/verificationScreen.dart';

class Approutes {
  static const String login = "/login";
  static const String register = "/register";
  static const String home = "/home";
  static const String verification = "/verification";
}

final appRouter = GoRouter(
  initialLocation: Approutes.login,
  routes: [
    GoRoute(
      path: Approutes.login,
      name: "login",
      builder: (context, state) => const Loginscreen(),
    ),
    GoRoute(
      path: Approutes.register,
      name: "register",
      builder: (context, state) => const Registerscreen(),
    ),
    GoRoute(
      path: Approutes.home,
      name: "home",
      builder: (context, state) => Homepage(),
    ),
    GoRoute(
      path: Approutes.verification,
      name: "verification",
      builder: (context, state) => const Verificationscreen(),
    ),
  ],
);
