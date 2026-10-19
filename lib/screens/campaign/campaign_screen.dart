import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../home.dart';
import '../master/master_screen.dart';
import '../sheet/sheet_screen.dart';
import 'iniciativa_view.dart';

class TelaCampanha extends StatelessWidget {
  final String campanhaId;
  const TelaCampanha({super.key, required this.campanhaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Campanha?>(
      stream: Repo.campanha(campanhaId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Sem acesso à mesa.\n${snap.error}')));
        }
        if (!snap.hasData) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final c = snap.data;
        if (c == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Mesa não encontrada.')));
        }
        if (c.masterUid == Repo.uid) return TelaMestre(camp: c);
        return _VisaoJogador(camp: c);
      },
    );
  }
}

class _VisaoJogador extends StatelessWidget {
  final Campanha camp;
  const _VisaoJogador({required this.camp});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(camp.nome),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'sair' &&
                    await confirmar(context, 'Sair da mesa "${camp.nome}"?')) {
                  await Repo.sairCampanha(camp);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sair', child: Text('Sair da mesa')),
              ],
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'MESA'), Tab(text: 'ROLAGENS')]),
        ),
        body: TabBarView(children: [
          _AbaMesaJogador(camp: camp),
          LogRolagens(cid: camp.id),
        ]),
      ),
    );
  }
}

class _AbaMesaJogador extends StatelessWidget {
  final Campanha camp;
  const _AbaMesaJogador({required this.camp});

  Future<void> _vincular(BuildContext context, List<Ficha> livres) async {
    if (livres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Crie um agente na aba Agentes primeiro.')));
      return;
    }
    final f = await showDialog<Ficha>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Qual agente vai para esta mesa?'),
        children: [
          for (final f in livres)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f),
              child: Text('${f.nome} (NEX ${f.nex}%)'),
            ),
        ],
      ),
    );
    if (f != null) Repo.vincularFicha(f, camp);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ficha>>(
      stream: Repo.minhasFichas(),
      builder: (context, snap) {
        final todas = snap.data ?? [];
        final aqui = todas.where((f) => f.campaignId == camp.id).toList();
        final livres = todas.where((f) => f.campaignId == null).toList();
        return ListView(padding: const EdgeInsets.all(12), children: [
          Secao(
            titulo: 'Mesa',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mestre: ${asStr(camp.members[camp.masterUid], '?')}'),
                  Text('Jogadores: ${camp.members.entries.where((e) => e.key != camp.masterUid).map((e) => e.value).join(', ')}',
                      style: const TextStyle(color: Cores.textoFraco)),
                  if (camp.missao.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('MISSÃO ATUAL',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: Cores.destaque)),
                    Text(camp.missao),
                  ],
                ]),
          ),
          if (asBool(camp.combate['ativo'])) IniciativaView(camp: camp),
          Secao(
            titulo: 'Seu agente aqui',
            acoes: [
              TextButton.icon(
                onPressed: () => _vincular(context, livres),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Vincular agente'),
              ),
            ],
            child: aqui.isEmpty
                ? const Text(
                    'Nenhum agente vinculado. Vincule um para o mestre ver sua ficha e suas rolagens aparecerem na mesa.',
                    style: TextStyle(color: Cores.textoFraco))
                : Column(children: [
                    for (final f in aqui)
                      CartaoAgente(ficha: f, regras: camp.regras),
                  ]),
          ),
        ]);
      },
    );
  }
}

/// Log de rolagens da mesa (tempo real).
class LogRolagens extends StatelessWidget {
  final String cid;
  final bool secretas;
  const LogRolagens({super.key, required this.cid, this.secretas = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Repo.logRolagens(cid, secretas: secretas),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final l = snap.data!;
        if (l.isEmpty) {
          return Center(
              child: Text(secretas
                  ? 'Nenhuma rolagem secreta.'
                  : 'Nenhuma rolagem ainda.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: l.length,
          itemBuilder: (context, i) {
            final r = l[i];
            final crit = asBool(r['critico']);
            final falha = asBool(r['falhaCritica']);
            final dano = r['danoTotal'];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  SizedBox(
                    width: 56,
                    child: Column(children: [
                      Text('${asInt(r['total'])}',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: crit
                                  ? Cores.ok
                                  : (falha ? Cores.destaque : Cores.texto))),
                      if (dano != null)
                        Text('dano ${asInt(dano)}',
                            style: const TextStyle(
                                fontSize: 11, color: Cores.destaque)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(asStr(r['titulo']),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${asStr(r['detalhe'])}${asStr(r['danoDetalhe']).isNotEmpty ? '\nDano: ${asStr(r['danoDetalhe'])}' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Cores.textoFraco),
                        ),
                        Text(
                            '${asStr(r['autor'])} • ${formatarHora(asInt(r['at']))}${crit ? ' • CRÍTICO' : ''}',
                            style: const TextStyle(
                                fontSize: 11, color: Cores.textoFraco)),
                      ],
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

void abrirFicha(BuildContext context, String id) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => TelaFicha(fichaId: id)));
