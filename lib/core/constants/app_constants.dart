/// Application-wide constants
class AppConstants {
  // App Information
  static const String appName = 'SpendTracker';
  static const String appSubtitle = 'SMS Money Manager';
  
  // SMS Constants
  static const int maxSmsToLoad = 10;
  static const String smsDateFormat = 'MMM dd, yyyy HH:mm';
  
  // Permission Messages
  static const String smsPermissionTitle = 'SMS Permission Required';
  static const String smsPermissionMessage = 
      'This app needs SMS permission to read your transaction messages. '
      'Your messages will only be processed locally on your device.';
  
  // Error Messages
  static const String permissionDeniedError = 'SMS permission was denied';
  static const String smsReadError = 'Failed to read SMS messages';
  static const String generalError = 'An unexpected error occurred';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
}
