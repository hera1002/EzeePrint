import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:isolate';


class TCPScanner {
  /// Host to scan
  String _host = '';

  /// List of scanning ports
  List<int> _ports = [];

  /// Scan results
  ScanResult _scanResult = ScanResult();

  /// Connection timeout. If the port doesn't receive an answer during this period it will be marked as unreachable.
  Duration _connectTimeout = Duration(microseconds: 100);

  /// Shuffle each scan
  late bool _shuffle;

  /// Count of isolates
  late int _isolatesCount;

  /// Isolates ScanResults
  List<ScanResult> _isolateScanResults = [];

  /// Results update interval
  late Duration _updateInterval;

  /// Prepares scanner to scan specified host and specified ports
  TCPScanner(String host, List<int> ports,
      {int timeout = 100, bool shuffle = false, int isolates = 1, Duration updateInterval = const Duration(seconds: 1)})
      : this.build(host, ports, timeout, shuffle, isolates, updateInterval);

  /// Prepares scanner to scan range of ports from startPort to endPort
  TCPScanner.range(String host, int startPort, int endPort,
      {int timeout = 100, bool shuffle = false, int isolates = 1, Duration updateInterval = const Duration(seconds: 1)})
      : this.build(
      host,
      List.generate(max(startPort, endPort) + 1 - min(startPort, endPort), (i) => min(startPort, endPort) + i),
      timeout,
      shuffle,
      isolates,
      updateInterval);

  /// All arguments constructor
  TCPScanner.build(String host, List<int> ports, int timeout, bool shuffle, int isolates, Duration updateInterval) {
    _host = host;
    _ports = ports;
    _connectTimeout = Duration(milliseconds: timeout);
    _shuffle = shuffle;
    _isolatesCount = isolates;
    _updateInterval = updateInterval;
  }

  /// Return scan status
  ScanResult get scanResult {
    var result = ScanResult(status: ScanStatuses.finished);
    _isolateScanResults.forEach((isolateResult) {
      result.host = isolateResult.host;
      result
        ..ports.addAll(isolateResult.ports)
        ..scanned.addAll(isolateResult.scanned)
        ..open.addAll(isolateResult.open)
        ..closed.addAll(isolateResult.closed);
    });
    result.status = _scanResult.status;
    result.elapsed = _scanResult.elapsed;
    return result;
  }

  /// Execute scanning with at least 1 isolates
  Future<ScanResult> scan() async {
    // Prepare port ranges for isolates
    var isolatePorts = <List<int>>[];
    var portsPerIsolate = (_ports.length / _isolatesCount).ceil();
    var startIndex = 0;
    var endIndex = 0;
    var ports = List<int>.from(_ports);

    if (_shuffle) ports.shuffle();
    while (startIndex < ports.length) {
      endIndex = startIndex + portsPerIsolate > ports.length ? ports.length : startIndex + portsPerIsolate;
      isolatePorts.add(ports.sublist(startIndex, endIndex));
      startIndex = endIndex;
    }
    // Scan result
    _isolateScanResults = [];
    _scanResult = ScanResult(host: _host, ports: _ports, status: ScanStatuses.scanning);
    // Run isolates and create listeners
    var completers = <Completer>[];
    for (var portsList in isolatePorts) {
      var completer = Completer();
      var receivePort = ReceivePort();
      var isolateScanResult = ScanResult(host: _host, ports: portsList, status: ScanStatuses.scanning);
      completers.add(completer);
      _isolateScanResults.add(isolateScanResult);
      await Isolate.spawn(_isolateScan,
          IsolateArguments(receivePort.sendPort, _host, portsList, _connectTimeout, updateInterval: _updateInterval));
      receivePort.listen((result) {
        // When response received add information to scanResult
        isolateScanResult.scanned = result.scanned;
        isolateScanResult.open = result.open;
        isolateScanResult.closed = result.closed;
        isolateScanResult.status = result.status;
        if (result.status == ScanStatuses.finished) {
          receivePort.close();
          completer.complete(result);
        }
      });
    }
    // Wait until all isolates finished
    await Future.wait(completers.map((completer) => completer.future));
    _scanResult.status = ScanStatuses.finished;
    completers.clear();
    return scanResult;
  }

  /// Execute scanning with no isolates
  Future<ScanResult> _noIsolateScan() async {
    Socket? connection;
    final scanResult = ScanResult(host: _host, ports: _ports, status: ScanStatuses.scanning);
    for (var port in _ports) {
      try {
        connection = await Socket.connect(_host, port, timeout: _connectTimeout);
        scanResult.addOpen(port);
      } catch (e) {
        scanResult.addClosed(port);
      } finally {
        if (connection != null) {
          connection.destroy();
        }
        scanResult.addScanned(port);
      }
    }
    scanResult.status = ScanStatuses.finished;
    return scanResult;
  }

