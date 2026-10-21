import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/rules.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../widgets/common.dart';
import '../widgets/importar_cris.dart';
import '../widgets/logo.dart';
import '../widgets/sigilos.dart';
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
        stream: Repo.minhasFichas(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final l = snap.data!;
          if (l.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Nenhum agente ainda.\nCrie o primeiro!',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => abrirImportarCris(context, logado: true),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Trazer do site do CRIS'),
                ),
              ]),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [for (final f in l) CartaoAgente(ficha: f)],
          );
        },
      ),
    );
  }
}

class CartaoAgente extends StatelessWidget {
  final Ficha ficha;
  final Map<String, dynamic>? regras;
  const CartaoAgente({super.key, required this.ficha, this.regras});
  @override
  Widget build(BuildContext context) {
    final c = Calc(ficha, regras);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => TelaFicha(fichaId: ficha.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(ficha.nome,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Text(c.resumoProgressao,
                    style: const TextStyle(
                        color: Cores.destaque, fontWeight: FontWeight.bold)),
              ]),
              Text(
                  [ficha.classe, ficha.trilha, ficha.origem]
                      .where((s) => s.isNotEmpty)
                      .join(' • '),
                  style: const TextStyle(color: Cores.textoFraco)),
              if (ficha.campaignId != null)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Em uma mesa',
                      style: TextStyle(color: Cores.roxo, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              _mini('PV', ficha.pvAtual, c.pvMax, Cores.pv, temp: ficha.pvTemp),
              if (c.determinacao)
                _mini('PD', ficha.pdAtual, c.pdMax, Cores.pd, temp: ficha.peTemp)
              else ...[
                _mini('PE', ficha.peAtual, c.peMax, Cores.pe, temp: ficha.peTemp),
                _mini('SAN', ficha.sanAtual, c.sanMax, Cores.san),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String r, int a, int m, Color cor, {int temp = 0}) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          SizedBox(
              width: 36,
              child: Text(r,
                  style: TextStyle(
                      color: cor, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: m <= 0 ? 0 : (a / m).clamp(0.0, 1.0),
                minHeight: 5,
                color: cor,
                backgroundColor: cor.withValues(alpha: 0.15),
              ),
            ),
          ),
          SizedBox(
              width: 80,
              child: Text(temp > 0 ? '$a/$m +$temp' : '$a/$m',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12))),
        ]),
      );
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
          padding: const EdgeInsets.all(12),
          children: [
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
                child: ListTile(
                  leading: Icon(
                    c.masterUid == Repo.uid
                        ? Icons.shield_moon_outlined
                        : Icons.person_outline,
                    color:
                        c.masterUid == Repo.uid ? Cores.destaque : Cores.roxo,
                  ),
                  title: Text(c.nome,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
