import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/arquivo.dart';
import '../../widgets/common.dart';
import '../../widgets/foto_jogador.dart';
import '../../widgets/sigilos.dart';
import '../home.dart';
import '../master/master_screen.dart';
import '../sheet/sheet_screen.dart';
import 'iniciativa_view.dart';
import 'jogadores.dart';
import 'sessao.dart';

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

/// O topo da mesa: o nome da operação e, embaixo, quem mestra. O mestre vê
/// também o código para os jogadores entrarem (tocar copia).
PreferredSizeWidget barraDaMesa(BuildContext context, Campanha camp, {List<Widget> acoes = const []}) {
  final mestre = camp.masterUid == Repo.uid;
  return AppBar(
    toolbarHeight: 66,
    bottom: const LinhaCris(),
    actions: acoes,
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(camp.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: estiloTitulo(21, cor: Cores.texto)),
      const SizedBox(height: 4),
      Row(children: [
        Flexible(
          child: Text(mestre ? 'Você mestra esta mesa' : 'Mestre: ${asStr(camp.members[camp.masterUid], '?')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: estiloRotulo(14, cor: Cores.textoFraco, peso: FontWeight.w500, espaco: 0.4)),
        ),
        if (mestre && camp.joinCode.isNotEmpty) ...[
          const SizedBox(width: 10),
          CodigoMesa(codigo: camp.joinCode),
        ],
      ]),
    ]),
  );
}

/// O código da mesa, batido à máquina numa etiqueta. Tocar copia.
class CodigoMesa extends StatelessWidget {
  final String codigo;
  final double tamanho;
  const CodigoMesa({super.key, required this.codigo, this.tamanho = 13});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Código para os jogadores entrarem. Toque para copiar.',
        child: InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: codigo));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Código copiado')));
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: tamanho * 0.5, vertical: tamanho * 0.12),
            decoration: BoxDecoration(
              color: Cores.painel2,
              border: Border.all(color: Cores.destaque.withValues(alpha: 0.45)),
            ),
            child: Text(codigo, style: estiloMaquina(tamanho, cor: Cores.destaque, espaco: tamanho * 0.22)),
          ),
        ),
      );
}

class _VisaoJogador extends StatefulWidget {
  final Campanha camp;
  const _VisaoJogador({required this.camp});

  @override
  State<_VisaoJogador> createState() => _VisaoJogadorState();
}

class _VisaoJogadorState extends State<_VisaoJogador> {
  int _aba = 0;

  @override
  Widget build(BuildContext context) {
    final camp = widget.camp;
    return Fichario(
      appBar: barraDaMesa(context, camp, acoes: [
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'sair' && await confirmar(context, 'Sair da mesa "${camp.nome}"?')) {
              await Repo.sairCampanha(camp);
              if (context.mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'sair', child: Text('Sair da mesa')),
          ],
        ),
      ]),
      abas: const [
        AbaFichario(Icons.groups_outlined, 'Mesa'),
        AbaFichario(Icons.casino_outlined, 'Rolagens'),
        AbaFichario(Icons.edit_note, 'Notas'),
        AbaFichario(Icons.auto_awesome_outlined, 'Pedidos'),
      ],
      atual: _aba,
      aoEscolher: (i) => setState(() => _aba = i),
      corpo: switch (_aba) {
        0 => _AbaMesaJogador(camp: camp),
        1 => LogRolagens(cid: camp.id),
        2 => AbaNotasJogador(camp: camp),
        _ => AbaPedidosJogador(camp: camp),
      },
    );
  }
}

/// A aba Mesa do jogador: a sessão, a missão, o combate, o agente dele e
/// quem mais está na mesa. Larga, fica em duas colunas.
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
        final situacao = <Widget>[
          AvisoSessao(camp: camp),
          if (camp.missao.isNotEmpty) _Missao(texto: camp.missao),
          if (asBool(camp.combate['ativo'])) IniciativaView(camp: camp),
        ];
        final vincular = TextButton.icon(
          onPressed: () => _vincular(context, livres),
          icon: const Icon(Icons.link, size: 18),
          label: const Text('Vincular agente'),
        );
        // o dossiê do agente já é um cartão: vai solto, sem outro painel
        final agente = aqui.isEmpty
            ? BlocoMesa(
                titulo: 'Seu agente aqui',
                acoes: [vincular],
                child: const Text(
                    'Nenhum agente vinculado. Vincule um para o mestre ver sua ficha e suas rolagens aparecerem na mesa.',
                    style: TextStyle(color: Cores.textoFraco, height: 1.4)),
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 0, 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(aqui.length > 1 ? 'Seus agentes aqui' : 'Seu agente aqui',
                          style: estiloTitulo(17, cor: Cores.texto)),
                    ),
                    vincular,
                  ]),
                ),
                for (final f in aqui) CartaoAgente(ficha: f, regras: camp.regras, mostrarMesa: false),
              ]);
        final membros = _Membros(camp: camp);
        return LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 900) {
            return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
              ...situacao,
              agente,
              membros,
            ]);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: situacao)),
              const SizedBox(width: 20),
              Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [agente, membros])),
            ]),
          );
        });
      },
    );
  }
}

