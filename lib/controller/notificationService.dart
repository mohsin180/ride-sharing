import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/notificationModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';

/// Talks to notification-service. The recipient is resolved server-side
/// from the gateway-injected user, so none of these take a userId.
class Notificationservice {
  final Apiclient apiclient;
  Notificationservice({required this.apiclient});

  /// The authenticated user's notifications, newest first.
  Future<List<AppNotification>> getNotifications() async {
    final json = await apiclient.get(Apiconsonants.notificationsEndpoint);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  /// Count of unread notifications — for the home-screen bell badge.
  Future<int> getUnreadCount() async {
    final json = await apiclient.get(Apiconsonants.unreadCountEndpoint);
    if (json is Map && json['count'] is num) {
      return (json['count'] as num).toInt();
    }
    return 0;
  }

  /// Marks a single notification read.
  Future<void> markAsRead(String id) async {
    await apiclient.post(Apiconsonants.markNotificationReadEndpoint(id), const {});
  }

  /// Marks every notification read (clears the badge).
  Future<void> markAllRead() async {
    await apiclient.post(Apiconsonants.markAllNotificationsReadEndpoint, const {});
  }

  /// Permanently deletes one notification.
  Future<void> deleteNotification(String id) async {
    await apiclient.delete(Apiconsonants.deleteNotificationEndpoint(id));
  }
}
