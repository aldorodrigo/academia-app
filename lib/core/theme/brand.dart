import 'package:flutter/material.dart';

/// Logo de Tuku: verde sobre fondos claros, blanco sobre el tema oscuro.
class TukuLogo extends StatelessWidget {
  const TukuLogo({super.key, this.width = 120});

  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark
          ? 'assets/images/tuku-logo-blanco.png'
          : 'assets/images/tuku-logo.png',
      width: width,
      semanticLabel: 'Tuku',
    );
  }
}

/// Pantalla mientras se carga la sesión: la misma que la pantalla de inicio
/// de Android, iOS y la web (Tuku en el centro), con un indicador debajo.
class TukuSplash extends StatelessWidget {
  const TukuSplash({super.key});

  static const _size = 160.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/tuku-splash.png',
            width: _size,
            height: _size,
            semanticLabel: 'Tuku',
          ),
          Transform.translate(
            offset: const Offset(0, _size / 2 + 40),
            child: const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ],
      ),
    );
  }
}
