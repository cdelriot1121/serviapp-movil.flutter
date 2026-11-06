import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviapp/core/theme/app_theme.dart';
import 'package:serviapp/features/auth/presentation/views/recuperar_contrasena_screen.dart';
import 'package:serviapp/features/auth/presentation/views/registro_screen.dart';

Widget _app(Widget pantalla) => MaterialApp(theme: AppTheme.lightTheme, home: pantalla);

void main() {
  testWidgets('el registro pide nombre, correo y una contraseña segura', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const RegistroScreen()));

    await tester.tap(find.text('Verificar correo'));
    await tester.pump();

    expect(find.text('Ingresa tu nombre completo'), findsOneWidget);
    expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
    expect(find.text('La contraseña no cumple todos los requisitos'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo'), 'Ana123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'ana@correo');
    await tester.pump();
    expect(find.text('Usa solo letras y espacios'), findsOneWidget);
    expect(find.text('Revisa tu correo, parece que no está bien escrito'), findsOneWidget);
  });

  testWidgets('los requisitos de la contraseña se marcan mientras se escribe', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const RegistroScreen()));

    Finder chequeado(String requisito) => find.descendant(
          of: find.ancestor(of: find.text(requisito), matching: find.byType(Row)),
          matching: find.byIcon(Icons.check_circle_rounded),
        );

    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'segura12');
    await tester.pumpAndSettle();
    expect(chequeado('Mínimo 8 caracteres'), findsOneWidget);
    expect(chequeado('Al menos un número'), findsOneWidget);
    expect(chequeado('Al menos una mayúscula'), findsNothing);
    expect(chequeado('Al menos un carácter especial'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Segura#12');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
  });

  testWidgets('recuperar contraseña trae el correo del login y lo valida', (tester) async {
    await tester.pumpWidget(_app(const RecuperarContrasenaScreen(email: 'ana@correo.com')));

    expect(find.text('ana@correo.com'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('Enviar enlace'));
    await tester.pump();
    expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
  });
}
