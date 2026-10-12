import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import 'views/analizando_recibo_screen.dart';
import 'widgets/instrucciones_foto_sheet.dart';

/// Flujo completo de "Escanear recibo":
/// instrucciones → cámara → análisis (FastAPI) → revisión → guardado (Spring).
Future<void> iniciarEscaneoRecibo(BuildContext context) async {
  final fuente = await InstruccionesFotoSheet.mostrar(context);
  if (fuente == null || !context.mounted) return;

  final XFile? foto;
  try {
    foto = await ImagePicker().pickImage(
      source: fuente,
      // Resolución suficiente para leer números pequeños y el código de barras
      maxWidth: 3000,
      maxHeight: 3000,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
  } on PlatformException catch (e) {
    if (!context.mounted) return;
    final sinPermiso = e.code.contains('access_denied');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sinPermiso
              ? 'ServiApp necesita permiso para usar la cámara.'
              : 'No fue posible abrir la cámara.',
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  if (foto == null || !context.mounted) return;
  final rutaImagen = foto.path;

  // La pantalla de análisis devuelve true si el usuario quiere tomar otra foto
  final repetir = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => AnalizandoReciboScreen(rutaImagen: rutaImagen),
    ),
  );
  if (repetir == true && context.mounted) {
    await iniciarEscaneoRecibo(context);
  }
}
