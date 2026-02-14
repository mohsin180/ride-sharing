import 'package:go_router/go_router.dart';
import 'package:ride_sharing/view/homepage.dart';
import 'package:ride_sharing/view/loginScreen.dart';
import 'package:ride_sharing/view/newPassword.dart';
import 'package:ride_sharing/view/registerScreen.dart';
import 'package:ride_sharing/view/roleSelection.dart';
import 'package:ride_sharing/view/verificationScreen.dart';

class Approutes {
  static const String login = "/login";
  static const String register = "/register";
  static const String home = "/home";
  static const String verification = "/verification";
  static const String roleSection = "/role";
  static const String resetPassword = "/reset-password";
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
    GoRoute(
      path: Approutes.roleSection,
      name: "role",
      builder: (context, state) => const Roleselection(),
    ),
    GoRoute(
      path: Approutes.resetPassword,
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        return Newpassword(token);
      },
    ),
  ],
);
