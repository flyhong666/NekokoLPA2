import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'epdg_tunnel.dart';
import 'models.dart';
import 'sms_codec.dart';

const String _iphoneUserAgent = 'iPhone14,5 iOS/17.6 IMS/8.0';
// Synthetic fallback using the app's default TAC; normal sessions pass the
// configured device identity from AppSettings.
const String _defaultDeviceIdentity = '3538374100000000';

class VowifiSmsClient {
  VowifiSmsClient({
    required this.config,
    this.authSecretProvider,
    this.digestAkaProvider,
    this.akaProvider,
    this.onLog,
  });

  final VowifiSmsConfig config;
  final Future<String?> Function(VowifiDigestChallenge challenge)?
  authSecretProvider;
  final Future<VowifiAkaResponse?> Function(VowifiDigestChallenge challenge)?
  digestAkaProvider;
  final VowifiAkaProvider? akaProvider;
  final void Function(String line)? onLog;
  final StreamController<VowifiSmsEvent> _events =
      StreamController<VowifiSmsEvent>.broadcast();

  Stream<VowifiSmsEvent> get events => _events.stream;

  _SipConnection? _connection;
  StreamSubscription<Uint8List>? _socketSubscription;
  BytesBuilder _buffer = BytesBuilder(copy: false);
  Completer<_SipMessage>? _pendingResponse;
  int _cseq = 1;
  int _smsMr = 0;
  final String _fromTag = _randomToken(10);
  final String _registerCallId = _randomToken(16);
  final String _localToTag = _randomToken(8);
  final int _secSpiC = _randomU32();
  final int _secSpiS = _randomU32();
  int _secPortC = 0;
  int _secPortS = 0;
  String _securityVerify = '';
  int _srvSpiC = 0;
  int _srvSpiS = 0;
  int _srvPortC = 0;
  int _srvPortS = 0;
  String _imsPreferredProfile = '';
  String _imsPreferredKey = '';
  VowifiAkaResponse? _lastDigestAka;
  VowifiSmsConnectionState _state = VowifiSmsConnectionState.disconnected;
  DateTime? _registeredUntil;
  String _publicIdentity = '';
  List<String> _associatedIdentities = const <String>[];
  String _preferredIdentityOverride = '';
  final Queue<VowifiSmsMessage> _smsReportQueue = Queue<VowifiSmsMessage>();
  Completer<void>? _smsReportNotifier;
  final Queue<String> _recentIncomingKeys = Queue<String>();
  final Set<String> _recentIncomingKeySet = <String>{};

  DateTime? get registeredUntil => _registeredUntil;
  String get publicIdentity => _publicIdentity;
  List<String> get associatedIdentities =>
      List<String>.unmodifiable(_associatedIdentities);
  String get preferredIdentity => _preferredIdentityOverride.trim().isNotEmpty
      ? _preferredIdentityOverride.trim()
      : _publicIdentity.trim();

  void setPreferredIdentity(String identity) {
    final trimmed = identity.trim();
    if (trimmed.isEmpty) {
      _preferredIdentityOverride = '';
      return;
    }
    if (_associatedIdentities.any((value) => value == trimmed) ||
        trimmed == _publicIdentity.trim()) {
      _preferredIdentityOverride = trimmed;
    }
  }

  Future<void> connectAndRegister() async {
    _requireConfig();
    if (_state == VowifiSmsConnectionState.registered) {
      return;
    }
    _log(
      'normalized from SIM imsi=${config.imsi} mcc=${config.mcc} mnc=${config.mnc} mnc_length=${config.mncLength} smsc=${config.smsc} domain=${config.domain} epdg=${config.epdgServer} apn=${config.apn} private_identity=${config.privateIdentity}',
    );
    _emitState(VowifiSmsConnectionState.connecting, info: 'Connecting');
    try {
      _connection = await _openConnection();
      _socketSubscription = _connection!.listen(
        _onData,
        onDone: _handleSocketDone,
        onError: _handleSocketError,
        cancelOnError: false,
      );
      _secPortC = _connection!.localPort;
      _secPortS = _connection!.localPort;
      _emitState(
        VowifiSmsConnectionState.connected,
        info:
            'Connected to ${_connection!.remoteHost}:${_connection!.remotePort}',
      );

      await _performRegister();
    } catch (error) {
      _emitState(VowifiSmsConnectionState.error, error: error.toString());
      rethrow;
    }
  }

