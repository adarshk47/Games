
/// App-wide constants shown in Profile (keep [version] in sync with pubspec.yaml).
class AppInfo {
  AppInfo._();
  static const name = 'Master G';
  static const version = '3.0.0';
  static const copyrightYear = 2026;
  static const brandUrl = 'https://mitrojan.in';

  /// "Our websites" links at the end of Profile (null = not live yet, hidden).
  static const List<(String emoji, String key, String? url)> websites = [
    ('🤝', 'home.site.mitrojan', 'https://mitrojan.in'),
  ];
  static const privacyUrl = 'https://adarshk47.github.io/Idealworld/master-g/privacy.html';
  static const deleteAccountUrl = 'https://adarshk47.github.io/Idealworld/master-g/delete-account.html';
}
