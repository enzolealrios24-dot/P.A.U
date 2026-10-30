import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/rules.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../data/seguranca.dart';
import '../widgets/arquivo.dart';
import '../widgets/common.dart';
import '../widgets/efeitos.dart';
import '../widgets/foto_jogador.dart';
import '../widgets/imagem.dart';
import '../widgets/importar_cris.dart';
import '../widgets/logo.dart';
import '../widgets/sigilos.dart';
import '../widgets/tema_picker.dart';
import 'campaign/campaign_screen.dart';
import 'pastas.dart';
import 'seguranca.dart';
import 'sheet/sheet_screen.dart';

class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key});
  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  int _aba = 0;

  @override
  void initState() {
    super.initState();
    // Agentes do site do CRIS escolhidos na tela de login.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => gravarPendentesCris(context));
  }

  @override
  Widget build(BuildContext context) {
    return Fichario(
      appBar: AppBar(
        title: const LogoCris(tamanho: 22),
        bottom: const LinhaCris(),
        actions: [
          IconButton(
            tooltip: 'Importar do site do CRIS',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => abrirImportarCris(context, logado: true),
          ),
          PopupMenuButton<String>(
            tooltip: 'Sua conta',
            // o ponto avisa que a senha precisa ser trocada
            icon: ValueListenableBuilder<String?>(
              valueListenable: Seguranca.avisoSenha,
              builder: (context, aviso, _) => Badge(
                isLabelVisible: aviso != null,
                backgroundColor: Cores.destaque,
                smallSize: 10,
                child: FotoJogador(uid: Repo.uid, nome: Repo.nomeUsuario, tamanho: 30),
              ),
            ),
            onSelected: (v) async {
              if (v == 'seguranca') {
                await Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const TelaSeguranca()));
              } else if (v == 'foto') {
                await opcoesFotoJogador(context);
              } else if (v == 'sair') {
                await FirebaseAuth.instance.signOut();
              } else if (v == 'tema') {
                await escolherTema(context);
              } else if (v == 'cris') {
                await abrirImportarCris(context, logado: true);
              } else if (v == 'nome') {
                final n = await pedirTexto(context, 'Seu nome na mesa',
                    inicial: Repo.nomeUsuario);
                if (n != null && n.isNotEmpty) {
                  await FirebaseAuth.instance.currentUser?.updateDisplayName(n);
                  await FirebaseAuth.instance.currentUser?.reload();
                  if (mounted) setState(() {});
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  enabled: false,
                  child: Text(Repo.nomeUsuario,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              const PopupMenuItem(value: 'nome', child: Text('Mudar meu nome')),
              const PopupMenuItem(value: 'foto', child: Text('Foto de perfil')),
              const PopupMenuItem(value: 'seguranca', child: Text('Segurança da conta')),
              const PopupMenuItem(value: 'tema', child: Text('Tema de cores')),
              const PopupMenuItem(
                  value: 'cris', child: Text('Importar do site do CRIS')),
              const PopupMenuItem(value: 'sair', child: Text('Sair da conta')),
            ],
          ),
        ],
      ),
      abas: const [
        AbaFichario(Icons.badge_outlined, 'Agentes'),
        AbaFichario(Icons.groups_outlined, 'Mesas'),
      ],
      atual: _aba,
      aoEscolher: (i) => setState(() => _aba = i),
      corpo: _aba == 0 ? const _ListaAgentes() : const _ListaMesas(),
    );
  }
}

/// Os nomes das mesas do jogador, pelo id (para dizer em qual mesa cada
/// agente está).
Stream<Map<String, String>> nomesDasMesas() =>
    Repo.minhasCampanhas().map((l) => {for (final c in l) c.id: c.nome});

