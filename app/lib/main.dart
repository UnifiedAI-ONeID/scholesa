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
import 'offline/offline_queue.dart';
import 'offline/sync_coordinator.dart';
import 'router/app_router.dart';
import 'services/api_client.dart';
import 'services/firestore_service.dart';
import 'services/session_bootstrap.dart';
import 'services/telemetry_service.dart';
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
        // HQ Admin services - uses authenticated user for audit logging
        ChangeNotifierProxyProvider<AppState, UserAdminService>(
          create: (_) => UserAdminService(),
          update: (_, AppState appState, UserAdminService? previous) {
            return UserAdminService(
              currentUserId: appState.userId,
              currentUserEmail: appState.email,
            );
          },
        ),
        // Site Check-in services - uses authenticated user's site
        ChangeNotifierProxyProvider<AppState, CheckinService>(
          create: (_) => CheckinService(),
          update: (_, AppState appState, CheckinService? previous) {
            return CheckinService(
              siteId: appState.activeSiteId,
            );
          },
        ),
        // Learner Missions services - uses authenticated user's ID
        ChangeNotifierProxyProvider<AppState, MissionService>(
          create: (_) => MissionService(),
          update: (_, AppState appState, MissionService? previous) {
            return MissionService(
              learnerId: appState.userId,
            );
          },
        ),
        // Learner Habits services - uses authenticated user's ID
        ChangeNotifierProxyProvider<AppState, HabitService>(
          create: (_) => HabitService(),
          update: (_, AppState appState, HabitService? previous) {
            return HabitService(learnerId: appState.userId);
          },
        ),
        // Messages services - uses authenticated user's ID
        ChangeNotifierProxyProvider<AppState, MessageService>(
          create: (_) => MessageService(),
          update: (_, AppState appState, MessageService? previous) {
            return MessageService(userId: appState.userId);
          },
        ),
        // Parent services - uses authenticated user's ID
        ChangeNotifierProxyProvider<AppState, ParentService>(
          create: (_) => ParentService(),
          update: (_, AppState appState, ParentService? previous) {
            return ParentService(parentId: appState.userId);
          },
        ),
        // Educator services - uses authenticated user's ID
        ChangeNotifierProxyProvider<AppState, EducatorService>(
          create: (_) => EducatorService(),
          update: (_, AppState appState, EducatorService? previous) {
            return EducatorService(
              educatorId: appState.userId,
            );
          },
        ),
        // Attendance services - uses authenticated user's ID and site
        ChangeNotifierProxyProvider<AppState, AttendanceService>(
          create: (_) => AttendanceService(syncCoordinator: _syncCoordinator),
          update: (_, AppState appState, AttendanceService? previous) {
            return AttendanceService(
              syncCoordinator: _syncCoordinator,
              educatorId: appState.userId,
              siteId: appState.activeSiteId,
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
