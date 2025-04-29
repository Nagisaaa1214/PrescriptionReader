import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:medication_reminder/medication_model.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart'; // For TimeOfDay

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones(); // Initialize timezone database

    // --- Android Initialization ---
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use default app icon

    // --- iOS Initialization ---
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    // --- Combined Initialization ---
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      // macOS: initializationSettingsMacOS, // Add if needed
      // linux: initializationSettingsLinux, // Add if needed
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Request permissions explicitly for iOS (and Android 13+)
    await _requestPermissions();
  }

   Future<void> _requestPermissions() async {
     // iOS
     await flutterLocalNotificationsPlugin
         .resolvePlatformSpecificImplementation<
             IOSFlutterLocalNotificationsPlugin>()
         ?.requestPermissions(
           alert: true,
           badge: true,
           sound: true,
         );

     // Android 13+ (API 33+)
     // Requires adding <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
     // to AndroidManifest.xml
     final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
         flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
             AndroidFlutterLocalNotificationsPlugin>();

     // Check if permission is needed (Android 13+) and request if necessary
     // Note: This might require additional logic to check Android version
     // or rely on the plugin handling it internally based on target SDK.
     // For simplicity here, we assume the plugin might handle some aspects,
     // but explicit request is safer.
     await androidImplementation?.requestNotificationsPermission(); // Newer versions
     // await androidImplementation?.requestPermission(); // Older versions might use this
   }


  // --- Notification Handlers (Background/Terminated Taps) ---
  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
      final String? payload = notificationResponse.payload;
      if (notificationResponse.payload != null) {
          debugPrint('notification payload: $payload');
      }
      // TODO: Handle notification tap (e.g., navigate to specific screen)
      // Example: await Navigator.push(context, MaterialPageRoute<void>(builder: (context) => SecondScreen(payload)));
  }

  // --- Notification Handler (Foreground iOS - older versions) ---
  void onDidReceiveLocalNotification(int id, String? title, String? body, String? payload) async {
    // display a dialog with the notification details, tap ok to go to another page
     debugPrint('Foreground iOS notification received: $title');
     // You might show an in-app message here if needed for older iOS versions
  }

  // --- Scheduling Logic ---
  Future<void> scheduleMedicationReminders(Medication medication) async {
    // --- Cancel existing notifications for this med first ---
    await cancelMedicationNotifications(medication.id ?? ''); // Use a unique base ID

    // --- Android Notification Channel ---
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medication_reminders_channel', // Channel ID
      'Medication Reminders', // Channel Name
      channelDescription: 'Channel for medication reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      // sound: RawResourceAndroidNotificationSound('notification_sound'), // Optional custom sound
      // largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Optional large icon
      ticker: 'ticker',
    );

    // --- iOS Notification Details ---
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // sound: 'notification_sound.aiff', // Optional custom sound
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // --- Schedule for each reminder time ---
    int notificationIndex = 0; // To create unique IDs per time slot
    for (TimeOfDay? time in medication.reminderTimes) {
      if (time != null) {
        final tz.TZDateTime scheduledDateTime = _nextInstanceOfTime(time);
        final int uniqueNotificationId = _generateNotificationId(medication.id!, notificationIndex++);

        try {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            uniqueNotificationId, // Unique ID for this specific time slot
            'Time for your medication!', // Title
            'Take ${medication.name} ${medication.dosage ?? ""}. ${medication.directions ?? ""}', // Body
            scheduledDateTime,
            platformChannelSpecifics,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Crucial for exact timing
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time, // Match only time for daily recurrence
            payload: 'med_id=${medication.id}&time=${time.hour}:${time.minute}', // Optional payload
          );
           print('Scheduled notification $uniqueNotificationId for ${medication.name} at $scheduledDateTime');
        } catch (e) {
           print('Error scheduling notification $uniqueNotificationId: $e');
        }
      }
    }
  }

  // --- Helper to calculate next occurrence of a time ---
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // --- Helper to generate unique but predictable IDs ---
  // Uses hash code, ensure medication.id is stable and unique per medication
  int _generateNotificationId(String medicationId, int index) {
     // Combine medication ID hash and index to create a unique ID
     // Using hashCode is simple but can have collisions, though unlikely for this scale.
     // Ensure the result fits within a 32-bit integer range for Android.
     final String combinedId = '${medicationId}_$index';
     int hashCode = combinedId.hashCode;
     // Keep it within 31 bits (positive range of signed 32-bit int)
     return hashCode & 0x7FFFFFFF;
  }


  // --- Cancel Notifications ---
  Future<void> cancelMedicationNotifications(String medicationId) async {
     // This is tricky because we scheduled multiple IDs per medication.
     // We need a way to find *all* IDs associated with medicationId.
     // Option 1: Store scheduled IDs somewhere (e.g., Firestore, SharedPreferences) - More complex.
     // Option 2: Iterate through a reasonable range of potential indices used in _generateNotificationId
     //           and try cancelling them. Less reliable if index > max range.
     // Option 3: Cancel *all* notifications (simpler but affects other meds).

     // --- Using Option 2 (Example - Cancel first 10 potential slots) ---
     print("Attempting to cancel notifications for med ID: $medicationId");
     for (int i = 0; i < 10; i++) { // Assume max 10 reminders per med for cancellation
        final int potentialId = _generateNotificationId(medicationId, i);
        try {
           await flutterLocalNotificationsPlugin.cancel(potentialId);
           // print("Cancelled potential notification ID: $potentialId");
        } catch (e) {
           print("Error cancelling notification $potentialId: $e");
        }
     }
     // Or use cancelAll() if appropriate for your app structure:
     // await flutterLocalNotificationsPlugin.cancelAll();
  }
}