/// A missão atual, como o mestre escreveu: datilografada, com uma margem
/// na cor do tema.
class _Missao extends StatelessWidget {
  final String texto;
  const _Missao({required this.texto});

  @override
  Widget build(BuildContext context) => BlocoMesa(
        titulo: 'Missão atual',
        child: Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Cores.destaque.withValues(alpha: 0.7), width: 2)),
          ),
          child: Text(texto, style: estiloMaquina(15, cor: Cores.texto, espaco: 0.3).copyWith(height: 1.5)),
        ),
      );
}

/// Quem está na mesa: o mestre e os jogadores, com as fotos.
class _Membros extends StatelessWidget {
  final Campanha camp;
  const _Membros({required this.camp});

  @override
  Widget build(BuildContext context) {
    final lista = camp.members.entries.toList()
      ..sort((a, b) => a.key == camp.masterUid ? -1 : (b.key == camp.masterUid ? 1 : 0));
    return BlocoMesa(
      titulo: 'Na mesa',
      child: Wrap(spacing: 18, runSpacing: 14, children: [
        for (final e in lista)
          Row(mainAxisSize: MainAxisSize.min, children: [
            FotoJogador(uid: e.key, nome: asStr(e.value), tamanho: 38),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(asStr(e.value, '?'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(e.key == camp.masterUid ? 'Mestre' : (e.key == Repo.uid ? 'Você' : 'Jogador'),
                  style: estiloRotulo(13, cor: e.key == camp.masterUid ? Cores.destaque : Cores.textoFraco, espaco: 0.4)),
            ]),
          ]),
      ]),
    );
  }
}

/// Log de rolagens da mesa (tempo real): o total à esquerda e, ao lado, o
/// que foi rolado, por quem e quando. Críticos e falhas ganham carimbo.
class LogRolagens extends StatelessWidget {
  final String cid;
  final bool secretas;
  /// Vai dentro de outra lista (não rola sozinho).
  final bool embutido;
  const LogRolagens({super.key, required this.cid, this.secretas = false, this.embutido = false});

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
          return Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
                secretas
                    ? 'Nenhuma rolagem secreta. Marque "Secreta" ao rolar para só você ver.'
                    : 'Nenhuma rolagem ainda. Tudo o que for rolado nas fichas da mesa aparece aqui.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Cores.textoFraco, height: 1.4)),
          );
        }
        return ListView.builder(
          shrinkWrap: embutido,
          physics: embutido ? const NeverScrollableScrollPhysics() : null,
          padding: embutido ? EdgeInsets.zero : const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: l.length,
          itemBuilder: (context, i) => _LinhaRolagem(r: l[i]),
        );
      },
    );
  }
}

class _LinhaRolagem extends StatelessWidget {
  final Map<String, dynamic> r;
  const _LinhaRolagem({required this.r});

  @override
  Widget build(BuildContext context) {
    final crit = asBool(r['critico']);
    final falha = asBool(r['falhaCritica']);
    final dano = r['danoTotal'];
    final detalhe = [
      asStr(r['detalhe']),
      if (asStr(r['danoDetalhe']).isNotEmpty) 'Dano: ${asStr(r['danoDetalhe'])}',
    ].where((s) => s.isNotEmpty).join('\n');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Cores.painel,
        shape: CorteCantos(
            corte: 10, cor: crit ? Cores.ok.withValues(alpha: 0.7) : (falha ? Cores.destaque.withValues(alpha: 0.7) : Cores.borda)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
          child: Row(children: [
            SizedBox(
              width: 66,
              child: Column(children: [
                Text('${asInt(r['total'])}',
                    style: estiloNumero(30, cor: crit ? Cores.ok : (falha ? Cores.destaque : Cores.texto))),
                if (dano != null) ...[
                  const SizedBox(height: 3),
                  Text('dano ${asInt(dano)}', style: estiloRotulo(12.5, cor: Cores.destaque, peso: FontWeight.w700, espaco: 0.4)),
                ],
              ]),
            ),
            Container(width: 1, height: 44, color: Cores.linha),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asStr(r['titulo']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (detalhe.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detalhe, style: const TextStyle(fontSize: 13, color: Cores.textoFraco, height: 1.35)),
                ],
                const SizedBox(height: 4),
                Text(
                    [
                      if (asStr(r['autor']).isNotEmpty) asStr(r['autor']),
                      'às ${formatarHora(asInt(r['at']))}',
                    ].join(', '),
                    style: estiloMaquina(12, cor: Cores.textoFraco, espaco: 0.3)),
              ]),
            ),
            if (crit || falha) ...[
              const SizedBox(width: 8),
              Carimbo(crit ? 'CRÍTICO' : 'FALHA', cor: crit ? Cores.ok : Cores.destaque, tamanho: 11),
            ],
          ]),
        ),
      ),
    );
  }
}

void abrirFicha(BuildContext context, String id) => Navigator.push(
    context, rotaFicha(id));
