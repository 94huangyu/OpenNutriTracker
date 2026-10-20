import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/presentation/widgets/empty_hint.dart';
import 'package:opennutritracker/generated/l10n.dart';

/// Shared camera failure UI for lookup and barcode-only entry.
class ScannerCameraError extends StatefulWidget {
  final MobileScannerException error;
  final Future<void> Function() onRetry;
  const ScannerCameraError({
    super.key,
    required this.error,
    required this.onRetry,
  });
  @override
  State<ScannerCameraError> createState() => _ScannerCameraErrorState();
}

class _ScannerCameraErrorState extends State<ScannerCameraError> {
  bool _retrying = false;
  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } catch (error, stack) {
      // The scanner controller also publishes the error to its errorBuilder.
      Logger('ScannerCameraError').warning('Camera retry failed', error, stack);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyHint(
              icon: Icons.no_photography_outlined,
              title: s.customMealBarcodeScanButton,
              subtitle:
                  widget.error.errorCode ==
                      MobileScannerErrorCode.permissionDenied
                  ? s.scannerPermissionHelp
                  : s.scannerCameraUnavailable,
            ),
            Semantics(
              identifier: 'scanner-camera-retry',
              child: FilledButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(s.retryLabel),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