class _ListaAgentes extends StatelessWidget {
  const _ListaAgentes();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novoAgente',
        onPressed: () {
          final id = Repo.criarFicha();
          Navigator.push(context,
              rotaFicha(id));
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo agente'),
      ),
      body: StreamBuilder<Map<String, String>>(
        stream: nomesDasMesas(),
        builder: (context, ms) => StreamBuilder<List<Pasta>>(
        stream: Repo.minhasPastas(),
        builder: (context, ps) => StreamBuilder<List<Ficha>>(
        stream: Repo.fichasEditaveis(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final todas = snap.data!;
          final mesas = ms.data ?? const <String, String>{};
          final l = todas
              .where((f) => f.ownerUid == Repo.uid && !f.eTransformacao)
              .toList();
          final pastas = ps.data ?? const <Pasta>[];
          final idsPastas = {for (final p in pastas) p.id};
          // agentes numa pasta aparecem só dentro dela
          final soltos = l.where((f) => !idsPastas.contains(f.pasta)).toList();
          if (l.isEmpty && pastas.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SigiloConhecimento(
                      tamanho: 120, cor: Cores.destaque.withValues(alpha: 0.5), espessura: 1.2),
                  const SizedBox(height: 20),
                  Text('Nenhum agente ainda', style: estiloTitulo(22, cor: Cores.texto)),
                  const SizedBox(height: 6),
                  const Text('Crie o primeiro ou traga os seus do site do CRIS.',
                      textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => abrirImportarCris(context, logado: true),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Trazer do site do CRIS'),
                  ),
                ]),
              ),
            );
          }
          return LayoutBuilder(builder: (context, cons) {
            final colunas = cons.maxWidth >= 1150 ? 3 : (cons.maxWidth >= 760 ? 2 : 1);
            final largura = (cons.maxWidth - 40 - 16 * (colunas - 1)) / colunas;
            final colunasPasta = cons.maxWidth >= 1150 ? 4 : (cons.maxWidth >= 760 ? 3 : 2);
            final larguraPasta = (cons.maxWidth - 40 - 12 * (colunasPasta - 1)) / colunasPasta;
            final cartoes = [
              for (final (i, f) in soltos.indexed)
                AgenteArrastavel(
                  ficha: f,
                  child: Surgir(
                    ordem: i + pastas.length,
                    child: CartaoAgente(
                      ficha: f,
                      mesa: mesas[f.campaignId],
                      formas: todas.where((t) => t.transformacaoDe == f.id).toList(),
                      aoMover: () => moverAgente(context, f, pastas),
                    ),
                  ),
                ),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              children: [
                TituloPagina(
                  titulo: 'Agentes',
                  subtitulo: [
                    l.length == 1 ? '1 agente' : '${l.length} agentes',
                    if (pastas.isNotEmpty) pastas.length == 1 ? '1 pasta' : '${pastas.length} pastas',
                  ].join(', '),
                  acoes: [
                    TextButton.icon(
                      onPressed: () => criarPasta(context),
                      icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                      label: const Text('Nova pasta'),
                    ),
                  ],
                ),
                if (pastas.isNotEmpty) ...[
                  const _Rotulo('Pastas'),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final (i, p) in pastas.indexed)
                      SizedBox(
                        width: larguraPasta,
                        child: Surgir(
                          ordem: i,
                          child: CartaoPasta(
                            pasta: p,
                            agentes: l.where((f) => f.pasta == p.id).toList(),
                            aoAbrir: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => TelaPasta(pastaId: p.id))),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 22),
                  if (soltos.isNotEmpty) const _Rotulo('Fora das pastas'),
                ],
                if (colunas == 1)
                  ...cartoes
                else
                  Wrap(spacing: 16, children: [
                    for (final c in cartoes) SizedBox(width: largura, child: c),
                  ]),
              ],
            );
          });
        },
      ),
      ),
      ),
    );
  }
}

/// Nome de um grupo da lista (Pastas, Fora das pastas).
class _Rotulo extends StatelessWidget {
  final String texto;
  const _Rotulo(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
        child: Text(texto, style: estiloTitulo(17, cor: Cores.textoFraco)),
      );
}

