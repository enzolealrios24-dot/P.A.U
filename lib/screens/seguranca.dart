import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/repo.dart';
import '../data/seguranca.dart';
import '../widgets/arquivo.dart';
import '../widgets/common.dart';
import '../widgets/sigilos.dart';

/// "hoje às 14:02", "ontem às 9:10" ou "28/10/2026 às 21:40".
String quandoFoi(DateTime d) {
  final hoje = DateUtils.dateOnly(DateTime.now());
  final dia = DateUtils.dateOnly(d);
  final hora = formatarHora(d.millisecondsSinceEpoch);
  if (dia == hoje) return 'hoje às $hora';
  if (dia == hoje.subtract(const Duration(days: 1))) return 'ontem às $hora';
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year} às $hora';
}

/// O erro do Firebase em português, para quem confirma ou troca a senha.
String erroDeConta(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Senha incorreta.';
      case 'too-many-requests':
        return 'Muitas tentativas seguidas. Espere alguns minutos e tente de novo.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'requires-recent-login':
        return 'Confirme a senha de novo.';
      case 'weak-password':
        return 'Senha fraca. Escolha outra.';
      default:
        return e.message ?? e.code;
    }
  }
  if (e is FirebaseException) return e.message ?? e.code;
  return '$e';
}

/// Campo de senha com o olho para mostrar o que foi digitado. Com [medidor],
/// mostra embaixo a força da senha e o que falta nela.
class CampoSenha extends StatefulWidget {
  final TextEditingController controller;
  final String rotulo;
  final bool medidor;
  final bool autofocus;
  final String Function()? email;
  final String Function()? nome;
  final ValueChanged<String>? aoEnviar;
  final TextInputAction? acaoTeclado;
  const CampoSenha({
    super.key,
    required this.controller,
    this.rotulo = 'Senha',
    this.medidor = false,
    this.autofocus = false,
    this.email,
    this.nome,
    this.aoEnviar,
    this.acaoTeclado,
  });

  @override
  State<CampoSenha> createState() => _CampoSenhaState();
}

class _CampoSenhaState extends State<CampoSenha> {
  bool _ver = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: widget.controller,
        obscureText: !_ver,
        autofocus: widget.autofocus,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: widget.acaoTeclado,
        onChanged: widget.medidor ? (_) => setState(() {}) : null,
        onSubmitted: widget.aoEnviar,
        decoration: InputDecoration(
          labelText: widget.rotulo,
          prefixIcon: const Icon(Icons.lock_outline, size: 20),
          suffixIcon: IconButton(
            tooltip: _ver ? 'Esconder a senha' : 'Mostrar a senha',
            icon: Icon(_ver ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
            onPressed: () => setState(() => _ver = !_ver),
          ),
        ),
      ),
      if (widget.medidor && widget.controller.text.isNotEmpty)
        _Medidor(avaliarSenha(widget.controller.text,
            email: widget.email?.call() ?? '', nome: widget.nome?.call() ?? '')),
    ]);
  }
}

class _Medidor extends StatelessWidget {
  final AvaliacaoSenha a;
  const _Medidor(this.a);

  @override
  Widget build(BuildContext context) {
    final cor = a.forca >= 2 ? Cores.ok : Cores.destaque;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4,
                color: i < a.forca || (i == 0 && a.forca == 0) ? cor : Cores.linha,
              ),
            ),
          ],
          const SizedBox(width: 10),
          Text(a.rotulo, style: estiloRotulo(14, cor: cor, peso: FontWeight.w700, espaco: 0.4)),
        ]),
        const SizedBox(height: 5),
        Text(
          a.bloqueio ??
              (a.forca < 3
                  ? 'Mais comprida fica mais forte. Dica: junte 4 palavras soltas que só você ligaria.'
                  : 'Use esta senha só no P.A.U.'),
          style: TextStyle(fontSize: 12.5, height: 1.35, color: a.serve ? Cores.textoFraco : Cores.destaque),
        ),
      ]),
    );
  }
}

