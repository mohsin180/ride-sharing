import 'package:go_router/go_router.dart';
import 'package:ride_sharing/view/loginScreen.dart';
import 'package:ride_sharing/view/registerScreen.dart';

class Approutes {
  static const String login = "/login";
  static const String register = "/register";
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
  ],
);