/// O dossiê de um agente: retrato com o NEX num hexágono, como os números
/// de página dos livros; nome, classe datilografada, recursos e a mesa em
/// que está.
class CartaoAgente extends StatelessWidget {
  final Ficha ficha;
  final Map<String, dynamic>? regras;
  /// Transformações do agente, mostradas embaixo dele.
  final List<Ficha> formas;
  /// Mostra o botão de mover para uma pasta (na tela inicial).
  final VoidCallback? aoMover;
  /// O nome da mesa em que o agente está, quando se sabe.
  final String? mesa;
  /// Diz em que mesa o agente está (dentro da própria mesa, não precisa).
  final bool mostrarMesa;
  const CartaoAgente(
      {super.key,
      required this.ficha,
      this.regras,
      this.formas = const [],
      this.aoMover,
      this.mesa,
      this.mostrarMesa = true});
  @override
  Widget build(BuildContext context) {
    final c = Calc(ficha, regras);
    final detalhes = [ficha.classe, ficha.trilha, ficha.origem].where((s) => s.isNotEmpty).join(', ');
    // só o NEX cabe no hexágono; nível, patente e estágio vão num selo
    final soNex = c.resumoProgressao == 'NEX ${ficha.nex}%';
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Material(
        color: Cores.painel,
        shape: CorteCantos(corte: 16, cor: Cores.borda),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, rotaFicha(ficha.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, right: 8),
                  child: RetratoFicha(
                    foto: ficha.foto,
                    nome: ficha.nome,
                    ajuste: ficha.fotoAjuste,
                    largura: 84,
                    heroi: 'retrato-${ficha.id}',
                    canto: soNex ? Hexagono('${ficha.nex}%', rotulo: 'NEX', tamanho: 46) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Text(ficha.nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: estiloTitulo(20, cor: Cores.texto)),
                      ),
                      if (aoMover != null)
                        IconButton(
                          tooltip: 'Mover para uma pasta',
                          visualDensity: VisualDensity.compact,
                          onPressed: aoMover,
                          icon: const Icon(Icons.drive_file_move_outline, size: 20, color: Cores.textoFraco),
                        ),
                    ]),
                    if (!soNex) ...[
                      const SizedBox(height: 4),
                      Selo(c.resumoProgressao),
                    ],
                    if (detalhes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(detalhes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: estiloMaquina(12.5, cor: Cores.textoFraco, espaco: 0.3)),
                    ],
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(children: [
                        Expanded(
                            child: MedidorMini(
                                rotulo: 'PV', atual: ficha.pvAtual, max: c.pvMax, cor: Cores.pv, temp: ficha.pvTemp)),
                        const SizedBox(width: 12),
                        if (c.determinacao)
                          Expanded(
                              child: MedidorMini(
                                  rotulo: 'PD', atual: ficha.pdAtual, max: c.pdMax, cor: Cores.pd, temp: ficha.peTemp))
                        else ...[
                          Expanded(
                              child: MedidorMini(
                                  rotulo: 'PE', atual: ficha.peAtual, max: c.peMax, cor: Cores.pe, temp: ficha.peTemp)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: MedidorMini(rotulo: 'SAN', atual: ficha.sanAtual, max: c.sanMax, cor: Cores.san)),
                        ],
                      ]),
                    ),
                  ]),
                ),
              ]),
              if (ficha.campaignId != null && mostrarMesa)
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 4),
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Cores.linha))),
                  child: Row(children: [
                    Icon(Icons.groups_outlined, size: 17, color: Cores.roxoClaro),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: mesa == null ? 'Numa mesa' : 'Na mesa '),
                          if (mesa != null)
                            TextSpan(text: mesa, style: const TextStyle(color: Cores.texto, fontWeight: FontWeight.w600)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco),
                      ),
                    ),
                  ]),
                ),
              if (formas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in formas) _chipForma(context, t),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chipForma(BuildContext context, Ficha t) {
    final ativa = ficha.formaAtiva == t.id;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => Navigator.push(context,
          rotaFicha(t.id)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: ativa ? Cores.roxo.withValues(alpha: 0.32) : Cores.painel2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: ativa ? Cores.roxoClaro.withValues(alpha: 0.7) : Cores.borda),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AvatarFicha(foto: t.foto, nome: t.nome, ajuste: t.fotoAjuste, tamanho: 28, transformacao: true),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (ativa)
              Text('EM USO', style: estiloRotulo(10, cor: Cores.roxoClaro, peso: FontWeight.w700, espaco: 1.4)),
            Text(t.nome, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

/// As mesas: criar uma (como mestre), entrar com código e a pasta de cada
/// operação, com quem mestra, a missão, quem está nela e a sessão.
class _ListaMesas extends StatelessWidget {
  const _ListaMesas();

  Future<void> _criar(BuildContext context) async {
    final n = await pedirTexto(context, 'Nome da mesa/campanha');
    if (n == null || n.isEmpty) return;
    try {
      final id = await Repo.criarCampanha(n);
      if (context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => TelaCampanha(campanhaId: id)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Não foi possível criar: $e')));
      }
    }
  }

  Future<void> _entrar(BuildContext context) async {
    final c = await pedirTexto(context, 'Código da mesa', dica: 'Ex.: K7Q2ZP');
    if (c == null || c.isEmpty) return;
    try {
      final id = await Repo.entrarCampanha(c);
      if (context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => TelaCampanha(campanhaId: id)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Campanha>>(
      stream: Repo.minhasCampanhas(),
      builder: (context, snap) {
        final l = snap.data ?? [];
        final mestradas = l.where((c) => c.masterUid == Repo.uid).length;
        final acoes = [
          _AcaoMesa(
            icone: Icons.shield_moon_outlined,
            titulo: 'Criar mesa',
            texto: 'Você mestra: cria a mesa e passa o código aos jogadores.',
            principal: true,
            aoTocar: () => _criar(context),
          ),
          _AcaoMesa(
            icone: Icons.vpn_key_outlined,
            titulo: 'Entrar com código',
            texto: 'O mestre te passa um código de seis letras.',
            aoTocar: () => _entrar(context),
          ),
        ];
        return LayoutBuilder(builder: (context, cons) {
          final colunas = cons.maxWidth >= 1150 ? 3 : (cons.maxWidth >= 760 ? 2 : 1);
          final largura = (cons.maxWidth - 40 - 16 * (colunas - 1)) / colunas;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              TituloPagina(
                titulo: 'Mesas',
                subtitulo: l.isEmpty
                    ? 'Campanhas que você mestra ou joga'
                    : [
                        l.length == 1 ? '1 mesa' : '${l.length} mesas',
                        if (mestradas > 0) 'você mestra $mestradas',
                      ].join(', '),
              ),
              if (cons.maxWidth >= 600)
                Row(children: [
                  for (final (i, a) in acoes.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: a),
                  ],
                ])
              else
                ...[
                  for (final (i, a) in acoes.indexed) ...[
                    if (i > 0) const SizedBox(height: 10),
                    a,
                  ],
                ],
              const SizedBox(height: 26),
              if (snap.hasError) Text('${snap.error}'),
              if (!snap.hasData && !snap.hasError)
                const Center(child: CircularProgressIndicator()),
              if (snap.hasData && l.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'Você ainda não está em nenhuma mesa.\nCrie uma como mestre ou entre com o código que o mestre te passar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Cores.textoFraco, height: 1.5)),
                ),
              Wrap(spacing: 16, runSpacing: 16, children: [
                for (final (i, c) in l.indexed)
                  SizedBox(
                    width: largura,
                    child: Surgir(
                      ordem: i,
                      child: _CartaoMesa(
                        camp: c,
                        aoAbrir: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => TelaCampanha(campanhaId: c.id))),
                      ),
                    ),
                  ),
              ]),
            ],
          );
        });
      },
    );
  }
}