/// Pede a senha para confirmar que é o dono quem está no aparelho e faz
/// [acao] depois. Devolve true quando deu certo.
Future<bool> confirmarComSenha(BuildContext context,
    {required String titulo, required String texto, required String botao, required Future<void> Function() acao}) async {
  final senha = TextEditingController();
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      var carregando = false;
      String? erro;
      return StatefulBuilder(builder: (ctx, set) {
        Future<void> ir() async {
          if (carregando) return;
          set(() {
            carregando = true;
            erro = null;
          });
          try {
            await Seguranca.confirmarSenha(senha.text);
            await acao();
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            set(() {
              carregando = false;
              erro = erroDeConta(e);
            });
          }
        }

        return AlertDialog(
          title: Text(titulo),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(texto, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              CampoSenha(controller: senha, rotulo: 'Sua senha', autofocus: true, aoEnviar: (_) => ir()),
              if (erro != null) ...[
                const SizedBox(height: 10),
                Text(erro!, style: TextStyle(color: Cores.destaque)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: carregando ? null : () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: carregando ? null : ir,
              child: carregando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(botao),
            ),
          ],
        );
      });
    },
  );
  return r ?? false;
}

/// Troca a senha (pede a atual) e desconecta os outros aparelhos.
Future<void> abrirTrocaDeSenha(BuildContext context) async {
  final atual = TextEditingController();
  final nova = TextEditingController();
  final repetir = TextEditingController();
  final email = Repo.auth.currentUser?.email ?? '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      var carregando = false;
      String? erro;
      return StatefulBuilder(builder: (ctx, set) {
        Future<void> ir() async {
          if (carregando) return;
          if (nova.text != repetir.text) {
            set(() => erro = 'A senha nova e a repetição estão diferentes.');
            return;
          }
          if (nova.text == atual.text) {
            set(() => erro = 'A senha nova precisa ser diferente da atual.');
            return;
          }
          set(() {
            carregando = true;
            erro = null;
          });
          try {
            final a = await conferirSenhaNova(nova.text, email: email, nome: Repo.nomeUsuario);
            if (!a.serve) throw a.bloqueio!;
            await Seguranca.trocarSenha(atual.text, nova.text);
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (e) {
            set(() {
              carregando = false;
              erro = erroDeConta(e);
            });
          }
        }

        return AlertDialog(
          title: const Text('Trocar a senha'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Os outros aparelhos saem da conta assim que a senha mudar.',
                    style: TextStyle(height: 1.4, color: Cores.textoFraco)),
                const SizedBox(height: 14),
                CampoSenha(
                    controller: atual, rotulo: 'Senha atual', autofocus: true, acaoTeclado: TextInputAction.next),
                const SizedBox(height: 10),
                CampoSenha(
                  controller: nova,
                  rotulo: 'Senha nova',
                  medidor: true,
                  email: () => email,
                  nome: () => Repo.nomeUsuario,
                  acaoTeclado: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                CampoSenha(controller: repetir, rotulo: 'Repita a senha nova', aoEnviar: (_) => ir()),
                if (erro != null) ...[
                  const SizedBox(height: 10),
                  Text(erro!, style: TextStyle(color: Cores.destaque, height: 1.35)),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: carregando ? null : () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: carregando ? null : ir,
              child: carregando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Trocar a senha'),
            ),
          ],
        );
      });
    },
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha trocada. Os outros aparelhos foram desconectados.')));
  }
}

/// Senha, e-mail de recuperação e os aparelhos que entraram na conta.
class TelaSeguranca extends StatefulWidget {
  /// Abre já com a troca de senha (quando alguém diz "não fui eu").
  final bool trocarAoAbrir;
  const TelaSeguranca({super.key, this.trocarAoAbrir = false});

  @override
  State<TelaSeguranca> createState() => _TelaSegurancaState();
}

class _TelaSegurancaState extends State<TelaSeguranca> {
  late final Future<String> _eu = Seguranca.idDoAparelho();
  bool _linkEnviado = false;

  @override
  void initState() {
    super.initState();
    if (widget.trocarAoAbrir) {
      WidgetsBinding.instance.addPostFrameCallback((_) => abrirTrocaDeSenha(context));
    }
  }

  Future<void> _desconectar() async {
    final ok = await confirmarComSenha(
      context,
      titulo: 'Desconectar os outros aparelhos',
      texto: 'Todos os aparelhos, menos este, saem da conta na hora e não conseguem mais '
          'ver nem mudar nada. Para confirmar que é você, digite sua senha.',
      botao: 'Desconectar',
      acao: Seguranca.desconectarOutros,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Os outros aparelhos foram desconectados.')));
    }
  }

