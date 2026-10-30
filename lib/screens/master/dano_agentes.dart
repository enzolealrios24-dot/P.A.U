import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/acoes_ameaca.dart';
import '../../core/dano.dart';
import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/imagem.dart';
import '../sheet/tab_combate.dart' show tirarDano;
import 'acao_ameaca.dart';

/// Um golpe de agente (ataque ou ritual) num combate: o id do registro, a
/// rolagem e a entrada da iniciativa do alvo marcado (null: o agente não
/// marcou alvo, e o mestre escolhe).
typedef GolpeAgente = ({String id, Map<String, dynamic> r, Map<String, dynamic>? alvo});

/// Os golpes deste combate: contra quem ainda está na ordem, ou sem alvo mas
/// feitos com estes participantes (os de combates encerrados ficam de fora,
/// porque as entradas da ordem são novas a cada combate).
List<GolpeAgente> golpesDoCombate(List<(String, Map<String, dynamic>)> registros, List<Map<String, dynamic>> ordem) {
  final porId = {for (final e in ordem) asStr(e['id']): e};
  return [
    for (final (id, r) in registros)
      if (porId[asStr(r['alvo'])] case final e?)
        (id: id, r: r, alvo: e)
      else if (asStr(r['alvo']).isEmpty && asStrList(r['participantes']).any(porId.containsKey))
        (id: id, r: r, alvo: null),
  ];
}

bool golpeResolvido(Map<String, dynamic> marcas, String id) => asStr(asMap(marcas[id])['estado']).isNotEmpty;

/// Alguém do combate que um golpe pode atingir: um agente (com a ficha) ou
/// uma ameaça (com as resistências lidas da ficha dela).
class _Atingido {
  final Map<String, dynamic> entrada;
  final Ficha? agente;
  final Map<String, dynamic>? ameaca;
  final Calc? calc;
  final ResistenciasAmeaca? res;
  _Atingido(this.entrada, this.agente, this.ameaca, Map<String, dynamic> regras)
      : calc = agente == null ? null : Calc(agente, regras),
        res = ameaca == null ? null : ResistenciasAmeaca.doTexto(asStr(ameaca['resistencias']));

  String get id => asStr(entrada['id']);
  String get nome => asStr(entrada['nome'], 'Alvo');
  bool get semFicha => agente == null && ameaca == null;

  int rdContra(String tipo) => res?.rdContra(tipo) ?? calc?.rdContra(tipo) ?? 0;

  /// Dano sofrido; [rdExtra] é o bloqueio de um agente.
  int sofre(int dano, String tipo, {bool metade = false, int rdExtra = 0}) =>
      res?.danoSofrido(dano, tipo, metade: metade) ?? danoFinal(dano, rdContra(tipo) + rdExtra, metade: metade);

  String recurso(String tipo) => tipo == 'mental' && calc != null ? (calc!.determinacao ? 'PD' : 'SAN') : 'PV';

  /// Teste de resistência: o agente pela ficha; a ameaça pela anotação
  /// dela ("Fortitude 2d20+5"), ou 1d20 sem anotação. O da ameaça fica no
  /// registro secreto.
  Rolagem resistir(String cid, String pericia, int dt) {
    final a = agente;
    if (a != null) {
      final c = calc!;
      final t = Dados.rolarTeste(
          titulo: '${a.nome}: $pericia (DT $dt)', nDados: c.dadosPericia(pericia), bonus: c.bonusPericia(pericia));
      Repo.registrarRolagem(cid, t, personagem: a.nome);
      return t;
    }
    final m = RegExp('$pericia\\s+([^•,;\\n]+)').firstMatch(asStr(ameaca?['pericias']));
    final (n, b) = testeDoLivro(m?[1] ?? '1d20');
    final t = Dados.rolarTeste(titulo: '$nome: $pericia (DT $dt)', nDados: n, bonus: b);
    Repo.registrarRolagem(cid, t, personagem: nome, secreta: true);
    return t;
  }

