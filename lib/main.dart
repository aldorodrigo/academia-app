import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';

void main() {
  // En la web, URLs sin "#": los links de invitación (/invitacion/{código})
  // abren directo la pantalla correcta.
  usePathUrlStrategy();
  runApp(const ProviderScope(child: App()));
}
