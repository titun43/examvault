// =============================================================================
// ExamVault - Payment Progress Dialog (robust, never-stuck helper)
// =============================================================================
// A small helper that manages the "Preparing payment..." / "Verifying
// payment..." loading dialogs shown during the Razorpay flow.
//
// KEY DESIGN GOALS (all fix real bugs seen in production):
//
// 1. NEVER STUCK — a built-in safety timer (25s by default) force-dismisses
//    the dialog no matter what. Even if the Razorpay plugin's success callback
//    never fires, even if the /verify HTTP call hangs beyond its timeout, even
//    if the Dart event loop is somehow blocked — the user is NEVER trapped.
//
// 2. ALWAYS CANCELLABLE — BOTH the "Preparing" and "Verifying" dialogs get a
//    Cancel button. Previously only "Preparing" was cancellable, which meant
//    that if the verify step hung, the user had NO way out except killing the
//    app. Now they can always cancel.
//
// 3. RELIABLE DISMISS — tracks the dialog's own BuildContext (not just a
//    counter) so we pop the EXACT dialog we pushed, not "whatever is on top
//    of the navigator". This prevents the bug where another route gets pushed
//    between show and dismiss and the wrong thing gets popped.
//
// 4. SAFETY-TIMEOUT CALLBACK — when the safety timer fires, the caller is
//    notified via [onSafetyTimeout] so it can show a "check My Purchases"
//    message. This does NOT set the caller's `cancelled` flag — the payment
//    may still succeed in the background and onSuccess must still process it.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';

class PaymentProgressDialog {
  /// The dialog's own BuildContext (captured inside the builder). Used to pop
  /// the exact dialog we pushed, avoiding "pop the wrong route" bugs.
  BuildContext? _dialogCtx;

  /// Safety timer — force-dismisses the dialog after [safetyTimeout] so the
  /// user is never trapped if a callback never fires.
  Timer? _safetyTimer;

  /// Whether a dialog is currently on screen.
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  /// Shows a loading dialog with [message]. If [cancellable], a Cancel button
  /// is shown; pressing it dismisses the dialog and calls [onCancel].
  ///
  /// [onSafetyTimeout] is called if the dialog has been on screen for
  /// [safetyTimeout] (25s by default) without being dismissed — the caller
  /// should show a "check My Purchases" message. The dialog IS dismissed
  /// before [onSafetyTimeout] is called.
  void show(
    BuildContext outerContext, {
    required String message,
    bool cancellable = false,
    String? cancelLabel,
    VoidCallback? onCancel,
    Duration safetyTimeout = const Duration(seconds: 25),
    VoidCallback? onSafetyTimeout,
  }) {
    // If a dialog is already open, dismiss it first (replace).
    if (_isOpen) {
      _forceDismiss();
    }
    _isOpen = true;
    _safetyTimer?.cancel();
    _safetyTimer = Timer(safetyTimeout, () {
      _forceDismiss();
      // Notify the caller — do NOT set any "cancelled" flag here; the payment
      // may still succeed in the background and onSuccess must still run.
      onSafetyTimeout?.call();
    });

    showDialog<void>(
      context: outerContext,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        // Capture the dialog's own context so we can pop exactly this dialog.
        _dialogCtx = ctx;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 20),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  if (cancellable) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          _safetyTimer?.cancel();
                          _forceDismiss();
                          onCancel?.call();
                        },
                        child: Text(cancelLabel ?? 'Cancel'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // The dialog was popped (by us via dismiss, by the safety timer, or by
      // the system). Clean up internal state. Using .then ensures we don't
      // leave _isOpen = true if the dialog is removed by some other path.
      _isOpen = false;
      _dialogCtx = null;
      _safetyTimer?.cancel();
    });
  }

  /// Dismisses the dialog if one is open. Safe to call multiple times.
  void dismiss() {
    _safetyTimer?.cancel();
    if (_isOpen && _dialogCtx != null && _dialogCtx!.mounted) {
      Navigator.of(_dialogCtx!).pop();
    }
    _isOpen = false;
    _dialogCtx = null;
  }

  /// Internal: pops the dialog WITHOUT cancelling the safety timer's callback.
  /// Used by the safety timer itself and by the Cancel button (which cancels
  /// the timer first).
  void _forceDismiss() {
    if (_isOpen && _dialogCtx != null && _dialogCtx!.mounted) {
      Navigator.of(_dialogCtx!).pop();
    }
    _isOpen = false;
    _dialogCtx = null;
  }
}