  Future<void> refreshRegistration() async {
    if (_connection == null) {
      throw StateError('Socket is not connected');
    }
    await _performRegister();
  }

  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _connection?.close();
    _connection = null;
    _buffer = BytesBuilder(copy: false);
    _pendingResponse?.completeError(StateError('Disconnected'));
    _pendingResponse = null;
    _smsReportQueue.clear();
    _smsReportNotifier = null;
    _recentIncomingKeys.clear();
    _recentIncomingKeySet.clear();
    _emitState(VowifiSmsConnectionState.disconnected, info: 'Disconnected');
  }

  Future<void> sendTextSms(String to, String text) async {
    if (_state != VowifiSmsConnectionState.registered) {
      throw StateError('Not registered');
    }
    _smsReportQueue.clear();
    _smsReportNotifier = null;
    final rpdu = SmsCodec.encodeSubmitRpdu(
      config.smsc,
      to,
      text,
      _smsMr++ & 0xFF,
    );
    final requestUri = _smsRequestUri();
    final toUri = _smscToUri();
    _log(
      'SMS submit to=$to smsc=${config.smsc} req-uri=$requestUri to-uri=$toUri mr=${_smsMr - 1} rpdu=${_hex(rpdu)}',
    );
    var response = await _sendRequestAwaitResponse(
      _buildMessageRequest(
        requestUri: requestUri,
        toUri: toUri,
        body: rpdu,
        contentType: 'application/vnd.3gpp.sms',
      ),
    );
    if (response.statusCode == 494) {
      final securityServer = response.header('security-server');
      if (securityServer.isNotEmpty) {
        _applySecurityServerSelection(securityServer);
      }
      response = await _sendRequestAwaitResponse(
        _buildMessageRequest(
          requestUri: requestUri,
          toUri: toUri,
          body: rpdu,
          contentType: 'application/vnd.3gpp.sms',
        ),
      );
    }
    if (_isDigestChallenge(response)) {
      final authHeader = await _authorizationHeader(
        method: 'MESSAGE',
        uri: requestUri,
        rawHeader: _challengeHeader(response),
      );
      response = await _sendRequestAwaitResponse(
        _buildMessageRequest(
          requestUri: requestUri,
          toUri: toUri,
          body: rpdu,
          contentType: 'application/vnd.3gpp.sms',
          authHeaderName: response.statusCode == 407
              ? 'Proxy-Authorization'
              : 'Authorization',
          authHeaderValue: authHeader,
        ),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log(
        'SMS send rejected: status=${response.startLine} warning="${response.header('warning')}" unsupported="${response.header('unsupported')}"',
      );
      throw StateError('MESSAGE failed: ${response.startLine}');
    }
    _log('SMS send accepted: ${response.startLine} to=$to');

    _events.add(
      VowifiSmsEvent.message(
        VowifiSmsMessage(
          direction: VowifiSmsDirection.outbound,
          peer: to,
          text: text,
          timestamp: DateTime.now(),
          status: response.startLine,
        ),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (true) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        break;
      }
      final report = await _waitForSmsReport(remaining);
      if (report == null) {
        break;
      }
      final upper = report.text.toUpperCase();
      if (upper.contains('SMS-SUBMIT-REPORT FAILURE')) {
        throw StateError('MESSAGE failed: ${report.text}');
      }
      if (upper.contains('SMS-SUBMIT-REPORT ACCEPTED') ||
          upper.contains('SMS-STATUS-REPORT')) {
        _log('SMS report: ${report.text}');
        return;
      }
      _log('Ignoring intermediate SMS report: ${report.text}');
    }
  }

  Future<void> _performRegister() async {
    _log(
      'trying REGISTER via P-CSCF ${_connection!.remoteHost}:${_connection!.remotePort}',
    );
    final step1 = _buildRegister();
    // _log('DEBUG REGISTER size: ${step1.length} bytes');
    // _logRequest('REGISTER step1 send', step1);
    var response = await _sendRequestAwaitResponse(step1);
    _log('REGISTER step1 status=${response.startLine}');
    var authRound = 0;
    while (_isDigestChallenge(response) && authRound < 2) {
      _log(
        'REGISTER challenge auth="${_challengeHeader(response)}" security-server="${response.header('security-server')}"',
      );
      final securityServer = response.header('security-server');
      if (securityServer.isNotEmpty) {
        _applySecurityServerSelection(securityServer);
      }
      final authHeader = await _authorizationHeader(
        method: 'REGISTER',
        uri: 'sip:${config.requestRealm}',
        rawHeader: _challengeHeader(response),
      );
      final step2 = _buildRegister(
        authHeaderName: response.statusCode == 407
            ? 'Proxy-Authorization'
            : 'Authorization',
        authHeaderValue: authHeader,
      );
      // _log('REGISTER step2 authz: $authHeader');
      // _logRequest('REGISTER step2 send round=0', step2);
      final connection = _connection;
      if (connection is _TunnelSipConnection &&
          _lastDigestAka != null &&
          _lastDigestAka!.auts.isEmpty &&
          _lastDigestAka!.ik.isNotEmpty &&
          _lastDigestAka!.ck.isNotEmpty) {
        response = await _sendAuthWithImsFallback(
          connection,
          step2,
          _lastDigestAka!.ik,
          _lastDigestAka!.ck,
        );
      } else {
        response = await _sendRequestAwaitResponse(step2);
      }
      _log('REGISTER step2 status round=$authRound: ${response.startLine}');
      authRound++;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log(
        'REGISTER rejected status=${response.startLine} require="${response.header('require')}" proxy-require="${response.header('proxy-require')}" unsupported="${response.header('unsupported')}" warning="${response.header('warning')}"',
      );
      _log('REGISTER reject headers=${response.headers}');
      throw StateError('REGISTER failed: ${response.startLine}');
    }

    _registeredUntil = _extractRegistrationExpiry(response);
    _associatedIdentities = _extractAssociatedIdentities(response);
    _publicIdentity = _extractAssociatedIdentity(response);
    if (_preferredIdentityOverride.trim().isNotEmpty &&
        !_associatedIdentities.contains(_preferredIdentityOverride.trim())) {
      _preferredIdentityOverride = '';
    }
    if (_publicIdentity.isNotEmpty) {
      _log('selected public identity from register: $_publicIdentity');
    }
    if (_associatedIdentities.isNotEmpty) {
      for (final identity in _associatedIdentities) {
        _log('P-Associated-URI: <$identity>');
      }
    }
    _log('registered: ${response.startLine}');
    _emitState(VowifiSmsConnectionState.registered, info: response.startLine);
  }

  void _requireConfig() {
    if (config.sipServer.trim().isEmpty ||
        config.domain.trim().isEmpty ||
        config.username.trim().isEmpty ||
        config.smsc.trim().isEmpty) {
      throw ArgumentError('Missing SIP server, domain, username, or SMSC.');
    }
  }

  Future<_SipConnection> _openConnection() async {
    if (config.useEpdg) {
      final provider = akaProvider;
      if (provider == null) {
        throw StateError('AKA provider required for ePDG attach');
      }
      final tunnel = await VowifiEpdgTunnel.attach(
        config: config,
        akaProvider: provider,
        onInfo: (info) {
          _log(info);
          _events.add(VowifiSmsEvent.info(info));
        },
      );
      return _TunnelSipConnection(tunnel);
    }
    final endpoint = _parseEndpoint(config.sipServer, config.transport);
    return _SocketSipConnection(await switch (config.transport) {
      VowifiTransport.udp => throw UnsupportedError(
        'Direct UDP SIP is not implemented',
      ),
      VowifiTransport.tcp => Socket.connect(
        endpoint.host,
        endpoint.port,
        timeout: const Duration(seconds: 10),
      ),
      VowifiTransport.tls => SecureSocket.connect(
        endpoint.host,
        endpoint.port,
        timeout: const Duration(seconds: 10),
        onBadCertificate: (_) => config.tlsSkipVerify,
      ),
    });
  }

  Future<_SipMessage> _sendRequestAwaitResponse(
    List<int> request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_connection == null) {
      throw StateError('Socket is not connected');
    }
    if (_pendingResponse != null) {
      throw StateError('Another SIP request is already in flight');
    }
    final completer = Completer<_SipMessage>();
    _pendingResponse = completer;
    await _connection!.send(Uint8List.fromList(request));
    // _logPacket('tx', request);
    try {
      final response = await completer.future.timeout(timeout);
      _logResponse(response);
      return response;
    } finally {
      if (identical(_pendingResponse, completer)) {
        _pendingResponse = null;
      }
    }
  }

  void _onData(Uint8List data) {
    // _logPacket('rx', data);
    _buffer.add(data);
    while (true) {
      final message = _tryParseMessage(_buffer.takeBytes());
      if (message.message == null) {
        if (message.remaining.isNotEmpty) {
          _buffer.add(message.remaining);
        }
        break;
      }
      if (message.remaining.isNotEmpty) {
        _buffer.add(message.remaining);
      }
      _handleMessage(message.message!);
    }
  }

  void _handleMessage(_SipMessage message) {
    if (message.isResponse) {
      final pending = _pendingResponse;
      if (pending != null && !pending.isCompleted) {
        pending.complete(message);
      }
      return;
    }

    switch (message.method) {
      case 'MESSAGE':
        _log(
          'MESSAGE received content-type="${message.header('content-type')}" from="${message.header('from')}"',
        );
        _sendResponse(message, 200, 'OK');
        final contentType = message.header('content-type');
        final ack = contentType.contains('application/vnd.3gpp.sms')
            ? SmsCodec.buildRpAck(message.body)
            : null;
        if (ack != null) {
          final destination = _extractUri(
            _firstNonEmpty(
              message.header('p-asserted-identity'),
              message.header('from'),
            ),
          );
          if (destination.isNotEmpty) {
            unawaited(
              _connection?.send(
                Uint8List.fromList(
                  _buildSmsRpAckRequest(
                    destination: destination,
                    inReplyTo: _firstNonEmpty(
                      message.header('call-id'),
                      message.header('callid'),
                    ),
                    body: ack,
                  ),
                ),
              ),
            );
            _log('SMS RP-ACK sent to=$destination');
          }
        }
        final incomingKey = _incomingMessageKey(message);
        if (_recentIncomingKeySet.contains(incomingKey)) {
          _log(
            'Duplicate inbound MESSAGE ignored call-id="${message.header('call-id')}" cseq="${message.header('cseq')}"',
          );
          break;
        }
        _rememberIncomingKey(incomingKey);
        try {
          final decoded = SmsCodec.decode(contentType, message.body);
          _log('SMS report/message: ${decoded.text}');
          if (_isSmsReport(decoded)) {
            _smsReportQueue.add(decoded);
            _smsReportNotifier?.complete();
            _smsReportNotifier = null;
          }
          _events.add(VowifiSmsEvent.message(decoded));
        } catch (error) {
          _events.add(VowifiSmsEvent.error('SMS decode failed: $error'));
        }
        break;
      case 'OPTIONS':
        _sendResponse(message, 200, 'OK');
        break;
      default:
        _sendResponse(message, 405, 'Method Not Allowed');
        break;
    }
  }

  void _sendResponse(_SipMessage request, int statusCode, String reason) {
    if (_connection == null) {
      return;
    }
    final to = request.header('to').contains(';tag=')
        ? request.header('to')
        : '${request.header('to')};tag=$_localToTag';
    final lines = <String>[
      'SIP/2.0 $statusCode $reason',
      'Via: ${request.header('via')}',
      'From: ${request.header('from')}',
      'To: $to',
      'Call-ID: ${request.header('call-id')}',
      'CSeq: ${request.header('cseq')}',
      'Content-Length: 0',
      '',
      '',
    ];
    _log('SIP response tx: SIP/2.0 $statusCode $reason for ${request.method}');
    unawaited(
      _connection!.send(Uint8List.fromList(ascii.encode(lines.join('\r\n')))),
    );
  }

  void _handleSocketDone() {
    _emitState(VowifiSmsConnectionState.disconnected, info: 'Socket closed');
  }

  void _handleSocketError(Object error, [StackTrace? _]) {
    _emitState(VowifiSmsConnectionState.error, error: error.toString());
  }

  bool _isSmsReport(VowifiSmsMessage message) {
    final upper = message.text.toUpperCase();
    return message.direction == VowifiSmsDirection.system &&
        (upper.contains('SMS-SUBMIT-REPORT') ||
            upper.contains('SMS-STATUS-REPORT') ||
            upper.contains('SMS-RPDU'));
  }

  Future<VowifiSmsMessage?> _waitForSmsReport(Duration timeout) async {
    if (_smsReportQueue.isNotEmpty) {
      return _smsReportQueue.removeFirst();
    }
    final notifier = Completer<void>();
    _smsReportNotifier = notifier;
    try {
      await notifier.future.timeout(timeout);
    } on TimeoutException {
      return null;
    } finally {
      if (identical(_smsReportNotifier, notifier)) {
        _smsReportNotifier = null;
      }
    }
    return _smsReportQueue.isEmpty ? null : _smsReportQueue.removeFirst();
  }

  String _incomingMessageKey(_SipMessage message) {
    return [
      message.method,
      message.header('call-id'),
      message.header('cseq'),
      message.header('from'),
      _hex(message.body),
    ].join('|');
  }

  void _rememberIncomingKey(String key) {
    if (_recentIncomingKeySet.add(key)) {
      _recentIncomingKeys.addLast(key);
    }
    while (_recentIncomingKeys.length > 256) {
      final removed = _recentIncomingKeys.removeFirst();
      _recentIncomingKeySet.remove(removed);
    }
  }

  void _emitState(
    VowifiSmsConnectionState state, {
    String? info,
    String? error,
  }) {
    _state = state;
    _events.add(VowifiSmsEvent.state(state, info: info, error: error));
  }

  List<int> _buildRegister({String? authHeaderName, String? authHeaderValue}) {
    final endpoint = _connection!;
    final viaTransport = endpoint.sipTransport;
    final initial = authHeaderName == null || authHeaderValue == null;
    final viaPort = _secPortS > 0 ? _secPortS : endpoint.localPort;
    final contact = _registerContact(endpoint, viaPort);
    final sentBy = _sipHostPort(endpoint.localHost, viaPort);
    final headers = <List<String>>[
      [
        'Via',
        'SIP/2.0/$viaTransport $sentBy;rport;branch=z9hG4bK${_randomToken(8)}',
      ],
      ['Max-Forwards', '70'],
      ['From', '<${_identityUri()}>;tag=$_fromTag'],
      ['To', '<${_identityUri()}>'],
      ['Call-ID', _registerCallId],
      ['CSeq', '${_cseq++} REGISTER'],
      ['Require', 'sec-agree'],
      ['Proxy-Require', 'sec-agree'],
      ['Contact', contact],
      ['Expires', config.registerExpires.toString()],
      ['Supported', 'outbound, path, gruu'],
      ['P-Visited-Network-ID', '"${config.domain}"'],
      ['P-Access-Network-Info', 'IEEE-802.11;i-wlan-node-id=ffffffffffff'],
      ['User-Agent', _iphoneUserAgent],
      ['Security-Client', _securityClient()],
    ];
    if (_securityVerify.isNotEmpty) {
      headers.add(['Security-Verify', _securityVerify]);
    }
    if (initial) {
      headers.add(['Authorization', _initialRegisterAuthorization()]);
    } else {
      headers.add([authHeaderName, authHeaderValue]);
    }
    return _buildRequest(
      'REGISTER sip:${config.requestRealm} SIP/2.0',
      headers,
      const <int>[],
    );
  }

  List<int> _buildMessageRequest({
    required String requestUri,
    required String toUri,
    required List<int> body,
    required String contentType,
    String? authHeaderName,
    String? authHeaderValue,
    List<List<String>> extraHeaders = const <List<String>>[],
  }) {
    final endpoint = _connection!;
    final viaTransport = endpoint.sipTransport;
    final sentBy = _sipHostPort(endpoint.localHost, endpoint.localPort);
    final headers = <List<String>>[
      [
        'Via',
        'SIP/2.0/$viaTransport $sentBy;rport;branch=z9hG4bK${_randomToken(8)}',
      ],
      ['Max-Forwards', '70'],
      ['From', '<${_identityUri()}>;tag=$_fromTag'],
      ['To', '<$toUri>'],
      ['Call-ID', _randomToken(16)],
      ['CSeq', '${_cseq++} MESSAGE'],
      ['Contact', _registerContact(endpoint, endpoint.localPort)],
      ['P-Preferred-Identity', '<${_identityUri()}>'],
      ['Require', 'sec-agree'],
      ['Proxy-Require', 'sec-agree'],
      ['User-Agent', _iphoneUserAgent],
      ['Content-Type', contentType],
    ];
    if (contentType.contains('application/vnd.3gpp.sms')) {
      headers.addAll(<List<String>>[
        ['Content-Transfer-Encoding', 'binary'],
        ['P-Asserted-Identity', '<${_identityUri()}>'],
        [
          'Supported',
          _securityVerify.isNotEmpty
              ? 'path, gruu, sec-agree'
              : 'path, gruu, sec-agree',
        ],
        ['Allow', 'MESSAGE'],
        ['Accept-Contact', '*;+g.3gpp.smsip;require;explicit'],
        ['Request-Disposition', 'no-fork'],
      ]);
    }
    final securityClient = _securityClient();
    if (securityClient.isNotEmpty) {
      headers.add(['Security-Client', securityClient]);
    }
    if (_securityVerify.isNotEmpty) {
      headers.add(['Security-Verify', _securityVerify]);
    }
    if (authHeaderName != null && authHeaderValue != null) {
      headers.add([authHeaderName, authHeaderValue]);
    }
    if (extraHeaders.isNotEmpty) {
      headers.addAll(extraHeaders);
    }
    return _buildRequest('MESSAGE $requestUri SIP/2.0', headers, body);
  }

  List<int> _buildSmsRpAckRequest({
    required String destination,
    required String inReplyTo,
    required List<int> body,
  }) {
    final extraHeaders = <List<String>>[
      ['Supported', 'path, gruu, sec-agree'],
      ['Allow', 'MESSAGE'],
      ['Accept-Contact', '*;+g.3gpp.smsip'],
      ['Request-Disposition', 'no-fork'],
    ];
    final trimmedReplyTo = inReplyTo.trim();
    if (trimmedReplyTo.isNotEmpty) {
      extraHeaders.insert(0, ['In-Reply-To', trimmedReplyTo]);
    }
    return _buildMessageRequest(
      requestUri: destination,
      toUri: destination,
      body: body,
      contentType: 'application/vnd.3gpp.sms',
      extraHeaders: extraHeaders,
    );
  }

  List<int> _buildRequest(
    String startLine,
    List<List<String>> headers,
    List<int> body,
  ) {
    final builder = StringBuffer('$startLine\r\n');
    for (final header in headers) {
      builder.write('${header[0]}: ${header[1]}\r\n');
    }
    builder.write('Content-Length: ${body.length}\r\n\r\n');
    return <int>[...ascii.encode(builder.toString()), ...body];
  }

  _ParsedMessage _tryParseMessage(Uint8List bytes) {
    final separator = _indexOf(bytes, const <int>[13, 10, 13, 10]);
    if (separator < 0) {
      return _ParsedMessage(null, bytes);
    }
    final headerText = latin1.decode(
      bytes.sublist(0, separator),
      allowInvalid: true,
    );
    final lines = headerText.split('\r\n');
    if (lines.isEmpty) {
      return _ParsedMessage(null, bytes);
    }
    var contentLength = 0;
    for (final line in lines.skip(1)) {
      final index = line.indexOf(':');
      if (index <= 0) {
        continue;
      }
      final key = line.substring(0, index).trim().toLowerCase();
      if (key == 'content-length') {
        contentLength = int.tryParse(line.substring(index + 1).trim()) ?? 0;
      }
    }
    final messageLength = separator + 4 + contentLength;
    if (bytes.length < messageLength) {
      return _ParsedMessage(null, bytes);
    }

    final message = _SipMessage.parse(bytes.sublist(0, messageLength));
    final remaining = bytes.sublist(messageLength);
    return _ParsedMessage(message, remaining);
  }

  bool _isDigestChallenge(_SipMessage message) {
    return message.statusCode == 401 ||
        message.statusCode == 407 ||
        _challengeHeader(message).isNotEmpty;
  }

  String _registerContact(_SipConnection endpoint, int port) {
    final configuredIdentity = config.deviceIdentity.trim();
    final deviceIdentity = configuredIdentity.isEmpty
        ? _defaultDeviceIdentity
        : configuredIdentity;
    final instance = '<urn:gsma:imei:$deviceIdentity>';
    final host = _sipUriHost(endpoint.localHost);
    return '<sip:${config.username}@$host:$port;transport=${endpoint.sipTransport.toLowerCase()}>;+g.3gpp.smsip;reg-id=1;ob;+sip.instance="$instance"';
  }

  String _firstNonEmpty(String a, String b) {
    final first = a.trim();
    if (first.isNotEmpty) {
      return first;
    }
    return b.trim();
  }

  String _securityClient() {
    final portC = _secPortC > 0 ? _secPortC : (_connection?.localPort ?? 0);
    final portS = _secPortS > 0 ? _secPortS : (_connection?.localPort ?? 0);
    return 'ipsec-3gpp;alg=hmac-md5-96;ealg=null;mod=trans;port-c=$portC;port-s=$portS;prot=esp;spi-c=$_secSpiC;spi-s=$_secSpiS';
  }

  String _initialRegisterAuthorization() {
    final privateIdentity = config.privateIdentity.trim().isNotEmpty
        ? config.privateIdentity.trim()
        : '${config.username}@${config.requestRealm}';
    return 'Digest uri="sip:${config.requestRealm}",username="$privateIdentity",response="",realm="${config.requestRealm}",nonce="",algorithm=AKAv1-MD5';
  }

  void _applySecurityServerSelection(String header) {
    _securityVerify = header.trim();
    final fields = _parseParameterHeader(header);
    _srvSpiC = int.tryParse(fields['spi-c'] ?? '') ?? 0;
    _srvSpiS = int.tryParse(fields['spi-s'] ?? '') ?? 0;
    _srvPortC = int.tryParse(fields['port-c'] ?? '') ?? 0;
    _srvPortS = int.tryParse(fields['port-s'] ?? '') ?? 0;
    _log(
      'Security-Server selected spi-c=$_srvSpiC spi-s=$_srvSpiS port-c=$_srvPortC port-s=$_srvPortS (client offer spi-c=$_secSpiC spi-s=$_secSpiS port-c=$_secPortC port-s=$_secPortS)',
    );
    final connection = _connection;
    if (connection is _TunnelSipConnection) {
      if (_srvPortS > 0) {
        connection.tunnel.setRemotePort(_srvPortS);
      }
    }
  }

  Future<_SipMessage> _sendAuthWithImsFallback(
    _TunnelSipConnection connection,
    List<int> request,
    List<int> ik,
    List<int> ck,
  ) async {
    final profiles = _imsProfiles(
      localPort: connection.localPort,
      ik: ik,
      ck: ck,
    );
    if (profiles.isEmpty) {
      return _sendRequestAwaitResponse(
        request,
        timeout: const Duration(milliseconds: 2500),
      );
    }
    final ordered = _prioritizeImsProfiles(profiles);
    Object? lastError;
    for (var i = 0; i < ordered.length; i++) {
      final profile = ordered[i];
      _log(
        'REGISTER step2 ims profile=${i + 1}/${ordered.length} name=${profile.name} key=${profile.keyName} spi-in=0x${profile.spiIn.toRadixString(16).padLeft(8, '0')} spi-out=0x${profile.spiOut.toRadixString(16).padLeft(8, '0')} out-port=${profile.portC} in-port=${profile.portIn} peer-in=${profile.peerPortIn}',
      );
      connection.tunnel.configureImsIpSec(
        spiIn: profile.spiIn,
        spiOut: profile.spiOut,
        portC: profile.portC,
        portIn: profile.portIn,
        peerPortIn: profile.peerPortIn,
        ik: Uint8List.fromList(profile.key),
      );
      try {
        final response = await _sendRequestAwaitResponse(
          request,
          timeout: const Duration(milliseconds: 2500),
        );
        _imsPreferredProfile = profile.name;
        _imsPreferredKey = profile.keyName;
        return response;
      } on TimeoutException catch (error) {
        lastError = error;
        _log('REGISTER step2 ims profile timeout name=${profile.name}');
      }
    }
    throw lastError ?? TimeoutException('IMS fallback exhausted');
  }

  List<_ImsProfile> _prioritizeImsProfiles(List<_ImsProfile> profiles) {
    if (_imsPreferredProfile.isEmpty || _imsPreferredKey.isEmpty) {
      return profiles;
    }
    final preferred = <_ImsProfile>[];
    final rest = <_ImsProfile>[];
    for (final profile in profiles) {
      if (profile.name == _imsPreferredProfile &&
          profile.keyName == _imsPreferredKey) {
        preferred.add(profile);
      } else {
        rest.add(profile);
      }
    }
    return <_ImsProfile>[...preferred, ...rest];
  }

  List<_ImsProfile> _imsProfiles({
    required int localPort,
    required List<int> ik,
    required List<int> ck,
  }) {
    final shapes =
        <
          ({
            String name,
            int spiIn,
            int spiOut,
            int portC,
            int portIn,
            int peerPortIn,
          })
        >[
          (
            name: 'legacy-ss-cport',
            spiIn: _secSpiS,
            spiOut: _srvSpiS,
            portC: _secPortC,
            portIn: _secPortC,
            peerPortIn: _srvPortC,
          ),
          (
            name: '3gpp-cs',
            spiIn: _srvSpiS,
            spiOut: _secSpiC,
            portC: _secPortC,
            portIn: _secPortS,
            peerPortIn: _srvPortC,
          ),
          (
            name: '3gpp-sc',
            spiIn: _srvSpiC,
            spiOut: _secSpiS,
            portC: _secPortC,
            portIn: _secPortC,
            peerPortIn: _srvPortS,
          ),
          (
            name: 'legacy-ss',
            spiIn: _secSpiS,
            spiOut: _srvSpiS,
            portC: _secPortC,
            portIn: _secPortC,
            peerPortIn: _srvPortS,
          ),
        ];
    final keys = <({String name, List<int> key})>[
      (name: 'IK', key: ik),
      (name: 'CK', key: ck),
    ];
    final out = <_ImsProfile>[];
    final seen = <String>{};
    for (final shape in shapes) {
      if (shape.spiIn == 0 || shape.spiOut == 0) {
        continue;
      }
      final portC = shape.portC > 0 ? shape.portC : localPort;
      final portIn = shape.portIn > 0 ? shape.portIn : portC;
      var peerPortIn = shape.peerPortIn;
      if (peerPortIn <= 0) {
        peerPortIn = _srvPortS;
        if (peerPortIn <= 0) {
          peerPortIn = localPort;
        }
      }
      for (final key in keys) {
        if (key.key.isEmpty) {
          continue;
        }
        final id =
            '${shape.name}|${shape.spiIn}|${shape.spiOut}|$portC|$portIn|$peerPortIn|${base64.encode(key.key)}';
        if (!seen.add(id)) {
          continue;
        }
        out.add(
          _ImsProfile(
            name: shape.name,
            spiIn: shape.spiIn,
            spiOut: shape.spiOut,
            portC: portC,
            portIn: portIn,
            peerPortIn: peerPortIn,
            key: Uint8List.fromList(key.key),
            keyName: key.name,
          ),
        );
      }
    }
    return out;
  }

  Map<String, String> _parseParameterHeader(String raw) {
    final out = <String, String>{};
    for (final part in raw.split(',')) {
      for (final piece in part.split(';')) {
        final trimmed = piece.trim();
        final index = trimmed.indexOf('=');
        if (index <= 0) {
          continue;
        }
        out[trimmed.substring(0, index).trim().toLowerCase()] = trimmed
            .substring(index + 1)
            .trim()
            .replaceAll('"', '');
      }
    }
    return out;
  }

  String _challengeHeader(_SipMessage message) {
    final proxy = message.header('proxy-authenticate');
    if (proxy.isNotEmpty) {
      return proxy;
    }
    return message.header('www-authenticate');
  }

  Future<String> _authorizationHeader({
    required String method,
    required String uri,
    required String rawHeader,
  }) async {
    final challenge = _parseAuthHeader(rawHeader);
    final realm = challenge['realm'] ?? config.requestRealm;
    final nonce = challenge['nonce'] ?? '';
    final qop = config.mcc == '244'
        ? (challenge['qop'] ?? '').split(',').first.trim()
        : '';
    final algorithm = challenge['algorithm'] ?? 'MD5';
    var secret = config.password;
    Uint8List? secretBytes;
    String? auts;
    if (_looksLikeAkaChallenge(algorithm, nonce) &&
        (digestAkaProvider != null || authSecretProvider != null)) {
      _log(
        '${method.toUpperCase()} challenge looks like AKA algorithm=$algorithm nonce_len=${nonce.length}',
      );
      if (digestAkaProvider != null) {
        _lastDigestAka = await digestAkaProvider!(
          VowifiDigestChallenge(
            method: method,
            uri: uri,
            rawHeader: rawHeader,
            fields: challenge,
          ),
        );
        if (_lastDigestAka == null) {
          throw StateError('No AKA response available for SIP digest');
        }
        if (_lastDigestAka!.auts.isNotEmpty) {
          auts = base64.encode(_lastDigestAka!.auts);
          secretBytes = Uint8List(0);
          _log('SIP Digest AKA synchronization failure; sending AUTS');
        } else {
          secretBytes = Uint8List.fromList(_lastDigestAka!.res);
        }
      }
      if (secretBytes == null && secret.isEmpty && authSecretProvider != null) {
        final provided = await authSecretProvider!(
          VowifiDigestChallenge(
            method: method,
            uri: uri,
            rawHeader: rawHeader,
            fields: challenge,
          ),
        );
        if (provided != null && provided.isNotEmpty) {
          secret = provided;
        }
      }
    }
    if (secretBytes == null && secret.isEmpty) {
      throw StateError('No digest secret available for $method');
    }
    final authUser = config.privateIdentity.trim().isNotEmpty
        ? config.privateIdentity.trim()
        : (config.username.contains('@')
              ? config.username
              : '${config.username}@${config.requestRealm}');
    final cnonce = _randomToken(16);
    const nc = '00000001';
    final ha1Bytes = BytesBuilder(copy: false)
      ..add(utf8.encode('$authUser:$realm:'))
      ..add(secretBytes ?? Uint8List.fromList(utf8.encode(secret)));
    final ha1 = md5.convert(ha1Bytes.takeBytes()).toString();
    final ha2 = md5.convert(utf8.encode('$method:$uri')).toString();
    final response = qop.isEmpty
        ? md5.convert(utf8.encode('$ha1:$nonce:$ha2')).toString()
        : md5
              .convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2'))
              .toString();
    final values = <String>[
      'username="$authUser"',
      'realm="$realm"',
      'nonce="$nonce"',
      'uri="$uri"',
      'response="$response"',
      'algorithm=$algorithm',
    ];
    if (auts != null) {
      values.add('auts="$auts"');
    }
    if (qop.isNotEmpty) {
      values.add('qop=$qop');
      values.add('nc=$nc');
      values.add('cnonce="$cnonce"');
    }
    return 'Digest ${values.join(', ')}';
  }

  void _log(String line) {
    onLog?.call(line);
  }

  // ignore: unused_element -- kept for debugging the exchange
  void _logRequest(String prefix, List<int> raw) {
    final msg = _SipMessage.parse(raw);
    _log('$prefix ${msg.startLine}');
    _log('headers=${msg.headers}');
  }

  void _logResponse(_SipMessage msg) {
    _log('SIP response: ${msg.startLine}');
  }

  // ignore: unused_element -- kept for debugging the exchange
  void _logPacket(String dir, List<int> raw) {
    final preview = raw.length > 160 ? raw.sublist(0, 160) : raw;
    _log(
      'sip $dir len=${raw.length} dump=${latin1.decode(preview, allowInvalid: true).replaceAll('\r', '\\r').replaceAll('\n', '\\n')}',
    );
  }

  String _hex(List<int> bytes) => bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();

  bool _looksLikeAkaChallenge(String algorithm, String nonce) {
    if (algorithm.toUpperCase().startsWith('AKAV1')) {
      return true;
    }
    if (nonce.isEmpty) {
      return false;
    }
    try {
      final decoded = base64.decode(base64.normalize(nonce));
      return decoded.length >= 32;
    } catch (_) {
      return false;
    }
  }

  DateTime _extractRegistrationExpiry(_SipMessage response) {
    final directExpires = int.tryParse(response.header('expires'));
    final contact = response.header('contact');
    final contactMatch = RegExp(
      r'expires=([0-9]+)',
      caseSensitive: false,
    ).firstMatch(contact);
    final contactExpires = int.tryParse(contactMatch?.group(1) ?? '');
    final seconds = contactExpires ?? directExpires ?? config.registerExpires;
    return DateTime.now().add(Duration(seconds: seconds));
  }

  String _extractAssociatedIdentity(_SipMessage response) {
    final identities = _extractAssociatedIdentities(response);
    if (identities.isEmpty) {
      return config.publicIdentity.trim();
    }
    for (final uri in identities) {
      if (uri.toLowerCase().startsWith('sip:+')) {
        return uri;
      }
    }
    for (final uri in identities) {
      if (uri.toLowerCase().startsWith('sip:')) {
        return uri;
      }
    }
    for (final uri in identities) {
      if (uri.toLowerCase().startsWith('tel:')) {
        return uri;
      }
    }
    return identities.first;
  }

  List<String> _extractAssociatedIdentities(_SipMessage response) {
    final values = response.headers['p-associated-uri'] ?? const <String>[];
    if (values.isEmpty) {
      final fallback = config.publicIdentity.trim();
      return fallback.isEmpty ? const <String>[] : <String>[fallback];
    }
    final identities = <String>[];
    for (final value in values) {
      final uri = _extractUri(value);
      if (uri.isNotEmpty && !identities.contains(uri)) {
        identities.add(uri);
      }
    }
    return identities;
  }

  Map<String, String> _parseAuthHeader(String raw) {
    final cleaned = raw.trim().replaceFirst(
      RegExp(r'^Digest\s+', caseSensitive: false),
      '',
    );
    final output = <String, String>{};
    for (final item in cleaned.split(',')) {
      final index = item.indexOf('=');
      if (index <= 0) {
        continue;
      }
      final key = item.substring(0, index).trim().toLowerCase();
      final value = item
          .substring(index + 1)
          .trim()
          .replaceAll(RegExp(r'^"|"$'), '');
      output[key] = value;
    }
    return output;
  }

  String _identityUri() {
    if (_preferredIdentityOverride.trim().isNotEmpty) {
      return _preferredIdentityOverride.trim();
    }
    if (_publicIdentity.trim().isNotEmpty) {
      return _publicIdentity.trim();
    }
    final identity = config.identityUri;
    if (identity.isNotEmpty) {
      return identity;
    }
    return 'sip:${config.username}@${config.requestRealm}';
  }

  String _smsRequestUri() {
    var domain = config.requestRealm;
    final privateIdentity = config.privateIdentity.trim();
    final at = privateIdentity.indexOf('@');
    if (at > 0 && at + 1 < privateIdentity.length) {
      domain = privateIdentity.substring(at + 1).trim();
    }
    return 'sip:$domain';
  }

  String _smscToUri() {
    var smsc = config.smsc.trim().replaceFirst(RegExp(r'^(sip:|tel:)'), '');
    smsc = smsc.replaceFirst('+', '');
    var domain = config.requestRealm;
    final privateIdentity = config.privateIdentity.trim();
    final at = privateIdentity.indexOf('@');
    if (at > 0 && at + 1 < privateIdentity.length) {
      domain = privateIdentity.substring(at + 1).trim();
    }
    return 'sip:+$smsc@$domain';
  }

  String _sipHostPort(String host, int port) {
    final formattedHost = _sipUriHost(host);
    return '$formattedHost:$port';
  }

  String _sipUriHost(String host) {
    if (host.contains(':') && !host.startsWith('[') && !host.endsWith(']')) {
      return '[$host]';
    }
    return host;
  }

  static String _extractUri(String value) {
    final trimmed = value.trim();
    final start = trimmed.indexOf('<');
    if (start >= 0) {
      final end = trimmed.indexOf('>', start + 1);
      if (end > start) {
        return trimmed.substring(start + 1, end).trim();
      }
    }
    final semicolon = trimmed.indexOf(';');
    return semicolon >= 0 ? trimmed.substring(0, semicolon).trim() : trimmed;
  }

  static _Endpoint _parseEndpoint(String value, VowifiTransport transport) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Empty SIP server');
    }
    final uri = trimmed.contains('://')
        ? Uri.parse(trimmed)
        : Uri.parse(
            '${switch (transport) {
              VowifiTransport.udp => 'udp',
              VowifiTransport.tcp => 'tcp',
              VowifiTransport.tls => 'tls',
            }}://$trimmed',
          );
    final port = uri.hasPort
        ? uri.port
        : (transport == VowifiTransport.tls ? 5061 : 5060);
    return _Endpoint(uri.host, port);
  }

  static int _indexOf(Uint8List source, List<int> pattern) {
    if (pattern.isEmpty || source.length < pattern.length) {
      return -1;
    }
    for (var index = 0; index <= source.length - pattern.length; index++) {
      var matched = true;
      for (var inner = 0; inner < pattern.length; inner++) {
        if (source[index + inner] != pattern[inner]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return index;
      }
    }
    return -1;
  }

  static String _randomToken(int length) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }

  static int _randomU32() => Random.secure().nextInt(0x7FFFFFFF);
}

