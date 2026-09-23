import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:voces/api.dart';
import 'package:voces/story_format.dart';
import 'package:voces/ui/kit.dart';
import 'package:voces/ui/story_card.dart';
import 'package:voces/ui/tokens.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api, required this.onChanged, required this.onLeaveStory});

  final VocesApi api;
  final VoidCallback onChanged;
  final VoidCallback onLeaveStory;

  @override
  State<AccountPage> createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _hidden = true;
  String? _error;
  List<StoryPin> _mine = [];
  bool _loadingMine = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    if (widget.api.account == null) return;
    setState(() => _loadingMine = true);
    try {
      final stories = await widget.api.mine();
      if (mounted) setState(() => _mine = stories);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No hay conexión con el archivo.');
    } finally {
      if (mounted) setState(() => _loadingMine = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await widget.api.register(_email.text.trim(), _password.text, _name.text.trim());
      } else {
        await widget.api.login(_email.text.trim(), _password.text);
      }
      _password.clear();
      widget.onChanged();
      await reload();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'No hay conexión con el archivo. Vuelve a intentarlo en un momento.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    widget.onChanged();
    setState(() {
      _mine = [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.api.account;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final pad = narrow ? 22.0 : 56.0;
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.settle),
      child: account == null
          ? _signedOut(pad, narrow)
          : CustomScrollView(
              key: const ValueKey('in'),
              slivers: [
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, narrow ? 28 : 56, pad, 0),
                    sliver: SliverToBoxAdapter(
                      child: _Profile(account: account, onLogout: _logout),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 48, pad, 20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lo que has dejado', style: display(narrow ? 34 : 44)),
                        const SizedBox(height: 6),
                        Text(
                          _loadingMine
                              ? 'Buscando tus historias…'
                              : (_mine.isEmpty ? 'Todavía nada.' : '${_mine.length} ${_mine.length == 1 ? 'historia' : 'historias'}'),
                          style: text(size: 15, color: Palette.haze),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Notice(message: _error!, action: 'Reintentar', onAction: reload),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 140),
                  sliver: _loadingMine
                      ? const SliverToBoxAdapter(child: LoadingSlab(height: 200, radius: 24))
                      : _mine.isEmpty
                      ? SliverToBoxAdapter(
                          child: Glass(
                            padding: const EdgeInsets.all(26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('¿Quién te ha contado algo de un sitio?', style: display(28)),
                                const SizedBox(height: 8),
                                Text(
                                  'Graba a esa persona. Basta con el móvil y cinco minutos.',
                                  style: text(size: 15.5, color: Palette.haze),
                                ),
                                const SizedBox(height: 20),
                                LampButton(label: 'Dejar una historia', icon: LucideIcons.mic, onPressed: widget.onLeaveStory),
                              ],
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            mainAxisSpacing: 18,
                            crossAxisSpacing: 18,
                            mainAxisExtent: 280,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => StoryCard(key: ValueKey(_mine[index].id), story: _mine[index], showStatus: true),
                            childCount: _mine.length,
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _signedOut(double pad, bool narrow) {
    return Center(
      key: const ValueKey('out'),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 40, pad, 140),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_registering ? 'Abre tu cuenta' : 'Entra para contar', style: display(narrow ? 46 : 58)),
                const SizedBox(height: 12),
                Text(
                  'Escuchar no pide cuenta. Para dejar una historia sí, y así sabemos a quién preguntar si hay dudas.',
                  style: text(size: 16, color: Palette.haze),
                ),
                const SizedBox(height: 28),
                Glass(
                  radius: 28,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Segmented(
                        registering: _registering,
                        onChanged: (value) => setState(() {
                          _registering = value;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 22),
                      AnimatedSize(
                        duration: Motion.of(context, Motion.settle),
                        curve: Motion.emphasized,
                        child: _registering
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: TextField(
                                  controller: _name,
                                  style: text(size: 16.5),
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  decoration: const InputDecoration(labelText: 'Tu nombre', prefixIcon: Icon(LucideIcons.user, size: 20)),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      TextField(
                        controller: _email,
                        style: text(size: 16.5),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(LucideIcons.mail, size: 20)),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        style: text(size: 16.5),
                        obscureText: _hidden,
                        autofillHints: _registering ? const [AutofillHints.newPassword] : const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          helperText: _registering ? 'Al menos 8 caracteres.' : null,
                          prefixIcon: const Icon(LucideIcons.lock, size: 20),
                          suffixIcon: IconButton(
                            tooltip: _hidden ? 'Mostrar la contraseña' : 'Ocultar la contraseña',
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 20),
                          ),
                        ),
                      ),
                      if (_error != null) ...[const SizedBox(height: 14), Text(_error!, style: text(size: 14, color: Palette.alarm))],
                      const SizedBox(height: 22),
                      LampButton(
                        label: _registering ? 'Crear la cuenta' : 'Entrar',
                        icon: _registering ? LucideIcons.userPlus : LucideIcons.logIn,
                        busy: _busy,
                        expand: true,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.registering, required this.onChanged});

  final bool registering;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final selected = registering == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: SizedBox(
              height: 44,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: Motion.quick,
                  style: text(size: 15, weight: FontWeight.w600, color: selected ? Palette.deep : Palette.bone),
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Palette.deep.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(999)),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: Motion.of(context, Motion.settle),
              curve: Motion.emphasized,
              alignment: registering ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(color: Palette.bone, borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ),
          ),
          Row(children: [option('Ya tengo cuenta', false), option('Crear cuenta', true)]),
        ],
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.account, required this.onLogout});

  final Account account;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final name = account.displayName.trim().isEmpty ? account.email : account.displayName.trim();
    final initials = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return Wrap(
      spacing: 24,
      runSpacing: 20,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: Palette.lampGlow,
            boxShadow: [BoxShadow(color: Palette.lamp.withValues(alpha: 0.45), blurRadius: 40)],
          ),
          child: Text(initials, style: display(44, color: Palette.deep)),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: display(48)),
              const SizedBox(height: 4),
              Text(account.email, style: text(size: 15, color: Palette.haze)),
              const SizedBox(height: 4),
              Text(roleLabel(account.role), style: text(size: 15, color: Palette.bone.withValues(alpha: 0.85))),
            ],
          ),
        ),
        GhostButton(label: 'Salir', icon: LucideIcons.logOut, compact: true, onPressed: onLogout),
      ],
    );
  }
}
