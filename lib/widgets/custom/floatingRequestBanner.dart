import 'dart:ui';

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
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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

    final radius = BorderRadius.circular(Consonants.rSheet.r);

    return Container(
      key: key,
      margin: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: Consonants.cardLift,
      ),
      // Floats over the live ride map, so it's translucent canvas over a blur
      // rather than an opaque bar — the route keeps reading underneath it.
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
            decoration: BoxDecoration(
              color: Consonants.canvas.withValues(alpha: 0.90),
              borderRadius: radius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Wash, not gradient: the Accept button is the only thing
                    // on this card allowed to carry the action gradient.
                    Container(
                      width: 44.w,
                      height: 44.w,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Consonants.indigoWash,
                      ),
                      child: Text(
                        name[0].toUpperCase(),
                        style: AppText.amount(color: Consonants.indigo)
                            .copyWith(fontSize: 17.sp),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.rowLabel(
                                    color: Consonants.headingInk)
                                .copyWith(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Icon(
                                driverOffer
                                    ? Icons.local_taxi_outlined
                                    : Icons.person_add_alt_1_outlined,
                                size: 13.sp,
                                color: Consonants.iconInk,
                              ),
                              SizedBox(width: 5.w),
                              Flexible(
                                child: Text(
                                  action,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.caption()
                                      .copyWith(fontSize: 12.5.sp),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: _busy ? null : () => _markHandled(req),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Icon(Icons.close_rounded,
                            size: 18.sp, color: Consonants.textMuted),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Decline',
                        kind: AppButtonKind.neutral,
                        onPressed: _busy ? null : () => _respond(req, false),
                      ),
                    ),
                    SizedBox(width: Consonants.gapButtons.w),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: driverOffer ? 'Accept driver' : 'Accept',
                        isLoading: _busy,
                        onPressed: _busy ? null : () => _respond(req, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