  void aplicar(String cid, int sofrido, String tipo, Set<String> condicoes) {
    final m = ameaca;
    final a = agente;
    if (m != null) {
      Repo.salvarDoc(Repo.ameacas(cid), asStr(entrada['ref']), {
        if (sofrido > 0) 'pv': max(0, asInt(m['pv']) - sofrido),
        if (condicoes.isNotEmpty) 'condicoes': {...asStrList(m['condicoes']), ...condicoes}.toList(),
      });
    } else if (a != null) {
      if (sofrido > 0) tirarDano(a, calc!, sofrido, mental: tipo == 'mental');
      if (condicoes.isNotEmpty) Repo.set(a.id, 'condicoes', {...a.condicoes, ...condicoes}.toList());
    }
  }
}

/// A terceira parte do combate do mestre: os ataques e rituais dos agentes.
/// Cada um diz se acertou a Defesa do alvo, quanto dano cada atingido sofre
/// (com RD, imunidade e vulnerabilidade) e que condições recebe; o mestre
/// aplica ou dispensa.
class DanoDosAgentes extends StatelessWidget {
  final Campanha camp;
  final List<GolpeAgente> golpes;
  /// O que o mestre já fez com cada golpe, pelo id.
  final Map<String, dynamic> marcas;
  final List<Map<String, dynamic>> ordem;
  final Map<String, Ficha> porId;
  final Map<String, Map<String, dynamic>> ameacas;
  const DanoDosAgentes({
    super.key,
    required this.camp,
    required this.golpes,
    required this.marcas,
    required this.ordem,
    required this.porId,
    required this.ameacas,
  });

  @override
  Widget build(BuildContext context) {
    final participantes = [
      for (final e in ordem)
        _Atingido(
          e,
          asStr(e['tipo']) == 'agente' ? porId[asStr(e['ref'])] : null,
          asStr(e['tipo']) == 'agente' ? null : ameacas[asStr(e['ref'])],
          camp.regras,
        ),
    ];
    // a conferir na ordem em que chegaram; os resolvidos, o mais novo antes
    final pendentes = golpes.where((g) => !golpeResolvido(marcas, g.id)).toList().reversed.toList();
    final resolvidos = golpes.where((g) => golpeResolvido(marcas, g.id)).take(8).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text('DANO', style: estiloTitulo(20, cor: Cores.destaque))),
        if (pendentes.isNotEmpty)
          Text('${pendentes.length} para conferir',
              style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w600, espaco: 0.4)),
      ]),
      Text(
        pendentes.isEmpty
            ? 'Quando um agente atacar ou conjurar um ritual que atinge outros durante o combate, o golpe aparece aqui para você conferir e aplicar.'
            : 'Golpes dos agentes: confira o acerto e as resistências e aplique o dano e os efeitos.',
        style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco),
      ),
      for (final g in pendentes) ...[
        const SizedBox(height: 12),
        _CartaoGolpe(
          key: ValueKey(g.id),
          camp: camp,
          golpe: g,
          marca: asMap(marcas[g.id]),
          atacante: porId[asStr(g.r['fichaId'])],
          participantes: participantes,
        ),
      ],
      if (resolvidos.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: Text('RESOLVIDOS',
              style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 1.6)),
        ),
        for (final g in resolvidos) _LinhaResolvida(camp: camp, golpe: g, marca: asMap(marcas[g.id])),
      ],
    ]);
  }
}

String _nomeDoGolpe(Map<String, dynamic> golpe) {
  final nome = asStr(golpe['nome']);
  return asStr(golpe['acao']) == 'ritual'
      ? '$nome${asStr(golpe['forma'], 'Padrão') == 'Padrão' ? '' : ' (${asStr(golpe['forma']).toLowerCase()})'}'
      : 'Ataque com $nome';
}

String _alvos(int n) => n == 1 ? '1 alvo' : '$n alvos';

/// "Felino, Medusa e Bianca".
String _juntar(List<String> nomes) =>
    nomes.length <= 1 ? nomes.join() : '${nomes.take(nomes.length - 1).join(', ')} e ${nomes.last}';

