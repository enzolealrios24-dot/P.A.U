import 'package:flutter/material.dart';

import '../../core/acoes_ameaca.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/catalogo_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import 'acao_ameaca.dart';
import 'combate.dart';

const camposAmeaca = [
  CampoDef('nome', 'Nome'),
  CampoDef('vd', 'VD', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('elemento', 'Elemento',
      tipo: TipoCampo.opcoes,
      opcoes: ['Nenhum', ...elementos],
      meiaLargura: true),
  CampoDef('pvMax', 'PV máximo', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('pv', 'PV atual', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('defesa', 'Defesa', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('deslocamento', 'Deslocamento', meiaLargura: true),
  CampoDef('iniciativaDados', 'Iniciativa: d20s',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('iniciativaBonus', 'Iniciativa: bônus',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('ataqueNome', 'Ataque: nome', meiaLargura: true),
  CampoDef('ataqueAlcance', 'Ataque: alcance', dica: 'Corpo a corpo x2', meiaLargura: true),
  CampoDef('ataqueDano', 'Ataque: dano', dica: '2d6+3', meiaLargura: true),
  CampoDef('ataqueDados', 'Ataque: d20s',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('ataqueBonus', 'Ataque: bônus',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('ataqueCritico', 'Ataque: crítico',
      dica: '19/x2', meiaLargura: true),
  CampoDef('presencaPerturbadora', 'Presença perturbadora',
      dica: 'DT / dano mental', meiaLargura: true),
  CampoDef('resistencias', 'Resistências e vulnerabilidades'),
  CampoDef('pericias', 'Perícias', dica: 'Percepção +10, Furtividade +5...'),
  CampoDef('habilidades', 'Habilidades / ações', tipo: TipoCampo.multi),
  CampoDef('notas', 'Notas do mestre', tipo: TipoCampo.multi),
];

const ameacaPadrao = {
  'nome': '',
  'vd': 20,
  'elemento': 'Nenhum',
  'pvMax': 30,
  'pv': 30,
  'defesa': 15,
  'iniciativaDados': 2,
  'iniciativaBonus': 5,
  'ataqueDados': 2,
  'ataqueBonus': 10,
  'ataqueDano': '2d6',
  'ataqueCritico': '20/x2',
};

String _textoAtaque(Map<String, dynamic> a) {
  final crit = asStr(a['critico']);
  return '${asStr(a['nome'])} (${asStr(a['alcance'])}): ${asStr(a['teste'])}${crit.isEmpty ? '' : ', crítico $crit'} • ${asStr(a['dano'])}';
}

/// Testes, perícias e atributos de uma ficha do livro, em texto.
String _testesDoLivro(Map<String, dynamic> a) {
  final at = asMap(a['atributos']);
  return [
    if (at.isNotEmpty)
      'AGI ${asStr(at['agi'])} • FOR ${asStr(at['for'])} • INT ${asStr(at['int'])} • PRE ${asStr(at['pre'])} • VIG ${asStr(at['vig'])}',
    'Percepção ${asStr(a['percepcao'])}${asStr(a['sentidos']).isEmpty ? '' : ' (${asStr(a['sentidos'])})'} • Fortitude ${asStr(a['fortitude'])} • Reflexos ${asStr(a['reflexos'])} • Vontade ${asStr(a['vontade'])}',
    if (asStr(a['pericias']).isNotEmpty) asStr(a['pericias']),
  ].join('\n');
}

/// Ataques extras, habilidades e enigma de uma ficha do livro, em texto.
String _habilidadesDoLivro(Map<String, dynamic> a, {bool todosAtaques = false}) {
  final ataques = asMapList(a['ataques']);
  return [
    for (final at in todosAtaques ? ataques : ataques.skip(1))
      'Ataque: ${_textoAtaque(at)}',
    for (final h in asMapList(a['habilidades']))
      '${asStr(h['acao'])} — ${asStr(h['nome'])}: ${asStr(h['resumo'])}',
    if (asStr(a['enigma']).isNotEmpty) 'Enigma de Medo: ${asStr(a['enigma'])}',
  ].join('\n');
}

/// Converte uma ficha de ameaça do livro para os campos da mesa.
Map<String, dynamic> ameacaDoLivro(Map<String, dynamic> a) {
  final ini = testeDoLivro(a['iniciativa']);
  final ataques = asMapList(a['ataques']);
  final atk = ataques.isEmpty ? <String, dynamic>{} : ataques.first;
  final tes = testeDoLivro(atk['teste']);
  final pv = asInt(a['pv']);
  return {
    'nome': asStr(a['nome']),
    'vd': asInt(a['vd']),
    'elemento': asStr(a['elemento'], 'Nenhum'),
    'pvMax': pv,
    'pv': pv,
    'defesa': asInt(a['defesa']),
    'deslocamento': asStr(a['deslocamento']),
    'iniciativaDados': ini.$1,
    'iniciativaBonus': ini.$2,
    if (atk.isNotEmpty) ...{
      'ataqueNome': asStr(atk['nome']),
      'ataqueAlcance': asStr(atk['alcance']),
      'ataqueDano': asStr(atk['dano']),
      'ataqueDados': tes.$1,
      'ataqueBonus': tes.$2,
      'ataqueCritico': asStr(atk['critico'], '20/x2'),
    },
    'presencaPerturbadora': asStr(a['presencaPerturbadora']),
    'resistencias': [
      if (asStr(a['resistencias']).isNotEmpty) 'Resistências: ${asStr(a['resistencias'])}',
      if (asStr(a['imunidades']).isNotEmpty) 'Imunidades: ${asStr(a['imunidades'])}',
      if (asStr(a['vulnerabilidades']).isNotEmpty) 'Vulnerabilidades: ${asStr(a['vulnerabilidades'])}',
    ].join(' • '),
    'pericias': _testesDoLivro(a),
    'habilidades': _habilidadesDoLivro(a),
    'notas': [
      '${asStr(a['tipo'])} • ${Catalogo.fonteCurta(a)}',
      if (asStrList(a['elementosSecundarios']).isNotEmpty)
        'Também: ${asStrList(a['elementosSecundarios']).join(', ')}',
      if (asStr(a['nota']).isNotEmpty) asStr(a['nota']),
    ].join('\n'),
    'ref': asStr(a['ref']),
  };
}

bool _daRealidade(Map<String, dynamic> a) =>
    asStr(a['elemento'], 'Nenhum') == 'Nenhum';

class AbaAmeacas extends StatelessWidget {
  final Campanha camp;
  const AbaAmeacas({super.key, required this.camp});

  Future<void> _doLivro(BuildContext context) async {
    final lista = [
      for (final a in Catalogo.instance.ameacas)
        {
          ...a,
          'resumo':
              'PV ${asInt(a['pv'])} • Defesa ${asStr(a['defesa'])}${asMapList(a['ataques']).isEmpty ? '' : ' • ${_textoAtaque(asMapList(a['ataques']).first)}'}',
        }
    ]..sort((x, y) => asInt(x['vd']).compareTo(asInt(y['vd'])));
    final e = await escolherDoLivro(
      context,
      titulo: 'Ameaças dos livros',
      itens: lista,
      filtros: [
        FiltroCatalogo('Todas', (_) => true),
        for (final el in elementos)
          FiltroCatalogo(el, (a) =>
              asStr(a['elemento']) == el ||
              asStrList(a['elementosSecundarios']).contains(el)),
        FiltroCatalogo('Realidade', _daRealidade),
      ],
      meta: (a) => [
        'VD ${asInt(a['vd'])}',
        asStr(a['elemento'], 'Nenhum') == 'Nenhum' ? '' : asStr(a['elemento']),
        asStr(a['tipo']),
      ].where((s) => s.isNotEmpty).join(' • '),
      detalhes: (a) => [
        'PV ${asInt(a['pv'])} • Defesa ${asStr(a['defesa'])} • Iniciativa ${asStr(a['iniciativa'])} • ${asStr(a['deslocamento'])}',
        if (asStr(a['presencaPerturbadora']).isNotEmpty)
          'Presença perturbadora: ${asStr(a['presencaPerturbadora'])}',
        _testesDoLivro(a),
        ameacaDoLivro(a)['resistencias'] as String,
        _habilidadesDoLivro(a, todosAtaques: true),
      ].where((s) => s.isNotEmpty).join('\n'),
    );
    if (e == null) return;
    final base = Catalogo.instance.porRef(asStr(e['ref'])) ?? e;
    Repo.salvarDoc(Repo.ameacas(camp.id), null, ameacaDoLivro(base));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${asStr(e['nome'])} entrou nas ameaças.')));
    }
  }

  Future<void> _editar(BuildContext context,
      [String? id, Map<String, dynamic>? atual]) async {
    final r = await editarFormulario(context,
        titulo: id == null ? 'Nova ameaça' : 'Editar ameaça',
        inicial: atual ?? Map<String, dynamic>.from(ameacaPadrao),
        campos: camposAmeaca,
        podeApagar: id != null);
    if (r == null) return;
    final col = Repo.ameacas(camp.id);
    if (r.apagar && id != null) {
      Repo.apagarDoc(col, id);
    } else if (r.dados != null) {
      Repo.salvarDoc(col, id, r.dados!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<(String, Map<String, dynamic>)>>(
      stream: Repo.stream(Repo.ameacas(camp.id)),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final l = snap.data!;
        final largura = MediaQuery.sizeOf(context).width;
        final w = largura < 720 ? largura - 24 : 360.0;
        return ListView(padding: const EdgeInsets.all(12), children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _editar(context),
                icon: const Icon(Icons.add),
                label: const Text('Nova ameaça'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _doLivro(context),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Do livro'),
              ),
              const Text('Só o mestre vê esta aba.',
                  style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final a in l)
              SizedBox(
                width: w,
                child: _CartaoAmeaca(
                  camp: camp,
                  id: a.$1,
                  d: a.$2,
                  aoEditar: () => _editar(context, a.$1, a.$2),
                ),
              ),
          ]),
        ]);
      },
    );
  }
}

class _CartaoAmeaca extends StatelessWidget {
  final Campanha camp;
  final String id;
  final Map<String, dynamic> d;
  final VoidCallback aoEditar;
  const _CartaoAmeaca(
      {required this.camp,
      required this.id,
      required this.d,
      required this.aoEditar});

  /// Usa a ação fora do combate (sem alvo): a rolagem é secreta e o
  /// resultado abre numa janela, com os dados por cima.
  void _usar(BuildContext context, AcaoAmeaca a) {
    final uso = usarAcao(camp: camp, ameacaId: id, ameaca: d, acao: a, secreto: true);
    mostrarUso(context, uso, camp, d);
    mostrarDadosDoUso(context, uso);
  }

  @override
  Widget build(BuildContext context) {
    final cor = Cores.elemento(asStr(d['elemento']));
    final elem = asStr(d['elemento']);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
            color: elem.isEmpty || elem == 'Nenhum' ? Cores.borda : cor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asStr(d['nome'], 'Ameaça'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(
                      'VD ${asInt(d['vd'])} • ${elem.isEmpty ? 'Nenhum' : elem} • Defesa ${asInt(d['defesa'])}${asStr(d['deslocamento']).isNotEmpty ? ' • ${asStr(d['deslocamento'])}' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Cores.textoFraco)),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                tooltip: 'Duplicar',
                onPressed: () => Repo.salvarDoc(Repo.ameacas(camp.id), null, {
                      ...d,
                      'nome': '${asStr(d['nome'])} 2',
                      'pv': asInt(d['pvMax']),
                      'condicoes': <String>[],
                    })),
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: aoEditar),
          ]),
          const SizedBox(height: 6),
          BarraStatus(
            rotulo: 'PV',
            atual: asInt(d['pv']),
            max: asInt(d['pvMax']),
            cor: Cores.pv,
            aoMudar: (v) =>
                Repo.salvarDoc(Repo.ameacas(camp.id), id, {'pv': v}),
          ),
          for (final k in const [
            'presencaPerturbadora',
            'resistencias',
            'pericias',
          ])
            if (asStr(d[k]).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(asStr(d[k]), style: const TextStyle(fontSize: 13)),
              ),
          AcoesDaAmeaca(acoes: acoesDaAmeaca(d), cor: corDaAmeaca(d), aoUsar: (a) => _usar(context, a)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final cd in asStrList(d['condicoes']))
              Chip(
                  label: Text(cd, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact),
            ActionChip(
              label: const Text('Condições', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              onPressed: () => editarCondicoesAmeaca(context, camp, id, d),
            ),
          ]),
        ]),
      ),
    );
  }
}
