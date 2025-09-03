import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/email_templates_provider.dart';
import '../providers/email_templates_api_provider.dart';
import '../widgets/email_template_dialog.dart';
import '../widgets/email_settings_dialog.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
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
    return '''Hey, is this [BUSINESS NAME]?

Awesome! My name is [YOUR NAME] and I'm actually a [YOUR BACKGROUND - e.g., stay-at-home parent, freelance] web developer. I found you on Google and took a look at your site - it's a pretty standard WordPress site that could use some work, and I wanted to call and see if I can help make you something better.

[If they don't have a website: "I found you on Google but didn't see a website anywhere, so I wanted to call and see if you needed any help with one."]

When they ask about cost:

I do things a little different - I charge \$0 down and \$150 a month. That includes hosting, unlimited edits, 24/7 support, lifetime updates, analytics, help with your Google Profile, the works. I do everything for you so you never have to worry about it. 6 month minimum contract and month-to-month after that, cancel anytime.

What makes my work different:

I custom code everything line by line - no page builders. This makes your site load instantly and makes Google happy. Google's core vitals update heavily favors mobile performance and speed in search rankings. Right now, your site scores around 30-40 out of 100 - that's terrible for ranking. My sites score 98-100 and are literally as fast as they can be.

Page builders have bloated code, are prone to hacking, and have very messy code. My sites are custom-built to convert traffic into customers by satisfying Google's metrics and making the best performing mobile site possible with keyword-rich content.

For every second of load time, you lose customers who didn't want to wait. When it loads instantly, people stay and convert instead of leaving.

I also use website conversion funnels - there's a specific order you place content and how you write it that guides visitors into a sale. You can't just throw whatever up and expect it to work. It's all calculated, purposeful, and deliberate. I even hire a copywriter to write all your content with keyword research designed to get picked up in search engines and get people to contact you.

When they ask about the monthly fee:

Think about it this way - if the website brings in just one new customer a month, it more than pays for itself. If it brings in 10 or more, imagine that return. The website becomes an asset to your business. That \$150 isn't just the site cost - it's access to me. It's a retainer to call me with any questions and make all your edits. It's peace of mind - I'm here for you so you don't waste time figuring this stuff out when you could be making money instead.

When you cancel, you keep your domain, but the design and code stay with me. You'd have to start over with someone else, which means you'll be 6 months behind where you could have been. It takes 6-12 months for Google to properly rank your site, so after six months you'll start seeing results and want to stick around.

I'm looking for people who understand websites are a long-term investment, not a turnkey product. If you don't see yourself sticking around long-term or aren't 100% committed to improving your online presence, I might not be the right fit. I don't want to waste your time and money if you aren't 100% committed.

The Process:
1. I send a contract to get signed electronically
2. First invoice for this month's work, then \$150 auto-bills on the 1st each month
3. I email you questions about your business and send design examples
4. My designer creates something unique based on your preferences
5. We review the design together and make any changes
6. I code it, optimize everything to score 98-100, add analytics, and set it live

What questions do you have about any of this?''';
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
                        icon: Icons.email_outlined,
                        title: 'Email Templates',
                        subtitle: 'Manage email templates for lead outreach',
                        onTap: () => _showEmailTemplatesManager(context),
                      ),
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.mail_lock_outlined,
                        title: 'Email Settings',
                        subtitle: 'Configure SMTP for sending calendar invites',
                        onTap: () => _showEmailSettings(context),
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

  void _showEmailSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EmailSettingsDialog(),
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
                      onPressed: () async {
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

  void _showEmailTemplatesManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: Colors.teal, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Email Templates',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: AppTheme.primaryGold),
                      onPressed: () => _showAddTemplateDialog(context),
                    ),
                  ],
                ),
              ),
              // Templates list
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final templates = ref.watch(emailTemplatesProvider);
                    
                    if (templates.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No email templates yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add templates to quickly send emails to leads',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showAddTemplateDialog(context),
                              icon: Icon(Icons.add),
                              label: Text('Add Template'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGold,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppTheme.elevatedSurface,
                          child: ExpansionTile(
                            title: Text(
                              template.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: template.description != null
                                ? Text(
                                    template.description!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, size: 20),
                                  color: Colors.teal,
                                  onPressed: () => _showEditTemplateDialog(context, template),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () => _confirmDeleteTemplate(context, ref, template),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subject:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      template.subject,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Body:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      template.body,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Available variables: {{businessName}}, {{location}}, {{industry}}, {{phone}}, {{rating}}, {{reviewCount}}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.teal.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTemplateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: Text(
          'Add Email Template',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Template Name *',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintText: 'e.g., Follow-up After Call',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.5)),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintText: 'Brief description of when to use',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.5)),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Email Subject *',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintText: 'e.g., Following up - {{businessName}}',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.5)),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bodyController,
                decoration: InputDecoration(
                  labelText: 'Email Body *',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintText: 'Email content...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.5)),
                  ),
                  alignLabelWithHint: true,
                ),
                style: TextStyle(color: Colors.white),
                maxLines: 8,
              ),
              const SizedBox(height: 8),
              Text(
                'Variables: {{businessName}}, {{location}}, {{industry}}, {{phone}}, {{rating}}, {{reviewCount}}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, child) => ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    subjectController.text.isNotEmpty &&
                    bodyController.text.isNotEmpty) {
                  final template = EmailTemplate(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    subject: subjectController.text,
                    body: bodyController.text,
                    description: descriptionController.text.isNotEmpty 
                        ? descriptionController.text 
                        : null,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await ref.read(emailTemplatesApiProvider.notifier).addTemplate(template);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Template added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
              ),
              child: Text('Add Template'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditTemplateDialog(BuildContext context, EmailTemplate template) {
    final nameController = TextEditingController(text: template.name);
    final subjectController = TextEditingController(text: template.subject);
    final bodyController = TextEditingController(text: template.body);
    final descriptionController = TextEditingController(text: template.description);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: Text(
          'Edit Email Template',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Template Name *',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Email Subject *',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bodyController,
                decoration: InputDecoration(
                  labelText: 'Email Body *',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
                  ),
                  alignLabelWithHint: true,
                ),
                style: TextStyle(color: Colors.white),
                maxLines: 8,
              ),
              const SizedBox(height: 8),
              Text(
                'Variables: {{businessName}}, {{location}}, {{industry}}, {{phone}}, {{rating}}, {{reviewCount}}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, child) => ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    subjectController.text.isNotEmpty &&
                    bodyController.text.isNotEmpty) {
                  final updatedTemplate = EmailTemplate(
                    id: template.id,
                    name: nameController.text,
                    subject: subjectController.text,
                    body: bodyController.text,
                    description: descriptionController.text.isNotEmpty 
                        ? descriptionController.text 
                        : null,
                    createdAt: template.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  await ref.read(emailTemplatesApiProvider.notifier).updateTemplate(updatedTemplate);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Template updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
              ),
              child: Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTemplate(BuildContext context, WidgetRef ref, EmailTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedSurface,
        title: Text(
          'Delete Template?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${template.name}"?',
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(emailTemplatesApiProvider.notifier).deleteTemplate(template.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Template deleted'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}