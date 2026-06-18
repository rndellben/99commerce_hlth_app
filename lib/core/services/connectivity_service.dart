import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple online/offline state.
enum ConnectivityStatus { online, offline }

/// Streams device connectivity with a 500ms debounce to avoid flapping.
///
/// Combines `connectivity_plus` (fast, cheap — checks radio state) with a
/// real DNS lookup (`InternetAddress.lookup`) to confirm actual reachability.
class ConnectivityService {
  ConnectivityService() {
    _sub = Connectivity().onConnectivityChanged.listen(_onEvent);
    // Seed immediately.
    _check();
  }

  final _controller = StreamController<ConnectivityStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;
  ConnectivityStatus _last = ConnectivityStatus.offline;

  Stream<ConnectivityStatus> get status => _controller.stream;
  ConnectivityStatus get current => _last;

  void _onEvent(List<ConnectivityResult> results) {
    // Debounce 500ms — radio toggles often fire multiple events.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _check);
  }

  Future<void> _check() async {
    final reachable = await _hasInternet();
    final next = reachable ? ConnectivityStatus.online : ConnectivityStatus.offline;
    if (next != _last) {
      _last = next;
      _controller.add(next);
    }
  }

  /// Lightweight reachability probe — a DNS lookup is cheaper than HTTP.
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _controller.close();
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final svc = ConnectivityService();
  ref.onDispose(svc.dispose);
  return svc;
});

final connectivityStateProvider = StreamProvider<ConnectivityStatus>((ref) {
  final svc = ref.watch(connectivityServiceProvider);
  return svc.status;
});
