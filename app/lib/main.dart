import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/src/router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import 'app_config.dart';
import 'auth/app_state.dart';
import 'auth/auth_service.dart';
import 'firebase_options.dart';
import 'modules/attendance/attendance_service.dart';
import 'modules/checkin/checkin.dart';
import 'modules/educator/educator.dart';
import 'modules/habits/habits.dart';
import 'modules/hq_admin/hq_admin.dart';
import 'modules/messages/messages.dart';
import 'modules/missions/missions.dart';
import 'modules/parent/parent.dart';
import 'modules/partner/partner.dart';
import 'modules/provisioning/provisioning_service.dart';
import 'modules/site/incident_service.dart';
import 'offline/offline_queue.dart';
import 'offline/sync_coordinator.dart';
import 'router/app_router.dart';
import 'services/ai_draft_service.dart';
import 'services/api_client.dart';
import 'services/billing_service.dart';
import 'services/cms_service.dart';
import 'services/curriculum_service.dart';
import 'services/export_service.dart';
import 'services/firestore_service.dart';
import 'services/identity_service.dart';
import 'services/insights_service.dart';
import 'services/integration_service.dart';
import 'services/marketplace_service.dart';
import 'services/notification_service.dart';
import 'services/popup_service.dart';
import 'services/portfolio_service.dart';
import 'services/scheduling_service.dart';
import 'services/session_bootstrap.dart';
import 'services/telemetry_service.dart';
import 'services/safety_service.dart';
import 'services/audit_log_service.dart';
import 'services/approval_service.dart';
import 'ui/theme/scholesa_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  await Hive.initFlutter();

  // Initialize Firebase with proper configuration
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure emulators if enabled
  if (AppConfig.useEmulators) {
    try {
      final List<String> authParts = AppConfig.authEmulatorHost.split(':');
      await FirebaseAuth.instance.useAuthEmulator(
        authParts[0],
        int.parse(authParts[1]),
      );
    } catch (e) {
      debugPrint('Failed to connect to auth emulator: $e');
    }
  }

  runApp(const ScholesaApp());
}

class ScholesaApp extends StatefulWidget {
  const ScholesaApp({super.key});

  @override
  State<ScholesaApp> createState() => _ScholesaAppState();
}

class _ScholesaAppState extends State<ScholesaApp> {
  late final AppState _appState;
  late final ApiClient _apiClient;
  late final FirestoreService _firestoreService;
  late final OfflineQueue _offlineQueue;
  late final SyncCoordinator _syncCoordinator;
  late final AuthService _authService;
  late final SessionBootstrap _sessionBootstrap;
  late final TelemetryService _telemetryService;

  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Create core services
      _appState = AppState();
      _apiClient = ApiClient();
      _firestoreService = FirestoreService();
      _offlineQueue = OfflineQueue();
      _telemetryService = TelemetryService();
      
      // Initialize offline queue
      await _offlineQueue.init();
      
      _syncCoordinator = SyncCoordinator(
        queue: _offlineQueue,
        apiClient: _apiClient,
      );
      await _syncCoordinator.init();

      _authService = AuthService(
        auth: FirebaseAuth.instance,
        appState: _appState,
        telemetryService: _telemetryService,
      );

      _sessionBootstrap = SessionBootstrap(
        auth: FirebaseAuth.instance,
        appState: _appState,
      );

      // Bootstrap session if user is already logged in
      await _sessionBootstrap.initialize();

