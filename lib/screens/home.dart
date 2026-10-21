import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/rules.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/common.dart';
import '../widgets/imagem.dart';
import '../widgets/importar_cris.dart';
import '../widgets/logo.dart';
import '../widgets/sigilos.dart';
import '../widgets/tema_picker.dart';
import 'campaign/campaign_screen.dart';
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
    final largo = MediaQuery.sizeOf(context).width >= 800;
    final corpo = _aba == 0 ? const _ListaAgentes() : const _ListaMesas();
    return Scaffold(
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
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) async {
              if (v == 'sair') {
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
              const PopupMenuItem(value: 'tema', child: Text('Tema de cores')),
              const PopupMenuItem(
                  value: 'cris', child: Text('Importar do site do CRIS')),
              const PopupMenuItem(value: 'sair', child: Text('Sair da conta')),
            ],
          ),
        ],
      ),
      body: largo
          ? Row(children: [
              NavigationRail(
                selectedIndex: _aba,
                onDestinationSelected: (i) => setState(() => _aba = i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.transparent,
                destinations: const [
                  NavigationRailDestination(
                      icon: Icon(Icons.badge_outlined), label: Text('Agentes')),
                  NavigationRailDestination(
                      icon: Icon(Icons.groups_outlined), label: Text('Mesas')),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: corpo),
            ])
          : corpo,
      bottomNavigationBar: largo
          ? null
          : NavigationBar(
              selectedIndex: _aba,
              onDestinationSelected: (i) => setState(() => _aba = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.badge_outlined), label: 'Agentes'),
                NavigationDestination(
                    icon: Icon(Icons.groups_outlined), label: 'Mesas'),
              ],
            ),
    );
  }
}

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
              MaterialPageRoute(builder: (_) => TelaFicha(fichaId: id)));
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo agente'),
      ),
      body: StreamBuilder<List<Ficha>>(
        stream: Repo.fichasEditaveis(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final todas = snap.data!;
          final l = todas
              .where((f) => f.ownerUid == Repo.uid && !f.eTransformacao)
              .toList();
          if (l.isEmpty) {
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
            final largura = (cons.maxWidth - 32 - 12 * (colunas - 1)) / colunas;
            final cartoes = [
              for (final f in l)
                CartaoAgente(
                    ficha: f,
                    formas: todas.where((t) => t.transformacaoDe == f.id).toList()),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                TituloPagina(
                  titulo: 'Agentes',
                  subtitulo: l.length == 1 ? '1 agente na sua pasta' : '${l.length} agentes na sua pasta',
                ),
                if (colunas == 1)
                  ...cartoes
                else
                  Wrap(spacing: 12, children: [
                    for (final c in cartoes) SizedBox(width: largura, child: c),
                  ]),
              ],
            );
          });
        },
      ),
    );
  }
}

class CartaoAgente extends StatelessWidget {
  final Ficha ficha;
  final Map<String, dynamic>? regras;
  /// Transformações do agente, mostradas embaixo dele.
  final List<Ficha> formas;
  const CartaoAgente(
      {super.key, required this.ficha, this.regras, this.formas = const []});
  @override
  Widget build(BuildContext context) {
    final c = Calc(ficha, regras);
    final detalhes = [ficha.classe, ficha.trilha, ficha.origem].where((s) => s.isNotEmpty).join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => TelaFicha(fichaId: ficha.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RetratoFicha(
                foto: ficha.foto,
                nome: ficha.nome,
                ajuste: ficha.fotoAjuste,
                largura: 78,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(ficha.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: estiloTitulo(18, cor: Cores.texto)),
                    ),
                    const SizedBox(width: 8),
                    Selo(c.resumoProgressao),
                  ]),
                  const SizedBox(height: 4),
                  Text(detalhes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco)),
                  if (ficha.campaignId != null) ...[
                    const SizedBox(height: 6),
                    Selo('Em uma mesa', cor: Cores.roxoClaro, icone: Icons.groups_outlined),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
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
                ]),
              ),
            ]),
            if (formas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in formas) _chipForma(context, t),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _chipForma(BuildContext context, Ficha t) {
    final ativa = ficha.formaAtiva == t.id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => TelaFicha(fichaId: t.id))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: ativa ? Cores.roxo.withValues(alpha: 0.32) : Cores.painel2,
          borderRadius: BorderRadius.circular(12),
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const TituloPagina(
                titulo: 'Mesas', subtitulo: 'Campanhas que você mestra ou joga'),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _criar(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Criar mesa (mestre)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _entrar(context),
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar com código'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (snap.hasError) Text('${snap.error}'),
            if (!snap.hasData && !snap.hasError)
              const Center(child: CircularProgressIndicator()),
            if (snap.hasData && l.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Você ainda não está em nenhuma mesa.\nCrie uma como mestre ou entre com o código que o mestre te passar.',
                    textAlign: TextAlign.center),
              ),
            for (final c in l)
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: (c.masterUid == Repo.uid ? Cores.destaque : Cores.roxoClaro)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: (c.masterUid == Repo.uid ? Cores.destaque : Cores.roxoClaro)
                              .withValues(alpha: 0.4)),
                    ),
                    child: Icon(
                      c.masterUid == Repo.uid
                          ? Icons.shield_moon_outlined
                          : Icons.person_outline,
                      color: c.masterUid == Repo.uid ? Cores.destaque : Cores.roxoClaro,
                    ),
                  ),
                  title: Text(c.nome, style: estiloTitulo(17, cor: Cores.texto)),
                  subtitle: Text(
                      '${c.masterUid == Repo.uid ? 'Você é o mestre' : 'Mestre: ${asStr(c.members[c.masterUid], '?')}'} • ${c.memberUids.length} na mesa'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TelaCampanha(campanhaId: c.id))),
                ),
              ),
          ],
        );
      },
    );
  }
}
