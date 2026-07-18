import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/motion_tokens.dart';
import 'package:fixbrief/features/ai_assessment/presentation/screens/ai_assessment_screen.dart';
import 'package:fixbrief/features/authentication/presentation/controllers/auth_session_state.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/authentication/presentation/screens/email_verification_screen.dart';
import 'package:fixbrief/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:fixbrief/features/authentication/presentation/screens/login_screen.dart';
import 'package:fixbrief/features/authentication/presentation/screens/registration_screen.dart';
import 'package:fixbrief/features/authentication/presentation/screens/reset_password_screen.dart';
import 'package:fixbrief/features/authentication/presentation/screens/splash_screen.dart';
import 'package:fixbrief/features/authentication/presentation/screens/welcome_screen.dart';
import 'package:fixbrief/features/customer_home/presentation/screens/customer_home_screen.dart';
import 'package:fixbrief/features/onboarding/presentation/screens/customer_onboarding_screen.dart';
import 'package:fixbrief/features/onboarding/presentation/screens/repairer_onboarding_screen.dart';
import 'package:fixbrief/features/onboarding/presentation/screens/role_selection_screen.dart';
import 'package:fixbrief/features/quotes/presentation/screens/quote_comparison_screen.dart';
import 'package:fixbrief/features/quotes/presentation/screens/quote_editor_screen.dart';
import 'package:fixbrief/features/quotes/presentation/screens/repairer_quotes_screen.dart';
import 'package:fixbrief/features/repair_requests/presentation/screens/repair_request_confirmation_screen.dart';
import 'package:fixbrief/features/repair_requests/presentation/screens/repair_request_wizard_screen.dart';
import 'package:fixbrief/features/repairer_dashboard/presentation/screens/repairer_dashboard_screen.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/screens/marketplace_request_detail_screen.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/screens/matching_requests_screen.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/screens/repairer_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(WidgetRef ref) {
    _subscription = ref.listenManual<AuthSessionState>(
      authSessionControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthSessionState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

GoRouter buildAppRouter(WidgetRef ref, AuthRouterRefresh refresh) {
  return GoRouter(
    initialLocation: AppPaths.splash,
    refreshListenable: refresh,
    redirect: (context, routerState) {
      return _redirect(ref.read(authSessionControllerProvider), routerState);
    },
    routes: <RouteBase>[
      _route(AppPaths.splash, const SplashScreen()),
      _route(AppPaths.welcome, const WelcomeScreen()),
      _route(AppPaths.login, const LoginScreen()),
      _route(AppPaths.register, const RegistrationScreen()),
      _route(AppPaths.forgotPassword, const ForgotPasswordScreen()),
      _route(AppPaths.emailVerification, const EmailVerificationScreen()),
      _route(AppPaths.resetPassword, const ResetPasswordScreen()),
      _route(AppPaths.roleSelection, const RoleSelectionScreen()),
      _route(AppPaths.customerOnboarding, const CustomerOnboardingScreen()),
      _route(AppPaths.repairerOnboarding, const RepairerOnboardingScreen()),
      _route(AppPaths.customerHome, const CustomerHomeScreen()),
      _route(
        AppPaths.repairRequestCategory,
        const RepairRequestWizardScreen(step: RepairWizardStep.category),
      ),
      _route(
        AppPaths.repairRequestItem,
        const RepairRequestWizardScreen(step: RepairWizardStep.item),
      ),
      _route(
        AppPaths.repairRequestProblem,
        const RepairRequestWizardScreen(step: RepairWizardStep.problem),
      ),
      _route(
        AppPaths.repairRequestEvidence,
        const RepairRequestWizardScreen(step: RepairWizardStep.evidence),
      ),
      _route(
        AppPaths.repairRequestReview,
        const RepairRequestWizardScreen(step: RepairWizardStep.review),
      ),
      _route(
        AppPaths.repairRequestPublish,
        const RepairRequestWizardScreen(step: RepairWizardStep.publish),
      ),
      _route(
        AppPaths.repairRequestConfirmation,
        const RepairRequestConfirmationScreen(),
      ),
      _route(AppPaths.repairerDashboard, const RepairerDashboardScreen()),
      _route(AppPaths.repairerRequests, const MatchingRequestsScreen()),
      _route(AppPaths.repairerQuotes, const RepairerQuotesScreen()),
      GoRoute(
        path: AppPaths.repairerRequest,
        pageBuilder: (context, state) => _liquidPage(
          state: state,
          child: MarketplaceRequestDetailScreen(
            requestId: state.pathParameters['requestId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppPaths.repairerProfile,
        pageBuilder: (context, state) => _liquidPage(
          state: state,
          child: RepairerProfileScreen(
            repairerId: state.pathParameters['repairerId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppPaths.repairerQuote,
        pageBuilder: (context, state) => _liquidPage(
          state: state,
          child: QuoteEditorScreen(
            requestId: state.pathParameters['requestId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppPaths.aiAssessment,
        pageBuilder: (context, state) => _liquidPage(
          state: state,
          child: AiAssessmentScreen(
            requestId: state.pathParameters['requestId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppPaths.customerQuoteComparison,
        pageBuilder: (context, state) => _liquidPage(
          state: state,
          child: QuoteComparisonScreen(
            requestId: state.pathParameters['requestId']!,
          ),
        ),
      ),
    ],
  );
}

String? _redirect(AuthSessionState auth, GoRouterState state) {
  final location = state.matchedLocation;
  if (auth.phase == AuthSessionPhase.loading) {
    return location == AppPaths.splash ? null : AppPaths.splash;
  }

  if (auth.phase == AuthSessionPhase.signedOut) {
    if (location == AppPaths.splash) {
      return AppPaths.welcome;
    }
    if (location == AppPaths.emailVerification &&
        auth.pendingVerificationEmail != null) {
      return null;
    }
    if (_signedOutRoutes.contains(location)) {
      return null;
    }
    return Uri(
      path: AppPaths.login,
      queryParameters: <String, String>{'returnTo': state.uri.toString()},
    ).toString();
  }

  final user = auth.user!;
  if (auth.isPasswordRecovery) {
    return location == AppPaths.resetPassword ? null : AppPaths.resetPassword;
  }
  if (!user.emailVerified) {
    return location == AppPaths.emailVerification
        ? null
        : AppPaths.emailVerification;
  }

  final role = auth.onboarding.role;
  if (role == null) {
    return location == AppPaths.roleSelection ? null : AppPaths.roleSelection;
  }
  if (!auth.onboarding.allowsAppAccess) {
    final requiredPath = role == UserRole.customer
        ? AppPaths.customerOnboarding
        : AppPaths.repairerOnboarding;
    return location == requiredPath ? null : requiredPath;
  }

  if (role == UserRole.customer && _isRepairerOnlyPath(location)) {
    return AppPaths.customerHome;
  }
  if (role == UserRole.repairer && location.startsWith('/customer')) {
    return AppPaths.repairerDashboard;
  }

  if (_preAppRoutes.contains(location)) {
    final returnTo = state.uri.queryParameters['returnTo'];
    if (_isSafeReturnPath(returnTo, role)) {
      return returnTo;
    }
    return role == UserRole.customer
        ? AppPaths.customerHome
        : AppPaths.repairerDashboard;
  }
  return null;
}

bool _isSafeReturnPath(String? value, UserRole role) {
  if (value == null || value.length > 500 || !value.startsWith('/')) {
    return false;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasAuthority || value.startsWith('//')) {
    return false;
  }
  if (role == UserRole.customer && _isRepairerOnlyPath(uri.path)) {
    return false;
  }
  if (role == UserRole.repairer && uri.path.startsWith('/customer')) {
    return false;
  }
  return !_preAppRoutes.contains(uri.path);
}

bool _isRepairerOnlyPath(String path) =>
    path == '/repairer' || path.startsWith('/repairer/');

const _signedOutRoutes = <String>{
  AppPaths.welcome,
  AppPaths.login,
  AppPaths.register,
  AppPaths.forgotPassword,
};

const _preAppRoutes = <String>{
  AppPaths.splash,
  AppPaths.welcome,
  AppPaths.login,
  AppPaths.register,
  AppPaths.forgotPassword,
  AppPaths.emailVerification,
  AppPaths.resetPassword,
  AppPaths.roleSelection,
  AppPaths.customerOnboarding,
  AppPaths.repairerOnboarding,
};

GoRoute _route(String path, Widget child) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => _liquidPage(state: state, child: child),
  );
}

CustomTransitionPage<void> _liquidPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: MotionTokens.pageTransition,
    reverseTransitionDuration: MotionTokens.pageTransition,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableAnimations) {
        return child;
      }
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: MotionTokens.standardCurve,
        reverseCurve: MotionTokens.standardCurve.flipped,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
