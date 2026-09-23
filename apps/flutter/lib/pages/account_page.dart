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
    if (account == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
            children: [
              Text('Entra para dejar una historia', style: vocesDisplay(32, color: VocesColors.inkOnDesk)),
              const SizedBox(height: 12),
              ..._signedOut(),
            ],
          ),
        ),
      );
    }
    final identity = _Identity(account: account, onLogout: _logout);
    final ledger = _Ledger(
      stories: _mine,
      loading: _loadingMine,
      error: _error,
      onOpen: (story) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => StoryPage(story: story)));
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        if (!wide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            children: [identity, const SizedBox(height: 24), ledger],
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(40, 40, 48, 40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 280, child: identity),
              const SizedBox(width: 48),
              Expanded(child: SingleChildScrollView(child: ledger)),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _signedOut() {
    return [
      Text(
        'Hace falta una cuenta para dejar una historia. La primera de una base vacía administra el archivo.',
        style: vocesSans(size: 16, color: VocesColors.inkOnDesk),
      ),
      const SizedBox(height: 20),
      Container(
        color: VocesColors.paper,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Espera' : (_registering ? 'Crear cuenta' : 'Entrar'))),
            TextButton(
              onPressed: () => setState(() => _registering = !_registering),
              child: Text(_registering ? 'Ya tengo cuenta' : 'No tengo cuenta'),
            ),
          ],
        ),
      ),
    ];
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.account, required this.onLogout});

  final Account account;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(account.displayName, style: vocesDisplay(30, color: VocesColors.inkOnDesk)),
        const SizedBox(height: 8),
        Text(account.email, style: vocesSans(size: 14.5, color: VocesColors.inkOnDesk)),
        const SizedBox(height: 8),
        Text(roleLabel(account.role), style: vocesSans(size: 13.5, color: VocesColors.mutedOnDesk, height: 1.5)),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: onLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: VocesColors.inkOnDesk,
            side: const BorderSide(color: VocesColors.inkOnDesk, width: 1.5),
          ),
          child: const Text('Salir'),
        ),
      ],
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.stories, required this.loading, required this.error, required this.onOpen});

  final List<StoryPin> stories;
  final bool loading;
  final String? error;
  final ValueChanged<StoryPin> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VocesColors.paper,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lo que has dejado', style: vocesDisplay(20)),
          const SizedBox(height: 8),
          if (loading)
            const StoryListStatus(message: 'Cargando tus historias', busy: true)
          else if (stories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: StoryListStatus(message: 'Todavía no has dejado ninguna.'),
            )
          else
            for (final story in stories)
              InkWell(
                onTap: () => onOpen(story),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: VocesColors.paperLine))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(story.title, style: vocesDisplay(18)),
                            const SizedBox(height: 2),
                            Text(story.placeName, style: vocesSans(size: 12.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusStamp(status: story.status),
                    ],
                  ),
                ),
              ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Text(error!, style: vocesSans(size: 14, color: VocesColors.crimson)),
            ),
        ],
      ),
    );
  }
}
