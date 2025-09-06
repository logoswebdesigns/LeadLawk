import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/email_templates_provider.dart';
import '../providers/email_templates_api_provider.dart';
import '../widgets/email_template_dialog.dart';
import '../widgets/email_settings_dialog.dart';
import '../widgets/sales_pitch_modal.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
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
          child: Padding(padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Section
                Card(
                  child: Padding(padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
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
                            color: Colors.white.withValues(alpha: 0.6),
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
                        title: 'Sales Pitches',
                        subtitle: 'Manage your sales pitch templates',
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
        child: Padding(padding: const EdgeInsets.all(16),
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
                        color: Colors.white.withValues(alpha: 0.6),
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
      color: Colors.white.withValues(alpha: 0.1),
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
    SalesPitchModal.show(context);
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
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, color: Colors.teal, size: 28),
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
                      icon: const Icon(Icons.add_circle, color: AppTheme.primaryGold),
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
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No email templates yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add templates to quickly send emails to leads',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showAddTemplateDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Template'),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: template.description != null
                                ? Text(
                                    template.description!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  color: Colors.teal,
                                  onPressed: () => _showEditTemplateDialog(context, template),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () => _confirmDeleteTemplate(context, ref, template),
                                ),
                              ],
                            ),
                            children: [
                              Padding(padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subject:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      template.subject,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Body:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      template.body,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Available variables: {{businessName}}, {{location}}, {{industry}}, {{phone}}, {{rating}}, {{reviewCount}}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.teal.withValues(alpha: 0.7),
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
        title: const Text(
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
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintText: 'e.g., Follow-up After Call',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                    borderSide: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintText: 'Brief description of when to use',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                    borderSide: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Email Subject *',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintText: 'e.g., Following up - {{businessName}}',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                    borderSide: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bodyController,
                decoration: InputDecoration(
                  labelText: 'Email Body *',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintText: 'Email content...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                    borderSide: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                  ),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 8,
              ),
              const SizedBox(height: 8),
              Text(
                'Variables: {{businessName}}, {{location}}, {{industry}}, {{phone}}, {{rating}}, {{reviewCount}}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, _) => ElevatedButton(
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
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Template added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Add Template'),
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
        title: const Text(
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
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Email Subject *',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bodyController,
                decoration: InputDecoration(
                  labelText: 'Email Body *',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
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
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 8,
              ),
              const SizedBox(height: 8),
              Text(
                'Variables: {{businessName}}, {{location}}, {{industry}}, {{phone}}, {{rating}}, {{reviewCount}}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, _) => ElevatedButton(
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
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Template updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save Changes'),
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
        title: const Text(
          'Delete Template?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${template.name}"?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(emailTemplatesApiProvider.notifier).deleteTemplate(template.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Template deleted'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}