import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/config/env.dart';
import 'core/push/class_notifications.dart';

void main() {
  // En la web, URLs sin "#": los links de invitación (/invitacion/{código})
  // abren directo la pantalla correcta.
  usePathUrlStrategy();
  // Push con botones que llegan con la app cerrada (Android/iOS).
  if (!kIsWeb && Env.hasFirebase) {
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
  }
  LicenseRegistry.addLicense(_fontLicenses);
  runApp(const ProviderScope(retry: apiRetry, child: App()));
}

/// Licencias OFL de las tipografías de la marca, que van dentro de la app.
Stream<LicenseEntry> _fontLicenses() async* {
  for (final (family, file) in [
    ('Baloo 2', 'OFL-Baloo2.txt'),
    ('Nunito Sans', 'OFL-NunitoSans.txt'),
  ]) {
    final text = await rootBundle.loadString('assets/fonts/$file');
    yield LicenseEntryWithLineBreaks([family], text);
  }
}
