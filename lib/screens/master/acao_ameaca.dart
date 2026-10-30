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
import '../sheet/tab_combate.dart' show tirarDano;

/// Cor das ações de uma ameaça: a do elemento, ou o destaque nas da Realidade.
Color corDaAmeaca(Map<String, dynamic> d) {
  final e = asStr(d['elemento']);
  return e.isEmpty || e == 'Nenhum' ? Cores.destaque : Cores.elemento(e);
}

/// A cor da ameaça mais clara, para texto no fundo escuro (o vermelho do
/// Sangue some no preto).
Color corDeTexto(Color cor) => Color.lerp(cor, Colors.white, 0.32)!;

const _titulosSecao = {
  'Ataque': 'ATAQUES',
  'Padrão': 'AÇÃO PADRÃO',
  'Movimento': 'MOVIMENTO',
  'Completa': 'AÇÃO COMPLETA',
  'Livre': 'AÇÃO LIVRE',
  'Reação': 'REAÇÕES',
  'Passiva': 'PASSIVAS',
  'Enigma': 'ENIGMA DE MEDO',
  'Outra': 'OUTRAS',
};

IconData _icone(AcaoAmeaca a) => switch (a.tipo) {
      'Ataque' => Icons.gps_fixed,
      'Padrão' => Icons.flash_on,
      'Movimento' => Icons.directions_run,
      'Completa' => Icons.hourglass_bottom,
      'Livre' => Icons.bolt,
      'Reação' => Icons.shield_outlined,
      'Passiva' => Icons.all_inclusive,
      'Enigma' => Icons.psychology_alt_outlined,
      _ => Icons.auto_awesome,
    };

/// Ataques e habilidades de uma ameaça, um botão cada, separados pelo tipo
/// de ação. Passando o mouse, o botão mostra o que a ação faz.
class AcoesDaAmeaca extends StatelessWidget {
  final List<AcaoAmeaca> acoes;
  final Color cor;
  final ValueChanged<AcaoAmeaca> aoUsar;
  const AcoesDaAmeaca({super.key, required this.acoes, required this.cor, required this.aoUsar});

  @override
  Widget build(BuildContext context) {
    if (acoes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Esta ameaça não tem ataques nem habilidades anotados.',
            style: TextStyle(color: Cores.textoFraco, fontSize: 13)),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final colunas = c.maxWidth >= 560 ? 2 : 1;
      final largura = (c.maxWidth - 8 * (colunas - 1)) / colunas;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final tipo in tiposAcao)
          if (acoes.where((a) => a.tipo == tipo).toList() case final doTipo when doTipo.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(_titulosSecao[tipo] ?? tipo.toUpperCase(),
                  style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 1.6)),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in doTipo)
                SizedBox(width: largura, child: _BotaoAcao(acao: a, cor: cor, aoTocar: () => aoUsar(a))),
            ]),
          ],
      ]);
    });
  }
}

