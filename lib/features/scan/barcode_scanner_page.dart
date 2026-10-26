import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/data/barcode_lookup.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/press_scale.dart';

/// Opens the camera, reads one product barcode and looks it up with
/// [lookup] before closing, so the caller gets a finished result. Null when
/// the user closes it.
Future<BarcodeResult?> showBarcodeScanner(
  BuildContext context, {
  required Future<BarcodeResult> Function(String barcode) lookup,
}) {
  Haptics.light();
  return Navigator.of(context, rootNavigator: true).push<BarcodeResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BarcodeScannerPage(lookup: lookup),
    ),
  );
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key, required this.lookup});

  final Future<BarcodeResult> Function(String barcode) lookup;

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  // Grocery codes only: faster, and QR codes on packs aren't products.
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// The code being looked up (or that failed); null while scanning.
  String? _code;
  bool _failed = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_code != null) return;
    final code = capture.barcodes.map((b) => b.rawValue).nonNulls.firstOrNull;
    if (code == null || code.isEmpty) return;
    Haptics.light();
    // Freeze on the frame that was read (stop() would blank the preview).
    _camera.pause();
    _look(code);
  }

  Future<void> _look(String code) async {
    setState(() {
      _code = code;
      _failed = false;
    });
    final result = await widget.lookup(code);
    if (!mounted) return;
    if (result is BarcodeFailed) {
      Haptics.warning();
      setState(() => _failed = true);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  void _scanAgain() {
    Haptics.tap();
    setState(() {
      _code = null;
      _failed = false;
    });
    _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final size = MediaQuery.sizeOf(context);
    // A wide, short window: the shape of a barcode.
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width - AppSpacing.huge * 2,
      height: (size.width - AppSpacing.huge * 2) * 0.62,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      // Every child is positioned against the full screen; a non-positioned
      // child would size the Stack down to itself.
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(error: error),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WindowPainter(window: window, active: _code == null)),
            ),
          ),
          // Status under the window.
          Positioned(
            left: AppSpacing.screen,
            right: AppSpacing.screen,
            top: window.bottom + AppSpacing.xxl,
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: _code == null
                  ? Text(
                      'Line up the barcode inside the frame',
                      key: const ValueKey('hint'),
                      textAlign: TextAlign.center,
                      style: t.bodyStrong.copyWith(color: Colors.white),
                    )
                  : !_failed
                      ? Row(
                          key: const ValueKey('busy'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text('Looking it up…', style: t.bodyStrong.copyWith(color: Colors.white)),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ),
          // Close and torch.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  _RoundButton(
                    icon: AppIcons.close,
                    label: 'Close',
                    onTap: () {
                      Haptics.tap();
                      Navigator.of(context).pop();
                    },
                  ),
                  const Spacer(),
                  ValueListenableBuilder(
                    valueListenable: _camera,
                    builder: (context, state, _) {
                      if (state.torchState == TorchState.unavailable) return const SizedBox.shrink();
                      final on = state.torchState == TorchState.on;
                      return _RoundButton(
                        icon: on ? AppIcons.lightningFill : AppIcons.lightning,
                        label: on ? 'Turn off the light' : 'Turn on the light',
                        highlighted: on,
                        onTap: () {
                          Haptics.tap();
                          _camera.toggleTorch();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          ),
          if (_failed)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              child: _FailedPanel(
                onRetry: () {
                  Haptics.tap();
                  _look(_code!);
                },
                onScanAgain: _scanAgain,
                onManual: () {
                  Haptics.tap();
                  Navigator.of(context).pop(BarcodeNotFound(_code!));
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Dims the camera outside a rounded window and outlines the window.
class _WindowPainter extends CustomPainter {
  _WindowPainter({required this.window, required this.active});

  final Rect window;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(window, const Radius.circular(AppRadii.lg));
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: active ? 1 : 0.4),
    );
  }

  @override
  bool shouldRepaint(_WindowPainter old) => old.window != window || old.active != active;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => PressScale(
        semanticLabel: label,
        scale: 0.9,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: AppSizes.iconTile + 4,
          height: AppSizes.iconTile + 4,
          decoration: BoxDecoration(
            color: highlighted ? Colors.white : Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: AppIcon(icon, size: 20, color: highlighted ? Colors.black : Colors.white),
        ),
      );
}

/// Shown when the lookup couldn't reach Open Food Facts.
class _FailedPanel extends StatelessWidget {
  const _FailedPanel({required this.onRetry, required this.onScanAgain, required this.onManual});

  final VoidCallback onRetry;
  final VoidCallback onScanAgain;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: p.surface, borderRadius: AppRadii.card),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Couldn’t look that up', style: t.heading),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The food database didn’t answer. Check your connection and try again, or enter it from the label.',
            style: t.body.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Try again', onPressed: onRetry),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: AppButton(label: 'Scan again', style: AppButtonStyle.outline, onPressed: onScanAgain)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: AppButton(label: 'Enter it', style: AppButtonStyle.outline, onPressed: onManual)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                denied ? 'Camera access is off' : 'The camera didn’t start',
                textAlign: TextAlign.center,
                style: t.heading.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                denied
                    ? 'Allow camera access for this app in your phone’s Settings to scan barcodes.'
                    : 'Close this and try again.',
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
