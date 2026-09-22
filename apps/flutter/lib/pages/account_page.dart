import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/pages/story_page.dart';
import 'package:voces/story_format.dart';
import 'package:voces/theme.dart';
import 'package:voces/widgets/story_list.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api, required this.onChanged});

  final VocesApi api;
  final VoidCallback onChanged;

  @override
  State<AccountPage> createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false;
  bool _busy = false;
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
    } finally {
      if (mounted) setState(() => _loadingMine = false);
    }
  }

  Future<void> _submit() async {
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
      widget.onChanged();
      await reload();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
          children: [
            Text(account == null ? 'Entra para dejar una historia' : account.displayName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            if (account == null) ..._signedOut() else ..._signedIn(account),
          ],
        ),
      ),
    );
  }

  List<Widget> _signedOut() {
    return [
      const Text('Hace falta una cuenta para dejar una historia. La primera de una base vacía administra el archivo.'),
      const SizedBox(height: 16),
      if (_registering) ...[
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Cómo te llamas')),
        const SizedBox(height: 12),
      ],
      TextField(
        controller: _email,
        decoration: const InputDecoration(labelText: 'Email'),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        decoration: InputDecoration(labelText: 'Contraseña', helperText: _registering ? 'Al menos 8 caracteres.' : null, errorText: _error),
        obscureText: true,
        autofillHints: _registering ? const [AutofillHints.newPassword] : const [AutofillHints.password],
        onSubmitted: (_) {
          if (!_busy) _submit();
        },
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Espera' : (_registering ? 'Crear cuenta' : 'Entrar'))),
      ),
      TextButton(
        onPressed: () => setState(() => _registering = !_registering),
        child: Text(_registering ? 'Ya tengo cuenta' : 'No tengo cuenta'),
      ),
    ];
  }

  List<Widget> _signedIn(Account account) {
    return [
      Text(account.email, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 8),
      Text(roleLabel(account.role), style: const TextStyle(color: VocesColors.muted, height: 1.4)),
      const SizedBox(height: 16),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: _logout, child: const Text('Salir'))),
      const SizedBox(height: 36),
      Text('Lo que has dejado', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (_loadingMine)
        const StoryListStatus(message: 'Cargando tus historias', busy: true)
      else if (_mine.isEmpty)
        const StoryListStatus(message: 'Todavía no has dejado ninguna.')
      else
        ChronicleList(
          stories: _mine,
          showStatus: true,
          onOpen: (story) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => StoryPage(story: story)));
          },
        ),
      if (_error != null) _errorText(),
    ];
  }

  Widget _errorText() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(_error!, style: const TextStyle(color: VocesColors.seal)),
    );
  }
}
