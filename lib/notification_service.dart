import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/material.dart'; // For TimeOfDay
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:medication_reminder/medication_model.dart';
import 'package:medication_reminder/frequency_parser_service.dart'; // Import the frequency parser
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // Singleton pattern setup (optional but common for services)
  // static final NotificationService _instance = NotificationService._internal();
  // factory NotificationService() => _instance;
  // NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FrequencyParserService _frequencyParser =
      FrequencyParserService(); // Instantiate the parser

  bool _initialized = false; // Track initialization status

  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_initialized) return;

    tz.initializeTimeZones(); // Initialize timezone database

    // --- Android Initialization ---
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Use default app icon

    // --- iOS Initialization ---
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // Callback for older iOS foreground notifications
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
      // Callback for when notification is tapped (app in foreground, background, or terminated)
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // Request permissions explicitly for iOS (and Android 13+)
    await _requestPermissions();
    _initialized = true;
    debugPrint("Notification Service Initialized");
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
    // to AndroidManifest.xml (inside the <manifest> tag)
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Request permission
    await androidImplementation?.requestNotificationsPermission();
  }

  // --- Notification Handlers ---

  // Handles tap on notification when app is in foreground/background/terminated
  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (notificationResponse.payload != null) {
      debugPrint('Notification tapped payload: $payload');
      // TODO: Implement navigation or action based on payload
      // Example: Parse payload 'med_id=XYZ&time=H:M'
      // Navigate to medication detail screen, mark as taken, etc.
    }
    // Example: Navigate to a specific screen if needed
    // await Navigator.push(context, MaterialPageRoute<void>(builder: (context) => SecondScreen(payload)));
  }

  // Handles foreground notifications on older iOS versions
  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // display a dialog with the notification details, tap ok to go to another page
    debugPrint(
        'Foreground iOS (Legacy) notification received: id=$id, title=$title');
    // Optionally show an in-app banner or dialog here for older iOS
  }

  // --- Scheduling Logic (MODIFIED) ---
  Future<void> scheduleMedicationReminders(Medication medication) async {
    if (!_initialized) {
      debugPrint("Notification Service not initialized. Cannot schedule.");
      return;
    }
    if (medication.id == null || medication.id!.isEmpty) {
      debugPrint("Error scheduling: Medication ID is missing.");
      return;
    }

    // --- Cancel existing notifications for this med first ---
    await cancelMedicationNotifications(medication.id!);

    // --- Parse the frequency text to get scheduled times ---
    final List<TimeOfDay> scheduledTimes =
        _frequencyParser.parseFrequency(medication.frequencyRaw); // Use the parser

    if (scheduledTimes.isEmpty) {
      debugPrint(
          "No automatic schedule determined for ${medication.name} based on '${medication.frequencyRaw}'. No notifications scheduled.");
      return; // Don't schedule if parsing failed or frequency is PRN/empty
    }

    debugPrint(
        "Scheduling ${scheduledTimes.length} notifications for ${medication.name} based on '${medication.frequencyRaw}'");

    // --- Notification Details (Platform Specific) ---
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medication_reminders_channel_id', // Channel ID ** MUST BE UNIQUE **
      'Medication Reminders', // Channel Name (visible in Android settings)
      channelDescription: 'Channel for medication reminder notifications',
      importance: Importance.max, // Show everywhere, make noise
      priority: Priority.high, // Highest priority
      // sound: RawResourceAndroidNotificationSound('notification_sound'), // Optional: Add a sound file 'notification_sound.mp3/wav' to android/app/src/main/res/raw
      // largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Optional
      ticker: 'Medication Reminder', // Ticker text for status bar
      visibility: NotificationVisibility.public, // Show on lock screen
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true, // Show alert banner
      presentBadge: true, // Update app icon badge
      presentSound: true, // Play sound
      // sound: 'notification_sound.aiff', // Optional: Add sound to iOS project
      // badgeNumber: 1, // Optional: Set specific badge number
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // --- Schedule for each PARSED reminder time ---
    int notificationIndex = 0; // Index for generating unique IDs
    // --- ** CORRECTED LOOP ITERATION ** ---
    for (TimeOfDay time in scheduledTimes) { // Iterate over parsed times
    // --- ** END CORRECTION ** ---

      // Use the PARSED time (variable 'time' is non-nullable here)
      final tz.TZDateTime scheduledDateTime = _nextInstanceOfTime(time);
      // Generate ID based on med ID and the index in the *parsed* schedule
      final int uniqueNotificationId =
          _generateNotificationId(medication.id!, notificationIndex++);

      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          uniqueNotificationId, // Unique ID for this specific time slot
          'Time for your medication!', // Notification Title
          // Notification Body: Include name, dosage, and directions
          'Take ${medication.name}${medication.dosage != null && medication.dosage!.isNotEmpty ? ' (${medication.dosage})' : ''}. ${medication.directions ?? ""}',
          scheduledDateTime,
          platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode
              .exactAllowWhileIdle, // Crucial for exact timing on Android
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation
                  .absoluteTime, // Use absolute time
          matchDateTimeComponents:
              DateTimeComponents.time, // Match only time for daily recurrence
          payload:
              'med_id=${medication.id}&time=${time.hour}:${time.minute}', // Optional payload for handling taps
        );
        debugPrint(
            'Scheduled notification $uniqueNotificationId for ${medication.name} at $scheduledDateTime');
      } catch (e) {
        debugPrint('Error scheduling notification $uniqueNotificationId: $e');
      }
    }
  }

  // --- Helper to calculate next occurrence of a time ---
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    // If the scheduled time today is in the past, schedule it for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // --- Helper to generate unique but predictable IDs ---
  // ID is based on medication ID and the index within the scheduled times list
  int _generateNotificationId(String medicationId, int index) {
    // Combine medication ID hash and index to create a unique ID
    // Using hashCode is simple but can have collisions, though unlikely for this scale.
    // Ensure the result fits within a 32-bit integer range for Android.
    final String combinedId = '${medicationId}_$index';
    int hashCode = combinedId.hashCode;
    // Keep it within 31 bits (positive range of signed 32-bit int)
    return hashCode & 0x7FFFFFFF;
  }

  // --- Cancel Notifications (MODIFIED) ---
  Future<void> cancelMedicationNotifications(String medicationId) async {
    if (!_initialized) {
      debugPrint("Notification Service not initialized. Cannot cancel.");
      return;
    }
    if (medicationId.isEmpty) {
      debugPrint("Cannot cancel notifications: Medication ID is empty.");
      return;
    }
    // Since we don't know the exact number of notifications scheduled without
    // parsing the frequency again, we guess a reasonable maximum number
    // of potential indices and try cancelling them.
    // A more robust solution would store the generated IDs when scheduling.
    debugPrint(
        "Attempting to cancel notifications for med ID: $medicationId (guessing indices)");
    const int maxPotentialNotifications =
        10; // Assume max 10 doses/notifications per day for cancellation
    for (int i = 0; i < maxPotentialNotifications; i++) {
      final int potentialId = _generateNotificationId(medicationId, i);
      try {
        await flutterLocalNotificationsPlugin.cancel(potentialId);
        // debugPrint("Cancelled potential notification ID: $potentialId");
      } catch (e) {
        // Ignore errors, as the ID might not exist if fewer notifications were scheduled
        // debugPrint("Note: Error cancelling potential notification $potentialId: $e");
      }
    }
    // Alternatively, cancel all notifications if that's acceptable:
    // await flutterLocalNotificationsPlugin.cancelAll();
    // debugPrint("Cancelled ALL notifications.");
  }
}