/// Os alvos escolhidos de um golpe: os que o mestre marcou ou, sem isso, o
/// que o agente marcou.
List<String> _alvosDoGolpe(GolpeAgente g, Map<String, dynamic> marca) =>
    marca['alvos'] != null ? asStrList(marca['alvos']) : [if (g.alvo != null) asStr(g.alvo!['id'])];

class _CartaoGolpe extends StatefulWidget {
  final Campanha camp;
  final GolpeAgente golpe;
  final Map<String, dynamic> marca;
  final Ficha? atacante;
  /// Todos no combate, para escolher quem o golpe atinge.
  final List<_Atingido> participantes;
  const _CartaoGolpe({
    super.key,
    required this.camp,
    required this.golpe,
    required this.marca,
    required this.atacante,
    required this.participantes,
  });

  @override
  State<_CartaoGolpe> createState() => _CartaoGolpeState();
}

/// O resultado do golpe em um atingido.
typedef _NoAlvo = ({int sofrido, bool? passou, bool metade, bool evita, bool afetado, List<String> ajustes});

class _CartaoGolpeState extends State<_CartaoGolpe> {
  String? _tipo;
  bool _contarAcerto = false;
  /// Esquiva e bloqueio de um agente atingido; null: a reação que ele
  /// escolheu na ficha, se ainda não usou nesta rodada.
  bool? _esquivou;
  bool? _bloqueou;
  bool? _metadeQuemPassa;
  Set<String>? _condicoes;
  bool _escolher = false;

  Map<String, dynamic> get _r => widget.golpe.r;
  Map<String, dynamic> get _golpe => asMap(_r['golpe']);
  String get _cid => widget.camp.id;

  /// Testes de resistência já rolados, por entrada da ordem.
  Map<String, dynamic> get _salvos => {
        // o primeiro formato guardava um teste só, o do alvo marcado
        if (widget.marca['resistencia'] != null && widget.golpe.alvo != null)
          asStr(widget.golpe.alvo!['id']): widget.marca['resistencia'],
        ...asMap(widget.marca['resistencias']),
      };

  void _escolherAlvo(String id, {required bool varios}) {
    final atual = _alvosDoGolpe(widget.golpe, widget.marca);
    final novo = varios
        ? (atual.contains(id) ? (atual.toList()..remove(id)) : [...atual, id])
        : (atual.contains(id) ? <String>[] : [id]);
    Repo.marcarGolpe(_cid, widget.golpe.id, {'alvos': novo});
  }

