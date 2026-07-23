import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/janus_config.dart';
import '../models/stream_config.dart';

enum JanusPhase {
  idle,
  connecting,
  joining,
  joined,
  negotiating,
  publishing,
  error,
}

class JanusService {
  ValueChanged<JanusPhase>? onPhaseChange;
  ValueChanged<String>? onError;

  JanusPhase get phase => _phase;
  MediaStream? get localStream => _localStream;

  JanusPhase _phase = JanusPhase.idle;
  StreamConfig? _streamConfig;
  bool _isStoppingPublishing = false;

  String _apiBase = '';
  bool get _isWs => _apiBase.startsWith('ws://') || _apiBase.startsWith('wss://');
  int? _sessionId;
  int? _handleId;

  final _http = _JanusHttp();
  WebSocket? _ws;
  final Map<String, Completer<Map<String, dynamic>>> _transactions = {};

  Completer<void>? _joinCompleter;
  Completer<Map<String, dynamic>>? _jsepCompleter;

  Timer? _keepAliveTimer;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  Future<void> joinRoom(JanusConfig config, StreamConfig streamConfig) async {
    if (_phase != JanusPhase.idle) await dispose();

    _streamConfig = streamConfig;
    _apiBase = _normaliseUrl(config.serverUrl);

    _setPhase(JanusPhase.connecting);

    try {
      if (_isWs) {
        _ws = await WebSocket.connect(_apiBase, protocols: ['janus-protocol']);
        _ws!.listen(_onWsMessage, onDone: _onWsClosed, onError: _onWsError);
      }

      final sessionResp = await _sendCoreRequest({'janus': 'create'});
      _sessionId = (sessionResp['data'] as Map)['id'] as int;

      _startKeepAliveOrPoll();

      final attachResp = await _sendCoreRequest({
        'janus': 'attach',
        'plugin': 'janus.plugin.videoroom',
      });
      _handleId = (attachResp['data'] as Map)['id'] as int;

      _setPhase(JanusPhase.joining);
      _joinCompleter = Completer<void>();

      final joinBody = <String, dynamic>{
        'request': 'join',
        'room': int.tryParse(config.roomId) ?? config.roomId,
        'ptype': 'publisher',
        'display': config.displayName,
      };
      if (config.pin.isNotEmpty) joinBody['pin'] = config.pin;
      await _sendMessage(joinBody);

      await _joinCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
            'Janus join timed out (30 s). Check room ID and server URL.'),
      );

