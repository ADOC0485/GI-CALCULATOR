import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sends one profile to another device on the same network (Wi-Fi/LAN).
///
/// The sender listens on [transferPort] and shows a 9-digit code: the first
/// 3 digits are the last part of its network address (so the receiver finds
/// it without searching) and the other 6 are a one-time secret.
///
/// Both sides agree on a key with X25519 and mix the secret into it, so the
/// data is encrypted (AES-GCM) and only someone who typed the right code
/// can read it. After [maxAttempts] wrong codes, or [codeLifetime], the
/// sender stops listening.
const transferPort = 47815;
const maxAttempts = 3;
const codeLifetime = Duration(minutes: 5);

/// A message to show the person, in Spanish.
class TransferException implements Exception {
  const TransferException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The code the sender shows and the receiver types.
class TransferCode {
  const TransferCode(this.host, this.secret);

  /// Last number of the sender's IPv4 address (0–255).
  final int host;

  /// Six digits.
  final String secret;

  String get digits => '${host.toString().padLeft(3, '0')}$secret';

  /// «042 718 305».
  String get text =>
      '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';

  static TransferCode parse(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) {
      throw const TransferException('El código tiene 9 números.');
    }
    final host = int.parse(digits.substring(0, 3));
    if (host > 255) {
      throw const TransferException('Ese código no es válido. Revísalo.');
    }
    return TransferCode(host, digits.substring(3));
  }

  static TransferCode random(int host) {
    final r = Random.secure();
    return TransferCode(host, List.generate(6, (_) => r.nextInt(10)).join());
  }
}

bool _isPrivate(InternetAddress a) {
  final b = a.rawAddress;
  return b[0] == 10 ||
      (b[0] == 192 && b[1] == 168) ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31);
}

/// IPv4 addresses of this device on local networks, home Wi-Fi first
/// (192.168.x.x), then 10.x.x.x, then 172.16–31.x.x (often virtual
/// adapters on a PC).
Future<List<InternetAddress>> localAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  final all = [
    for (final i in interfaces)
      for (final a in i.addresses)
        if (_isPrivate(a)) a,
  ];
  int rank(InternetAddress a) => switch (a.rawAddress[0]) {
    192 => 0,
    10 => 1,
    _ => 2,
  };
  all.sort((a, b) => rank(a).compareTo(rank(b)));
  return all;
}

// --- Framing: [type byte][4-byte length][bytes] -------------------------

const _plain = 0, _sealed = 1;
const _maxFrame = 64 * 1024 * 1024;

class _Frames {
  _Frames(Socket socket) : _input = StreamIterator(socket);
  final StreamIterator<Uint8List> _input;
  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);

  Future<Uint8List> _take(int n, Duration timeout) async {
    while (_pending.length < n) {
      final more = await _input.moveNext().timeout(timeout);
      if (!more) {
        throw const TransferException('Se cortó la conexión.');
      }
      _buffer
        ..add(_pending)
        ..add(_input.current);
      _pending = _buffer.takeBytes();
    }
    final out = Uint8List.sublistView(_pending, 0, n);
    _pending = Uint8List.fromList(Uint8List.sublistView(_pending, n));
    return Uint8List.fromList(out);
  }

  Future<(int, Uint8List)> read({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final head = await _take(5, timeout);
    final length = ByteData.sublistView(head).getUint32(1);
    if (length > _maxFrame) {
      throw const TransferException('Llegó un mensaje demasiado grande.');
    }
    return (head[0], await _take(length, timeout));
  }

  Future<void> cancel() => _input.cancel();
}

void _write(Socket socket, int type, List<int> bytes) {
  final head = ByteData(5)
    ..setUint8(0, type)
    ..setUint32(1, bytes.length);
  socket
    ..add(head.buffer.asUint8List())
    ..add(bytes);
}

void _writeJson(Socket socket, Map<String, Object?> json) =>
    _write(socket, _plain, utf8.encode(jsonEncode(json)));

Map<String, dynamic> _json(int type, Uint8List bytes) {
  if (type != _plain) throw const TransferException('Respuesta inesperada.');
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic>) {
    throw const TransferException('Respuesta inesperada.');
  }
  return value;
}

// --- Crypto ---------------------------------------------------------------

final _x25519 = X25519();
final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
const _hello = 'genshin-progress-planner/hola';

