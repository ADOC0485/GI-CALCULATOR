import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lan_transfer.dart';
import 'profile.dart';
import 'profiles_card.dart' show profileDetails;
import 'profile_dialog.dart' show ProfileAvatar;

const _sameNetwork =
    'Los dos dispositivos tienen que estar conectados a la misma red Wi-Fi.';

/// Shows a code and waits for another device to receive one profile.
class SendProfileDialog extends ConsumerStatefulWidget {
  const SendProfileDialog({super.key});

  @override
  ConsumerState<SendProfileDialog> createState() => _SendProfileDialogState();
}

class _SendProfileDialogState extends ConsumerState<SendProfileDialog> {
  String? profileId;
  ProfileSender? sender;
  StreamSubscription<SendStatus>? listening;
  Timer? ticker;
  DateTime? expires;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    ticker?.cancel();
    listening?.cancel();
    sender?.close();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final package = await ref
          .read(profilesProvider.notifier)
          .exportPackage(profileId!);
      final started = await ref.read(profileSenderProvider)(
        encodePackage(package),
      );
      if (!mounted) {
        await started.close();
        return;
      }
      listening = started.status.listen((_) {
        if (mounted) setState(() {});
      });
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() {
        sender = started;
        expires = DateTime.now().add(codeLifetime);
      });
    } on TransferException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'No se pudo preparar el envío.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _again() async {
    ticker?.cancel();
    await listening?.cancel();
    await sender?.close();
    setState(() {
      sender = null;
      ticker = null;
      listening = null;
    });
    await _start();
  }

  Widget _chooser(Profiles data) {
    profileId ??= data.activeId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿Qué perfil quieres enviar?'),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: profileId,
          onChanged: (v) => setState(() => profileId = v),
          child: Column(
            children: [
              for (final p in data.items)
                RadioListTile<String>(
                  key: ValueKey('send-${p.id}'),
                  value: p.id,
                  contentPadding: EdgeInsets.zero,
                  secondary: ProfileAvatar(profile: p, radius: 18),
                  title: Text(p.name),
                  subtitle: Text(profileDetails(p)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Se envía una copia con sus builds, inventario, resina, agenda e '
          'historial. Aquí no cambia nada. $_sameNetwork',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _waiting(ProfileSender s) {
    final theme = Theme.of(context);
    final status = s.current;
    final left = expires == null
        ? Duration.zero
        : expires!.difference(DateTime.now());
    final clock = left.isNegative
        ? '0:00'
        : '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        switch (status.stage) {
          SendStage.done => Icon(
            Icons.check_circle,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          SendStage.failed => Icon(
            Icons.close,
            size: 56,
            color: theme.colorScheme.error,
          ),
          _ => const SizedBox.shrink(),
        },
        if (status.stage == SendStage.waiting ||
            status.stage == SendStage.sending) ...[
          const Text(
            'En el otro dispositivo abre Ajustes › Perfiles › '
            'Recibir perfil y escribe:',
          ),
          const SizedBox(height: 16),
          SelectableText(
            s.code.text,
            key: const ValueKey('send-code'),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status.stage == SendStage.sending
                ? 'Enviando…'
                : 'Esperando… El código vence en $clock.',
            style: theme.textTheme.bodyMedium,
          ),
          if (s.attemptsLeft < maxAttempts)
            Text(
              'Código mal escrito: quedan ${s.attemptsLeft} intentos.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          const SizedBox(height: 8),
          if (status.stage == SendStage.sending)
            const LinearProgressIndicator(),
          Text(_sameNetwork, style: theme.textTheme.bodySmall),
        ] else if (status.stage == SendStage.done)
          const Text('¡Listo! El perfil llegó al otro dispositivo.')
        else
          Text(status.message ?? 'No se pudo enviar.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(profilesProvider).asData?.value;
    final s = sender;
    final stage = s?.current.stage;
    return AlertDialog(
      title: const Text('Enviar perfil'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data == null)
                const LinearProgressIndicator()
              else if (s == null)
                _chooser(data)
              else
                _waiting(s),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(stage == SendStage.done ? 'Cerrar' : 'Cancelar'),
        ),
        if (s == null)
          FilledButton(
            key: const ValueKey('send-start'),
            onPressed: busy || data == null ? null : _start,
            child: const Text('Generar código'),
          )
        else if (stage == SendStage.failed)
          FilledButton(
            onPressed: busy ? null : _again,
            child: const Text('Generar otro código'),
          ),
      ],
    );
  }
}

/// Asks for the code shown on the other device and saves the profile.
class ReceiveProfileDialog extends ConsumerStatefulWidget {
  const ReceiveProfileDialog({super.key});

  @override
  ConsumerState<ReceiveProfileDialog> createState() =>
      _ReceiveProfileDialogState();
}

class _ReceiveProfileDialogState extends ConsumerState<ReceiveProfileDialog> {
  final code = TextEditingController();
  bool busy = false;
  String? error;
  Profile? saved;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  /// null: cancel; false: as a copy; true: replace.
  Future<bool?> _askReplace(Profile existing) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Ya tienes el perfil de ${existing.name}'),
      content: const Text(
        '«Reemplazar» deja el tuyo igual al que llega: lo que tenías en este '
        'perfil aquí se pierde. «Guardar como copia» añade otro perfil.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const ValueKey('receive-copy'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Guardar como copia'),
        ),
        FilledButton(
          key: const ValueKey('receive-replace'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Reemplazar'),
        ),
      ],
    ),
  );

  Future<void> _receive() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final package = decodePackage(
        await ref.read(profileReceiverProvider)(code.text),
      );
      final profiles = ref.read(profilesProvider.notifier);
      final existing = await profiles.sameProfile(package);
      Profile? replace;
      if (existing != null) {
        if (!mounted) return;
        final answer = await _askReplace(existing);
        if (answer == null) {
          setState(() => error = 'No se guardó nada.');
          return;
        }
        if (answer) replace = existing;
      }
      final profile = await profiles.importPackage(package, replace: replace);
      if (mounted) setState(() => saved = profile);
    } on TransferException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on ProfileLimitException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on ProfilePackageException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo recibir el perfil.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = saved;
    return AlertDialog(
      title: const Text('Recibir perfil'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (done != null) ...[
                Center(
                  child: Icon(
                    Icons.check_circle,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text('¡Listo! Llegó el perfil de ${done.name}.'),
              ] else ...[
                const Text(
                  'En el otro dispositivo abre Ajustes › Perfiles › Enviar '
                  'perfil y escribe aquí el código que aparece.',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('receive-code'),
                  controller: code,
                  enabled: !busy,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                    LengthLimitingTextInputFormatter(11),
                  ],
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 2,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Código de 9 números',
                    hintText: '000 000 000',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => busy ? null : _receive(),
                ),
                const SizedBox(height: 8),
                if (busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Conectando…'),
                ],
                Text(_sameNetwork, style: theme.textTheme.bodySmall),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (done == null) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('receive-start'),
            onPressed: busy ? null : _receive,
            child: const Text('Recibir'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(profilesProvider.notifier).activate(done.id);
              if (!context.mounted) return;
              final router = GoRouter.maybeOf(context);
              Navigator.pop(context);
              router?.go('/dashboard');
            },
            child: const Text('Usar ahora'),
          ),
        ],
      ],
    );
  }
}
