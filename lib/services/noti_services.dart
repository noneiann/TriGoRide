import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotiService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Initialize the plugin (call in main and in background handler)
  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@drawable/trigoridelogo1');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    // Request iOS permissions if needed
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Show a local notification
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/trigoridelogo1',
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  }

  /// Send SMS via Semaphore API
  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Ensure .env is loaded
      await dotenv.load(fileName: ".env");

      final apiKey = dotenv.env['SEMAPHORE_API_KEY'];

      print('🔍 Debug: Checking Semaphore API Key...');
      print('🔍 API Key exists: ${apiKey != null}');
      print('🔍 API Key empty: ${apiKey?.isEmpty ?? true}');

      if (apiKey == null || apiKey.isEmpty || apiKey.contains('YOUR_')) {
        print('⚠️ Semaphore API key not configured. Skipping SMS.');
        return false;
      }

      // Format phone number for Semaphore (09XXXXXXXXX format)
      String formattedNumber = phoneNumber.trim();
      print('🔍 Original phone number: $phoneNumber');

      // Remove +63 prefix if present
      if (formattedNumber.startsWith('+63')) {
        formattedNumber = '0${formattedNumber.substring(3)}';
      }
      // Remove 63 prefix if present (without +)
      else if (formattedNumber.startsWith('63') &&
          !formattedNumber.startsWith('0')) {
        formattedNumber = '0${formattedNumber.substring(2)}';
      }
      // Ensure it starts with 0
      else if (!formattedNumber.startsWith('0')) {
        formattedNumber = '0$formattedNumber';
      }

      print('🔍 Formatted phone number: $formattedNumber');
      print('🔍 Message length: ${message.length} characters');

      final response = await http.post(
        Uri.parse('https://api.semaphore.co/api/v4/messages'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'apikey': apiKey,
          'number': formattedNumber,
          'message': message,
          'senderName': 'TriGoRide',
        },
      );

      print('🔍 SMS API Response Status: ${response.statusCode}');
      print('🔍 SMS API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print('🔍 Decoded response data: $responseData');

          // Semaphore returns an array of message objects
          if (responseData is List && responseData.isNotEmpty) {
            final firstMessage = responseData[0];
            final status = firstMessage['status']?.toString();
            final messageId = firstMessage['message_id']?.toString();
            final recipient = firstMessage['recipient']?.toString();

            print('🔍 SMS Message ID: $messageId');
            print('🔍 SMS Recipient: $recipient');
            print('🔍 SMS Status: $status');

            // According to Semaphore docs, valid statuses are:
            // "Queued", "Pending", "Sent" = Success
            // "Failed", "Refunded" = Failure
            if (status == 'Queued' || status == 'Pending' || status == 'Sent') {
              print(
                  '✅ SMS sent successfully to $formattedNumber via Semaphore (Status: $status, ID: $messageId)');
              return true;
            } else if (status == 'Failed' || status == 'Refunded') {
              print('❌ SMS failed with status: $status');
              print('❌ SMS full response: ${response.body}');
              return false;
            } else {
              // Unknown status, but HTTP 200 received
              print('⚠️ Unknown SMS status: $status - treating as success');
              return true;
            }
          } else {
            print(
                '⚠️ Unexpected response format (not array), but HTTP 200 - assuming success');
            return true;
          }
        } catch (e) {
          print('⚠️ Error parsing response, but HTTP 200 received: $e');
          // If we got HTTP 200 but can't parse, assume it worked
          return true;
        }
      } else {
        print('❌ SMS failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ SMS error: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Send Email via SendGrid
  Future<bool> sendEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String htmlBody,
    String? plainTextBody,
  }) async {
    try {
      // Ensure .env is loaded
      await dotenv.load(fileName: ".env");

      final apiKey = dotenv.env['SENDGRID_API_KEY'];
      final fromEmail =
          dotenv.env['SENDGRID_FROM_EMAIL'] ?? 'innovisionprimetech@gmail.com';
      final fromName = dotenv.env['SENDGRID_FROM_NAME'] ?? 'TriGoRide';

      print('🔍 Debug: Checking SendGrid API Key...');
      print('🔍 API Key exists: ${apiKey != null}');

      if (apiKey == null || apiKey.isEmpty || apiKey.contains('YOUR_')) {
        print('⚠️ SendGrid API key not configured. Skipping email.');
        return false;
      }

      final response = await http.post(
        Uri.parse('https://api.sendgrid.com/v3/mail/send'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'personalizations': [
            {
              'to': [
                {'email': toEmail, 'name': toName}
              ],
              'subject': subject,
            }
          ],
          'from': {'email': fromEmail, 'name': fromName},
          'content': [
            {'type': 'text/plain', 'value': plainTextBody ?? htmlBody},
            {'type': 'text/html', 'value': htmlBody},
          ],
        }),
      );

      print('🔍 Email API Response Status: ${response.statusCode}');

      if (response.statusCode == 202) {
        print('✅ Email sent successfully to $toEmail');
        return true;
      } else {
        print('❌ Email failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Email error: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Send booking acceptance SMS to passenger
  Future<void> sendBookingAcceptedSMS({
    required String passengerPhone,
    required String passengerName,
    required String driverName,
    required String pickupLocation,
  }) async {
    final message = '''
Hello $passengerName!

Your ride has been accepted by $driverName.

Pickup: $pickupLocation

Driver is on the way. Track your ride in the TriGoRide app.

- TriGoRide Team
    '''
        .trim();

    await sendSMS(phoneNumber: passengerPhone, message: message);
  }

  /// Send ride completion email to passenger
  Future<void> sendRideCompletionEmail({
    required String passengerEmail,
    required String passengerName,
    required String driverName,
    required String pickupLocation,
    required String dropoffLocation,
    required double fare,
    required String bookingId,
  }) async {
    final htmlBody = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #FF9800; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background-color: #f9f9f9; padding: 30px; border: 1px solid #ddd; border-top: none; }
    .detail-row { margin: 15px 0; padding: 10px; background: white; border-radius: 5px; }
    .label { font-weight: bold; color: #FF9800; }
    .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
    .button { background-color: #FF9800; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1> 🛺 Ride Completed!</h1>
    </div>
    <div class="content">
      <p>Hi <strong>$passengerName</strong>,</p>
      
      <p>Thank you for riding with TriGoRide! Your trip has been completed successfully.</p>
      
      <div class="detail-row">
        <span class="label">Booking ID:</span> $bookingId
      </div>
      
      <div class="detail-row">
        <span class="label">Driver:</span> $driverName
      </div>
      
      <div class="detail-row">
        <span class="label">From:</span> $pickupLocation
      </div>
      
      <div class="detail-row">
        <span class="label">To:</span> $dropoffLocation
      </div>
      
      <div class="detail-row">
        <span class="label">Fare:</span> ₱${fare.toStringAsFixed(2)}
      </div>
      
      <p>We hope you had a great experience! Don't forget to rate your driver in the app.</p>
    </div>
    
    <div class="footer">
      <p>TriGoRide - Oroquieta City's Premier Tricycle Booking Service</p>
      <p>This is an automated message. Please do not reply to this email.</p>
    </div>
  </div>
</body>
</html>
    ''';

    final plainText = '''
Ride Completed - TriGoRide

Hi $passengerName,

Thank you for riding with TriGoRide! Your trip has been completed successfully.

Booking ID: $bookingId
Driver: $driverName
From: $pickupLocation
To: $dropoffLocation
Fare: ₱${fare.toStringAsFixed(2)}

We hope you had a great experience! Don't forget to rate your driver in the app.

- TriGoRide Team
Oroquieta City's Premier Tricycle Booking Service
    ''';

    await sendEmail(
      toEmail: passengerEmail,
      toName: passengerName,
      subject: '🚖 Your TriGoRide Trip Receipt - Booking #$bookingId',
      htmlBody: htmlBody,
      plainTextBody: plainText,
    );
  }
}
