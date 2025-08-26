import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _salesPitch = '';

  @override
  void initState() {
    super.initState();
    _loadSalesPitch();
  }

  Future<void> _loadSalesPitch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _salesPitch = prefs.getString('sales_pitch') ?? _getDefaultSalesPitch();
    });
  }

  Future<void> _saveSalesPitch(String pitch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sales_pitch', pitch);
    setState(() {
      _salesPitch = pitch;
    });
  }

  String _getDefaultSalesPitch() {
    return '''Hi there! I noticed your business online and wanted to reach out about something that could really help you stand out from your competition.

I specialize in creating professional websites for local businesses like yours. A great website can help you:
• Attract more customers online
• Look more professional and trustworthy  
• Show up better in Google searches
• Give customers an easy way to contact you

I'd love to show you some examples of websites I've built for other businesses in your area. Would you be interested in a quick 10-minute call to discuss how a professional website could help grow your business?

Thanks for your time!''';
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.surfaceDark,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              'Account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: false,
            titlePadding: EdgeInsets.only(left: 16, bottom: 16),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: AppTheme.primaryGold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Logos Web Designs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lead Generation Pro',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Account Settings
                Card(
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        icon: Icons.campaign_outlined,
                        title: 'Sales Pitch',
                        subtitle: 'Edit your default sales pitch template',
                        onTap: () => _showSalesPitchEditor(context),
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Manage your notification preferences',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.security_outlined,
                        title: 'Privacy & Security',
                        subtitle: 'Control your privacy settings',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.storage_outlined,
                        title: 'Data Management',
                        subtitle: 'Export or delete your data',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // App Settings
                Card(
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        subtitle: 'Customize the app theme',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.language_outlined,
                        title: 'Language',
                        subtitle: 'English (US)',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        subtitle: 'Get help and contact support',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // About
                Card(
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        icon: Icons.info_outline,
                        title: 'About LeadLoq',
                        subtitle: 'Version 1.0.0',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.article_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Read our terms and conditions',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: AppTheme.mediumGray,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppTheme.mediumGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.1),
      indent: 56,
    );
  }

  void _showSalesPitchEditor(BuildContext context) {
    final controller = TextEditingController(text: _salesPitch);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Edit Sales Pitch'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _saveSalesPitch(controller.text);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sales pitch saved!')),
                    );
                  }
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Sales Pitch Template',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This template will be displayed on all lead detail pages. Customize it to match your business and services.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your sales pitch here...',
                      hintStyle: TextStyle(
                        color: Colors.grey.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.03),
                    ),
                    cursorColor: AppTheme.primaryGold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        controller.text = _getDefaultSalesPitch();
                      },
                      child: const Text(
                        'Reset to Default',
                        style: TextStyle(color: AppTheme.mediumGray),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${controller.text.length} characters',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}