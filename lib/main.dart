import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/leads/presentation/pages/leads_list_page_v2.dart';
import 'features/leads/presentation/pages/lead_detail_page.dart';
import 'features/leads/presentation/pages/run_scrape_page.dart';
import 'features/leads/presentation/pages/scrape_monitor_page.dart';
import 'features/leads/presentation/pages/server_diagnostics_page.dart';
import 'features/leads/presentation/providers/scrape_form_provider.dart';
import 'features/leads/presentation/providers/server_status_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        scrapeFormProvider.overrideWith(
          (ref) => ScrapeFormNotifier(prefs),
        ),
      ],
      child: const LeadLawkApp(),
    ),
  );
}

class LeadLawkApp extends ConsumerStatefulWidget {
  const LeadLawkApp({super.key});

  @override
  ConsumerState<LeadLawkApp> createState() => _LeadLawkAppState();
}

class _LeadLawkAppState extends ConsumerState<LeadLawkApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    // Create the router once so route state isn't reset on rebuilds.
    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) => '/leads',
        ),
        GoRoute(
          path: '/leads',
          builder: (context, state) {
            final filter = state.uri.queryParameters['filter'];
            return LeadsListPageV2(initialFilter: filter);
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
          path: '/scrape',
          builder: (context, state) => const RunScrapePage(),
        ),
        GoRoute(
          path: '/scrape/monitor/:jobId',
          builder: (context, state) {
            final jobId = state.pathParameters['jobId']!;
            return ScrapeMonitorPage(jobId: jobId);
          },
        ),
        GoRoute(
          path: '/server',
          builder: (context, state) => const ServerDiagnosticsPage(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen without rebuilding the app on status polls.
    ref.listen(serverStatusProvider, (_, __) {});
    return MaterialApp.router(
      title: 'LeadLawk',
      theme: AppTheme.lightTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
