import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/quadro.dart';
import '../../data/repo.dart';
import '../../widgets/arquivo.dart';
import '../../widgets/common.dart';
import '../../widgets/efeitos.dart';
import '../../widgets/foto_jogador.dart';
import '../../widgets/imagem.dart';
import '../campaign/campaign_screen.dart';
import '../campaign/jogadores.dart';
import '../campaign/sessao.dart';
import '../sheet/tab_agente.dart';
import '../quadro/quadro_screen.dart';
import 'ameacas.dart';
import 'combate.dart';
import 'nomes.dart';
import 'regras.dart';

class TelaMestre extends StatefulWidget {
  final Campanha camp;
  const TelaMestre({super.key, required this.camp});
  @override
  State<TelaMestre> createState() => _TelaMestreState();
}

class _TelaMestreState extends State<TelaMestre> {
  int _aba = 0;
  static const _abas = [
    (Icons.dashboard_outlined, 'Painel'),
    (Icons.flash_on_outlined, 'Combate'),
    (Icons.pest_control_outlined, 'Ameaças'),
    (Icons.casino_outlined, 'Rolagens'),
    (Icons.event_note_outlined, 'Sessões'),
    (Icons.forum_outlined, 'Jogadores'),
    (Icons.person_search_outlined, 'Nomes'),
    (Icons.tune, 'Regras'),
    (Icons.settings_outlined, 'Mesa'),
  ];

  static const _jogadores = 5;

  /// As fichas da mesa, para contar as notas e os pedidos dos jogadores.
  late final _fichas = Repo.todasDaCampanha(widget.camp.id);