class _BotaoAcao extends StatelessWidget {
  final AcaoAmeaca acao;
  final Color cor;
  final VoidCallback aoTocar;
  const _BotaoAcao({required this.acao, required this.cor, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final mecanica = acao.mecanica;
    final passiva = acao.passiva;
    return Tooltip(
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: false,
      constraints: const BoxConstraints(maxWidth: 380),
      richMessage: TextSpan(children: [
        TextSpan(text: acao.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        TextSpan(text: '  ${acao.tipo == 'Outra' ? '' : acao.tipo}', style: TextStyle(color: corDeTexto(cor), fontSize: 12.5)),
        if (mecanica.isNotEmpty) TextSpan(text: '\n$mecanica', style: TextStyle(color: corDeTexto(cor), fontSize: 12.5)),
        if (acao.texto.isNotEmpty) TextSpan(text: '\n${acao.texto}', style: const TextStyle(fontSize: 13, height: 1.35)),
      ]),
      child: Material(
        color: cor.withValues(alpha: passiva ? 0.03 : 0.08),
        shape: CorteCantos(corte: 10, cor: cor.withValues(alpha: passiva ? 0.25 : 0.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(_icone(acao), size: 18, color: cor.withValues(alpha: passiva ? 0.6 : 1)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(acao.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    mecanica.isNotEmpty ? mecanica : acao.texto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: mecanica.isNotEmpty
                        ? estiloRotulo(12.5, cor: corDeTexto(cor), peso: FontWeight.w500, espaco: 0.3)
                        : const TextStyle(fontSize: 12, color: Cores.textoFraco, height: 1.3),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- usar uma ação ----------------

/// Uma rolagem feita ao usar a ação.
class Rolado {
  final ParteRolagem parte;
  final int total;
  final String detalhe;
  const Rolado(this.parte, this.total, this.detalhe);
}

/// Um ataque rolado (o teste já leva o dano, para a animação dos dados). O
/// dano sai junto, já com o crítico, e só conta se acertar.
class Golpe {
  final Rolagem teste;
  final List<Rolado> dano;
  const Golpe(this.teste, this.dano);
  int get danoTotal => dano.fold(0, (s, r) => s + r.total);
}

/// O que saiu ao usar uma ação de ameaça, e contra quem.
class UsoAcao {
  final String ameacaId;
  final String ameacaNome;
  final AcaoAmeaca acao;
  final String? alvoId;
  final List<Golpe> golpes;
  final List<Rolado> rolados;
  /// Testes de resistência do alvo, pelo índice em [AcaoAmeaca.resistencias].
  final Map<int, Rolagem> resistidas;
  final bool secreto;
  const UsoAcao({
    required this.ameacaId,
    required this.ameacaNome,
    required this.acao,
    required this.alvoId,
    this.golpes = const [],
    this.rolados = const [],
    this.resistidas = const {},
    required this.secreto,
  });
}

Rolado _rolar(ParteRolagem p, {int mult = 1}) {
  if (p.papel == PapelRolagem.teste) {
    final t = testeDoLivro(p.expressao);
    final r = Dados.rolarTeste(titulo: '', nDados: t.$1, bonus: t.$2);
    return Rolado(p, r.total, r.detalhe);
  }
  final r = Dados.expressao(p.expressao, multDados: mult);
  return Rolado(p, r.total, r.detalhe);
}

/// Resistências que o alvo rola sozinho quando a ação é usada.
const _resistenciasDiretas = {'Fortitude', 'Reflexos', 'Vontade'};

Rolagem _testeDoAlvo(Ficha alvo, Map<String, dynamic> regras, Resistencia r) {
  final c = Calc(alvo, regras);
  return Dados.rolarTeste(
      titulo: '${alvo.nome}: ${r.pericia} (DT ${r.dt})',
      nDados: c.dadosPericia(r.pericia),
      bonus: c.bonusPericia(r.pericia));
}

String _textoRolados(List<Rolado> l) => l.map((r) => '${r.parte.rotulo}: ${r.detalhe} = ${r.total}').join(' · ');

/// Usa a ação: rola os ataques (contra a Defesa do alvo, se houver) ou o
/// que a habilidade pede, e o teste de resistência do alvo. Tudo vai para o
/// registro de rolagens da mesa (o secreto, só o mestre vê). Quem chama
/// mostra os dados do primeiro ataque com [mostrarDadosDoUso].
UsoAcao usarAcao({
  required Campanha camp,
  required String ameacaId,
  required Map<String, dynamic> ameaca,
  required AcaoAmeaca acao,
  Ficha? alvo,
  required bool secreto,
}) {
  final nome = asStr(ameaca['nome']).isEmpty ? 'Ameaça' : asStr(ameaca['nome']);
  final titulo = '$nome: ${acao.nome}${alvo == null ? '' : ' contra ${alvo.nome}'}';
  void registrar(Rolagem r, [String? quem]) =>
      Repo.registrarRolagem(camp.id, r, personagem: quem ?? nome, secreta: secreto);

  if (acao.ataque) {
    final crit = Dados.critico(acao.critico);
    final golpes = <Golpe>[];
    for (var i = 0; i < acao.golpes; i++) {
      final t = Dados.rolarTeste(
          titulo: acao.golpes > 1 ? '$titulo (${i + 1}º ataque)' : titulo,
          nDados: acao.dados,
          bonus: acao.bonus,
          margemCritico: crit.margem);
      final dano = [for (final p in acao.rolagens) _rolar(p, mult: t.critico ? crit.mult : 1)];
      final comDano = Rolagem(
        titulo: t.titulo,
        detalhe: t.detalhe,
        total: t.total,
        critico: t.critico,
        falhaCritica: t.falhaCritica,
        danoTotal: dano.isEmpty ? null : dano.fold<int>(0, (s, r) => s + r.total),
        danoDetalhe: dano.isEmpty ? null : dano.map((r) => r.detalhe).join(' + '),
        dados: t.dados,
        natural: t.natural,
        bonus: t.bonus,
        pegouMenor: t.pegouMenor,
      );
      golpes.add(Golpe(comDano, dano));
      registrar(comDano);
    }
    return UsoAcao(
        ameacaId: ameacaId, ameacaNome: nome, acao: acao, alvoId: alvo?.id, golpes: golpes, secreto: secreto);
  }

  final rolados = acao.direta ? [for (final p in acao.rolagens) _rolar(p)] : <Rolado>[];
  final resistidas = <int, Rolagem>{};
  if (acao.direta && alvo != null && acao.resistencias.length == 1) {
    final r = acao.resistencias.single;
    if (_resistenciasDiretas.contains(r.pericia)) resistidas[0] = _testeDoAlvo(alvo, camp.regras, r);
  }
  if (rolados.isNotEmpty) {
    final dano = rolados.where((r) => r.parte.papel == PapelRolagem.dano).fold(0, (s, r) => s + r.total);
    registrar(Rolagem(
      titulo: titulo,
      detalhe: _textoRolados(rolados),
      total: dano > 0 ? dano : rolados.first.total,
      danoTotal: dano > 0 ? dano : null,
    ));
  }
  for (final t in resistidas.values) {
    registrar(t, alvo!.nome);
  }
  return UsoAcao(
    ameacaId: ameacaId,
    ameacaNome: nome,
    acao: acao,
    alvoId: alvo?.id,
    rolados: rolados,
    resistidas: resistidas,
    secreto: secreto,
  );
}

/// A animação dos dados do primeiro ataque (habilidades não têm).
void mostrarDadosDoUso(BuildContext context, UsoAcao uso) {
  if (uso.golpes.isNotEmpty) mostrarRolagem(context, uso.golpes.first.teste);
}

// ---------------- resultado ----------------

/// O resultado de uma ação: os ataques (acertou ou não contra a Defesa do
/// alvo), as rolagens, o teste de resistência do alvo e o dano final, já
/// com a RD dele, para aplicar com um toque. Ações com várias opções rolam
/// cada parte num botão.
class CartaoUso extends StatefulWidget {
  final UsoAcao uso;
  final Campanha camp;
  /// O alvo como está agora (PV e condições atualizados).
  final Ficha? alvo;
  /// A ameaça como está agora (para curar).
  final Map<String, dynamic>? ameaca;
  final VoidCallback? aoFechar;
  const CartaoUso({super.key, required this.uso, required this.camp, this.alvo, this.ameaca, this.aoFechar});

  @override
  State<CartaoUso> createState() => _CartaoUsoState();
}

class _CartaoUsoState extends State<CartaoUso> {
  late final List<Rolado> _rolados = [...widget.uso.rolados];
  late final Map<int, Rolagem> _resistidas = {...widget.uso.resistidas};
  late String _tipo = widget.uso.acao.tiposDano.firstOrNull ?? '';
  /// A reação de defesa do alvo contra o primeiro ataque: começa com a que
  /// o agente escolheu na ficha, se ainda não usou nesta rodada.
  bool _esquivou = false;
  bool _bloqueou = false;
  /// Metade do dano marcada à mão (ações com mais de um teste de resistência).
  bool _metadeManual = false;
  late final Set<String> _condicoes = {if (_falhou == true) ...widget.uso.acao.condicoes};
  bool _aplicado = false;
  bool _curado = false;

  AcaoAmeaca get _acao => widget.uso.acao;

  @override
  void initState() {
    super.initState();
    final alvo = widget.alvo;
    if (alvo == null || !_acao.ataque || reacaoUsada(widget.camp, alvo)) return;
    final c = Calc(alvo, widget.camp.regras);
    final corpo = _acao.alcance.isEmpty || semAcento(_acao.alcance.toLowerCase()).contains('corpo');
    _esquivou = alvo.reacao == 'esquiva' && c.podeEsquivar;
    _bloqueou = alvo.reacao == 'bloqueio' && c.podeBloquear && corpo;
    if (_esquivou || _bloqueou) _gastarReacao(true);
  }

  /// Marca na ficha do alvo que a reação desta rodada foi usada (ou devolve).
  void _gastarReacao(bool usada) {
    final alvo = widget.alvo;
    if (alvo == null) return;
    final m = marcaReacao(widget.camp, alvo);
    if (m.isNotEmpty) Repo.set(alvo.id, 'reacaoUsada', usada ? m : '');
  }

  /// Uma reação por rodada: esquivar tira o bloqueio, e o contrário.
  void _reagir({required bool esquiva, required bool v}) {
    setState(() {
      _esquivou = esquiva && v;
      _bloqueou = !esquiva && v;
    });
    _gastarReacao(v);
  }

  /// Ataque de um dano só que pode ser de mais de um tipo ("impacto,
  /// perfuração ou Sangue"): o mestre escolhe o tipo (e a RD que vale).
  bool get _alternativas => _acao.ataque && _acao.rolagens.length == 1 && _acao.tiposDano.length > 1;

  /// O alvo passou no teste de resistência (null: ainda não rolou ou há mais de um).
  bool? get _passou {
    if (_resistidas.length != 1 || _acao.resistencias.isEmpty) return null;
    final e = _resistidas.entries.single;
    return e.value.total >= _acao.resistencias[e.key].dt;
  }

  bool? get _falhou => _passou == null ? null : !_passou!;

  void _registrar(Rolagem r, [String? quem]) => Repo.registrarRolagem(widget.camp.id, r,
      personagem: quem ?? widget.uso.ameacaNome, secreta: widget.uso.secreto);

  void _rolarParte(ParteRolagem p) {
    final r = _rolar(p);
    setState(() => _rolados.add(r));
    _registrar(Rolagem(
      titulo: '${widget.uso.ameacaNome}: ${_acao.nome}',
      detalhe: _textoRolados([r]),
      total: r.total,
      danoTotal: p.papel == PapelRolagem.dano ? r.total : null,
    ));
  }

  void _rolarResistencia(int i) {
    final alvo = widget.alvo;
    if (alvo == null) return;
    final t = _testeDoAlvo(alvo, widget.camp.regras, _acao.resistencias[i]);
    setState(() {
      _resistidas[i] = t;
      if (t.total < _acao.resistencias[i].dt) _condicoes.addAll(_acao.condicoes);
    });
    _registrar(t, alvo.nome);
  }

  @override
  Widget build(BuildContext context) {
    final cor = widget.ameaca == null ? Cores.destaque : corDaAmeaca(widget.ameaca!);
    final alvo = widget.alvo;
    final c = alvo == null ? null : Calc(alvo, widget.camp.regras);
    final acao = _acao;

    // dano que o alvo sofre, separado em PV e mental (SAN ou PD)
    var pv = 0, mental = 0;
    final linhas = <Widget>[];
    String rdTexto(int rd) => rd == 0 ? '' : ' · RD $rd';

    if (acao.ataque) {
      for (final (i, g) in widget.uso.golpes.indexed) {
        // a reação vale contra um ataque só: o primeiro
        final defesa = c == null ? null : (_esquivou && i == 0 ? c.defesaEsquiva : c.defesa);
        final bloqueio = c != null && _bloqueou && i == 0 ? c.rdBloqueio : 0;
        final acertou = defesa == null ? null : g.teste.total >= defesa;
        final conta = acertou != false && g.dano.isNotEmpty;
        // cada parte do dano com a RD do seu tipo; o bloqueio vale uma vez
        // por golpe, contra o dano que não é mental
        var golpePv = 0, golpeMental = 0, rdTotal = 0;
        for (final r in g.dano) {
          final tipo = _alternativas ? _tipo : r.parte.tipoDano;
          final rd = c?.rdContra(tipo) ?? 0;
          rdTotal += min(rd, r.total);
          if (tipo == 'mental') {
            golpeMental += danoFinal(r.total, rd);
          } else {
            golpePv += danoFinal(r.total, rd);
          }
        }
        if (golpePv > 0 && bloqueio > 0) {
          rdTotal += min(bloqueio, golpePv);
          golpePv = max(0, golpePv - bloqueio);
        }
        if (conta) {
          pv += golpePv;
          mental += golpeMental;
        }
        linhas.add(LinhaResultado(
          titulo: '${widget.uso.golpes.length > 1 ? '${i + 1}º ataque' : 'Ataque'}: ${g.teste.total}',
          detalhe: g.teste.detalhe,
          resultado: acertou == null
              ? (g.teste.critico ? 'crítico' : null)
              : acertou
                  ? (g.teste.critico ? 'acertou, crítico' : 'acertou')
                  : 'errou (Defesa $defesa${_esquivou && i == 0 ? ', com esquiva' : ''})',
          bom: acertou,
          cor: cor,
        ));
        if (g.dano.isNotEmpty && acertou != false) {
          final partes = [
            for (final r in g.dano)
              '${r.total} ${tipoDanoPorId(_alternativas ? _tipo : r.parte.tipoDano)?.nome.toLowerCase() ?? ''}'.trim(),
          ];
          linhas.add(LinhaResultado(
            titulo: '   dano ${g.danoTotal}${g.dano.length > 1 || partes.single.contains(' ') ? ' (${partes.join(' + ')})' : ''}'
                '${rdTotal == 0 || c == null ? '' : ' · RD $rdTotal · sofre ${golpePv + golpeMental}'}',
            detalhe: g.dano.map((r) => r.detalhe).join(' + '),
            cor: cor,
          ));
        }
      }
    } else {
      final passou = _passou;
      final r = passou == null ? null : _acao.resistencias[_resistidas.keys.single];
      final metade = passou == null ? _metadeManual : (passou && r!.metade);
      final evita = passou == true && r!.evita && !r.metade;
      for (final x in _rolados) {
        final tipo = x.parte.tipoDano;
        if (x.parte.papel == PapelRolagem.dano) {
          final rd = c?.rdContra(tipo) ?? 0;
          final sofrido = evita ? 0 : danoFinal(x.total, rd, metade: metade);
          if (tipo == 'mental') {
            mental += sofrido;
          } else {
            pv += sofrido;
          }
          linhas.add(LinhaResultado(
            titulo: '${x.parte.rotulo}: ${x.total}'
                '${evita ? ' · evitado' : '${metade ? ' · metade ${x.total ~/ 2}' : ''}${rdTexto(rd)}${metade || rd != 0 ? ' · sofre $sofrido' : ''}'}',
            detalhe: x.detalhe,
            cor: cor,
          ));
        } else {
          linhas.add(LinhaResultado(titulo: '${x.parte.rotulo}: ${x.total}', detalhe: x.detalhe, cor: cor));
        }
      }
      for (final e in _resistidas.entries) {
        final res = _acao.resistencias[e.key];
        final ok = e.value.total >= res.dt;
        linhas.add(LinhaResultado(
          titulo: '${alvo?.nome ?? 'Alvo'}: ${res.pericia} ${e.value.total} contra DT ${res.dt}',
          detalhe: e.value.detalhe,
          resultado: ok
              ? (res.metade ? 'passou: metade do dano' : res.evita ? 'passou: evita' : 'passou')
              : 'falhou',
          bom: !ok,
          cor: cor,
        ));
      }
    }

    final cura = _rolados.where((r) => r.parte.papel == PapelRolagem.cura).fold(0, (s, r) => s + r.total);
    final pendentes = [
      for (final p in acao.ataque ? const <ParteRolagem>[] : acao.rolagens)
        if (!acao.direta) p,
    ];
    final semTeste = [
      for (var i = 0; i < acao.resistencias.length; i++)
        if (!_resistidas.containsKey(i)) i,
    ];
    final recursoMental = c?.determinacao == true ? 'PD' : 'SAN';

    return Material(
      color: cor.withValues(alpha: 0.06),
      shape: CorteCantos(corte: 14, cor: cor.withValues(alpha: 0.6)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(_icone(acao), size: 20, color: corDeTexto(cor)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(acao.nome, style: estiloTitulo(17, cor: Cores.texto)),
                Text('${widget.uso.ameacaNome}${alvo == null ? '' : ' contra ${alvo.nome}'}',
                    style: TextStyle(fontSize: 13, color: corDeTexto(cor))),
              ]),
            ),
            if (widget.uso.secreto)
              const Tooltip(
                message: 'Rolagem secreta: só o mestre vê no registro',
                child: Icon(Icons.visibility_off_outlined, size: 17, color: Cores.textoFraco),
              ),
            if (widget.aoFechar != null)
              IconButton(
                tooltip: 'Fechar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: Cores.textoFraco),
                onPressed: widget.aoFechar,
              ),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ...linhas,
              if (_alternativas) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in acao.tiposDano)
                    ChoiceChip(
                      label: Text(tipoDanoPorId(t)?.nome ?? t),
                      selected: _tipo == t,
                      onSelected: (_) => setState(() => _tipo = t),
                    ),
                ]),
              ],
              if (acao.ataque && c != null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (c.podeEsquivar)
                    FilterChip(
                      label: Text('Esquivou${widget.uso.golpes.length > 1 ? ' do 1º' : ''} (Defesa ${c.defesaEsquiva})'),
                      selected: _esquivou,
                      onSelected: (v) => _reagir(esquiva: true, v: v),
                    ),
                  if (c.podeBloquear)
                    FilterChip(
                      label: Text('Bloqueou${widget.uso.golpes.length > 1 ? ' o 1º' : ''} (RD +${c.rdBloqueio})'),
                      selected: _bloqueou,
                      onSelected: (v) => _reagir(esquiva: false, v: v),
                    ),
                  if (!_esquivou && !_bloqueou && alvo != null && reacaoUsada(widget.camp, alvo))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Já usou a reação nesta rodada.',
                          style: TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
                    ),
                ]),
              ],
              if (pendentes.isNotEmpty || (alvo != null && semTeste.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final p in pendentes)
                    ActionChip(
                      avatar: Icon(Icons.casino_outlined, size: 16, color: cor),
                      label: Text('Rolar ${p.rotulo}'),
                      onPressed: () => _rolarParte(p),
                    ),
                  if (alvo != null)
                    for (final i in semTeste)
                      ActionChip(
                        avatar: Icon(Icons.person_outline, size: 16, color: cor),
                        label: Text('${acao.resistencias[i].pericia} DT ${acao.resistencias[i].dt} de ${alvo.nome}'),
                        onPressed: () => _rolarResistencia(i),
                      ),
                ]),
              ],
              if (!acao.ataque && _passou == null && _rolados.any((r) => r.parte.papel == PapelRolagem.dano)) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('Alvo passou: metade do dano'),
                    selected: _metadeManual,
                    onSelected: (v) => setState(() => _metadeManual = v),
                  ),
                ),
              ],
              if (acao.condicoes.isNotEmpty && alvo != null) ...[
                const SizedBox(height: 10),
                Text('CONDIÇÕES NO ALVO', style: estiloRotulo(11.5, cor: Cores.textoFraco, espaco: 1.4)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final cd in acao.condicoes)
                    FilterChip(
                      label: Text(cd),
                      selected: _condicoes.contains(cd),
                      onSelected: _aplicado
                          ? null
                          : (v) => setState(() => v ? _condicoes.add(cd) : _condicoes.remove(cd)),
                    ),
                ]),
              ],
              if (alvo != null && c != null && (pv > 0 || mental > 0 || _condicoes.isNotEmpty)) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Text(
                      [
                        if (pv > 0) '−$pv PV',
                        if (mental > 0) '−$mental $recursoMental',
                        if (_condicoes.isNotEmpty) _condicoes.join(', '),
                      ].join(' · '),
                      style: estiloNumero(17, cor: _aplicado ? Cores.textoFraco : Cores.pv),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _aplicado
                        ? null
                        : () {
                            tirarDano(alvo, c, pv);
                            tirarDano(alvo, c, mental, mental: true);
                            if (_condicoes.isNotEmpty) {
                              Repo.set(alvo.id, 'condicoes', {...alvo.condicoes, ..._condicoes}.toList());
                            }
                            setState(() => _aplicado = true);
                          },
                    icon: Icon(_aplicado ? Icons.check : Icons.south, size: 18),
                    label: Text(_aplicado ? 'Aplicado' : 'Aplicar em ${alvo.nome.split(' ').first}'),
                  ),
                ]),
              ],
              if (cura > 0 && widget.ameaca != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _curado
                        ? null
                        : () {
                            final a = widget.ameaca!;
                            Repo.salvarDoc(Repo.ameacas(widget.camp.id), widget.uso.ameacaId,
                                {'pv': min(asInt(a['pvMax']), asInt(a['pv']) + cura)});
                            setState(() => _curado = true);
                          },
                    icon: const Icon(Icons.healing_outlined, size: 18),
                    label: Text(_curado ? 'Curou $cura PV' : 'Curar ${widget.uso.ameacaNome} (+$cura PV)'),
                  ),
                ),
              ],
              if (acao.texto.isNotEmpty && !acao.ataque) ...[
                const SizedBox(height: 10),
                Text(acao.texto, style: const TextStyle(fontSize: 13, height: 1.4, color: Cores.textoFraco)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Uma linha do resultado (ataque, dano, teste), com os dados ao passar o
/// mouse.
class LinhaResultado extends StatelessWidget {
  final String titulo;
  final String detalhe;
  final String? resultado;
  /// Bom para quem age (acertou, alvo falhou): na cor dela; ruim: apagado.
  final bool? bom;
  final Color cor;
  const LinhaResultado({required this.titulo, required this.detalhe, this.resultado, this.bom, required this.cor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Tooltip(
          message: detalhe,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: titulo, style: estiloNumero(15, cor: Cores.texto, peso: FontWeight.w600)),
            if (resultado != null)
              TextSpan(
                text: '  $resultado',
                style: estiloRotulo(13.5,
                    cor: bom == false ? Cores.textoFraco : corDeTexto(cor), peso: FontWeight.w600, espaco: 0.4),
              ),
          ])),
        ),
      );
}

/// Mostra o resultado de uma ação numa janela (fora do combate, sem alvo).
void mostrarUso(BuildContext context, UsoAcao uso, Campanha camp, Map<String, dynamic> ameaca) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Cores.painel2,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: CartaoUso(uso: uso, camp: camp, ameaca: ameaca, aoFechar: () => Navigator.pop(ctx)),
        ),
      ),
    ),
  );
}