Future<SecretKey> _deriveKey(
  SimpleKeyPair mine,
  List<int> theirPublic,
  List<int> salt,
  String secret,
) async {
  final shared = await _x25519.sharedSecretKey(
    keyPair: mine,
    remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519),
  );
  return _hkdf.deriveKey(
    secretKey: shared,
    nonce: salt,
    info: utf8.encode('gpp-perfil-v1:$secret'),
  );
}

Future<List<int>> _seal(SecretKey key, List<int> data) async =>
    (await _aes.encrypt(data, secretKey: key)).concatenation();

Future<List<int>> _open(SecretKey key, List<int> data) => _aes.decrypt(
  SecretBox.fromConcatenation(
    data,
    nonceLength: _aes.nonceLength,
    macLength: _aes.macAlgorithm.macLength,
  ),
  secretKey: key,
);

// --- Sender ---------------------------------------------------------------

enum SendStage { waiting, sending, done, failed }

class SendStatus {
  const SendStatus(this.stage, [this.message]);
  final SendStage stage;
  final String? message;
}

/// Listens for one receiver and hands it [payload].
class ProfileSender {
  ProfileSender._(this._server, this.code, this._payload) {
    _expiry = Timer(codeLifetime, () {
      _finish(const SendStatus(SendStage.failed, 'El código venció.'));
    });
    _server.listen(_handle);
  }

  /// Starts listening. [host] replaces the detected address (tests).
  static Future<ProfileSender> start(
    List<int> payload, {
    int? host,
    InternetAddress? bindAddress,
    int port = transferPort,
  }) async {
    final number =
        host ??
        await () async {
          final addresses = await localAddresses();
          if (addresses.isEmpty) {
            throw const TransferException(
              'No estás conectado a una red Wi-Fi o LAN.',
            );
          }
          return addresses.first.rawAddress[3];
        }();
    final ServerSocket server;
    try {
      server = await ServerSocket.bind(
        bindAddress ?? InternetAddress.anyIPv4,
        port,
      );
    } on SocketException {
      throw const TransferException(
        'No se pudo abrir la conexión. Cierra otros envíos abiertos e '
        'inténtalo de nuevo.',
      );
    }
    return ProfileSender._(server, TransferCode.random(number), payload);
  }

  final ServerSocket _server;
  final TransferCode code;
  final List<int> _payload;
  late final Timer _expiry;
  final _status = StreamController<SendStatus>.broadcast();
  SendStatus _current = const SendStatus(SendStage.waiting);
  int _failures = 0;
  bool _busy = false;

  SendStatus get current => _current;
  Stream<SendStatus> get status => _status.stream;
  int get attemptsLeft => maxAttempts - _failures;

