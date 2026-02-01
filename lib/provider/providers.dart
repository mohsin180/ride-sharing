import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/controller/authService.dart';

final apiClientProvider = Provider<Apiclient>((ref) => Apiclient());
final authServiceProvider = Provider<Authservice>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return Authservice(apiclient: apiClient);
});
