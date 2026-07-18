abstract final class AppPaths {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const emailVerification = '/auth/verify-email';
  static const resetPassword = '/auth/reset-password';
  static const roleSelection = '/onboarding/role';
  static const customerOnboarding = '/onboarding/customer';
  static const repairerOnboarding = '/onboarding/repairer';
  static const customerHome = '/customer/home';
  static const repairRequestCategory = '/customer/requests/new/category';
  static const repairRequestItem = '/customer/requests/new/item';
  static const repairRequestProblem = '/customer/requests/new/problem';
  static const repairRequestEvidence = '/customer/requests/new/evidence';
  static const repairRequestReview = '/customer/requests/new/review';
  static const repairRequestPublish = '/customer/requests/new/submit';
  static const repairRequestConfirmation =
      '/customer/requests/new/confirmation';
  static const repairerDashboard = '/repairer/dashboard';
  static const repairerRequests = '/repairer/requests';
  static const repairerRequest = '/repairer/requests/:requestId';
  static const repairerQuote = '/repairer/requests/:requestId/quote';
  static const repairerQuotes = '/repairer/quotes';
  static const repairerProfile = '/repairers/:repairerId';
  static const aiAssessment = '/customer/requests/:requestId/assessment';
  static const customerQuoteComparison = '/customer/requests/:requestId/quotes';

  static String aiAssessmentFor(String requestId) =>
      '/customer/requests/$requestId/assessment';

  static String repairerRequestFor(String requestId) =>
      '/repairer/requests/$requestId';

  static String repairerQuoteFor(String requestId) =>
      '/repairer/requests/$requestId/quote';

  static String customerQuoteComparisonFor(String requestId) =>
      '/customer/requests/$requestId/quotes';

  static String repairerProfileFor(String repairerId) =>
      '/repairers/$repairerId';

  static String repairRequestStep(int index) => switch (index) {
    0 => repairRequestCategory,
    1 => repairRequestItem,
    2 => repairRequestProblem,
    3 => repairRequestEvidence,
    4 => repairRequestReview,
    _ => repairRequestPublish,
  };
}