  /// Isolated port scanner
  static void _isolateScan(IsolateArguments arguments) async {
    var scanResult = ScanResult(host: arguments.host, ports: arguments.ports, status: ScanStatuses.scanning);
    Socket? connection;
    var timer = Timer.periodic(arguments.updateInterval, (timer) {
      arguments.sendPort.send(scanResult);
    });
    for (int port in arguments.ports) {
      if (port <= 0 || port > 65536) {
        scanResult.status = ScanStatuses.finished;
        arguments.sendPort.send(scanResult);
        timer.cancel();
        throw Exception('Invalid port: $port');
      } else {
        try {
          connection = await Socket.connect(arguments.host, port, timeout: arguments.timeout);
          await connection.close();
          scanResult.addOpen(port);
        } catch (e) {
          scanResult.addClosed(port);
        } finally {
          scanResult.addScanned(port);
        }
      }
    }
    scanResult.status = ScanStatuses.finished;
    arguments.sendPort.send(scanResult);
    timer.cancel();
  }
}


/// Scanning statuses
enum ScanStatuses { unknown, scanning, finished }

/// Scan result contains data of prepared, current and finished scan.
class ScanResult {
  static final String keyHost = 'host';
  static final String keyPorts = 'ports';
  static final String keyScanned = 'scanned';
  static final String keyOpen = 'open';
  static final String keyClosed = 'closed';
  static final String keyElapsed = 'elapsed';
  static final String keyStatus = 'status';

  /// Host
  String? host;

  /// All testing ports
  List<int> ports = [];

  /// Open ports
  List<int> open = [];

  /// Closed ports
  List<int> closed = [];

  /// Ports which was scanned. This field is modifies when scan is in progress.
  List<int> scanned = [];

  /// Elapsed time. It can be null if scanning is in progress.
  int? _elapsed;

  /// Time when status changed to scanning
  DateTime? _startTime;

  /// Time when status changed to finished
  DateTime? _finishTime;

  /// Current status
  ScanStatuses _status = ScanStatuses.unknown;

  /// Main constructor
  ScanResult({String? host, List<int> ports = const [], List<int> open = const [], List<int> closed = const [], List<int> scanned = const [], ScanStatuses status = ScanStatuses.unknown}) {
    this.host = host;
    this.ports.addAll(ports);
    this.open.addAll(open);
    this.closed.addAll(closed);
    this.scanned.addAll(scanned);
    _status = status;
    if (status != ScanStatuses.finished) _startTime = DateTime.now();
  }

  /// Creation object from JSON
  ScanResult.fromJson(String json) {
    fromJson(json);
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    var statusString = 'unknown';
    if (_status == ScanStatuses.scanning) {
      statusString = 'scanning';
    } else if (_status == ScanStatuses.finished) {
      statusString = 'finished';
    }
    return {keyHost: host, keyPorts: ports, keyScanned: scanned, keyOpen: open, keyClosed: closed, keyElapsed: elapsed, keyStatus: statusString};
  }

  /// Deserialize from JSON
  void fromJson(String json) {
    Map<String, dynamic> map = jsonDecode(json);
    if (map.containsKey(keyHost)) host = map[keyHost].toString();
    if (map.containsKey(keyPorts)) ports = List<int>.from(map[keyPorts]);
    if (map.containsKey(keyScanned)) scanned = List<int>.from(map[keyScanned]);
    if (map.containsKey(keyOpen)) open = List<int>.from(map[keyOpen]);
    if (map.containsKey(keyClosed)) closed = List<int>.from(map[keyClosed]);
    if (map.containsKey(keyElapsed)) _elapsed = map[keyElapsed];
    if (map.containsKey(keyStatus)) {
      if (map[keyStatus] == 'finished') {
        _status = ScanStatuses.finished;
      } else if (map[keyStatus] == 'scanning') {
        _status = ScanStatuses.scanning;
      } else {
        _status = ScanStatuses.unknown;
      }
    }
  }

  /// Add single port
  void addPort(int port) => ports.add(port);

  /// Add open port
  void addOpen(int port) => open.add(port);

  /// Add closed port
  void addClosed(int port) => closed.add(port);

  /// Add scanned port
  void addScanned(int port) => scanned.add(port);

  /// Sets status, and modifies startTime and finishTime. If status is finished then modifies _elapsedTime.
  set status(value) {
    _status = value;
    if (value == ScanStatuses.scanning) {
      _startTime = DateTime.now();
    } else if (value == ScanStatuses.finished) {
      if (_startTime == null) {
        _elapsed = -1;
      } else {
        _finishTime = DateTime.now();
        _elapsed = _finishTime!.difference(_startTime!).inMilliseconds;
      }
    }
  }

  /// Returns current scanning status
  ScanStatuses get status => _status;

  /// Returns elapsed scan time in milliseconds.
  /// If scanning is still in progress then returns difference between scan start and current time.
  /// If the start time is undefined return -1
  int get elapsed {
    if (_elapsed != null) {
      return _elapsed!;
    } else if (_startTime == null || _finishTime == null) {
      return -1;
    } else {
      return DateTime.now().difference(_startTime!).inMilliseconds;
    }
  }

  set elapsed(value) {
    _elapsed = value;
  }
}


/// Isolate scanner arguments
class IsolateArguments {
  final SendPort sendPort;
  final String host;
  final List<int> ports;
  final Duration timeout;
  final Duration updateInterval;

  IsolateArguments(this.sendPort, this.host, this.ports, this.timeout, {this.updateInterval = const Duration(seconds: 1)});
}