  void _emit(SendStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  void _finish(SendStatus s) {
    if (_current.stage == SendStage.done ||
        _current.stage == SendStage.failed) {
      return;
    }
    _emit(s);
    close();
  }

  Future<void> _handle(Socket socket) async {
    if (_busy || _current.stage != SendStage.waiting) {
      socket.destroy();
      return;
    }
    _busy = true;
    final frames = _Frames(socket);
    try {
      final (t1, b1) = await frames.read();
      final hello = _json(t1, b1);
      final theirs = base64Decode('${hello['pub']}');
      final mine = await _x25519.newKeyPair();
      final salt = List.generate(16, (_) => Random.secure().nextInt(256));
      _writeJson(socket, {
        'pub': base64Encode((await mine.extractPublicKey()).bytes),
        'salt': base64Encode(salt),
      });
      final key = await _deriveKey(mine, theirs, salt, code.secret);
      final (t2, b2) = await frames.read();
      try {
        if (t2 != _sealed || utf8.decode(await _open(key, b2)) != _hello) {
          throw const FormatException();
        }
      } catch (_) {
        _failures++;
        _writeJson(socket, {'error': 'code', 'left': attemptsLeft});
        // Stop listening before the receiver hears it was the last try.
        if (_failures >= maxAttempts) {
          _finish(
            const SendStatus(
              SendStage.failed,
              'Se escribió mal el código 3 veces. Genera uno nuevo.',
            ),
          );
        }
        await socket.flush();
        return;
      }
      _emit(const SendStatus(SendStage.sending));
      _write(socket, _sealed, await _seal(key, _payload));
      await socket.flush();
      final (t3, b3) = await frames.read(timeout: const Duration(minutes: 2));
      if (t3 != _sealed || utf8.decode(await _open(key, b3)) != 'ok') {
        throw const TransferException('El otro dispositivo no lo confirmó.');
      }
      _finish(const SendStatus(SendStage.done));
    } catch (e) {
      // A dropped connection lets the receiver try again with the same code.
      if (_current.stage == SendStage.sending) {
        _emit(const SendStatus(SendStage.waiting));
      }
    } finally {
      _busy = false;
      await frames.cancel().catchError((_) {});
      socket.destroy();
    }
  }

  Future<void> close() async {
    _expiry.cancel();
    await _server.close();
    if (_current.stage == SendStage.waiting ||
        _current.stage == SendStage.sending) {
      _emit(const SendStatus(SendStage.failed, 'Envío cancelado.'));
    }
    await _status.close();
  }
}

// --- Receiver -------------------------------------------------------------

/// Candidate addresses of the sender: same network as this device, ending
/// in the code's number.
Future<List<InternetAddress>> _senderAddresses(TransferCode code) async {
  final seen = <String>{};
  return [
    for (final mine in await localAddresses())
      if (seen.add(mine.rawAddress.take(3).join('.')))
        InternetAddress.fromRawAddress(
          Uint8List.fromList([...mine.rawAddress.take(3), code.host]),
        ),
  ];
}

/// Connects to the sender of [input] and returns what it sent.
/// [addresses] replaces the detected candidates (tests).
Future<List<int>> receiveProfile(
  String input, {
  List<InternetAddress>? addresses,
  int port = transferPort,
}) async {
  final code = TransferCode.parse(input);
  final candidates = addresses ?? await _senderAddresses(code);
  if (candidates.isEmpty) {
    throw const TransferException('No estás conectado a una red Wi-Fi o LAN.');
  }
  Socket? socket;
  for (final address in candidates) {
    try {
      socket = await Socket.connect(
        address,
        port,
        timeout: const Duration(seconds: 4),
      );
      break;
    } on SocketException {
      continue;
    }
  }
  if (socket == null) {
    throw const TransferException(
      'No encontré el otro dispositivo. Revisa que los dos estén en la misma '
      'red Wi-Fi, que tenga abierto «Enviar perfil» y que el código sea '
      'correcto.',
    );
  }
  final frames = _Frames(socket);
  try {
    final mine = await _x25519.newKeyPair();
    _writeJson(socket, {
      'v': 1,
      'pub': base64Encode((await mine.extractPublicKey()).bytes),
    });
    final (t1, b1) = await frames.read();
    final reply = _json(t1, b1);
    final key = await _deriveKey(
      mine,
      base64Decode('${reply['pub']}'),
      base64Decode('${reply['salt']}'),
      code.secret,
    );
    _write(socket, _sealed, await _seal(key, utf8.encode(_hello)));
    await socket.flush();
    final (t2, b2) = await frames.read(timeout: const Duration(minutes: 2));
    if (t2 == _plain) {
      final left = _json(t2, b2)['left'];
      throw TransferException(
        left is int && left > 0
            ? 'El código no es correcto. Te quedan $left intentos.'
            : 'El código no es correcto y ya no sirve. Pide que generen otro.',
      );
    }
    final List<int> payload;
    try {
      payload = await _open(key, b2);
    } catch (_) {
      throw const TransferException('Lo recibido llegó dañado.');
    }
    _write(socket, _sealed, await _seal(key, utf8.encode('ok')));
    await socket.flush();
    return payload;
  } on TimeoutException {
    throw const TransferException('El otro dispositivo dejó de responder.');
  } on SocketException {
    throw const TransferException('Se cortó la conexión.');
  } finally {
    await frames.cancel().catchError((_) {});
    socket.destroy();
  }
}

/// Packs a profile for sending: JSON, compressed.
List<int> encodePackage(Map<String, Object?> package) =>
    gzip.encode(utf8.encode(jsonEncode(package)));

Map<String, dynamic> decodePackage(List<int> bytes) {
  try {
    final value = jsonDecode(utf8.decode(gzip.decode(bytes)));
    if (value is Map<String, dynamic>) return value;
  } catch (_) {}
  throw const TransferException('Lo recibido no es un perfil.');
}

/// Starts a sender; tests replace it to use this computer only.
final profileSenderProvider =
    Provider<Future<ProfileSender> Function(List<int> payload)>(
      (ref) => ProfileSender.start,
    );

/// Receives with a code; tests replace it.
final profileReceiverProvider =
    Provider<Future<List<int>> Function(String code)>((ref) => receiveProfile);