  Widget _corpo() {
    final c = widget.camp;
    switch (_aba) {
      case 0:
        return PainelAoVivo(camp: c);
      case 1:
        return AbaCombate(camp: c);
      case 2:
        return AbaAmeacas(camp: c);
      case 3:
        return _AbaRolagensMestre(camp: c);
      case 4:
        return AbaSessoesMestre(camp: c);
      case 5:
        return AbaJogadoresMestre(camp: c);
      case 6:
        return AbaNomes(camp: c);
      case 7:
        return AbaRegras(camp: c);
      default:
        return _AbaMesa(camp: c);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Ficha>>(
        stream: _fichas,
        builder: (context, snap) {
          final pendentes = pendentesDoMestre(snap.data ?? const []);
          return Fichario(
            appBar: barraDaMesa(context, widget.camp),
            abas: [
              for (var i = 0; i < _abas.length; i++)
                AbaFichario(_abas[i].$1, _abas[i].$2, aviso: i == _jogadores ? pendentes : 0),
            ],
            atual: _aba,
            aoEscolher: (i) => setState(() => _aba = i),
            corpo: _corpo(),
          );
        },
      );
}

// ---------------- PAINEL AO VIVO ----------------

class PainelAoVivo extends StatelessWidget {
  final Campanha camp;
  const PainelAoVivo({super.key, required this.camp});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ficha>>(
      stream: Repo.fichasDaCampanha(camp.id),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final fichas = snap.data!;
        final acoes = <(IconData, String, VoidCallback?)>[
          (Icons.casino_outlined, 'Pedir teste a todos', fichas.isEmpty ? null : () => pedirTesteGrupo(context, camp, fichas)),
          (Icons.exposure, 'Dano/cura em grupo', fichas.isEmpty ? null : () => _aplicarTodos(context, fichas)),
          (Icons.restore, 'Recuperar todos', fichas.isEmpty ? null : () => _recuperarTodos(context, fichas)),
        ];
        return LayoutBuilder(builder: (context, c) {
          final colunas = c.maxWidth >= 1180 ? 3 : (c.maxWidth >= 760 ? 2 : 1);
          final largura = (c.maxWidth - 32 - 14 * (colunas - 1)) / colunas;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
            if (camp.masterUid == Repo.uid) ...[
              CartaoSessao(camp: camp),
              const SizedBox(height: 14),
            ],
            // no celular, os três botões dividem a largura; no computador,
            // ficam lado a lado no tamanho deles
            if (c.maxWidth < 600)
              Row(children: [
                for (final (i, a) in acoes.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _BotaoGrupo(icone: a.$1, rotulo: a.$2, aoTocar: a.$3, principal: i == 0)),
                ],
              ])
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (i, a) in acoes.indexed)
                  i == 0
                      ? FilledButton.icon(onPressed: a.$3, icon: Icon(a.$1), label: Text(a.$2))
                      : OutlinedButton.icon(onPressed: a.$3, icon: Icon(a.$1), label: Text(a.$2)),
              ]),
            const SizedBox(height: 22),
            Row(children: [
              Text('Agentes na mesa', style: estiloTitulo(19, cor: Cores.texto)),
              const SizedBox(width: 10),
              Text('${fichas.length}', style: estiloNumero(19, cor: Cores.textoFraco)),
            ]),
            const SizedBox(height: 10),
            if (fichas.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Nenhum agente vinculado ainda.\nPasse o código '),
                    TextSpan(text: camp.joinCode, style: estiloMaquina(15, cor: Cores.destaque, espaco: 2)),
                    const TextSpan(
                        text: ' para os jogadores: eles entram na mesa e vinculam o agente deles.'),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Cores.textoFraco, height: 1.5),
                ),
              ),
            Wrap(spacing: 14, runSpacing: 14, children: [
              for (final (i, f) in fichas.indexed)
                SizedBox(width: largura, child: Surgir(ordem: i, child: _CartaoPainel(ficha: f, camp: camp))),
            ]),
          ]);
        });
      },
    );
  }

  Future<void> _recuperarTodos(BuildContext context, List<Ficha> fichas) async {
    if (!await confirmar(context, 'Recuperar PV, PE, SAN e PD de todos ao máximo?')) return;
    for (final f in fichas) {
      final c = Calc(f, camp.regras);
      Repo.mudarRecursos(f, {
        'pvAtual': c.pvMax,
        'peAtual': c.peMax,
        'sanAtual': c.sanMax,
        'pdAtual': c.pdMax,
      });
    }
  }

  Future<void> _aplicarTodos(BuildContext context, List<Ficha> fichas) async {
    final calc0 = Calc(fichas.first, camp.regras);
    final opcoes =
        calc0.determinacao ? ['PV', 'PD'] : ['PV', 'PE', 'SAN'];
    var stat = 'PV';
    final ctl = TextEditingController(text: '-');
    final r = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Aplicar a todos os agentes'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: [
                for (final o in opcoes) ButtonSegment(value: o, label: Text(o))
              ],
              selected: {stat},
              onSelectionChanged: (s) => set(() => stat = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                  labelText: 'Valor', helperText: 'Negativo = dano/perda'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, int.tryParse(ctl.text.trim())),
                child: const Text('Aplicar')),
          ],
        ),
      ),
    );
    if (r == null) return;
    final campo = {
      'PV': 'pvAtual',
      'PE': 'peAtual',
      'SAN': 'sanAtual',
      'PD': 'pdAtual'
    }[stat]!;
    for (final f in fichas) {
      Repo.mudarPontos(f, campo, asInt(f.d[campo]) + r);
    }
  }
}

