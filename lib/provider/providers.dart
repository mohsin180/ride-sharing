import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/controller/authService.dart';
import 'package:ride_sharing/controller/kycService.dart';
import 'package:ride_sharing/controller/messagingService.dart';
import 'package:ride_sharing/controller/notificationService.dart';
import 'package:ride_sharing/controller/profileService.dart';
import 'package:ride_sharing/controller/rideService.dart';

final apiClientProvider = Provider<Apiclient>((ref) => Apiclient());
final authServiceProvider = Provider<Authservice>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return Authservice(apiclient: apiClient);
});
final profileServiceProvider = Provider<Profileservice>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return Profileservice(apiclient: apiClient);
});
final rideServiceProvider = Provider<Rideservice>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return Rideservice(apiclient: apiClient);
});
final notificationServiceProvider = Provider<Notificationservice>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return Notificationservice(apiclient: apiClient);
});
final messagingServiceProvider = Provider<Messagingservice>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return Messagingservice(apiclient: apiClient);
});
final kycServiceProvider = Provider<Kycservice>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return Kycservice(apiclient: apiClient);
});
