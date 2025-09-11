import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/email_settings_provider.dart';

class EmailSettingsDialog extends ConsumerStatefulWidget {
  const EmailSettingsDialog({super.key});

  @override
  ConsumerState<EmailSettingsDialog> createState() => _EmailSettingsDialogState();
}

class _EmailSettingsDialogState extends ConsumerState<EmailSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _senderEmailController;
  late TextEditingController _senderNameController;
  bool _useSSL = false;
  bool _enabled = true;
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(emailSettingsProvider);
    _hostController = TextEditingController(text: settings.smtpHost ?? 'smtp.gmail.com');
    _portController = TextEditingController(text: settings.smtpPort?.toString() ?? '587');
    _usernameController = TextEditingController(text: settings.smtpUsername ?? 'logoswebdesigninfo@gmail.com');
    _passwordController = TextEditingController(text: settings.smtpPassword ?? '');
    _senderEmailController = TextEditingController(text: settings.senderEmail ?? 'logoswebdesigninfo@gmail.com');
    _senderNameController = TextEditingController(text: settings.senderName ?? 'LeadLoq CRM');
    _useSSL = settings.useSSL;
    _enabled = settings.enabled;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _senderEmailController.dispose();
    _senderNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final settings = EmailSettings(
        enabled: _enabled,
        smtpHost: _hostController.text,
        smtpPort: int.tryParse(_portController.text),
        smtpUsername: _usernameController.text,
        smtpPassword: _passwordController.text,
        useSSL: _useSSL,
        senderEmail: _senderEmailController.text,
        senderName: _senderNameController.text,
      );

      await ref.read(emailSettingsProvider.notifier).updateSettings(settings);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email settings saved successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyGmailPreset() {
    setState(() {
      _hostController.text = 'smtp.gmail.com';
      _portController.text = '587';
      _useSSL = false;
      _usernameController.text = 'logoswebdesigninfo@gmail.com';
      _senderEmailController.text = 'logoswebdesigninfo@gmail.com';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: const Row(
        children: [
          Icon(Icons.email_outlined, color: AppTheme.primaryGold, size: 24),
          const SizedBox(width: 12),
          Text(
            'Email Settings',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Setup Buttons
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Setup',
                      style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _applyGmailPreset,
                          icon: Icon(Icons.email),
                          label: const Text('Gmail'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGold,
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Enable/Disable Toggle
              SwitchListTile(
                title: const Text(
                  'Enable Email Sending',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                activeColor: AppTheme.primaryGold,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              // SMTP Settings
              Text(
                'SMTP Configuration',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Host
              TextFormField(
                controller: _hostController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'SMTP Host',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  hintText: 'smtp.gmail.com',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Port
              TextFormField(
                controller: _portController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  hintText: '587',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Username
              TextFormField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Username (Email)',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  hintText: 'logoswebdesigninfo@gmail.com',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Password
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'App Password',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  hintText: 'Enter your app password',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 18,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // Instructions
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Gmail Setup Instructions',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Enable 2-Factor Authentication\n'
                      '2. Go to Google Account Settings\n'
                      '3. Security → 2-Step Verification → App passwords\n'
                      '4. Generate new app password for "Mail"\n'
                      '5. Copy the 16-character password here',
                      style: TextStyle(
                        color: Colors.blue.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGold,
            foregroundColor: Colors.black,
          ),
          child: _isLoading
              ? SizedBox(
        width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text('Save Settings'),
        ),
      ],
    );
  }
}