  Future<void> _enviarConfirmacao() async {
    try {
      await Repo.auth.currentUser?.sendEmailVerification();
      setState(() => _linkEnviado = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erroDeConta(e))));
      }
    }
  }

  Future<void> _jaConfirmei() async {
    await Repo.auth.currentUser?.reload();
    if (!mounted) return;
    setState(() {});
    if (Repo.auth.currentUser?.emailVerified != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ainda não confirmado. Abra o link do e-mail e toque aqui de novo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Repo.auth.currentUser;
    return Scaffold(
      // o título fica no cabeçalho da página, logo abaixo
      appBar: AppBar(bottom: const LinhaCris()),
      body: ColoredBox(
        color: corDoCampo,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const CabecalhoAba(
                    titulo: 'Segurança da conta',
                    texto: 'Quem tem a sua senha entra na sua conta. Aqui você vê por onde ela está '
                        'aberta e fecha o que não for seu.',
                  ),
                  _senha(),
                  _email(user),
                  _aparelhos(),
                  const SizedBox(height: 14),
                  const Text(
                    'Para saber se uma senha já vazou, o P.A.U não a envia a ninguém: só os 5 primeiros '
                    'caracteres de um código tirado dela vão para o serviço Have I Been Pwned, que '
                    'devolve centenas de parecidos para a comparação ser feita aqui.',
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: Cores.textoFraco),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _senha() => ValueListenableBuilder<String?>(
        valueListenable: Seguranca.avisoSenha,
        builder: (context, aviso, _) => BlocoMesa(
          titulo: 'Senha',
          forte: aviso != null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (aviso != null) ...[
              const Carimbo('TROQUE A SENHA'),
              const SizedBox(height: 10),
              Text(aviso, style: const TextStyle(height: 1.4, color: Cores.texto)),
            ] else
              const Text(
                'Uma senha comprida, que você não usa em nenhum outro site, é a barreira principal. '
                'Trocar a senha também desconecta todos os outros aparelhos.',
                style: TextStyle(height: 1.4, color: Cores.textoFraco),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => abrirTrocaDeSenha(context),
              icon: const Icon(Icons.key_outlined, size: 18),
              label: const Text('Trocar a senha'),
            ),
          ]),
        ),
      );

  Widget _email(User? user) {
    final confirmado = user?.emailVerified == true;
    return BlocoMesa(
      titulo: 'E-mail de recuperação',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(user?.email ?? '', style: estiloMaquina(15, cor: Cores.texto)),
          if (confirmado) Carimbo('CONFIRMADO', cor: Cores.ok, tamanho: 11),
        ]),
        const SizedBox(height: 8),
        Text(
          confirmado
              ? 'É para este e-mail que vai o link de nova senha.'
              : _linkEnviado
                  ? 'Link enviado. Abra o e-mail (veja também o Spam), toque no link e volte aqui.'
                  : 'Confirme que este e-mail é seu: é por ele que a senha é recuperada se você esquecer.',
          style: const TextStyle(height: 1.4, color: Cores.textoFraco),
        ),
        if (!confirmado) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
              onPressed: _enviarConfirmacao,
              child: Text(_linkEnviado ? 'Enviar de novo' : 'Enviar link de confirmação'),
            ),
            if (_linkEnviado) TextButton(onPressed: _jaConfirmei, child: const Text('Já confirmei')),
          ]),
        ],
      ]),
    );
  }

  Widget _aparelhos() => FutureBuilder<String>(
        future: _eu,
        builder: (context, eu) => StreamBuilder<int>(
          stream: Seguranca.cortadasAte(),
          builder: (context, corte) => StreamBuilder<List<Aparelho>>(
            stream: Seguranca.aparelhos(),
            builder: (context, snap) {
              final l = snap.data ?? const <Aparelho>[];
              final ate = corte.data ?? 0;
              final outros = l.where((a) => a.id != eu.data && a.desde >= ate).length;
              return BlocoMesa(
                titulo: 'Aparelhos com acesso',
                acoes: [
                  TextButton(onPressed: _desconectar, child: const Text('Desconectar os outros')),
                ],
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!snap.hasData && !snap.hasError)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (l.isEmpty)
                    const Text('Nenhum aparelho anotado ainda.', style: TextStyle(color: Cores.textoFraco))
                  else
                    for (final (i, a) in l.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      _LinhaAparelho(a, esteAparelho: a.id == eu.data, desconectado: a.desde < ate),
                    ],
                  const SizedBox(height: 12),
                  Text(
                    outros == 0
                        ? 'Só este aparelho está com a conta aberta. Se aparecer um que você não '
                            'reconhece, troque a senha: isso desconecta todos os outros na hora.'
                        : 'Não reconhece algum? Troque a senha: isso desconecta todos os outros '
                            'na hora, e quem entrou não consegue mais ver nem mudar seus agentes e mesas.',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Cores.textoFraco),
                  ),
                ]),
              );
            },
          ),
        ),
      );
}

