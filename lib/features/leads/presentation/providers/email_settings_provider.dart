import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailSettings {
  final bool enabled;
  final String? smtpHost;
  final int? smtpPort;
  final String? smtpUsername;
  final String? smtpPassword;
  final bool useSSL;
  final String? senderEmail;
  final String? senderName;
  
  EmailSettings({
    this.enabled = false,
    this.smtpHost,
    this.smtpPort,
    this.smtpUsername,
    this.smtpPassword,
    this.useSSL = false,
    this.senderEmail,
    this.senderName,
  });
  
  EmailSettings copyWith({
    bool? enabled,
    String? smtpHost,
    int? smtpPort,
    String? smtpUsername,
    String? smtpPassword,
    bool? useSSL,
    String? senderEmail,
    String? senderName,
  }) {
    return EmailSettings(
      enabled: enabled ?? this.enabled,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpUsername: smtpUsername ?? this.smtpUsername,
      smtpPassword: smtpPassword ?? this.smtpPassword,
      useSSL: useSSL ?? this.useSSL,
      senderEmail: senderEmail ?? this.senderEmail,
      senderName: senderName ?? this.senderName,
    );
  }
  
  // Common SMTP presets
  static EmailSettings gmailPreset(String email, String appPassword) {
    return EmailSettings(
      enabled: true,
      smtpHost: 'smtp.gmail.com',
      smtpPort: 587,
      smtpUsername: email,
      smtpPassword: appPassword,
      useSSL: false,
      senderEmail: email,
      senderName: 'LeadLoq CRM',
    );
  }
  
  static EmailSettings outlookPreset(String email, String password) {
    return EmailSettings(
      enabled: true,
      smtpHost: 'smtp-mail.outlook.com',
      smtpPort: 587,
      smtpUsername: email,
      smtpPassword: password,
      useSSL: false,
      senderEmail: email,
      senderName: 'LeadLoq CRM',
    );
  }
}

class EmailSettingsNotifier extends StateNotifier<EmailSettings> {
  EmailSettingsNotifier() : super(EmailSettings()) {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    state = EmailSettings(
      enabled: prefs.getBool('email_enabled') ?? false,
      smtpHost: prefs.getString('email_smtp_host'),
      smtpPort: prefs.getInt('email_smtp_port'),
      smtpUsername: prefs.getString('email_smtp_username'),
      smtpPassword: prefs.getString('email_smtp_password'),
      useSSL: prefs.getBool('email_use_ssl') ?? false,
      senderEmail: prefs.getString('email_sender_email'),
      senderName: prefs.getString('email_sender_name') ?? 'LeadLoq CRM',
    );
  }
  
  Future<void> updateSettings(EmailSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('email_enabled', settings.enabled);
    if (settings.smtpHost != null) {
      await prefs.setString('email_smtp_host', settings.smtpHost!);
    }
    if (settings.smtpPort != null) {
      await prefs.setInt('email_smtp_port', settings.smtpPort!);
    }
    if (settings.smtpUsername != null) {
      await prefs.setString('email_smtp_username', settings.smtpUsername!);
    }
    if (settings.smtpPassword != null) {
      await prefs.setString('email_smtp_password', settings.smtpPassword!);
    }
    await prefs.setBool('email_use_ssl', settings.useSSL);
    if (settings.senderEmail != null) {
      await prefs.setString('email_sender_email', settings.senderEmail!);
    }
    if (settings.senderName != null) {
      await prefs.setString('email_sender_name', settings.senderName!);
    }
    
    state = settings;
  }
  
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove('email_enabled');
    await prefs.remove('email_smtp_host');
    await prefs.remove('email_smtp_port');
    await prefs.remove('email_smtp_username');
    await prefs.remove('email_smtp_password');
    await prefs.remove('email_use_ssl');
    await prefs.remove('email_sender_email');
    await prefs.remove('email_sender_name');
    
    state = EmailSettings();
  }
}

final emailSettingsProvider = StateNotifierProvider<EmailSettingsNotifier, EmailSettings>((ref) {
  return EmailSettingsNotifier();
});