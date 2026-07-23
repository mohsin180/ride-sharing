import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/notificationModels.dart';
import 'package:ride_sharing/provider/notificationProvider.dart';
import 'package:ride_sharing/provider/passengerActiveRideProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideDetailsProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/acceptJoinDialog.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Floating, real-time request card shown over the ride page (inDrive style).
///
/// Surfaces the newest pending **co-passenger join request** or **driver
/// offer** aimed at the host, with Accept/Decline right there — no need to
/// open the notifications screen. Backed by [pendingRequestsProvider], which
/// self-polls every ~7s, so a new request slides in near-real-time. Renders
/// nothing when there's no pending request.
///
/// Drop it into a [Stack] positioned near the top of the ride screen.
class FloatingRequestBanner extends ConsumerStatefulWidget {
  const FloatingRequestBanner({super.key});

  @override
  ConsumerState<FloatingRequestBanner> createState() =>
      _FloatingRequestBannerState();
}

class _FloatingRequestBannerState extends ConsumerState<FloatingRequestBanner> {
  /// Notification ids already acted on / dismissed this session, so a handled
  /// request never flashes back while the poll catches up.
  final Set<String> _handled = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingRequestsProvider).value ??
        const <AppNotification>[];

    // Newest actionable request we haven't handled yet (list is newest-first).
    AppNotification? req;
    for (final n in pending) {
      if (!_handled.contains(n.id)) {
        req = n;
        break;
      }
    }
    if (req == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _card(req, key: ValueKey(req.id)),
    );
  }

  Widget _card(AppNotification req, {required Key key}) {
    final driverOffer = req.isDriverOffer;
    final name = (req.subjectName ?? '').trim().isEmpty
        ? (driverOffer ? 'A driver' : 'A passenger')
        : req.subjectName!.trim();
    final action = driverOffer ? 'offered to drive your ride' : 'wants to join';

    return Container(
      key: key,
      margin: EdgeInsets.symmetric(horizontal: 14.w),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: Consonants.primaryColor.withValues(alpha: 0.30),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                  ),
                ),
                child: CustomWidgets.customText(
                    name[0].toUpperCase(), 18.sp, Consonants.whiteColor,
                    FontWeight.w800),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomWidgets.customText(
                        name, 14.sp, Consonants.boldTextColor, FontWeight.w800,
                        maxLines: 1),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(
                          driverOffer
                              ? Icons.local_taxi_rounded
                              : Icons.person_add_alt_1_rounded,
                          size: 12.sp,
                          color: Consonants.primaryColor,
                        ),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: CustomWidgets.customText(action, 11.sp,
                              Consonants.greyColor, FontWeight.w600,
                              maxLines: 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _busy ? null : () => _markHandled(req),
                child: Icon(Icons.close_rounded,
                    size: 18.sp, color: Consonants.greyColor),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _busy ? null : () => _respond(req, false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Consonants.whiteColor,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                          color: const Color(0xffEF4444), width: 1.5),
                    ),
                    child: CustomWidgets.customText("Decline", 12.sp,
                        const Color(0xffEF4444), FontWeight.w800),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _busy ? null : () => _respond(req, true),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: _busy
                        ? SizedBox(
                            height: 16.h,
                            width: 16.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : CustomWidgets.customText(
                            driverOffer ? "Accept driver" : "Accept",
                            12.sp,
                            Consonants.whiteColor,
                            FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respond(AppNotification n, bool accept) async {
    if (n.rideId == null || n.requestId == null) return;
    // Join requests: show the host the fare impact before committing.
    if (accept && !n.isDriverOffer) {
      final ok = await confirmAcceptJoin(context, ref,
          rideId: n.rideId!,
          requestId: n.requestId!,
          requesterName: n.subjectName ?? 'this rider');
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      final svc = ref.read(rideServiceProvider);
      if (n.isDriverOffer) {
        accept
            ? await svc.acceptDriverOffer(n.rideId!, n.requestId!)
            : await svc.declineDriverOffer(n.rideId!, n.requestId!);
      } else {
        accept
            ? await svc.acceptJoinRequest(n.rideId!, n.requestId!)
            : await svc.declineJoinRequest(n.rideId!, n.requestId!);
      }
      _invalidateRide(n.rideId!);
      await _markHandled(n);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customSuccessSnackBar(accept
            ? (n.isDriverOffer ? 'Driver assigned to your ride' : 'Passenger added')
            : (n.isDriverOffer ? 'Driver declined' : 'Request declined')));
    } catch (e) {
      // Usually "already handled" — hide it and surface the message.
      await _markHandled(n);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customErrorSnackBar(ErrorHandler.message(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markHandled(AppNotification n) async {
    _handled.add(n.id);
    // Mark read server-side so it doesn't reappear after a restart.
    try {
      await ref.read(notificationServiceProvider).markAsRead(n.id);
    } catch (_) {}
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationsProvider);
    if (mounted) setState(() {});
  }

  void _invalidateRide(String rideId) {
    ref.invalidate(rideDetailsProvider(rideId));
    ref.invalidate(passengerActiveRideProvider);
  }
}