      // Start listening to auth changes
      _sessionBootstrap.listenToAuthChanges();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('App initialization failed: $e');
      setState(() {
        _initError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _apiClient.dispose();
    _syncCoordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return MaterialApp(
        home: _ErrorBootstrapScreen(
          error: _initError!,
          onRetry: () {
            setState(() {
              _initError = null;
              _isInitialized = false;
            });
            _initializeApp();
          },
        ),
      );
    }

    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading Scholesa...'),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider.value(value: _appState),
        ChangeNotifierProvider.value(value: _syncCoordinator),
        Provider.value(value: _apiClient),
        Provider.value(value: _firestoreService),
        Provider.value(value: _authService),
        Provider.value(value: _telemetryService),
        // HQ Admin services - uses authenticated user for audit logging (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, UserAdminService>(
          create: (_) => UserAdminService(telemetryService: _telemetryService),
          update: (_, AppState appState, UserAdminService? previous) {
            return UserAdminService(
              currentUserId: appState.userId,
              currentUserEmail: appState.email,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Site Check-in services - uses authenticated user's site
        ChangeNotifierProxyProvider<AppState, CheckinService>(
          create: (_) => CheckinService(telemetryService: _telemetryService),
          update: (_, AppState appState, CheckinService? previous) {
            return CheckinService(
              siteId: appState.activeSiteId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Learner Missions services - uses authenticated user's ID
        ChangeNotifierProxyProvider<AppState, MissionService>(
          create: (_) => MissionService(telemetryService: _telemetryService),
          update: (_, AppState appState, MissionService? previous) {
            return MissionService(
              learnerId: appState.userId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Learner Habits services - uses authenticated user's ID
        ChangeNotifierProxyProvider<AppState, HabitService>(
          create: (_) => HabitService(telemetryService: _telemetryService),
          update: (_, AppState appState, HabitService? previous) {
            return HabitService(
              learnerId: appState.userId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Messages services - uses authenticated user's ID
        ChangeNotifierProxyProvider<AppState, MessageService>(
          create: (_) => MessageService(telemetryService: _telemetryService),
          update: (_, AppState appState, MessageService? previous) {
            return MessageService(
              userId: appState.userId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Parent services - uses authenticated user's ID (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, ParentService>(
          create: (_) => ParentService(telemetryService: _telemetryService),
          update: (_, AppState appState, ParentService? previous) {
            return ParentService(
              parentId: appState.userId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Provisioning services - site admin user/guardian management (✅ telemetry)
        ChangeNotifierProvider<ProvisioningService>(
          create: (_) => ProvisioningService(telemetryService: _telemetryService),
        ),
        // Educator services - uses authenticated user's ID (✅ telemetry for insights/supports)
        ChangeNotifierProxyProvider<AppState, EducatorService>(
          create: (_) => EducatorService(telemetryService: _telemetryService),
          update: (_, AppState appState, EducatorService? previous) {
            return EducatorService(
              educatorId: appState.userId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Attendance services - uses authenticated user's ID and site
        ChangeNotifierProxyProvider<AppState, AttendanceService>(
          create: (_) => AttendanceService(
            syncCoordinator: _syncCoordinator,
            telemetryService: _telemetryService,
          ),
          update: (_, AppState appState, AttendanceService? previous) {
            return AttendanceService(
              syncCoordinator: _syncCoordinator,
              educatorId: appState.userId,
              siteId: appState.activeSiteId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Partner services - uses authenticated user's ID (✅ telemetry for deliverables/payouts)
        ChangeNotifierProxyProvider<AppState, PartnerService>(
          create: (_) => PartnerService(partnerId: '', telemetryService: _telemetryService),
          update: (_, AppState appState, PartnerService? previous) {
            return PartnerService(
              partnerId: appState.userId ?? '',
              telemetryService: _telemetryService,
            );
          },
        ),
        // Popup/Nudge services - micro-coaching engine (docs/21)
        ChangeNotifierProxyProvider<AppState, PopupService>(
          create: (_) => PopupService(telemetryService: _telemetryService),
          update: (_, AppState appState, PopupService? previous) {
            return PopupService(
              userId: appState.userId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Insights services - teacher support insights (docs/23)
        ChangeNotifierProxyProvider<AppState, InsightsService>(
          create: (_) => InsightsService(telemetryService: _telemetryService),
          update: (_, AppState appState, InsightsService? previous) {
            return InsightsService(
              educatorId: appState.userId,
              siteId: appState.activeSiteId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Incident services - uses authenticated user's ID and site (✅ telemetry for safety)
        ChangeNotifierProxyProvider<AppState, IncidentService>(
          create: (_) => IncidentService(telemetryService: _telemetryService),
          update: (_, AppState appState, IncidentService? previous) {
            return IncidentService(
              userId: appState.userId,
              siteId: appState.activeSiteId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Export services - audit/compliance (docs/43) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, ExportService>(
          create: (_) => ExportService(telemetryService: _telemetryService),
          update: (_, AppState appState, ExportService? previous) {
            return ExportService(
              userId: appState.userId,
              siteId: appState.activeSiteId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Identity services - matching/resolution (docs/46) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, IdentityService>(
          create: (_) => IdentityService(telemetryService: _telemetryService),
          update: (_, AppState appState, IdentityService? previous) {
            return IdentityService(
              userId: appState.userId,
              siteId: appState.activeSiteId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Scheduling services - calendar/rooms (docs/44) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, SchedulingService>(
          create: (_) => SchedulingService(telemetryService: _telemetryService),
          update: (_, AppState appState, SchedulingService? previous) {
            return SchedulingService(
              userId: appState.userId,
              siteId: appState.activeSiteId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Curriculum services - versioning/rubrics (docs/45) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, CurriculumService>(
          create: (_) => CurriculumService(telemetryService: _telemetryService),
          update: (_, AppState appState, CurriculumService? previous) {
            return CurriculumService(
              educatorId: appState.userId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Billing services - subscriptions/invoices (docs/13) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, BillingService>(
          create: (_) => BillingService(telemetryService: _telemetryService),
          update: (_, AppState appState, BillingService? previous) {
            return BillingService(
              userId: appState.userId,
              siteId: appState.activeSiteId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Marketplace services - listings/orders (docs/15) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, MarketplaceService>(
          create: (_) => MarketplaceService(telemetryService: _telemetryService),
          update: (_, AppState appState, MarketplaceService? previous) {
            return MarketplaceService(
              userId: appState.userId,
              partnerId: appState.role?.name == 'partner' ? appState.userId : null,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Notification services - in-app notifications (docs/17) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, NotificationService>(
          create: (_) => NotificationService(telemetryService: _telemetryService),
          update: (_, AppState appState, NotificationService? previous) {
            return NotificationService(
              userId: appState.userId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Portfolio services - learner portfolios (docs/47) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, PortfolioService>(
          create: (_) => PortfolioService(telemetryService: _telemetryService),
          update: (_, AppState appState, PortfolioService? previous) {
            return PortfolioService(
              learnerId: appState.role?.name == 'learner' ? appState.userId : null,
              telemetryService: _telemetryService,
            );
          },
        ),
        // AI Draft services - human-in-the-loop AI (docs/07) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, AiDraftService>(
          create: (_) => AiDraftService(telemetryService: _telemetryService),
          update: (_, AppState appState, AiDraftService? previous) {
            return AiDraftService(
              userId: appState.userId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
        // CMS services - marketing pages/leads (docs/14) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, CmsService>(
          create: (_) => CmsService(telemetryService: _telemetryService),
          update: (_, AppState appState, CmsService? previous) {
            return CmsService(
              userId: appState.userId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Integration services - Classroom/GitHub (docs/36) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, IntegrationService>(
          create: (_) => IntegrationService(telemetryService: _telemetryService),
          update: (_, AppState appState, IntegrationService? previous) {
            return IntegrationService(
              userId: appState.userId,
              siteId: appState.activeSiteId,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Safety services - consent/pickup (docs/41) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, SafetyService>(
          create: (_) => SafetyService(telemetryService: _telemetryService),
          update: (_, AppState appState, SafetyService? previous) {
            return SafetyService(
              userId: appState.userId,
              siteId: appState.activeSiteId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Audit Log services - compliance/exports (docs/43) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, AuditLogService>(
          create: (_) => AuditLogService(telemetryService: _telemetryService),
          update: (_, AppState appState, AuditLogService? previous) {
            return AuditLogService(
              userId: appState.userId,
              siteId: appState.activeSiteId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
        // Approval services - HQ approvals queue (docs/15,16) (✅ telemetry)
        ChangeNotifierProxyProvider<AppState, ApprovalService>(
          create: (_) => ApprovalService(telemetryService: _telemetryService),
          update: (_, AppState appState, ApprovalService? previous) {
            return ApprovalService(
              userId: appState.userId,
              userRole: appState.role?.name,
              telemetryService: _telemetryService,
            );
          },
        ),
      ],
      child: Consumer<AppState>(
        builder: (BuildContext context, AppState appState, _) {
          final GoRouter router = createAppRouter(appState);

          return MaterialApp.router(
            title: 'Scholesa',
            debugShowCheckedModeBanner: false,
            theme: ScholesaTheme.light,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

class _ErrorBootstrapScreen extends StatelessWidget {

  const _ErrorBootstrapScreen({
    required this.error,
    required this.onRetry,
  });
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to start Scholesa',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