  void _rolarResistencias(List<_Atingido> quem, String pericia, int dt) {
    Repo.marcarGolpe(_cid, widget.golpe.id, {
      'resistencias': {
        for (final t in quem)
          if (t.resistir(_cid, pericia, dt) case final r)
            t.id: {'pericia': pericia, 'total': r.total, 'detalhe': r.detalhe},
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final cor = Cores.destaque;
    final golpe = _golpe;
    final ritual = asStr(golpe['acao']) == 'ritual';
    final area = asStr(golpe['area']);
    final temDano = _r['danoTotal'] != null;
    final dano = asInt(_r['danoTotal']);
    final porId = {for (final p in widget.participantes) p.id: p};
    final atingidos = [
      for (final id in _alvosDoGolpe(widget.golpe, widget.marca))
        if (porId[id] case final t?) t,
    ];
    final principal = atingidos.firstOrNull;

    // com mais de um tipo possível ("corte ou perfuração"), o que fere mais
    final tipos = asStrList(golpe['tiposDano']);
    final tipo = _tipo ??
        (tipos.isEmpty
            ? ''
            : tipos.reduce((a, b) => (principal?.sofre(dano, b) ?? 0) > (principal?.sofre(dano, a) ?? 0) ? b : a));
    final nomeTipo = tipoDanoPorId(tipo)?.nome.toLowerCase() ?? '';

    // ataque: contra a Defesa do alvo, com a esquiva e o bloqueio de um agente
    final total = asInt(_r['total']);
    final critico = asBool(_r['critico']);
    final calcAlvo = ritual ? null : principal?.calc;
    final corpo = asBool(golpe['corpo']);
    final agenteAlvo = ritual ? null : principal?.agente;
    final reacao = agenteAlvo == null || reacaoUsada(widget.camp, agenteAlvo) ? '' : agenteAlvo.reacao;
    final esquivou = _esquivou ?? (reacao == 'esquiva' && calcAlvo!.podeEsquivar);
    final bloqueou = _bloqueou ?? (reacao == 'bloqueio' && calcAlvo!.podeBloquear && corpo);
    final defesa = ritual || principal == null
        ? null
        : principal.ameaca != null
            ? asInt(principal.ameaca!['defesa'])
            : calcAlvo == null
                ? null
                : (esquivou ? calcAlvo.defesaEsquiva : calcAlvo.defesa);
    final acertou = defesa == null ? null : total >= defesa;
    final conta = ritual || acertou != false || _contarAcerto;
    final bloqueio = calcAlvo != null && bloqueou && tipo != 'mental' ? calcAlvo.rdBloqueio : 0;

    // ao resolver o golpe, a reação usada conta para a rodada do agente
    void gastarReacao() {
      final a = agenteAlvo;
      if (a == null || !(esquivou || bloqueou)) return;
      final m = marcaReacao(widget.camp, a);
      if (m.isNotEmpty) Repo.set(a.id, 'reacaoUsada', m);
    }

    // ritual: o teste de resistência de cada atingido
    final textoRes = asStr(golpe['resistencia']);
    final pericia = RegExp(r'Fortitude|Reflexos|Vontade').firstMatch(textoRes)?[0];
    final dt = asInt(golpe['dt']);
    final modo = semAcento(textoRes.toLowerCase());
    final anula = modo.contains('anula');
    final metadeSozinha = modo.contains('metade');
    final metadeQuemPassa = _metadeQuemPassa ?? (metadeSozinha || modo.contains('parcial'));
    final salvos = _salvos;
    final condicoesDoGolpe = asStrList(golpe['condicoes']);
    final condicoes = _condicoes ?? condicoesDoGolpe.toSet();

    _NoAlvo noAlvo(_Atingido t) {
      final s = asMap(salvos[t.id]);
      final passou = !ritual || s.isEmpty ? null : asInt(s['total']) >= dt;
      final metade = passou == true && metadeQuemPassa && !anula;
      final evita = passou == true && anula;
      final imune = t.res?.imuneA(tipo) ?? false;
      final rd = t.rdContra(tipo);
      return (
        sofrido: !temDano || !conta || evita || t.semFicha ? 0 : t.sofre(dano, tipo, metade: metade, rdExtra: bloqueio),
        passou: passou,
        metade: metade,
        evita: evita,
        afetado: passou != true && !t.semFicha,
        ajustes: [
          if (imune) 'imune'
          else ...[
            if (metade) 'metade',
            if (t.res?.vulneravel.contains(tipo) ?? false) 'vulnerável: dobro',
            if (rd > 0) 'RD $rd',
            if (bloqueio > 0) 'bloqueio $bloqueio',
          ],
        ],
      );
    }

    final resultados = {for (final t in atingidos) t.id: noAlvo(t)};
    final danoTotal = resultados.values.fold(0, (s, r) => s + r.sofrido);
    final comCondicao = condicoes.isEmpty ? 0 : resultados.values.where((r) => r.afetado).length;

    final linhas = <Widget>[
      if (!ritual && principal != null)
        LinhaResultado(
          titulo: 'Ataque $total',
          detalhe: asStr(_r['detalhe']),
          resultado: acertou == null
              ? (critico ? 'crítico' : null)
              : acertou
                  ? (critico ? 'acertou, crítico' : 'acertou')
                  : 'errou (Defesa $defesa${esquivou ? ', com esquiva' : ''})',
          bom: acertou,
          cor: cor,
        ),
      if (!ritual && principal != null && conta && temDano)
        LinhaResultado(
          titulo: 'dano $dano${nomeTipo.isEmpty ? '' : ' $nomeTipo'}'
              '${resultados[principal.id]!.ajustes.isEmpty ? '' : ' · ${resultados[principal.id]!.ajustes.join(' · ')}'}'
              '${principal.semFicha || resultados[principal.id]!.sofrido == dano ? '' : ' · sofre ${resultados[principal.id]!.sofrido}'}',
          detalhe: asStr(_r['danoDetalhe']),
          cor: cor,
        ),
      if (ritual && dt > 0)
        LinhaResultado(titulo: 'DT $dt', detalhe: textoRes, resultado: textoRes.isEmpty ? null : textoRes, cor: cor),
      if (ritual && area.isNotEmpty) LinhaResultado(titulo: area, detalhe: 'Área do ritual', cor: cor),
      if (ritual && temDano)
        LinhaResultado(
            titulo: 'dano $dano${nomeTipo.isEmpty ? '' : ' $nomeTipo'}', detalhe: asStr(_r['danoDetalhe']), cor: cor),
      if (ritual)
        for (final t in atingidos)
          if (resultados[t.id]! case final r)
            LinhaResultado(
              titulo: '${t.nome}${switch (r) {
                _ when t.semFicha => '',
                _ when r.evita => ': anulado',
                _ when r.sofrido > 0 => ': −${r.sofrido} ${t.recurso(tipo)}',
                _ when temDano => ': sem dano',
                _ => '',
              }}${r.ajustes.isEmpty || !temDano || r.evita ? '' : ' (${r.ajustes.join(', ')})'}'
                  '${r.afetado && condicoes.isNotEmpty ? ' · ${condicoes.join(', ')}' : ''}',
              detalhe: asStr(asMap(salvos[t.id])['detalhe']),
              resultado: r.passou == null
                  ? (pericia != null && dt > 0 && !t.semFicha ? 'sem teste' : null)
                  : '$pericia ${asInt(asMap(salvos[t.id])['total'])}: '
                      '${r.passou! ? (r.evita ? 'passou, anula' : r.metade ? 'passou, metade' : 'passou') : 'falhou'}',
              bom: r.passou == null ? null : !r.passou!,
              cor: cor,
            ),
    ];

    final semTeste = [
      for (final t in atingidos)
        if (!t.semFicha && salvos[t.id] == null) t,
    ];
    final escolhendo = area.isNotEmpty || atingidos.isEmpty || _escolher;
    final chips = <Widget>[
      if (ritual && pericia != null && dt > 0 && semTeste.isNotEmpty)
        ActionChip(
          avatar: Icon(Icons.casino_outlined, size: 16, color: cor),
          label: Text(semTeste.length == 1
              ? 'Rolar $pericia de ${semTeste.single.nome.split(' ').first}'
              : 'Rolar $pericia (${semTeste.length} alvos)'),
          onPressed: () => _rolarResistencias(semTeste, pericia, dt),
        ),
      if (acertou == false)
        FilterChip(
          label: const Text('Contar como acerto'),
          selected: _contarAcerto,
          onSelected: (v) => setState(() => _contarAcerto = v),
        ),
      if (calcAlvo != null && calcAlvo.podeEsquivar)
        FilterChip(
          label: Text('Esquivou (Defesa ${calcAlvo.defesaEsquiva})'),
          selected: esquivou,
          onSelected: (v) => setState(() {
            _esquivou = v;
            if (v) _bloqueou = false;
          }),
        ),
      if (calcAlvo != null && calcAlvo.podeBloquear && corpo)
        FilterChip(
          label: Text('Bloqueou (RD +${calcAlvo.rdBloqueio})'),
          selected: bloqueou,
          onSelected: (v) => setState(() {
            _bloqueou = v;
            if (v) _esquivou = false;
          }),
        ),
      if (ritual && temDano && pericia != null && !anula && !metadeSozinha)
        FilterChip(
          label: const Text('Quem passou sofre metade'),
          selected: metadeQuemPassa,
          onSelected: (v) => setState(() => _metadeQuemPassa = v),
        ),
      if (conta && temDano) ...[
        for (final t in tipos.length > 1 ? tipos : const <String>[])
          ChoiceChip(
            label: Text(tipoDanoPorId(t)?.nome ?? t),
            selected: tipo == t,
            onSelected: (_) => setState(() => _tipo = t),
          ),
        if (principal != null && !principal.semFicha)
          _TrocarTipo(tipo: tipo, rdContra: principal.rdContra, aoEscolher: (t) => setState(() => _tipo = t)),
      ],
      if (!escolhendo)
        ActionChip(
          avatar: Icon(ritual ? Icons.group_add_outlined : Icons.swap_horiz, size: 16, color: cor),
          label: Text(ritual ? 'Mais alvos' : 'Trocar alvo'),
          onPressed: () => setState(() => _escolher = true),
        ),
    ];

    final atacante = widget.atacante;
    final quem = asStr(_r['personagem'], atacante?.nome ?? 'Agente');
    final rotulo = estiloRotulo(11.5, cor: Cores.textoFraco, espaco: 1.4);
    final aplicavel = atingidos.isNotEmpty && (danoTotal > 0 || comCondicao > 0);
    return Material(
      color: cor.withValues(alpha: 0.06),
      shape: CorteCantos(corte: 14, cor: cor.withValues(alpha: 0.6)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            RetratoFicha(
              foto: atacante?.foto ?? '',
              nome: quem,
              ajuste: atacante?.fotoAjuste ?? const {},
              largura: 38,
              proporcao: 1,
              raio: 4,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nomeDoGolpe(golpe), style: estiloTitulo(17, cor: Cores.texto)),
                Text(
                    atingidos.isEmpty
                        ? '$quem · sem alvo marcado'
                        : '$quem contra ${_juntar([for (final t in atingidos) t.nome])}',
                    style: TextStyle(fontSize: 13, color: corDeTexto(cor))),
              ]),
            ),
            Icon(ritual ? Icons.auto_awesome : Icons.gps_fixed, size: 20, color: corDeTexto(cor)),
          ]),
          const SizedBox(height: 6),
          ...linhas,
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: chips),
          ],
          if (escolhendo) ...[
            const SizedBox(height: 10),
            Text(area.isNotEmpty ? 'QUEM ESTÁ NA ÁREA' : (ritual ? 'ALVOS' : 'ALVO'), style: rotulo),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in widget.participantes)
                FilterChip(
                  label: Text(p.nome),
                  avatar: Icon(asStr(p.entrada['tipo']) == 'agente' ? Icons.person_outline : Icons.pest_control_outlined,
                      size: 16),
                  selected: atingidos.contains(p),
                  onSelected: (_) => _escolherAlvo(p.id, varios: ritual),
                ),
            ]),
          ],
          if (ritual && condicoesDoGolpe.isNotEmpty && atingidos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(pericia != null && dt > 0 ? 'CONDIÇÕES EM QUEM FALHAR' : 'CONDIÇÕES', style: rotulo),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final cd in condicoesDoGolpe)
                FilterChip(
                  label: Text(cd),
                  selected: condicoes.contains(cd),
                  onSelected: (v) => setState(() => _condicoes = v ? {...condicoes, cd} : ({...condicoes}..remove(cd))),
                ),
            ]),
          ],
          if (ritual && asStr(golpe['efeito']).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(asStr(golpe['efeito']), style: const TextStyle(fontSize: 13, height: 1.4, color: Cores.textoFraco)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(
                atingidos.isEmpty
                    ? (area.isNotEmpty ? 'Escolha quem está na área.' : 'Escolha o alvo.')
                    : !conta
                        ? 'Errou: sem dano'
                        : aplicavel
                            ? [
                                if (danoTotal > 0)
                                  atingidos.length == 1
                                      ? '−$danoTotal ${principal!.recurso(tipo)}'
                                      : '−$danoTotal PV em ${_alvos(resultados.values.where((r) => r.sofrido > 0).length)}',
                                if (comCondicao > 0)
                                  atingidos.length == 1 ? condicoes.join(', ') : '${condicoes.join(', ')} em ${_alvos(comCondicao)}',
                              ].join(' · ')
                            : atingidos.every((t) => t.semFicha)
                                ? 'Sem ficha para aplicar.'
                                : 'Nada para aplicar.',
                style: aplicavel && conta
                    ? estiloNumero(17, cor: Cores.pv)
                    : const TextStyle(fontSize: 14, color: Cores.textoFraco),
              ),
            ),
            TextButton(
              onPressed: () {
                gastarReacao();
                Repo.marcarGolpe(_cid, widget.golpe.id, {'estado': 'dispensado'});
              },
              child: const Text('Dispensar'),
            ),
            if (aplicavel && conta) ...[
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () {
                  gastarReacao();
                  for (final t in atingidos) {
                    final r = resultados[t.id]!;
                    t.aplicar(_cid, r.sofrido, tipo, r.afetado ? condicoes : const {});
                  }
                  Repo.marcarGolpe(_cid, widget.golpe.id, {
                    'estado': 'aplicado',
                    'sofreu': danoTotal,
                    'tipo': tipo,
                    'resumo': [
                      for (final t in atingidos)
                        if (resultados[t.id]! case final r when r.sofrido > 0 || (r.afetado && condicoes.isNotEmpty))
                          '${t.nome} ${[
                            if (r.sofrido > 0) '−${r.sofrido} ${t.recurso(tipo)}',
                            if (r.afetado) ...condicoes,
                          ].join(', ')}',
                    ].join('; '),
                  });
                },
                icon: const Icon(Icons.south, size: 18),
                label: Text(danoTotal > 0 ? 'Aplicar dano' : 'Aplicar efeito'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// Troca o tipo do dano (a arma sem tipo anotado, ou o ritual de outro
/// elemento), mostrando a RD do alvo contra cada um.
class _TrocarTipo extends StatelessWidget {
  final String tipo;
  final int Function(String) rdContra;
  final ValueChanged<String> aoEscolher;
  const _TrocarTipo({required this.tipo, required this.rdContra, required this.aoEscolher});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Trocar o tipo do dano',
        onSelected: aoEscolher,
        itemBuilder: (_) => [
          for (final t in ['', ...tiposDano.map((t) => t.id)])
            PopupMenuItem(
              value: t,
              child: Row(children: [
                Expanded(child: Text(t.isEmpty ? 'Sem tipo' : tipoDanoPorId(t)!.nome)),
                if (rdContra(t) > 0)
                  Text('RD ${rdContra(t)}', style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
              ]),
            ),
        ],
        child: Chip(
          avatar: const Icon(Icons.swap_horiz, size: 16),
          label: Text(tipo.isEmpty ? 'Tipo do dano' : 'Tipo: ${tipoDanoPorId(tipo)?.nome ?? tipo}'),
        ),
      );
}

class _LinhaResolvida extends StatelessWidget {
  final Campanha camp;
  final GolpeAgente golpe;
  final Map<String, dynamic> marca;
  const _LinhaResolvida({required this.camp, required this.golpe, required this.marca});

  @override
  Widget build(BuildContext context) {
    final aplicado = asStr(marca['estado']) == 'aplicado';
    final g = asMap(golpe.r['golpe']);
    final resumo = asStr(marca['resumo']);
    return Tooltip(
      message: resumo,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(aplicado ? Icons.check : Icons.remove, size: 16, color: aplicado ? Cores.destaque : Cores.textoFraco),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${asStr(golpe.r['personagem'], 'Agente')}: ${_nomeDoGolpe(g)}'
              '${golpe.alvo == null ? '' : ' contra ${asStr(golpe.alvo!['nome'])}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Cores.textoFraco),
            ),
          ),
          const SizedBox(width: 8),
          if (aplicado)
            Text(asInt(marca['sofreu']) > 0 ? '−${asInt(marca['sofreu'])}' : 'efeito',
                style: estiloNumero(14, cor: Cores.texto))
          else
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => Repo.marcarGolpe(camp.id, golpe.id, {'estado': ''}),
              child: const Text('Reabrir'),
            ),
        ]),
      ),
    );
  }
}
