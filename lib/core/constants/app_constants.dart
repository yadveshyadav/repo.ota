/// Application-wide string constants and metadata for HERO APP.
abstract class AppConstants {
  static const String appName = 'HERO APP';
  static const String appPackage = 'com.infocrats.heroapp';
  static const String appVersion = '1.0.5';

  // Branding Taglines
  static const String taglineLine1 = 'Smart Operations.';
  static const String taglineLine2 = 'Stronger Performance.';

  // Auth Strings
  static const String welcomeBack = 'Welcome back';
  static const String signInSubtitle = 'Sign in to continue to HERO APP';
  static const String emailOrUsernameLabel = 'Email or Username';
  static const String emailOrUsernameHint = 'Enter your email or username';
  static const String passwordLabel = 'Password';
  static const String passwordHint = 'Enter your password';
  static const String rememberMe = 'Remember me';
  static const String forgotPassword = 'Forgot Password?';
  static const String signInButton = 'Sign In';

  // Validation Messages
  static const String emailRequired = 'Please enter your email or username';
  static const String passwordRequired = 'Please enter your password';

  // Messages
  static const String authFutureNotice =
      'Authentication connected successfully.';
  static const String forgotPasswordNotice =
      'Password reset link sent to your registered email.';

  // Splash Config (Minimum Display Duration in ms)
  static const int splashDurationMs = 3200;

  // Base URLs & API Endpoints
  static const String devApiBaseUrl = 'https://dev.ilync.tech';
  static const String uatApiBaseUrl = 'https://uat.ilync.tech';
  static const String prodApiBaseUrl = 'https://ilync.tech';

  /// Set with `--dart-define=ILYNC_ENV=dev|uat|prod`.
  /// Defaults to UAT so ordinary local/release builds retain current behavior.
  static const String ilyncEnvironment = String.fromEnvironment(
    'ILYNC_ENV',
    defaultValue: 'uat',
  );
  static const bool ilyncIsDev = ilyncEnvironment == 'dev';
  static const bool ilyncIsProd = ilyncEnvironment == 'prod';
  static const String ilyncApiBaseUrl = ilyncIsDev
      ? devApiBaseUrl
      : ilyncIsProd
      ? prodApiBaseUrl
      : uatApiBaseUrl;
  static const String productionAuthBaseUrl = 'https://hero.pramaanu.co.in';
  //static const String defaultBaseUrl = 'https://27qxnvkh-3000.inc1.devtunnels.ms';
  static const String defaultBaseUrl = 'https://hero.pramaanu.co.in';
  static const String attendanceBaseUrl = 'https://hero.pramaanu.co.in';
  static const String machinesEndpoint = '/api/v1/machines/';
  static const String machinesFallbackEndpoint =
      'https://hero.pramaanu.co.in/api/v1/machines/';
  static const String vendorsEndpoint = '/api/v1/integrations/vendors/';
}