class _LinhaAparelho extends StatelessWidget {
  final Aparelho a;
  final bool esteAparelho;
  final bool desconectado;
  const _LinhaAparelho(this.a, {required this.esteAparelho, required this.desconectado});

  @override
  Widget build(BuildContext context) {
    final cor = desconectado ? Cores.textoFraco : Cores.texto;
    final icone = switch (a.plataforma) {
      'android' || 'ios' => Icons.smartphone_outlined,
      _ => Icons.desktop_windows_outlined,
    };
    final uso = a.ultimoUso;
    return Opacity(
      opacity: desconectado ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(border: Border.all(color: Cores.borda)),
            child: Icon(icone, size: 22, color: cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(a.nome, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: cor)),
                if (esteAparelho) Carimbo('ESTE APARELHO', cor: Cores.ok, tamanho: 10),
                if (desconectado) const Carimbo('DESCONECTADO', cor: Cores.textoFraco, tamanho: 10),
              ]),
              const SizedBox(height: 4),
              Text(
                'entrou ${quandoFoi(a.entrou)}'
                '${uso != null && !desconectado ? ', último uso ${quandoFoi(uso)}' : ''}',
                style: estiloMaquina(12.5, cor: Cores.textoFraco),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Fica de olho na conta enquanto ela está aberta: anota este aparelho,
/// avisa de entradas novas em outros, pede a troca de senha fraca e sai
/// sozinho quando o dono desconecta este aparelho de outro lugar.
class VigiaConta extends StatefulWidget {
  final Widget child;
  const VigiaConta({super.key, required this.child});

  @override
  State<VigiaConta> createState() => _VigiaContaState();
}

class _VigiaContaState extends State<VigiaConta> {
  StreamSubscription<int>? _corte;
  StreamSubscription<List<Aparelho>>? _aparelhos;
  int? _inicio;
  bool _avisouSenha = false;

  @override
  void initState() {
    super.initState();
    Seguranca.avisoSenha.addListener(_avisoMudou);
    _comecar();
  }

  @override
  void dispose() {
    Seguranca.avisoSenha.removeListener(_avisoMudou);
    _corte?.cancel();
    _aparelhos?.cancel();
    super.dispose();
  }

  Future<void> _comecar() async {
    try {
      await Seguranca.carregarAviso();
      _inicio = await Seguranca.inicioDaSessao();
    } catch (_) {}
    if (!mounted) return;
    _corte = Seguranca.cortadasAte().listen(_conferirCorte, onError: (_) {});
    try {
      await Seguranca.registrarAparelho();
    } catch (_) {}
    if (!mounted) return;
    _aparelhos = Seguranca.aparelhos().listen((l) async {
      final novas = await Seguranca.entradasNovas(l);
      if (novas.isNotEmpty && mounted) _avisarEntrada(novas.first);
    }, onError: (_) {});
  }

  Future<void> _conferirCorte(int corte) async {
    if (corte <= (_inicio ?? corte)) return;
    // este aparelho pode ter acabado de confirmar a senha (e cortado os outros)
    _inicio = await Seguranca.inicioDaSessao();
    if (_inicio == null || corte <= _inicio! || !mounted) return;
    final aviso = ScaffoldMessenger.of(context);
    await Repo.auth.signOut();
    aviso.showSnackBar(const SnackBar(
      duration: Duration(seconds: 8),
      content: Text('Esta conta foi desconectada deste aparelho a partir de outro. '
          'Se foi você, entre de novo com a sua senha.'),
    ));
  }

  void _avisoMudou() {
    final aviso = Seguranca.avisoSenha.value;
    if (aviso == null || _avisouSenha) return;
    _avisouSenha = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final trocar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Troque sua senha'),
          content: Text('$aviso\n\nCom ela, outra pessoa consegue entrar na sua conta com facilidade.',
              style: const TextStyle(height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Depois')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trocar agora')),
          ],
        ),
      );
      if (trocar == true && mounted) await abrirTrocaDeSenha(context);
    });
  }

  Future<void> _avisarEntrada(Aparelho a) async {
    final naoFui = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo acesso à sua conta'),
        content: Text('${a.nome} entrou na sua conta ${quandoFoi(a.entrou)}. Foi você?',
            style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Cores.destaque),
            child: const Text('Não fui eu'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Fui eu')),
        ],
      ),
    );
    if (naoFui == true && mounted) {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaSeguranca(trocarAoAbrir: true)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
