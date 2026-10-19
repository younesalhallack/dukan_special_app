import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/barcode_utils.dart';
import '../../../l10n/l10n.dart';
import '../widgets/name_dialog.dart';

/// Barcode formats used in shops. Restricting the formats makes reading
/// faster and avoids false reads.
const List<BarcodeFormat> kRetailBarcodeFormats = <BarcodeFormat>[
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code128,
  BarcodeFormat.code39,
  BarcodeFormat.qrCode,
];

/// Opens the scanner and returns the scanned (or typed) barcode, or null
/// when the user went back without scanning.
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
  );
}

/// Opens the scanner in continuous mode: it stays open, [onScan] is called
/// for every new code, and the text it returns is shown as feedback.
/// The user closes the screen with the back button.
Future<void> scanBarcodesContinuously(
  BuildContext context,
  Future<String> Function(String code) onScan, {
  String? hint,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => BarcodeScannerScreen(onScan: onScan, hint: hint),
    ),
  );
}

/// Full-screen camera scanner. In single mode it returns the first valid
/// barcode and closes. With [onScan] it keeps scanning. A manual-entry button
/// is always available as a fallback.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, this.onScan, this.hint});

  final Future<String> Function(String code)? onScan;

  /// Overrides the hint shown in continuous mode.
  final String? hint;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller =
      MobileScannerController(formats: kRetailBarcodeFormats);
  final ScanDebouncer _debouncer = ScanDebouncer();
  bool _done = false;
  bool _manualEntryOpen = false;
  bool _processing = false;
  String? _feedback;

  bool get _continuous => widget.onScan != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(code);
  }

  Future<void> _handleContinuous(String code) async {
    // accept() is called first so a code held in view keeps being ignored.
    if (!_debouncer.accept(code) || _processing) return;
    _processing = true;
    HapticFeedback.mediumImpact();
    try {
      final message = await widget.onScan!(code);
      if (mounted) setState(() => _feedback = message);
    } finally {
      _processing = false;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    // Ignore reads while the manual dialog is open, otherwise popping would
    // close the dialog instead of this screen.
    if (_done || _manualEntryOpen) return;
    for (final barcode in capture.barcodes) {
      final code = BarcodeUtils.clean(barcode.rawValue);
      if (code == null) continue;
      if (_continuous) {
        _handleContinuous(code);
      } else {
        _finish(code);
      }
      return;
    }
  }

  Future<void> _enterManually() async {
    final l10n = context.l10n;
    _manualEntryOpen = true;
    final text = await showNameDialog(
      context,
      title: l10n.enterManually,
      label: l10n.barcode,
    );
    _manualEntryOpen = false;
    final code = BarcodeUtils.clean(text);
    if (code == null || !mounted) return;
    if (_continuous) {
      await _handleContinuous(code);
    } else {
      _finish(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.scanBarcode),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((state.availableCameras ?? 0) > 1)
                    IconButton(
                      icon: const Icon(Icons.cameraswitch_outlined),
                      tooltip: l10n.switchCamera,
                      onPressed: () => _controller.switchCamera(),
                    ),
                  if (state.torchState != TorchState.unavailable)
                    IconButton(
                      icon: Icon(
                        state.torchState == TorchState.on
                            ? Icons.flash_on
                            : Icons.flash_off,
                      ),
                      tooltip: l10n.torch,
                      onPressed: _controller.toggleTorch,
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
            overlayBuilder: (context, constraints) {
              final width = constraints.maxWidth * 0.8;
              return IgnorePointer(
                child: Center(
                  child: Container(
                    width: width,
                    height: width * 0.5,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_feedback != null) ...[
                      Text(
                        _feedback!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      _continuous
                          ? (widget.hint ?? l10n.continuousScanHint)
                          : l10n.scanHint,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _enterManually,
                      icon: const Icon(Icons.keyboard_outlined),
                      label: Text(l10n.enterManually),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => l10n.cameraPermissionDenied,
      MobileScannerErrorCode.unsupported => l10n.cameraUnavailable,
      _ => l10n.cameraError,
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
