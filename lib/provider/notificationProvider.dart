import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/notificationModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// The authenticated user's notifications (newest first). Backed by
/// `GET /api/v1/notifications`. Invalidate after marking read / on
/// pull-to-refresh.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.read(notificationServiceProvider).getNotifications();
});

/// Actionable ride requests aimed at the host — pending co-passenger join
/// requests and driver offers — that power the floating in-ride banner.
/// Self-polls every 7s (autoDispose, so it stops when the ride page is off
/// screen) so a new request pops up near-real-time without a manual refresh.
final pendingRequestsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final timer = Timer(const Duration(seconds: 7), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final all = await ref.read(notificationServiceProvider).getNotifications();
  return all
      .where((n) => !n.read && (n.isJoinRequest || n.isDriverOffer))
      .toList();
});

/// Unread count for the home-screen bell badge. Backed by
/// `GET /api/v1/notifications/unread-count`. Invalidate alongside
/// [notificationsProvider] whenever read-state changes.
///
/// Self-polls every 15s. There's no push/websocket channel for
/// notifications, so without polling the badge would only light up when the
/// user opens the notifications screen (the only place that invalidates
/// this). Each fetch schedules an [Ref.invalidateSelf], which refetches and
/// reschedules — so a notification that arrives while the user sits on the
/// home screen turns the bell red within ~15s. Watched by both the
/// passenger and driver home headers, so a single poll covers both roles.
final unreadCountProvider = FutureProvider<int>((ref) {
  final timer = Timer(const Duration(seconds: 15), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(notificationServiceProvider).getUnreadCount();
});
