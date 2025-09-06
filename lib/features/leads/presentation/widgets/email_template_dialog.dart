import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/lead.dart';
import '../providers/email_templates_provider.dart';

class EmailTemplateDialog extends ConsumerStatefulWidget {
  final Lead lead;

  const EmailTemplateDialog({
    super.key,
    required this.lead,
  });

  @override
  ConsumerState<EmailTemplateDialog> createState() => _EmailTemplateDialogState();
}

class _EmailTemplateDialogState extends ConsumerState<EmailTemplateDialog> {
  final _emailController = TextEditingController();
  EmailTemplate? _selectedTemplate;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(emailTemplatesProvider);

    return Dialog(
      backgroundColor: AppTheme.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.email,
                    color: Colors.teal,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Send Email',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Business Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.lead.businessName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Email field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Recipient Email *',
                  hintText: 'Enter client email address',
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.teal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.teal),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email address';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Template selection
              Text(
                'Select Email Template',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),
              
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: templates.isEmpty
                    ? _buildNoTemplatesMessage()
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          final isSelected = _selectedTemplate?.id == template.id;
                          
                          return Padding(padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedTemplate = template;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.teal.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected 
                                        ? Colors.teal 
                                        : Colors.white.withValues(alpha: 0.1),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected 
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      size: 20,
                                      color: isSelected 
                                          ? Colors.teal
                                          : Colors.white.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            template.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (template.description != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              template.description!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white.withValues(alpha: 0.6),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedTemplate != null ? _sendEmail : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send, size: 18),
                        SizedBox(width: 8),
                        Text('Send Email'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoTemplatesMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.orange,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'No Email Templates',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create email templates in the Account page to use this feature',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text;
    final template = _selectedTemplate!;
    
    // Process template with lead data
    String subject = _processTemplate(template.subject, widget.lead);
    String body = _processTemplate(template.body, widget.lead);
    
    // Create mailto URL
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQueryParameters(<String, String>{
        'subject': subject,
        'body': body,
      }),
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        Navigator.of(context).pop();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening email client...'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open email client: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _processTemplate(String template, Lead lead) {
    // Basic lead information
    String processed = template
        .replaceAll('{{businessName}}', lead.businessName)
        .replaceAll('{{location}}', lead.location)
        .replaceAll('{{industry}}', lead.industry)
        .replaceAll('{{phone}}', lead.phone)
        .replaceAll('{{rating}}', lead.rating?.toStringAsFixed(1) ?? 'N/A')
        .replaceAll('{{reviewCount}}', lead.reviewCount?.toString() ?? '0')
        .replaceAll('{{website}}', lead.websiteUrl ?? 'No website')
        .replaceAll('{{hasWebsite}}', lead.hasWebsite ? 'Yes' : 'No');
    
    // PageSpeed scores
    processed = processed
        .replaceAll('{{mobileScore}}', lead.pagespeedMobileScore?.toString() ?? 'Not tested')
        .replaceAll('{{desktopScore}}', lead.pagespeedDesktopScore?.toString() ?? 'Not tested')
        .replaceAll('{{mobilePerformance}}', lead.pagespeedMobilePerformance?.toStringAsFixed(1) ?? 'N/A')
        .replaceAll('{{desktopPerformance}}', lead.pagespeedDesktopPerformance?.toStringAsFixed(1) ?? 'N/A');
    
    // Core Web Vitals
    processed = processed
        .replaceAll('{{fcpTime}}', _formatSeconds(lead.pagespeedFirstContentfulPaint))
        .replaceAll('{{lcpTime}}', _formatSeconds(lead.pagespeedLargestContentfulPaint))
        .replaceAll('{{clsScore}}', lead.pagespeedCumulativeLayoutShift?.toStringAsFixed(3) ?? 'N/A')
        .replaceAll('{{tbtTime}}', _formatMilliseconds(lead.pagespeedTotalBlockingTime))
        .replaceAll('{{ttiTime}}', _formatSeconds(lead.pagespeedTimeToInteractive))
        .replaceAll('{{speedIndex}}', _formatSeconds(lead.pagespeedSpeedIndex));
    
    // Other PageSpeed scores
    processed = processed
        .replaceAll('{{accessibilityScore}}', lead.pagespeedAccessibilityScore?.toString() ?? 'N/A')
        .replaceAll('{{bestPracticesScore}}', lead.pagespeedBestPracticesScore?.toString() ?? 'N/A')
        .replaceAll('{{seoScore}}', lead.pagespeedSeoScore?.toString() ?? 'N/A');
    
    // Complex template markers
    processed = processed
        .replaceAll('[PAGESPEED_SUMMARY]', _generatePageSpeedSummary(lead))
        .replaceAll('[PAGESPEED_DETAILS]', _generatePageSpeedDetails(lead))
        .replaceAll('[PERFORMANCE_ISSUES]', _generatePerformanceIssues(lead))
        .replaceAll('[IMPROVEMENT_AREAS]', _generateImprovementAreas(lead));
    
    return processed;
  }
  
  String _formatSeconds(double? seconds) {
    if (seconds == null) return 'N/A';
    return '${seconds.toStringAsFixed(1)}s';
  }
  
  String _formatMilliseconds(double? ms) {
    if (ms == null) return 'N/A';
    return '${ms.toStringAsFixed(0)}ms';
  }
  
  String _generatePageSpeedSummary(Lead lead) {
    if (lead.pagespeedMobileScore == null && lead.pagespeedDesktopScore == null) {
      return 'PageSpeed testing not performed yet';
    }
    
    final mobileScore = lead.pagespeedMobileScore ?? 0;
    final desktopScore = lead.pagespeedDesktopScore ?? 0;
    
    String performance = 'needs improvement';
    if (mobileScore >= 90 && desktopScore >= 90) {
      performance = 'excellent';
    } else if (mobileScore >= 50 && desktopScore >= 50) {
      performance = 'moderate';
    }
    
    return '''Your website's performance is $performance:
• Mobile Score: $mobileScore/100
• Desktop Score: $desktopScore/100''';
  }
  
  String _generatePageSpeedDetails(Lead lead) {
    if (lead.pagespeedMobileScore == null && lead.pagespeedDesktopScore == null) {
      return 'No PageSpeed data available';
    }
    
    return '''PageSpeed Analysis Results:

Performance Scores:
• Mobile: ${lead.pagespeedMobileScore ?? 'N/A'}/100
• Desktop: ${lead.pagespeedDesktopScore ?? 'N/A'}/100

Core Web Vitals:
• First Contentful Paint: ${_formatSeconds(lead.pagespeedFirstContentfulPaint)}
• Largest Contentful Paint: ${_formatSeconds(lead.pagespeedLargestContentfulPaint)}
• Cumulative Layout Shift: ${lead.pagespeedCumulativeLayoutShift?.toStringAsFixed(3) ?? 'N/A'}
• Total Blocking Time: ${_formatMilliseconds(lead.pagespeedTotalBlockingTime)}

Additional Metrics:
• Accessibility: ${lead.pagespeedAccessibilityScore ?? 'N/A'}/100
• Best Practices: ${lead.pagespeedBestPracticesScore ?? 'N/A'}/100
• SEO: ${lead.pagespeedSeoScore ?? 'N/A'}/100''';
  }
  
  String _generatePerformanceIssues(Lead lead) {
    List<String> issues = [];
    
    // Check mobile score
    if (lead.pagespeedMobileScore != null && lead.pagespeedMobileScore! < 50) {
      issues.add('• Poor mobile performance (${lead.pagespeedMobileScore}/100)');
    }
    
    // Check desktop score
    if (lead.pagespeedDesktopScore != null && lead.pagespeedDesktopScore! < 50) {
      issues.add('• Poor desktop performance (${lead.pagespeedDesktopScore}/100)');
    }
    
    // Check LCP
    if (lead.pagespeedLargestContentfulPaint != null && lead.pagespeedLargestContentfulPaint! > 2.5) {
      issues.add('• Slow page loading (LCP: ${_formatSeconds(lead.pagespeedLargestContentfulPaint)})');
    }
    
    // Check FCP
    if (lead.pagespeedFirstContentfulPaint != null && lead.pagespeedFirstContentfulPaint! > 1.8) {
      issues.add('• Slow initial content display (FCP: ${_formatSeconds(lead.pagespeedFirstContentfulPaint)})');
    }
    
    // Check CLS
    if (lead.pagespeedCumulativeLayoutShift != null && lead.pagespeedCumulativeLayoutShift! > 0.1) {
      issues.add('• Layout stability issues (CLS: ${lead.pagespeedCumulativeLayoutShift?.toStringAsFixed(3)})');
    }
    
    // Check TBT
    if (lead.pagespeedTotalBlockingTime != null && lead.pagespeedTotalBlockingTime! > 200) {
      issues.add('• High blocking time (${_formatMilliseconds(lead.pagespeedTotalBlockingTime)})');
    }
    
    // Check Accessibility
    if (lead.pagespeedAccessibilityScore != null && lead.pagespeedAccessibilityScore! < 90) {
      issues.add('• Accessibility improvements needed (${lead.pagespeedAccessibilityScore}/100)');
    }
    
    // Check SEO
    if (lead.pagespeedSeoScore != null && lead.pagespeedSeoScore! < 90) {
      issues.add('• SEO optimization required (${lead.pagespeedSeoScore}/100)');
    }
    
    if (issues.isEmpty) {
      return 'Your website is performing well with no major issues detected.';
    }
    
    return 'Key issues identified:\n${issues.join('\n')}';
  }
  
  String _generateImprovementAreas(Lead lead) {
    List<String> improvements = [];
    
    // Based on scores, suggest improvements
    if (lead.pagespeedMobileScore != null && lead.pagespeedMobileScore! < 90) {
      improvements.add('• Optimize for mobile devices');
    }
    
    if (lead.pagespeedLargestContentfulPaint != null && lead.pagespeedLargestContentfulPaint! > 2.5) {
      improvements.add('• Reduce server response times');
      improvements.add('• Optimize images and lazy load content');
    }
    
    if (lead.pagespeedTotalBlockingTime != null && lead.pagespeedTotalBlockingTime! > 200) {
      improvements.add('• Minimize JavaScript execution time');
      improvements.add('• Break up long tasks');
    }
    
    if (lead.pagespeedCumulativeLayoutShift != null && lead.pagespeedCumulativeLayoutShift! > 0.1) {
      improvements.add('• Reserve space for dynamic content');
      improvements.add('• Avoid inserting content above existing content');
    }
    
    if (lead.pagespeedAccessibilityScore != null && lead.pagespeedAccessibilityScore! < 90) {
      improvements.add('• Improve alt text for images');
      improvements.add('• Ensure proper heading structure');
    }
    
    if (improvements.isEmpty) {
      return 'Your website is well-optimized!';
    }
    
    return 'Recommended improvements:\n${improvements.join('\n')}';
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}

// Email Template Model
class EmailTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmailTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subject': subject,
    'body': body,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory EmailTemplate.fromJson(Map<String, dynamic> json) => EmailTemplate(
    id: json['id'],
    name: json['name'],
    subject: json['subject'],
    body: json['body'],
    description: json['description'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  factory EmailTemplate.fromApiJson(Map<String, dynamic> json) => EmailTemplate(
    id: json['id'],
    name: json['name'],
    subject: json['subject'],
    body: json['body'],
    description: json['description'],
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}