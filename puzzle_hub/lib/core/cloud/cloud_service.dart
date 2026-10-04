/// Firebase (auth + Firestore sync). Must work without google-services.json:
/// then [available] is false and the app stays fully local.
class CloudService {
  CloudService._();

  static bool available = false;

  static Future<void> init() async {}
}