/// Botão grande de criar mesa ou entrar numa: ícone, nome e o que acontece.
class _AcaoMesa extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;
  final bool principal;
  final VoidCallback aoTocar;
  const _AcaoMesa(
      {required this.icone, required this.titulo, required this.texto, required this.aoTocar, this.principal = false});

  @override
  Widget build(BuildContext context) {
    final frente = principal ? Cores.sobreDestaque : Cores.texto;
    return Material(
      color: principal ? Cores.destaque : Cores.painel,
      shape: CorteCantos(corte: 12, cor: principal ? null : Cores.borda),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Icon(icone, size: 28, color: principal ? Cores.sobreDestaque : Cores.destaque),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: estiloRotulo(18, cor: frente, peso: FontWeight.w700, espaco: 0.6)),
                const SizedBox(height: 2),
                Text(texto,
                    style: TextStyle(fontSize: 13.5, height: 1.3, color: frente.withValues(alpha: principal ? 0.8 : 0.65))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A pasta de uma operação: lombada na cor do papel de quem abre (mestre ou
/// agente), o nome, a missão datilografada, quem está nela e a sessão.
class _CartaoMesa extends StatelessWidget {
  final Campanha camp;
  final VoidCallback aoAbrir;
  const _CartaoMesa({required this.camp, required this.aoAbrir});

  @override
  Widget build(BuildContext context) {
    final mestre = camp.masterUid == Repo.uid;
    final cor = mestre ? Cores.destaque : Cores.roxoClaro;
    final sessao = camp.sessao;
    final aoVivo = asBool(sessao['ativa']);
    final jogadas = camp.historicoSessoes.where((s) => asInt(s['fim']) > 0).length;
    final rostos = [
      if (camp.members.containsKey(camp.masterUid)) camp.masterUid,
      ...camp.memberUids.where((u) => u != camp.masterUid),
    ];
    return Material(
      color: Cores.painel,
      shape: CorteCantos(corte: 16, cor: aoVivo ? cor.withValues(alpha: 0.8) : Cores.borda, largura: aoVivo ? 1.4 : 1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoAbrir,
        // a lombada da pasta, na borda da esquerda
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: cor.withValues(alpha: 0.85), width: 5))),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(camp.nome,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: estiloTitulo(20, cor: Cores.texto)),
                  ),
                  const SizedBox(width: 10),
                  Carimbo(mestre ? 'MESTRE' : 'AGENTE', cor: cor, tamanho: 11),
                ]),
                const SizedBox(height: 4),
                Text(
                    mestre
                        ? 'código ${camp.joinCode}'
                        : 'mestre: ${asStr(camp.members[camp.masterUid], '?')}',
                    style: estiloMaquina(12.5, cor: Cores.textoFraco, espaco: 0.5)),
                if (camp.missao.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: cor.withValues(alpha: 0.5), width: 2)),
                    ),
                    child: Text(camp.missao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.4, color: Cores.texto)),
                  ),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  SizedBox(
                    width: rostos.isEmpty ? 0 : 30.0 + 20 * (rostos.take(5).length - 1),
                    height: 30,
                    child: Stack(children: [
                      for (final (i, u) in rostos.take(5).indexed)
                        Positioned(
                          left: 20.0 * i,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Cores.painel2, width: 2),
                            ),
                            child: FotoJogador(uid: u, nome: asStr(camp.members[u]), tamanho: 26),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(camp.memberUids.length == 1 ? 'só você' : '${camp.memberUids.length} na mesa',
                      style: estiloRotulo(13.5, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 0.4)),
                  const Spacer(),
                  if (aoVivo) ...[
                    Icon(Icons.radio_button_checked, size: 14, color: cor),
                    const SizedBox(width: 6),
                    Text('Sessão ${asInt(sessao['numero'])}',
                        style: estiloRotulo(13.5, cor: Cores.texto, peso: FontWeight.w600, espaco: 0.4)),
                    const SizedBox(width: 8),
                    Cronometro(inicio: asInt(sessao['inicio']), estilo: estiloNumero(15, cor: Cores.texto)),
                  ] else
                    Text(
                        jogadas == 0
                            ? 'nenhuma sessão ainda'
                            : (jogadas == 1 ? '1 sessão jogada' : '$jogadas sessões jogadas'),
                        style: estiloRotulo(13.5, cor: Cores.textoFraco, peso: FontWeight.w500, espaco: 0.4)),
                ]),
              ]),
            ),
        ),
      ),
    );
  }
}
