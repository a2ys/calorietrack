/// The app's own small server (a Cloudflare Worker, see proxy/README.md):
/// photo logging and the barcode products friends share. Its URL and token
/// are baked in at build time (--dart-define-from-file=photo_proxy.json);
/// without them both features quietly step aside.
abstract final class AppProxy {
  static const url = String.fromEnvironment('PHOTO_PROXY_URL');
  static const token = String.fromEnvironment('PHOTO_PROXY_TOKEN');

  static bool get isConfigured => url.isNotEmpty && token.isNotEmpty;

  static Map<String, String> headers(String installId) => {
        'Authorization': 'Bearer $token',
        'X-Install-Id': installId,
        'content-type': 'application/json',
      };
}
