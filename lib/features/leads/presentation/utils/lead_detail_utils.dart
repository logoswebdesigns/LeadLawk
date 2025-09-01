import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadDetailUtils {
  static void showFullScreenshot(BuildContext context, String screenshotPath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Image.network(
                  'http://localhost:8000/screenshots/$screenshotPath',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        'Failed to load screenshot',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  static Future<void> openWebsite(String url) async {
    Uri uri;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      uri = Uri.parse('https://$url');
    } else {
      uri = Uri.parse(url);
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> searchOnGoogle(String businessName) async {
    final query = Uri.encodeComponent(businessName);
    final Uri uri = Uri.parse('https://www.google.com/search?q=$query');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openGoogleMapsProfile(String profileUrl) async {
    final Uri uri = Uri.parse(profileUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}