/// O mestre rola o mesmo teste para todos os agentes e ve quem passou.
Future<void> pedirTesteGrupo(
    BuildContext context, Campanha camp, List<Ficha> fichas) async {
  var pericia = 'Percepção';
  var secreto = false;
  final dt = TextEditingController(text: '15');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Teste em grupo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Seletor(
            rotulo: 'Perícia',
            valor: pericia,
            opcoes: [for (final p in periciasDef) p.nome],
            aoMudar: (v) => set(() => pericia = v),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: dt,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'DT')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Secreto (só o mestre vê)'),
            value: secreto,
            onChanged: (v) => set(() => secreto = v),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rolar para todos')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final valorDt = int.tryParse(dt.text.trim()) ?? 15;
  final resultados = <(Ficha, Rolagem)>[];
  for (final f in fichas) {
    final c = Calc(f, camp.regras);
    final r = Dados.rolarTeste(
      titulo: '${f.nome}: $pericia (DT $valorDt)',
      nDados: c.dadosPericia(pericia),
      bonus: c.bonusPericia(pericia),
    );
    resultados.add((f, r));
    Repo.registrarRolagem(camp.id, r, personagem: f.nome, secreta: secreto);
  }
  resultados.sort((a, b) => b.$2.total.compareTo(a.$2.total));
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$pericia • DT $valorDt'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in resultados)
            ListTile(
              dense: true,
              leading: Icon(
                e.$2.total >= valorDt ? Icons.check_circle : Icons.cancel,
                color: e.$2.total >= valorDt ? Cores.ok : Cores.destaque,
              ),
              title: Text(e.$1.nome),
              subtitle: Text(e.$2.detalhe),
              trailing: Text('${e.$2.total}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))
      ],
    ),
  );
}

/// Botão das ações em grupo no celular: ícone em cima e o nome embaixo, em
/// até duas linhas, para os três caberem lado a lado.
class _BotaoGrupo extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;
  final bool principal;
  const _BotaoGrupo({required this.icone, required this.rotulo, required this.aoTocar, this.principal = false});

  @override
  Widget build(BuildContext context) {
    final ligado = aoTocar != null;
    final frente = !ligado ? Cores.textoFraco : (principal ? Cores.sobreDestaque : Cores.destaque);
    return Material(
      color: principal && ligado ? Cores.destaque : Cores.painel,
      shape: CorteCantos(corte: 10, cor: principal && ligado ? null : Cores.borda),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icone, size: 22, color: frente),
            const SizedBox(height: 6),
            Text(rotulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: estiloRotulo(14, cor: frente, peso: FontWeight.w700, espaco: 0.3)),
          ]),
        ),
      ),
    );
  }
}

