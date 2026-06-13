import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/notificationModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// The authenticated user's notifications (newest first). Backed by
/// `GET /api/v1/notifications`. Invalidate after marking read / on
/// pull-to-refresh.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.read(notificationServiceProvider).getNotifications();
});

/// Unread count for the home-screen bell badge. Backed by
/// `GET /api/v1/notifications/unread-count`. Invalidate alongside
/// [notificationsProvider] whenever read-state changes.
final unreadCountProvider = FutureProvider<int>((ref) {
  return ref.read(notificationServiceProvider).getUnreadCount();
});
