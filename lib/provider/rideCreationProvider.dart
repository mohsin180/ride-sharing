import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';

/// Owns the lifecycle of the passenger's "Book" tap on the homepage:
///   - `isLoading` while the POST is in flight (drives the CTA spinner)
///   - `error` carries the user-facing message on failure (read by
///     ref.listen and shown via [ErrorHandler.show])
///   - `isSuccess` flips false→true exactly once per successful create,
///     letting screens drive navigation off state alone
///   - `ride` holds the created [RideResponse] so the next screen can
///     read its id / status without a re-fetch
class RideCreationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final RideResponse? ride;

  const RideCreationState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.ride,
  });

  RideCreationState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isSuccess,
    RideResponse? ride,
  }) {
    return RideCreationState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSuccess: isSuccess ?? this.isSuccess,
      ride: ride ?? this.ride,
    );
  }
}

class RideCreationNotifier extends StateNotifier<RideCreationState> {
  final Ref ref;
  RideCreationNotifier(this.ref) : super(const RideCreationState());

  Future<RideResponse> createRide(CreateRideRequest request) async {
    state = state.copyWith(
      isLoading: true,
      isSuccess: false,
      clearError: true,
    );
    try {
      final response = await ref.read(rideServiceProvider).createRide(request);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        ride: response,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSuccess: false,
        error: ErrorHandler.message(e),
      );
      rethrow;
    }
  }

  /// Resets the transient flags so a screen re-entering the flow
  /// doesn't see stale `isSuccess`/`error` from a prior attempt.
  void reset() {
    state = const RideCreationState();
  }
}

final rideCreationProvider =
    StateNotifierProvider<RideCreationNotifier, RideCreationState>(
      (ref) => RideCreationNotifier(ref),
    );