      _setPhase(JanusPhase.joined);
    } catch (e) {
      _setPhase(JanusPhase.error);
      onError?.call('Connection failed: $e');
      await _cleanupSession();
      _setPhase(JanusPhase.idle);
      rethrow;
    }
  }

  Future<void> startPublishing(bool useFrontCamera) async {
    if (_phase != JanusPhase.joined) {
      throw StateError('startPublishing requires phase=joined, got $_phase');
    }

    _setPhase(JanusPhase.negotiating);

    try {
      _pc = await _buildPeerConnection();
      await _acquireLocalMedia(useFrontCamera);

      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }

      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await _pc!.setLocalDescription(offer);

      _jsepCompleter = Completer<Map<String, dynamic>>();
      await _sendMessage({
        'request': 'publish',
        'audio': true,
        'video': true,
        'bitrate': _streamConfig!.bitrateKbps * 1000,
      }, jsep: {
        'type': offer.type,
        'sdp': offer.sdp,
      });

      final answerJsep = await _jsepCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('SDP answer timed out (30 s)'),
      );

      await _pc!.setRemoteDescription(RTCSessionDescription(
        answerJsep['sdp'] as String,
        answerJsep['type'] as String,
      ));

      _setPhase(JanusPhase.publishing);
    } catch (e) {
      _setPhase(JanusPhase.error);
      onError?.call('Failed to start publishing: $e');
      await _cleanupWebRtc();
      _setPhase(JanusPhase.joined);
      rethrow;
    }
  }

  Future<void> stopPublishing() async {
    if (_phase != JanusPhase.publishing) return;
    _isStoppingPublishing = true;
    try {
      await _sendMessage({'request': 'unpublish'});
    } catch (_) {
    } finally {
      await _cleanupWebRtc();
      _setPhase(JanusPhase.joined);
      _isStoppingPublishing = false;
    }
  }

  Future<void> applyStreamConfig(StreamConfig newConfig) async {
    final old = _streamConfig;
    _streamConfig = newConfig;

    if (_phase != JanusPhase.publishing || _pc == null) return;

    final bitrateOnly = newConfig.bitrateKbps != old?.bitrateKbps &&
        newConfig.resolution == old?.resolution &&
        newConfig.fps == old?.fps;

    if (bitrateOnly) {
      await _sendMessage({
        'request': 'configure',
        'bitrate': newConfig.bitrateKbps * 1000,
      });
      return;
    }

    if (newConfig.resolution != old?.resolution || newConfig.fps != old?.fps) {
      await _renegotiate();
    }
  }

  Future<void> dispose() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    if (_phase == JanusPhase.publishing) {
      _isStoppingPublishing = true;
      try {
        await _sendMessage({'request': 'unpublish'});
      } catch (_) {}
    }

    await _cleanupWebRtc();
    await _cleanupSession();

    _streamConfig = null;
    _isStoppingPublishing = false;
    _setPhase(JanusPhase.idle);
  }

  Future<RTCPeerConnection> _buildPeerConnection() async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });

    pc.onIceCandidate = _sendTrickle;

    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (_phase == JanusPhase.publishing && !_isStoppingPublishing) {
          onError?.call('WebRTC peer connection failed');
          _setPhase(JanusPhase.error);
        }
      }
    };

    return pc;
  }

  Future<void> _acquireLocalMedia(bool useFrontCamera) async {
    final sc = _streamConfig!;
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'width': {'ideal': sc.resolution.width},
        'height': {'ideal': sc.resolution.height},
        'frameRate': {'ideal': sc.fps},
        'facingMode': useFrontCamera ? 'user' : 'environment',
      },
    });
  }

  Future<void> _renegotiate() async {
    if (_pc == null) return;
    final offer = await _pc!.createOffer({});
    await _pc!.setLocalDescription(offer);

    _jsepCompleter = Completer<Map<String, dynamic>>();
    await _sendMessage({'request': 'configure'}, jsep: {
      'type': offer.type,
      'sdp': offer.sdp,
    });

    final jsep = await _jsepCompleter!.future.timeout(
      const Duration(seconds: 20),
    );
    await _pc!.setRemoteDescription(
      RTCSessionDescription(jsep['sdp'] as String, jsep['type'] as String),
    );
  }

  Future<Map<String, dynamic>> _sendCoreRequest(
      Map<String, dynamic> payload) async {
    final tx = _tx();
    payload['transaction'] = tx;

    if (_isWs) {
      if (_sessionId != null) payload['session_id'] = _sessionId;
      if (_handleId != null) payload['handle_id'] = _handleId;

      final c = Completer<Map<String, dynamic>>();
      _transactions[tx] = c;

      _ws!.add(jsonEncode(payload));
      final resp = await c.future.timeout(const Duration(seconds: 15));
      _assertOk(resp);
      return resp;
    } else {
      String url = _apiBase;
      if (_sessionId != null) url += '/$_sessionId';
      if (_handleId != null) url += '/$_handleId';
      return _http.post(url, payload);
    }
  }

  Future<Map<String, dynamic>> _sendMessage(
    Map<String, dynamic> body, {
    Map<String, dynamic>? jsep,
  }) {
    final payload = <String, dynamic>{
      'janus': 'message',
      'body': body,
    };
    if (jsep != null) payload['jsep'] = jsep;
    return _sendCoreRequest(payload);
  }

  void _startKeepAliveOrPoll() {
    final interval =
        _isWs ? const Duration(seconds: 30) : const Duration(milliseconds: 300);
    _keepAliveTimer = Timer.periodic(interval, (_) {
      if (_isWs) {
        if (_sessionId != null) {
          _ws?.add(jsonEncode({
            'janus': 'keepalive',
            'session_id': _sessionId,
            'transaction': _tx(),
          }));
        }
      } else {
        _httpPoll();
      }
    });
  }

  Future<void> _httpPoll() async {
    if (_sessionId == null || _isWs) return;
    try {
      final url =
          '$_apiBase/$_sessionId?maxev=1&rid=${DateTime.now().millisecondsSinceEpoch}';
      final resp = await _http.get(url);
      if (resp != null) _dispatch(resp);
    } catch (_) {
    }
  }

  void _onWsMessage(dynamic message) {
    if (message is String) {
      final json = jsonDecode(message) as Map<String, dynamic>;

      final tx = json['transaction'] as String?;
      if (tx != null && _transactions.containsKey(tx)) {
        final janusEvent = json['janus'];
        if (janusEvent == 'success' ||
            janusEvent == 'error' ||
            janusEvent == 'ack') {
          _transactions.remove(tx)!.complete(json);
        }
      }
      _dispatch(json);
    }
  }

  void _onWsClosed() {
    for (final c in _transactions.values) {
      if (!c.isCompleted) c.completeError(Exception('WebSocket closed'));
    }
    _transactions.clear();
    if (_phase != JanusPhase.idle && _phase != JanusPhase.error) {
      onError?.call('WebSocket disconnected unexpectedly');
      dispose();
    }
  }

  void _onWsError(dynamic error) {
    onError?.call('WebSocket error: $error');
  }

  void _dispatch(Map<String, dynamic> json) {
    final ev = json['janus'] as String? ?? '';
    switch (ev) {
      case 'event':
        _handlePluginEvent(json);
        break;
      case 'hangup':
        final reason = json['reason']?.toString() ?? 'server closed';
        if (_phase == JanusPhase.publishing && !_isStoppingPublishing) {
          _cleanupWebRtc();
          _setPhase(JanusPhase.joined);
          if (reason != 'unpublish' && reason != 'Close PC') {
            onError?.call('Stream ended: $reason');
          }
        }
        break;
      case 'error':
        final reason =
            (json['error'] as Map?)?.containsKey('reason') == true
                ? json['error']['reason']
                : json.toString();
        if (!_isStoppingPublishing) {
          onError?.call('Janus error: $reason');
        }
        _failPendingCompleters('$reason');
        break;
    }
  }

  void _handlePluginEvent(Map<String, dynamic> json) {
    final plugindata = json['plugindata'] as Map<String, dynamic>?;
    final data = plugindata?['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final videoroom = data['videoroom'] as String?;
    final jsep = json['jsep'] as Map<String, dynamic>?;

    if (data.containsKey('error')) {
      final msg = '${data['error']} (code ${data['error_code'] ?? '?'})';
      if (!_isStoppingPublishing) {
        onError?.call('VideoRoom error: $msg');
      }
      _failPendingCompleters(msg);
      return;
    }

    switch (videoroom) {
      case 'joined':
        _safeComplete(_joinCompleter);
        break;
      case 'event':
        if (jsep != null) {
          _safeCompleteJsep(_jsepCompleter, jsep);
        }
        break;
      case 'destroyed':
        onError?.call('Room was destroyed by the server');
        dispose();
        break;
      default:
        if (jsep != null) {
          _safeCompleteJsep(_jsepCompleter, jsep);
        }
    }
  }

  Future<void> _sendTrickle(RTCIceCandidate? candidate) async {
    if (_sessionId == null || _handleId == null) return;
    try {
      final Map<String, dynamic> candMap;
      if (candidate == null ||
          candidate.candidate == null ||
          candidate.candidate!.isEmpty) {
        candMap = {'completed': true};
      } else {
        candMap = {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        };
      }
      await _sendCoreRequest({
        'janus': 'trickle',
        'candidate': candMap,
      });
    } catch (_) {
    }
  }

  Future<void> _cleanupWebRtc() async {
    await _localStream?.dispose();
    _localStream = null;

    await _pc?.close();
    _pc = null;
  }

  Future<void> _cleanupSession() async {
    if (_handleId != null && _sessionId != null) {
      try {
        await _sendCoreRequest({'janus': 'detach'});
      } catch (_) {}
      _handleId = null;
    }
    if (_sessionId != null) {
      try {
        await _sendCoreRequest({'janus': 'destroy'});
      } catch (_) {}
      _sessionId = null;
    }

    if (_isWs) {
      await _ws?.close();
      _ws = null;
      for (final c in _transactions.values) {
        if (!c.isCompleted) c.completeError(Exception('Session closed'));
      }
      _transactions.clear();
    }
  }

  String _normaliseUrl(String raw) {
    var url = raw.trim().replaceAll(RegExp(r'/$'), '');
    if (url.startsWith('ws://') || url.startsWith('wss://')) {
      return url;
    }
    if (!url.endsWith('/janus')) url = '$url/janus';
    return url;
  }

  String _tx() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = math.Random();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  void _safeComplete(Completer<void>? c) {
    if (c != null && !c.isCompleted) c.complete();
  }

  void _safeCompleteJsep(
      Completer<Map<String, dynamic>>? c, Map<String, dynamic> jsep) {
    if (c != null && !c.isCompleted) c.complete(jsep);
  }

  void _failPendingCompleters(String msg) {
    final err = Exception(msg);
    if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
      _joinCompleter!.completeError(err);
    }
    if (_jsepCompleter != null && !_jsepCompleter!.isCompleted) {
      _jsepCompleter!.completeError(err);
    }
  }

  void _setPhase(JanusPhase p) {
    _phase = p;
    onPhaseChange?.call(p);
  }
}

void _assertOk(Map<String, dynamic> json) {
  if (json['janus'] == 'error') {
    final reason =
        (json['error'] as Map?)?.containsKey('reason') == true
            ? json['error']['reason']
            : json.toString();
    throw Exception('[Janus] $reason');
  }
}

final janusServiceProvider = Provider<JanusService>((ref) {
  final service = JanusService();
  ref.onDispose(service.dispose);
  return service;
});

class _JanusHttp {
  final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 60);

  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(url);
    final req = await _client.postUrl(uri);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final resp = await req.close();
    final raw = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _assertOk(json);
    return json;
  }

  Future<Map<String, dynamic>?> get(String url) async {
    final uri = Uri.parse(url);
    final req = await _client.getUrl(uri);
    final resp = await req.close();
    if (resp.statusCode == 204) return null;
    final raw = await resp.transform(utf8.decoder).join();
    if (raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.isNotEmpty ? decoded.first as Map<String, dynamic> : null;
    }
    return decoded as Map<String, dynamic>;
  }
}
