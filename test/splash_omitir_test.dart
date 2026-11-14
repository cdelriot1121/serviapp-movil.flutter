import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/core/theme/app_theme.dart';
import 'package:serviapp/features/auth/presentation/views/login_screen.dart';
import 'package:serviapp/features/splash/presentation/views/splash_screen.dart';

void main() {
  testWidgets('el botón Omitir salta la intro y abre el login', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SplashScreen()),
    );
    // En los tests no hay audio: la intro arranca tras el tiempo de espera del sonido
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('Omitir'), findsOneWidget);
    final opacidad = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.text('Omitir'), matching: find.byType(AnimatedOpacity)),
    );
    expect(opacidad.opacity, 1);
    await tester.tap(find.text('Omitir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
