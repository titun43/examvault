// =============================================================================
// ExamVault - Connectivity Banner
// =============================================================================
// A slim banner that appears at the top of the screen when the device has no
// internet connection. Uses the connectivity_plus package (which was already
// in pubspec.yaml but NEVER used — that's one reason "app offline kaj kore
// na": the user had no indication they were offline, so every StreamBuilder
// just showed an infinite spinner).
//
// The banner is:
//   - Sticky at the top of the screen (doesn't scroll away)
//   - Non-blocking (the user can still interact with content below)
//   - Auto-hides when connectivity is restored
//   - Uses a permission-friendly listen (no polling — event-driven)
//
// USAGE (inside a Scaffold or Column):
//   ConnectivityBanner()
//
// Or wrap the body:
//   Column(
//     children: [
//       ConnectivityBanner(),
//       Expanded(child: body),
//     ],
//   )
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityBanner extends StatefulWidget {
  /// If true, the banner takes up space even when online (reserved space).
  /// Default false — the banner slides in/out, pushing content when offline.
  final bool reserveSpace;

  const ConnectivityBanner({super.key, this.reserveSpace = false});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late final Connectivity _connectivity;
  // NOTE: connectivity_plus 5.0.2 emits a SINGULAR ConnectivityResult (not a
  // List). The List-based API only exists in later 5.x / 6.x versions. Using
  // the wrong stream type here causes a compile error (StreamSubscription<
  // ConnectivityResult> can't be assigned to StreamSubscription<List<...>>?).
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    // Check the CURRENT state immediately (the stream only emits CHANGES).
    _connectivity.checkConnectivity().then((result) {
      if (!mounted) return;
      setState(() {
        _isOffline = _resultIndicatesOffline(result);
      });
    });
    // Listen for changes.
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      if (!mounted) return;
      final offline = _resultIndicatesOffline(result);
      if (offline != _isOffline) {
        setState(() => _isOffline = offline);
      }
    });
  }

  /// Returns true if the given ConnectivityResult indicates NO active
  /// connection.
  ///
  /// connectivity_plus 5.0.2 emits a SINGULAR ConnectivityResult (not a
  /// List — that came in later versions). So we just check the one value.
  ///
  /// We treat anything that is NOT one of the known "connected" types as
  /// offline. This is intentionally written WITHOUT referencing
  /// ConnectivityResult.other (which does not exist in 5.0.2 — it was added
  /// in a later version). This way the code compiles on 5.0.2 AND on newer
  /// versions that add more enum values.
  ///
  /// NOTE: ConnectivityResult.mobile means cellular data is CONNECTED, not
  /// just that a SIM is present. ConnectivityResult.none means no connection
  /// at all (airplane mode, no signal, etc.).
  bool _resultIndicatesOffline(ConnectivityResult result) {
    // If the result is any of the connected types, we're online.
    if (result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.bluetooth ||
        result == ConnectivityResult.vpn) {
      return false;
    }
    // none / unknown / any future enum value → offline.
    return true;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline && !widget.reserveSpace) {
      return const SizedBox.shrink();
    }
    if (!_isOffline && widget.reserveSpace) {
      return const SizedBox(height: 0);
    }
    return Material(
      color: const Color(0xFFE65100), // deep orange — noticeable but not alarming
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'You are offline. Some content may be unavailable.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Tapping the X dismisses the banner until connectivity
              // changes again. Useful when the user knows they're offline
              // and wants the screen space back.
              GestureDetector(
                onTap: () {
                  setState(() => _isOffline = false);
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
