import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { wifi, cellular, otherOnline, offline }

abstract interface class NetworkMonitor {
  Stream<NetworkStatus> get status;
  Future<NetworkStatus> currentStatus();
}

final class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor(this._connectivity);

  final Connectivity _connectivity;

  @override
  Stream<NetworkStatus> get status =>
      _connectivity.onConnectivityChanged.map(_map);

  @override
  Future<NetworkStatus> currentStatus() async =>
      _map(await _connectivity.checkConnectivity());

  NetworkStatus _map(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return NetworkStatus.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return NetworkStatus.cellular;
    }
    return results.isEmpty || results.contains(ConnectivityResult.none)
        ? NetworkStatus.offline
        : NetworkStatus.otherOnline;
  }
}
