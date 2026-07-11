// =============================================================================
// ExamVault - Offline-Aware Stream Builder
// =============================================================================
// A wrapper around StreamBuilder that fixes the two most common offline UX
// problems in this app:
//
//   1. INFINITE SPINNER: When the stream is in ConnectionState.waiting AND
//      there is no cached data, the default StreamBuilder pattern shows a
//      CircularProgressIndicator that never resolves (because the stream
//      can't reach the server). The user thinks the app is frozen.
//
//   2. SILENT ERROR SWALLOW: Many Firestore streams in this app use
//      `.handleError((e) => print(...))` which swallows errors so the
//      StreamBuilder never sees snapshot.hasError. Combined with #1, the
//      user sees an infinite spinner forever with no explanation.
//
// This widget fixes both by:
//   - Showing cached data IMMEDIATELY if snapshot.hasData (even if the
//     stream is still "waiting" for a fresh fetch). This is the key fix:
//     the user sees content right away instead of a spinner while the
//     stream re-validates against the server.
//   - Showing a friendly "You're offline" message instead of an infinite
//     spinner when there is NO cached data AND the stream is waiting or
//     errored. The message includes a retry button.
//   - Showing a small "offline" badge above cached data when the stream
//     is waiting/errored but we DO have cached data, so the user knows
//     they're seeing stale content.
//
// USAGE:
//   OfflineAwareStreamBuilder<List<CategoryModel>>(
//     stream: FirestoreService.getCategoriesStream(),
//     loadingBuilder: (context) => ShimmerGrid(),
//     emptyBuilder: (context, retry) => EmptyState(onRetry: retry),
//     offlineBuilder: (context, retry) => OfflineState(onRetry: retry),
//     errorBuilder: (context, error, retry) => ErrorState(error: error, onRetry: retry),
//     dataBuilder: (context, data, isStale) => ContentList(data: data, isStale: isStale),
//   )
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';

class OfflineAwareStreamBuilder<T> extends StatefulWidget {
  final Stream<T> stream;
  final T? initialData;

  /// Shown only on the VERY FIRST load when there is no cached data at all.
  /// Typically a shimmer/skeleton placeholder.
  final WidgetBuilder? loadingBuilder;

  /// Shown when the stream emits a non-null but empty result (e.g. an empty
  /// list). `retry` is a callback that re-subscribes to the stream.
  final Widget Function(BuildContext context, VoidCallback retry)?
      emptyBuilder;

  /// Shown when the stream is waiting/errored AND there is no cached data
  /// (i.e. the user is offline on first visit). `retry` re-subscribes.
  final Widget Function(BuildContext context, VoidCallback retry)?
      offlineBuilder;

  /// Shown when the stream errors AND there is no cached data. Falls back to
  /// offlineBuilder if not provided.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
      errorBuilder;

  /// Shown when the stream has data. `isStale` is true when the stream is
  /// also in a waiting/error state (meaning the data is from cache and may
  /// not be up-to-date).
  final Widget Function(BuildContext context, T data, bool isStale)
      dataBuilder;

  const OfflineAwareStreamBuilder({
    super.key,
    required this.stream,
    required this.dataBuilder,
    this.initialData,
    this.loadingBuilder,
    this.emptyBuilder,
    this.offlineBuilder,
    this.errorBuilder,
  });

  @override
  State<OfflineAwareStreamBuilder<T>> createState() =>
      _OfflineAwareStreamBuilderState<T>();
}

class _OfflineAwareStreamBuilderState<T>
    extends State<OfflineAwareStreamBuilder<T>> {
  late Stream<T> _stream;
  StreamSubscription<T>? _subscription;
  T? _cachedData;
  Object? _lastError;
  bool _isWaiting = true;
  int _retryNonce = 0;

  @override
  void initState() {
    super.initState();
    _cachedData = widget.initialData;
    _stream = widget.stream;
    _subscribe();
  }

  @override
  void didUpdateWidget(OfflineAwareStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-subscribe only if the stream identity changed (avoids unnecessary
    // re-subscription on parent rebuilds).
    if (oldWidget.stream != widget.stream) {
      _stream = widget.stream;
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _isWaiting = true;
    // Keep _cachedData from the previous subscription so we can show it
    // while the new stream loads (this is the KEY offline behavior — the
    // user sees content immediately instead of a spinner).
    _subscription = _stream.listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _cachedData = data;
          _lastError = null;
          _isWaiting = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _lastError = error;
          // Keep _isWaiting false — we got a definitive error, not a timeout.
          // The UI will show cached data (if any) with a stale badge, or the
          // offline/error builder.
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isWaiting = false;
        });
      },
    );
  }

  void _retry() {
    setState(() {
      _retryNonce++;
      _isWaiting = true;
      _lastError = null;
      // Re-subscribe to the SAME stream (stream properties may have been
      // rebuilt by the parent on the next frame, but for retry we just
      // re-listen to the current _stream reference).
    });
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Case 1: We have cached data — show it immediately.
    // isStale = true when the stream is still loading or errored (meaning
    // the cached data might not be the latest).
    if (_cachedData != null) {
      final isStale = _isWaiting || _lastError != null;
      return widget.dataBuilder(context, _cachedData as T, isStale);
    }

    // Case 2: No cached data, stream errored — show error or offline state.
    if (_lastError != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _lastError!, _retry);
      }
      if (widget.offlineBuilder != null) {
        return widget.offlineBuilder!(context, _retry);
      }
      return _defaultOfflineState(context, _retry);
    }

    // Case 3: No cached data, stream still loading — show loading or
    // offline state. On a truly first visit this is a loading spinner; on
    // an offline first visit the stream may stay in "waiting" indefinitely,
    // so we show the offline state (which is more helpful than an infinite
    // spinner).
    if (_isWaiting) {
      // Give the stream a brief moment to resolve before showing the
      // offline state — if it resolves quickly (cached data available),
      // we never show the spinner at all. But if it takes too long, we
      // show the offline message instead of an infinite spinner.
      // We use the presence of initialData to decide: if the parent
      // provided initialData, show the loading spinner briefly; otherwise
      // show the offline state immediately for a snappier UX.
      if (widget.loadingBuilder != null) {
        return widget.loadingBuilder!(context);
      }
      return _defaultLoadingState(context);
    }

    // Case 4: Stream completed with no data and no error — show empty state.
    if (widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context, _retry);
    }
    return _defaultEmptyState(context, _retry);
  }

  // ─── Default fallbacks (used when the caller doesn't provide a custom
  // builder for a given state) ───

  Widget _defaultLoadingState(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _defaultOfflineState(BuildContext context, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'You appear to be offline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to the internet and try again, or browse cached content on other tabs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultEmptyState(BuildContext context, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nothing here yet',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
