import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/api_service.dart';
import 'services/sync_service.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background FCM message received — trigger sync
  await SyncService().syncAll();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive for local cache
  await Hive.initFlutter();

  // Init Firebase (skip gracefully if google-services.json not configured)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Register FCM token with backend
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await ApiService().registerFcmToken(token);
    }

    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });
  } catch (e) {
    debugPrint('Firebase not configured: $e');
  }

  // Init local notifications
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings),
  );

  // Register WorkManager background sync
  await SyncService.register();

  // Trigger a sync on app open
  SyncService().syncAll().then((result) {
    debugPrint('Initial sync: $result');
  });

  runApp(const ProviderScope(child: ILMApp()));
}

void _showLocalNotification(RemoteMessage message) {
  flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'Life Manager',
    message.notification?.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'ilm_channel',
        'Life Manager',
        channelDescription: 'Task and habit reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
