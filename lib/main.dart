import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/main_scaffold.dart';
import 'features/leads/presentation/pages/leads_list_page.dart';
import 'features/leads/presentation/pages/lead_detail_page.dart';
import 'features/leads/presentation/pages/lead_search_page.dart';
import 'features/leads/presentation/pages/automation_monitor_page.dart';
import 'features/leads/presentation/pages/server_diagnostics_page.dart';
import 'features/leads/presentation/pages/account_page.dart';
import 'features/analytics/presentation/pages/analytics_page.dart';
import 'features/leads/presentation/providers/automation_form_provider.dart';
import 'features/leads/presentation/providers/server_status_provider.dart';
import 'features/leads/presentation/providers/lead_monitor_provider.dart';
import 'features/leads/presentation/services/pagespeed_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        automationFormProvider.overrideWith(
          (ref) => AutomationFormNotifier(prefs),
        ),
      ],
      child: const LeadLoqApp(),
    ),
  );
}

class LeadLoqApp extends ConsumerStatefulWidget {
  const LeadLoqApp({super.key});

  @override
  ConsumerState<LeadLoqApp> createState() => _LeadLoqAppState();
}

class _LeadLoqAppState extends ConsumerState<LeadLoqApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    
    // Initialize notification service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notificationService = ref.read(pageSpeedNotificationServiceProvider);
        notificationService.initialize(context);
      }
    });

    // Create the router once so route state isn't reset on rebuilds.
    _router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/',
              redirect: (context, state) => '/leads',
            ),
            GoRoute(
              path: '/leads',
              builder: (context, state) {
                final filter = state.uri.queryParameters['filter'];
                return LeadsListPage(initialFilter: filter);
              },
            ),
            GoRoute(
              path: '/leads/:id',
              builder: (context, state) {
                final leadId = state.pathParameters['id']!;
                return LeadDetailPage(leadId: leadId);
              },
            ),
            GoRoute(
              path: '/browser',
              builder: (context, state) => const LeadSearchPage(),
            ),
            GoRoute(
              path: '/browser/monitor/:jobId',
              builder: (context, state) {
                final jobId = state.pathParameters['jobId']!;
                return AutomationMonitorPage(jobId: jobId);
              },
            ),
            GoRoute(
              path: '/analytics',
              builder: (context, state) => const AnalyticsPage(),
            ),
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountPage(),
            ),
            GoRoute(
              path: '/server',
              builder: (context, state) => const ServerDiagnosticsPage(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen without rebuilding the app on status polls.
    ref.listen(serverStatusProvider, (_, __) {});
    
    // Listen for new leads and show toast notifications
    ref.listen(leadMonitorProvider, (previous, next) {
      if (next.isNotEmpty && context.mounted) {
        for (final lead in next) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.business, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'New lead added: ${lead.businessName}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    });
    
    return MaterialApp.router(
      title: 'LeadLoq',
      theme: AppTheme.lightTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