/// Um agente no Painel: rosto, nome e quem joga; os recursos para mexer
/// direto; os números de combate e as condições.
class _CartaoPainel extends StatelessWidget {
  final Ficha ficha;
  final Campanha camp;
  const _CartaoPainel({required this.ficha, required this.camp});
  @override
  Widget build(BuildContext context) {
    final f = ficha;
    final c = Calc(f, camp.regras);
    final morrendo = f.pvAtual <= 0;
    final jogador = f.jogador.isEmpty ? asStr(camp.members[f.ownerUid]) : f.jogador;
    return Material(
      color: morrendo ? Color.alphaBlend(Cores.destaque.withValues(alpha: 0.08), Cores.painel) : Cores.painel,
      shape: CorteCantos(
          corte: 14, cor: morrendo ? Cores.destaque : Cores.borda, largura: morrendo ? 1.6 : 1),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AvatarFicha(
              foto: f.foto,
              nome: f.nome,
              ajuste: f.fotoAjuste,
              tamanho: 54,
              transformacao: f.eTransformacao,
              aoTocar: () => abrirFicha(context, f.id),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => abrirFicha(context, f.id),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (f.eTransformacao || morrendo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Carimbo(morrendo ? 'MORRENDO' : 'TRANSFORMADO',
                          cor: morrendo ? Cores.destaque : Cores.roxoClaro, tamanho: 10),
                    ),
                  Text(f.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: estiloTitulo(18, cor: Cores.texto)),
                  const SizedBox(height: 3),
                  Text([jogador, f.classe, c.resumoProgressao].where((s) => s.isNotEmpty).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: estiloMaquina(12, cor: Cores.textoFraco, espaco: 0.3)),
                ]),
              ),
            ),
            IconButton(
              tooltip: 'Abrir ficha completa',
              icon: const Icon(Icons.open_in_new, size: 20),
              onPressed: () => abrirFicha(context, f.id),
            ),
          ]),
          const SizedBox(height: 12),
          BarraStatus(
              rotulo: 'PV',
              atual: f.pvAtual,
              max: c.pvMax,
              cor: Cores.pv,
              aoMudar: (v) => Repo.mudarPontos(f, 'pvAtual', v)),
          if (f.pvTemp > 0) ...[
            const SizedBox(height: 6),
            BarraStatus(
                rotulo: 'PV TEMP',
                atual: f.pvTemp,
                max: f.pvTempMax < f.pvTemp ? f.pvTemp : f.pvTempMax,
                cor: Cores.pvTemp,
                compacta: true,
                aoMudar: (v) => Repo.mudarTemporario(f, 'pvTemp', v)),
          ],
          const SizedBox(height: 6),
          if (c.determinacao)
            BarraStatus(
                rotulo: 'PD',
                atual: f.pdAtual,
                max: c.pdMax,
                cor: Cores.pd,
                aoMudar: (v) => Repo.mudarPontos(f, 'pdAtual', v))
          else
            BarraStatus(
                rotulo: 'PE',
                atual: f.peAtual,
                max: c.peMax,
                cor: Cores.pe,
                aoMudar: (v) => Repo.mudarPontos(f, 'peAtual', v)),
          if (f.peTemp > 0) ...[
            const SizedBox(height: 6),
            BarraStatus(
                rotulo: c.determinacao ? 'PD TEMP' : 'PE TEMP',
                atual: f.peTemp,
                max: f.peTempMax < f.peTemp ? f.peTemp : f.peTempMax,
                cor: c.determinacao ? Cores.pdTemp : Cores.peTemp,
                compacta: true,
                aoMudar: (v) => Repo.mudarTemporario(f, 'peTemp', v)),
          ],
          if (!c.determinacao) ...[
            const SizedBox(height: 6),
            BarraStatus(
                rotulo: 'SAN',
                atual: f.sanAtual,
                max: c.sanMax,
                cor: Cores.san,
                aoMudar: (v) => Repo.mudarRecursos(f, {'sanAtual': v})),
          ],
          const SizedBox(height: 12),
          FileiraMarcadores([
            Marcador('Defesa', '${c.defesa}'),
            Marcador('Desloc.', '${c.deslocamento} m'),
            Marcador('Carga', '${c.cargaAtual}/${c.cargaMax}'),
            Marcador(c.patente.nome, '${f.pp} PP'),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final cd in f.condicoes)
              Chip(
                label: Text(cd),
                visualDensity: VisualDensity.compact,
                backgroundColor: Color.alphaBlend(Cores.destaque.withValues(alpha: 0.18), Cores.painel2),
                side: BorderSide(color: Cores.destaque.withValues(alpha: 0.5)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Condição'),
              visualDensity: VisualDensity.compact,
              onPressed: () => editarCondicoes(context, f),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ---------------- ROLAGENS DO MESTRE ----------------

class _AbaRolagensMestre extends StatefulWidget {
  final Campanha camp;
  const _AbaRolagensMestre({required this.camp});
  @override
  State<_AbaRolagensMestre> createState() => _AbaRolagensMestreState();
}

class _AbaRolagensMestreState extends State<_AbaRolagensMestre> {
  bool _secretas = false;
  bool _rolarSecreto = true;
  final _expr = TextEditingController(text: '1d20');

  @override
  void dispose() {
    _expr.dispose();
    super.dispose();
  }

  void _rolar() {
    final e = Dados.expressao(_expr.text);
    final r = Rolagem(
        titulo: 'Mestre: ${_expr.text}', detalhe: e.detalhe, total: e.total);
    mostrarRolagem(context, r);
    Repo.registrarRolagem(widget.camp.id, r,
        personagem: 'Mestre', secreta: _rolarSecreto);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
      const CabecalhoAba(
        titulo: 'Rolagens',
        texto: 'Tudo o que se rola nas fichas da mesa aparece aqui na hora. As secretas só você vê.',
      ),
      Material(
        color: Cores.painel,
        shape: CorteCantos(corte: 12, cor: Cores.borda),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _expr,
                style: estiloNumero(20, cor: Cores.texto),
                decoration: const InputDecoration(labelText: 'Rolar dados', hintText: 'ex.: 3d6+2'),
                onSubmitted: (_) => _rolar(),
              ),
            ),
            const SizedBox(width: 10),
            FilterChip(
              label: const Text('Secreta'),
              selected: _rolarSecreto,
              onSelected: (v) => setState(() => _rolarSecreto = v),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: _rolar, icon: const Icon(Icons.casino_outlined), label: const Text('Rolar')),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Row(children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Mesa')),
            ButtonSegment(value: true, label: Text('Secretas')),
          ],
          selected: {_secretas},
          onSelectionChanged: (s) => setState(() => _secretas = s.first),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () async {
            if (await confirmar(context, 'Apagar o log de rolagens ${_secretas ? 'secretas' : 'da mesa'}?')) {
              await Repo.limparLog(widget.camp.id, secretas: _secretas);
            }
          },
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Limpar'),
        ),
      ]),
      const SizedBox(height: 8),
      LogRolagens(key: ValueKey(_secretas), cid: widget.camp.id, secretas: _secretas, embutido: true),
    ]);
  }
}

