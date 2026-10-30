import 'package:flutter/material.dart';
import 'package:voces/api.dart';
import 'package:voces/theme/vdl_colors.dart';
import 'package:voces/ui/avisos.dart';
import 'package:voces/ui/campos.dart';
import 'package:voces/ui/pagina.dart';
import 'package:voces/ui/placa.dart';

/// Entrar o crear una cuenta. Al terminar llama a [onHecho] o, si no hay,
/// vuelve atrás con `true` para que quien la abrió siga donde estaba.
class EntrarPage extends StatefulWidget {
  const EntrarPage({super.key, required this.api, this.crear = false, this.sesionCaducada = false, this.onHecho});

  final VocesApi api;
  final bool crear;
  final bool sesionCaducada;
  final VoidCallback? onHecho;

  @override
  State<EntrarPage> createState() => _EntrarPageState();
}

class _EntrarPageState extends State<EntrarPage> {
  late bool _crear = widget.crear;
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _clave = TextEditingController();
  bool _ocupado = false;
  bool _noCoinciden = false;
  String? _errorNombre;
  String? _errorEmail;
  String? _errorClave;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _email, _clave]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    final nombre = _nombre.text.trim();
    final email = _email.text.trim();
    final clave = _clave.text;
    setState(() {
      _noCoinciden = false;
      _error = null;
      _errorNombre = _crear && nombre.isEmpty ? 'Escribe tu nombre: así firmarás lo que recojas.' : null;
      _errorEmail = !email.contains('@') ? 'Escribe un email, por ejemplo: nombre@correo.es.' : null;
      _errorClave = _crear && clave.length < 8
          ? 'Tiene ${clave.length} caracteres. Necesita al menos 8.'
          : (!_crear && clave.isEmpty ? 'Escribe tu contraseña.' : null);
    });
    if (_errorNombre != null || _errorEmail != null || _errorClave != null) return;
    setState(() => _ocupado = true);
    try {
      if (_crear) {
        await widget.api.register(email, clave, nombre);
      } else {
        await widget.api.login(email, clave);
      }
      if (!mounted) return;
      if (widget.onHecho != null) {
        widget.onHecho!();
      } else {
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final noCoinciden = !_crear && (e.message.contains('contraseña') || e.message.contains('email'));
      setState(() {
        _noCoinciden = noCoinciden;
        _error = noCoinciden ? null : e.message;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No hay conexión. Revisa el wifi o los datos y vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VdlColors.of(context);
    final letra = Theme.of(context).textTheme;
    final puedeVolver = Navigator.canPop(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: MargenPagina(
            ancho: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (puedeVolver) EnlaceDiscreto(etiqueta: 'Volver', onPressed: () => Navigator.pop(context, false)),
                if (tamano(context) != Vdl.amplio) ...[const SizedBox(height: 8), const Marca(pequena: true)],
                const SizedBox(height: 18),
                TarjetaConPestana(
                  pestana: _crear ? 'Alta' : 'Entrada',
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TituloPantalla(_crear ? 'Crear una cuenta' : 'Entrar'),
                        const SizedBox(height: 8),
                        Text(
                          _crear
                              ? 'Para dejar historias y corregirlas mientras se revisan. Para escuchar no hace falta.'
                              : 'Para dejar historias y ver en qué estado están.',
                          style: letra.bodyMedium!.copyWith(fontSize: 17, color: c.piedra),
                        ),
                        if (widget.sesionCaducada && !_crear) ...[
                          const SizedBox(height: 14),
                          const Aviso(
                            tono: TonoAviso.aviso,
                            titulo: 'Tu sesión ha caducado',
                            texto: 'Entra otra vez. Lo que estabas haciendo sigue guardado.',
                          ),
                        ],
                        if (_noCoinciden) ...[
                          const SizedBox(height: 14),
                          const Aviso(
                            tono: TonoAviso.error,
                            titulo: 'El email o la contraseña no coinciden',
                            texto: 'Revísalos y vuelve a intentarlo.',
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Aviso(tono: TonoAviso.error, titulo: 'No se ha podido', texto: _error),
                        ],
                        const SizedBox(height: 20),
                        if (_crear) ...[
                          CampoTexto(
                            etiqueta: 'Tu nombre',
                            controller: _nombre,
                            error: _errorNombre,
                            autorrelleno: const [AutofillHints.name],
                            mayusculas: TextCapitalization.words,
                            maximo: 80,
                          ),
                          const SizedBox(height: 18),
                        ],
                        CampoTexto(
                          etiqueta: 'Email',
                          controller: _email,
                          error: _errorEmail,
                          teclado: TextInputType.emailAddress,
                          autorrelleno: const [AutofillHints.email],
                          mayusculas: TextCapitalization.none,
                        ),
                        const SizedBox(height: 18),
                        CampoTexto(
                          etiqueta: 'Contraseña',
                          controller: _clave,
                          ocultar: true,
                          ayuda: _crear ? 'Al menos 8 caracteres.' : null,
                          error: _errorClave,
                          autorrelleno: [_crear ? AutofillHints.newPassword : AutofillHints.password],
                          accion: TextInputAction.done,
                          onSubmitted: (_) => _enviar(),
                        ),
                        const SizedBox(height: 18),
                        BotonPlaca(
                          etiqueta: _crear ? 'Crear la cuenta' : 'Entrar',
                          cargando: _ocupado ? (_crear ? 'Creando la cuenta…' : 'Entrando…') : null,
                          expandir: true,
                          onPressed: _enviar,
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _crear ? '¿Ya tienes cuenta? ' : '¿No tienes cuenta? ',
                              style: letra.bodyMedium!.copyWith(fontSize: 17),
                            ),
                            EnlaceDiscreto(
                              etiqueta: _crear ? 'Entrar' : 'Crear una cuenta',
                              onPressed: () => setState(() {
                                _crear = !_crear;
                                _noCoinciden = false;
                                _error = null;
                                _errorClave = null;
                                _errorNombre = null;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
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