class _Endpoint {
  const _Endpoint(this.host, this.port);

  final String host;
  final int port;
}

abstract class _SipConnection {
  String get localHost;
  int get localPort;
  String get remoteHost;
  int get remotePort;
  String get sipTransport;

  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  });

  Future<void> send(Uint8List data);
  Future<void> close();
}

class _SocketSipConnection implements _SipConnection {
  const _SocketSipConnection(this.socket);

  final Socket socket;

  @override
  String get localHost => socket.address.address;

  @override
  int get localPort => socket.port;

  @override
  String get remoteHost => socket.remoteAddress.address;

  @override
  int get remotePort => socket.remotePort;

  @override
  String get sipTransport => socket is SecureSocket ? 'TLS' : 'TCP';

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return socket.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<void> send(Uint8List data) async {
    socket.add(data);
    await socket.flush();
  }

  @override
  Future<void> close() => socket.close();
}

class _TunnelSipConnection implements _SipConnection {
  _TunnelSipConnection(this.tunnel);

  final VowifiEpdgTunnel tunnel;

  @override
  String get localHost => tunnel.localAddress.address;

  @override
  int get localPort => tunnel.localPort;

  @override
  String get remoteHost => tunnel.pcscfHost;

  @override
  int get remotePort => tunnel.pcscfPort;