// ---------------- MESA (configuracoes) ----------------

class _AbaMesa extends StatelessWidget {
  final Campanha camp;
  const _AbaMesa({required this.camp});

  Future<void> _evento(BuildContext context) async {
    var evento = eventosPP.keys.first;
    final valor = TextEditingController(text: '${eventosPP[evento]}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Evento de missão'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Seletor(
              rotulo: 'Evento',
              valor: evento,
              opcoes: [...eventosPP.keys, 'Outro'],
              aoMudar: (v) => set(() {
                evento = v;
                if (eventosPP.containsKey(v)) valor.text = '${eventosPP[v]}';
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: valor,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                  labelText: 'Pontos de prestígio para cada agente'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Aplicar a todos')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final v = int.tryParse(valor.text.trim()) ?? 0;
    final fichas = await Repo.agentesDaCampanha(camp.id).first;
    for (final f in fichas) {
      Repo.set(f.id, 'pp', f.pp + v);
    }
    Repo.setCamp(camp.id, {
      'ledger': FieldValue.arrayUnion([
        {
          'evento': evento,
          'pp': v,
          'at': DateTime.now().millisecondsSinceEpoch,
        }
      ])
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledger = camp.ledger.reversed.toList();
    final membros = camp.members.entries.toList()
      ..sort((a, b) => a.key == camp.masterUid ? -1 : (b.key == camp.masterUid ? 1 : 0));
    final mesa = BlocoMesa(
      titulo: 'A mesa',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CampoSync(
            valor: camp.nome,
            rotulo: 'Nome da campanha',
            aoSalvar: (v) => Repo.setCamp(camp.id, {'nome': v})),
        const SizedBox(height: 16),
        Wrap(spacing: 14, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Código para os jogadores', style: TextStyle(color: Cores.textoFraco)),
          CodigoMesa(codigo: camp.joinCode, tamanho: 20),
        ]),
        const SizedBox(height: 12),
        CampoSync(
            valor: camp.missao,
            rotulo: 'Missão atual (os jogadores veem)',
            maxLinhas: 4,
            aoSalvar: (v) => Repo.setCamp(camp.id, {'missao': v})),
      ]),
    );
    final quem = BlocoMesa(
      titulo: 'Membros',
      child: Column(children: [
        for (final e in membros)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              FotoJogador(uid: e.key, nome: asStr(e.value), tamanho: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(asStr(e.value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(e.key == camp.masterUid ? 'Mestre' : 'Jogador',
                      style: estiloRotulo(13, cor: e.key == camp.masterUid ? Cores.destaque : Cores.textoFraco, espaco: 0.4)),
                ]),
              ),
              if (e.key != camp.masterUid)
                IconButton(
                  tooltip: 'Tirar da mesa',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () async {
                    if (await confirmar(context, 'Remover ${e.value} da mesa?')) {
                      await Repo.removerMembro(camp, e.key);
                    }
                  },
                ),
            ]),
          ),
      ]),
    );
    final prestigio = BlocoMesa(
      titulo: 'Prestígio da missão',
      acoes: [
        TextButton.icon(
          onPressed: () => _evento(context),
          icon: const Icon(Icons.military_tech_outlined, size: 18),
          label: const Text('Registrar evento'),
        ),
      ],
      child: ledger.isEmpty
          ? const Text(
              'Registre solução do caso (+10), pistas (+2), mortes (-2/-5)... os PP são somados em todas as fichas da mesa.',
              style: TextStyle(color: Cores.textoFraco, height: 1.4))
          : Column(children: [
              for (final l in ledger.take(20))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Cores.linha))),
                  child: Row(children: [
                    SizedBox(
                      width: 92,
                      child: Text(_data(asInt(l['at'])), style: estiloMaquina(12, cor: Cores.textoFraco, espaco: 0.3)),
                    ),
                    Expanded(child: Text(asStr(l['evento']), style: const TextStyle(fontSize: 14.5))),
                    Text('${asInt(l['pp']) >= 0 ? '+' : ''}${asInt(l['pp'])} PP',
                        style: estiloNumero(16, cor: asInt(l['pp']) >= 0 ? Cores.ok : Cores.destaque)),
                  ]),
                ),
            ]),
    );
    final quadro = BlocoMesa(
      titulo: 'Quadro do mestre',
      child: StreamBuilder<Map<String, Quadro>>(
        stream: FonteQuadro.mestre(camp.id).todos,
        builder: (context, s) {
          final raiz = s.data?[FonteQuadro.raiz];
          void abrir() => Navigator.push(
              context, MaterialPageRoute(builder: (_) => TelaQuadro(fonte: FonteQuadro.mestre(camp.id))));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
              onTap: abrir,
              borderRadius: BorderRadius.circular(4),
              child: MiniQuadro(quadro: raiz),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: abrir,
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Abrir quadro do mestre'),
            ),
            const SizedBox(height: 6),
            const Text('Quadro estilo Milanote para planejar a campanha: só você vê.',
                style: TextStyle(fontSize: 13, color: Cores.textoFraco)),
          ]);
        },
      ),
    );
    final notas = BlocoMesa(
      titulo: 'Notas privadas do mestre',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: Repo.notasMestre(camp.id).snapshots(),
        builder: (context, s) {
          if (!s.hasData) return const LinearProgressIndicator();
          return CampoSync(
            valor: asStr(s.data!.data()?['texto']),
            maxLinhas: 12,
            dica: 'Segredos, ganchos, NPCs... só você vê.',
            aoSalvar: (v) => Repo.notasMestre(camp.id).set({'texto': v}, SetOptions(merge: true)),
          );
        },
      ),
    );
    final apagar = Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Cores.destaque),
        onPressed: () async {
          if (await confirmar(context,
              'Apagar a mesa "${camp.nome}"? As fichas dos jogadores continuam existindo.')) {
            final fichas = await Repo.todasDaCampanha(camp.id).first;
            for (final f in fichas) {
              if (f.ownerUid != Repo.uid) {
                // o dono desvincula depois; aqui so tiramos o mestre dos editores
                Repo.setVarios(f.id, {
                  'campaignId': null,
                  'editors': [f.ownerUid]
                });
              } else {
                Repo.desvincularFicha(f);
              }
            }
            await Repo.apagarCampanha(camp);
            if (context.mounted) Navigator.pop(context);
          }
        },
        icon: const Icon(Icons.delete_forever_outlined),
        label: const Text('Apagar mesa'),
      ),
    );
    const cabecalho = CabecalhoAba(
      titulo: 'Mesa',
      texto: 'O nome, o código para os jogadores entrarem, quem está na mesa, o prestígio e as suas notas.',
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 980) {
        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 28), children: [
          cabecalho,
          mesa,
          quem,
          prestigio,
          quadro,
          notas,
          const SizedBox(height: 12),
          apagar,
        ]);
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          cabecalho,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [mesa, quem, prestigio])),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              quadro,
              notas,
              const SizedBox(height: 12),
              apagar,
            ])),
          ]),
        ]),
      );
    });
  }

  String _data(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${formatarHora(ms)}';
  }
}
