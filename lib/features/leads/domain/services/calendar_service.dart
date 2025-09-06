import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:enough_icalendar/enough_icalendar.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/lead.dart';
import '../../../../core/utils/debug_logger.dart';

class CalendarService {
  static const String _senderEmail = 'logoswebdesigninfo@gmail.com';
  static const String _senderName = 'LeadLoq CRM';
  
  /// Add event to native calendar app
  static Future<bool> addToNativeCalendar({
    required Lead lead,
    required DateTime callbackDateTime,
    String? notes,
  }) async {
    try {
      // Check platform support
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        // Mobile platforms - use add_2_calendar
        final Event event = Event(
          title: 'Callback: ${lead.businessName}',
          description: _buildEventDescription(lead, notes),
          location: lead.location,
          startDate: callbackDateTime,
          endDate: callbackDateTime.add(const Duration(minutes: 30)),
          allDay: false,
          iosParams: const IOSParams(
            reminder: Duration(minutes: 15),
          ),
          androidParams: const AndroidParams(
            emailInvites: [],
          ),
        );
        
        final result = await Add2Calendar.addEvent2Cal(event);
        return result;
      } else {
        // Desktop/Web platforms - create and download ICS file
        final icsFile = await createICSFile(
          lead: lead,
          callbackDateTime: callbackDateTime,
          notes: notes,
          recipientEmail: null,
        );
        
        // For desktop, open the ICS file which will prompt to add to calendar
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          final uri = Uri.file(icsFile.path);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            return true;
          }
        }
        
        DebugLogger.log('Platform does not support direct calendar integration');
        return false;
      }
    } catch (e) {
      DebugLogger.error('Error adding to native calendar: $e');
      return false;
    }
  }
  
  /// Create ICS file for calendar invite
  static Future<File> createICSFile({
    required Lead lead,
    required DateTime callbackDateTime,
    String? notes,
    String? recipientEmail,
  }) async {
    // Use the convenient createEvent method
    final attendees = recipientEmail != null && recipientEmail.isNotEmpty
        ? [recipientEmail]
        : <String>[];
    
    final calendar = VCalendar.createEvent(
      organizerEmail: _senderEmail,
      attendeeEmails: attendees,
      rsvp: true,
      start: callbackDateTime,
      end: callbackDateTime.add(const Duration(minutes: 30)),
      location: lead.location,
      summary: 'Callback: ${lead.businessName}',
      description: _buildEventDescription(lead, notes),
      productId: 'LeadLoq CRM/v1',
      method: Method.request,
      uid: 'leadloq-${lead.id}-${DateTime.now().millisecondsSinceEpoch}@leadloq.com',
    );
    
    // Save ICS file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/callback_${lead.id}.ics');
    await file.writeAsString(calendar.toString());
    
    return file;
  }
  
  /// Send calendar invite via email
  static Future<bool> sendCalendarInvite({
    required Lead lead,
    required DateTime callbackDateTime,
    required String recipientEmail,
    String? notes,
    String? smtpHost,
    int? smtpPort,
    String? smtpUsername,
    String? smtpPassword,
  }) async {
    try {
      // Create ICS file
      final icsFile = await createICSFile(
        lead: lead,
        callbackDateTime: callbackDateTime,
        notes: notes,
        recipientEmail: recipientEmail,
      );
      
      // Configure SMTP (use Gmail as default example)
      final smtpServer = smtpHost != null
          ? SmtpServer(
              smtpHost,
              port: smtpPort ?? 587,
              username: smtpUsername,
              password: smtpPassword,
              ssl: false,
              allowInsecure: true,
            )
          : gmail(smtpUsername ?? '', smtpPassword ?? '');
      
      // Create email message
      final message = Message()
        ..from = const Address(_senderEmail, _senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Callback Scheduled: ${lead.businessName}'
        ..text = _buildEmailText(lead, callbackDateTime, notes)
        ..html = _buildEmailHtml(lead, callbackDateTime, notes)
        ..attachments.add(FileAttachment(icsFile)
          ..contentType = 'text/calendar; charset=UTF-8; method=REQUEST'
          ..fileName = 'invite.ics');
      
      // Send email
      final sendReport = await send(message, smtpServer);
      DebugLogger.log('Calendar invite sent: ${sendReport.toString()}');
      
      // Clean up temp file
      await icsFile.delete();
      
      return true;
    } catch (e) {
      DebugLogger.error('Error sending calendar invite: $e');
      return false;
    }
  }
  
  static String _buildEventDescription(Lead lead, String? notes) {
    return '''
Business: ${lead.businessName}
Phone: ${lead.phone}
Location: ${lead.location}
${lead.websiteUrl != null ? 'Website: ${lead.websiteUrl}\n' : ''}
${lead.rating != null ? 'Rating: ${lead.rating} ⭐\n' : ''}
${notes != null && notes.isNotEmpty ? '\nNotes:\n$notes' : ''}

---
Scheduled via LeadLoq CRM
''';
  }
  
  static String _buildEmailText(Lead lead, DateTime callbackDateTime, String? notes) {
    return '''
Hello ${lead.businessName},

This is a confirmation that we have scheduled a callback for:
Date: ${_formatDateTime(callbackDateTime)}

Business Details:
- Name: ${lead.businessName}
- Phone: ${lead.phone}
- Location: ${lead.location}

${notes != null && notes.isNotEmpty ? 'Notes: $notes\n' : ''}

Please add this event to your calendar using the attached invitation.

Best regards,
LeadLoq Team
''';
  }
  
  static String _buildEmailHtml(Lead lead, DateTime callbackDateTime, String? notes) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #FFD700; padding: 20px; border-radius: 8px 8px 0 0; }
    .content { background-color: #f9f9f9; padding: 20px; border-radius: 0 0 8px 8px; }
    .details { background-color: white; padding: 15px; border-radius: 8px; margin: 15px 0; }
    h2 { color: #333; margin-top: 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h2>Callback Scheduled</h2>
    </div>
    <div class="content">
      <p>Hello <strong>${lead.businessName}</strong>,</p>
      <p>This is a confirmation that we have scheduled a callback for:</p>
      <div class="details">
        <strong>📅 Date & Time:</strong> ${_formatDateTime(callbackDateTime)}<br>
        <strong>📍 Location:</strong> ${lead.location}<br>
        <strong>📞 Phone:</strong> ${lead.phone}<br>
        ${notes != null && notes.isNotEmpty ? '<strong>📝 Notes:</strong> $notes<br>' : ''}
      </div>
      <p>Please add this event to your calendar using the attached invitation.</p>
      <p>Best regards,<br><strong>LeadLoq Team</strong></p>
    </div>
    <div class="footer">
      Sent via LeadLoq CRM - Lead Management System
    </div>
  </div>
</body>
</html>
''';
  }
  
  static String _formatDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $hour:$minute $period';
  }
}