  @override
  String get sipTransport => 'UDP';

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return tunnel.packets.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<void> send(Uint8List data) => tunnel.send(data);

  @override
  Future<void> close() => tunnel.close();
}

class _ImsProfile {
  _ImsProfile({
    required this.name,
    required this.spiIn,
    required this.spiOut,
    required this.portC,
    required this.portIn,
    required this.peerPortIn,
    required this.key,
    required this.keyName,
  });

  final String name;
  final int spiIn;
  final int spiOut;
  final int portC;
  final int portIn;
  final int peerPortIn;
  final Uint8List key;
  final String keyName;
}

class _ParsedMessage {
  const _ParsedMessage(this.message, this.remaining);

  final _SipMessage? message;
  final Uint8List remaining;
}

class _SipMessage {
  const _SipMessage({
    required this.startLine,
    required this.headers,
    required this.body,
  });

  final String startLine;
  final Map<String, List<String>> headers;
  final List<int> body;

  bool get isResponse => startLine.startsWith('SIP/2.0 ');

  String get method => isResponse ? '' : startLine.split(' ').first;

  int get statusCode {
    if (!isResponse) {
      return 0;
    }
    final parts = startLine.split(' ');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  String header(String key) {
    final values = headers[key.toLowerCase()];
    if (values == null || values.isEmpty) {
      return '';
    }
    return values.first;
  }

  static _SipMessage parse(List<int> raw) {
    final split = VowifiSmsClient._indexOf(Uint8List.fromList(raw), const <int>[
      13,
      10,
      13,
      10,
    ]);
    final headerText = latin1.decode(raw.sublist(0, split), allowInvalid: true);
    final body = raw.sublist(split + 4);
    final lines = headerText.split('\r\n');
    final headers = <String, List<String>>{};
    String? lastKey;
    for (final line in lines.skip(1)) {
      if ((line.startsWith(' ') || line.startsWith('\t')) && lastKey != null) {
        headers[lastKey]![headers[lastKey]!.length - 1] =
            '${headers[lastKey]!.last} ${line.trim()}';
        continue;
      }
      final index = line.indexOf(':');
      if (index <= 0) {
        continue;
      }
      final key = line.substring(0, index).trim().toLowerCase();
      lastKey = key;
      headers
          .putIfAbsent(key, () => <String>[])
          .add(line.substring(index + 1).trim());
    }
    return _SipMessage(startLine: lines.first, headers: headers, body: body);
  }
}
