import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
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
  runApp(const ProviderScope(child: App()));
}
