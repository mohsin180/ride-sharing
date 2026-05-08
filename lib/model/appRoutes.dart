import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing/view/bottomNavbar.dart';
import 'package:ride_sharing/view/driverScreens/driverMessages.dart';
import 'package:ride_sharing/view/driverScreens/driverNotification.dart';
import 'package:ride_sharing/view/driverScreens/driverProfileData.dart';
import 'package:ride_sharing/view/driverScreens/driverVehicleDetails.dart';
import 'package:ride_sharing/view/homepage.dart';
import 'package:ride_sharing/view/loginScreen.dart';
import 'package:ride_sharing/view/newPassword.dart';
import 'package:ride_sharing/view/passengerScreens/passengerMessages.dart';
import 'package:ride_sharing/view/passengerScreens/passengerNotification.dart';
import 'package:ride_sharing/view/profileData.dart';
import 'package:ride_sharing/view/registerScreen.dart';
import 'package:ride_sharing/view/roleSelection.dart';
import 'package:ride_sharing/view/verificationScreen.dart';
import 'package:ride_sharing/view/viewRequest.dart';

class Approutes {
  static const String login = "/login";
  static const String register = "/register";
  static const String home = "/home";
  static const String verification = "/verification";
  static const String roleSection = "/role";
  static const String resetPassword = "/reset-password";
  static const String bottomNavbar = "/bottom-navbar";
  static const String emailVerification = "/verify-email";
  static const String passengerProfileData = "/passenger";
  static const String driverProfileData = "/driver";
  static const String driverVehicleDetails = "/driver/vehicle";
  static const String viewRequest = "/viewRequest";
  static const String driverNotification = "/driver-notification";
  static const String driverMessages = "/driver-messages";
  static const String passengerMessages = "/passenger-messages";
  static const String passengerNotification = "/passenger-notification";
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
    GoRoute(
      path: Approutes.emailVerification,
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        return VerificationSucceed(token: token);
      },
    ),
    GoRoute(
      path: Approutes.passengerProfileData,
      builder: (context, state) => PassengerProfileData(),
    ),
    GoRoute(
      path: Approutes.driverProfileData,
      builder: (context, state) => const DriverProfileData(),
    ),
    GoRoute(
      path: Approutes.driverVehicleDetails,
      builder: (context, state) => const DriverVehicleDetails(),
    ),
    GoRoute(
      path: Approutes.bottomNavbar,
      builder: (context, state) {
        return Bottomnavbar();
      },
    ),
    GoRoute(
      path: Approutes.viewRequest,
      builder: (context, state) {
        final raw = state.extra;
        final extra = raw is Map ? raw : const {};
        final pickup = extra['pickup'];
        final drop = extra['drop'];
        final seats = extra['seats'];
        final pickupLatLng = extra['pickupLatLng'];
        final dropLatLng = extra['dropLatLng'];
        return Viewrequest(
          pickup: pickup is String && pickup.isNotEmpty
              ? pickup
              : "Hostel City, Block B",
          drop: drop is String && drop.isNotEmpty
              ? drop
              : "Taramri Chowk",
          seats: seats is int ? seats : 1,
          pickupLatLng: pickupLatLng is LatLng ? pickupLatLng : null,
          dropLatLng: dropLatLng is LatLng ? dropLatLng : null,
        );
      },
    ),
    GoRoute(
      path: Approutes.driverNotification,
      builder: (context, state) => const Drivernotification(),
    ),
    GoRoute(
      path: Approutes.driverMessages,
      builder: (context, state) => const Drivermessages(),
    ),
    GoRoute(
      path: Approutes.passengerMessages,
      builder: (context, state) => const Passengermessages(),
    ),
    GoRoute(
      path: Approutes.passengerNotification,
      builder: (context, state) => const Passengernotification(),
    ),
  ],
);
