import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Opens WhatsApp directly with a pre-filled message for the given phone number.
  /// Works with both WhatsApp and WhatsApp Business.
  static Future<bool> sendDirectMessage({
    required String phoneNumber,
    required String message,
  }) async {
    // Clean phone number (remove +, spaces, dashes)
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add default country code (91 for India) if not present
    if (!cleanNumber.startsWith('91') && cleanNumber.length == 10) {
      cleanNumber = '91$cleanNumber';
    }

    final String encodedMsg = Uri.encodeComponent(message);
    
    // Try native WhatsApp URL scheme first
    final Uri whatsappNativeUri = Uri.parse('whatsapp://send?phone=$cleanNumber&text=$encodedMsg');
    
    // Fallback web link
    final Uri whatsappWebUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanNumber&text=$encodedMsg');

    try {
      if (await canLaunchUrl(whatsappNativeUri)) {
        return await launchUrl(whatsappNativeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(whatsappWebUri)) {
        return await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
      } else {
        return false;
      }
    } catch (e) {
      print('WhatsApp launch error: $e');
      return false;
    }
  }

  /// Format attendance report message for parent
  static String formatAttendanceMessage({
    required String studentName,
    required String status,
    required String time,
    required String date,
    required String madrasaName,
  }) {
    final emoji = status == 'Present' ? '✅' : (status == 'Late' ? '⚠️' : '❌');
    return '''
*${madrasaName.toUpperCase()} - ATTENDANCE ALERT* $emoji

Dear Parent,

Attendance update for *$studentName*:
📅 Date: $date
⏰ Time: $time
STATUS: *$status*

Thank you,
*Administration*
''';
  }
}
