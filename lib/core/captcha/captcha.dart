import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';

/// Prueba de que hay una persona (Cloudflare Turnstile, invisible) antes de
/// pedir un código por WhatsApp o correo. La API lo exige si la plataforma lo
/// tiene configurado.
abstract class Captcha {
  /// Token para mandar como `captcha_token`; null si no hay captcha
  /// configurado (desarrollo).
  Future<String?> token();
}

class TurnstileCaptcha implements Captcha {
  const TurnstileCaptcha(this.siteKey, this.baseUrl);

  final String siteKey;
  final String baseUrl;

  @override
  Future<String?> token() async {
    final turnstile = CloudflareTurnstile.invisible(
      siteKey: siteKey,
      baseUrl: baseUrl,
    );
    try {
      return await turnstile.getToken();
    } catch (_) {
      // La API responde "Confirmá que no sos un robot." si hacía falta.
      return null;
    } finally {
      turnstile.dispose();
    }
  }
}

class NoCaptcha implements Captcha {
  const NoCaptcha();

  @override
  Future<String?> token() async => null;
}

/// Reemplazable en los tests.
final captchaProvider = Provider<Captcha>(
  (ref) => Env.turnstileSiteKey.isEmpty
      ? const NoCaptcha()
      : const TurnstileCaptcha(Env.turnstileSiteKey, Env.turnstileBaseUrl),
);
