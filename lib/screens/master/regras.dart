import 'package:flutter/material.dart';

import '../../core/regras_combate.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import '../sheet/tab_listas.dart';

/// Regras caseiras por campanha + biblioteca homebrew.
class AbaRegras extends StatelessWidget {
  final Campanha camp;
  const AbaRegras({super.key, required this.camp});

  @override
  Widget build(BuildContext context) {
    final r = camp.regras;
    final classesOver = asMap(r['classes']);
    final custo = asMap(r['custoRitual']);
    void set(String campo, dynamic v) =>
        Repo.setCamp(camp.id, {'regras.$campo': v});

    return ListView(padding: const EdgeInsets.all(12), children: [
      Secao(
        titulo: 'Regras opcionais',
        child: Column(children: [
          Seletor(
            rotulo: 'Progressão dos personagens',
            valor: modosProgressao[asStr(r['progressao'], 'nex')] ??
                modosProgressao['nex']!,
            opcoes: modosProgressao.values.toList(),
            aoMudar: (v) => set(
                'progressao',
                modosProgressao.entries.firstWhere((e) => e.value == v).key),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
                'Somente NEX: regra padrão. Nível + NEX: o nível controla a classe e o NEX só sobe por exposição (Sobrevivendo ao Horror). Patentes: evolui pelos pontos de prestígio e sempre usa PD.',
                style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Jogar sem sanidade (Determinação)'),
            subtitle: const Text(
                'Junta PE e Sanidade em Pontos de Determinação (PD), do Sobrevivendo ao Horror. Vale para todas as fichas da mesa.'),
            value: asBool(r['determinacao']) || asStr(r['progressao']) == 'patente',
            onChanged: asStr(r['progressao']) == 'patente'
                ? null
                : (v) => set('determinacao', v),
          ),
          const Divider(),
          Row(children: [
            Expanded(
              child: CampoNumero(
                  valor: asInt(r['cargaBase'], 0),
                  rotulo: 'Carga: base',
                  aoSalvar: (v) => set('cargaBase', v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CampoNumero(
                  valor: asInt(r['cargaPorFor'], 5),
                  rotulo: 'Carga: espaços por FOR',
                  aoSalvar: (v) => set('cargaPorFor', v)),
            ),
          ]),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
                'Livro: 5 por FOR (base 0). Variantes comuns: base 5 ou base 10.',
                style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
          ),
          const Divider(),
          Row(children: [
            for (var c = 1; c <= 4; c++) ...[
              if (c > 1) const SizedBox(width: 8),
              Expanded(
                child: CampoNumero(
                    valor: asInt(custo['$c'], custoRitualPadrao[c]!),
                    rotulo: 'PE ${c}º círc.',
                    aoSalvar: (v) => set('custoRitual.$c', v)),
              ),
            ],
          ]),
        ]),
      ),
      Secao(
        titulo: 'Valores das classes',
        acoes: [
          TextButton(
            onPressed: () async {
              if (await confirmar(
                  context, 'Voltar todos os valores de classe ao padrão do livro?')) {
                Repo.setCamp(camp.id, {'regras.classes': <String, dynamic>{}});
              }
            },
            child: const Text('Restaurar padrão'),
          ),
        ],
        child: Column(children: [
          for (final cl in nomesClasses())
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(cl, style: const TextStyle(fontWeight: FontWeight.bold)),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in const {
                    'pvIni': 'PV inicial (+VIG)',
                    'pvNex': 'PV por NEX (+VIG)',
                    'peIni': 'PE inicial (+PRE)',
                    'peNex': 'PE por NEX (+PRE)',
                    'sanIni': 'SAN inicial',
                    'sanNex': 'SAN por NEX',
                    'pdIni': 'PD inicial (+PRE)',
                    'pdNex': 'PD por NEX (+PRE)',
                    'pericias': 'Perícias (+INT)',
                  }.entries)
                    SizedBox(
                      width: 140,
                      child: CampoNumero(
                        valor: asInt(asMap(classesOver[cl])[e.key],
                            valoresClasse(cl)[e.key] ?? 0),
                        rotulo: e.value,
                        aoSalvar: (v) => set('classes.$cl.${e.key}', v),
                      ),
                    ),
                ]),
              ],
            ),
        ]),
      ),
      _Biblioteca(camp: camp),
      const _ConsultaLivros(),
    ]);
  }
}

class _Biblioteca extends StatelessWidget {
  final Campanha camp;
  const _Biblioteca({required this.camp});

  static const _tipos = {
    'item': ('Itens', camposItem, itemPadrao),
    'ritual': ('Rituais', camposRitual, ritualPadrao),
    'poder': ('Poderes', camposPoder, poderPadrao),
  };

  Future<void> _editar(BuildContext context, String tipo,
      [String? id, Map<String, dynamic>? atual]) async {
    final def = _tipos[tipo]!;
    final r = await editarFormulario(context,
        titulo: id == null ? 'Novo (${def.$1})' : 'Editar',
        inicial: atual ?? Map<String, dynamic>.from(def.$3),
        campos: def.$2,
        podeApagar: id != null);
    if (r == null) return;
    final col = Repo.homebrew(camp.id);
    if (r.apagar && id != null) {
      Repo.apagarDoc(col, id);
    } else if (r.dados != null) {
      Repo.salvarDoc(col, id, {...r.dados!, 'tipoBiblio': tipo});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Secao(
      titulo: 'Biblioteca homebrew da mesa',
      child: StreamBuilder<List<(String, Map<String, dynamic>)>>(
        stream: Repo.stream(Repo.homebrew(camp.id)),
        builder: (context, snap) {
          final l = snap.data ?? const [];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'Crie itens, rituais e poderes próprios. Os jogadores adicionam na ficha pelo botão "Da biblioteca da mesa".',
                    style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
                for (final t in _tipos.entries) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: Text(t.value.$1,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    TextButton.icon(
                      onPressed: () => _editar(context, t.key),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar'),
                    ),
                  ]),
                  for (final e
                      in l.where((e) => asStr(e.$2['tipoBiblio']) == t.key))
                    ListTile(
                      dense: true,
                      title: Text(asStr(e.$2['nome'], '(sem nome)')),
                      subtitle: asStr(e.$2['descricao']).isEmpty
                          ? null
                          : Text(asStr(e.$2['descricao']),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _editar(context, t.key, e.$1, e.$2),
                    ),
                ],
              ]);
        },
      ),
    );
  }
}

/// "efeitosMedo" -> "Efeitos medo".
String _tituloRegra(String chave) {
  final t = chave.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// Texto legível de uma regra dos livros, qualquer que seja o formato.
String _textoRegra(dynamic v, [String recuo = '']) {
  if (v is Map) {
    final linhas = <String>[
      if (v['resumo'] != null) '$recuo${asStr(v['resumo'])}',
    ];
    for (final e in v.entries) {
      if (const {'resumo', 'pag', 'id', 'nome', 'fonte'}.contains(e.key)) continue;
      if (e.value is Map || e.value is List) {
        linhas.add('$recuo${_tituloRegra(asStr(e.key))}:');
        linhas.add(_textoRegra(e.value, '$recuo  '));
      } else {
        linhas.add('$recuo${_tituloRegra(asStr(e.key))}: ${asStr(e.value)}');
      }
    }
    return linhas.join('\n');
  }
  if (v is List) {
    return [
      for (final x in v)
        if (x is Map)
          '$recuo• ${asStr(x['nome']).isEmpty ? '' : '${asStr(x['nome'])}: '}${_textoRegra(x, '$recuo  ').trim()}'
        else
          '$recuo• ${asStr(x)}',
    ].join('\n');
  }
  return '$recuo${asStr(v)}';
}

/// As principais regras de combate do livro básico, por assunto.
class _RegrasCombate extends StatelessWidget {
  const _RegrasCombate();

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Icon(Icons.flash_on_outlined, color: Cores.destaque),
        title: const Text('Regras de combate', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Resumo do livro básico: ações, ataque, reações, manobras, dano e morte',
            style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
        children: [
          for (final t in regrasCombate)
            ExpansionTile(
              tilePadding: const EdgeInsets.only(left: 12),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 8, 12),
              expandedAlignment: Alignment.centerLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(t.titulo),
              subtitle: Text(t.paginas, style: const TextStyle(fontSize: 11)),
              children: [
                for (final (nome, texto) in t.itens)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableText.rich(TextSpan(children: [
                      TextSpan(text: '$nome. ', style: TextStyle(fontWeight: FontWeight.w700, color: Cores.destaque)),
                      TextSpan(text: texto),
                    ]), style: const TextStyle(fontSize: 13.5, height: 1.4)),
                  ),
              ],
            ),
        ],
      );
}

/// Regras, tabelas, doenças e perigos dos livros, só para consulta.
class _ConsultaLivros extends StatelessWidget {
  const _ConsultaLivros();

  @override
  Widget build(BuildContext context) {
    final regras = Catalogo.instance.regras;
    final fontes = regras.keys.toList()
      ..sort((a, b) {
        int peso(String f) => f == 'oprpg' ? 0 : (f == 'sah' ? 1 : 2);
        final p = peso(a).compareTo(peso(b));
        return p != 0 ? p : a.compareTo(b);
      });
    return Secao(
      titulo: 'Consulta dos livros',
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
              'Resumos das regras, tabelas, doenças, venenos e perigos de cada livro, com a página para conferir.',
              style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
        ),
        const _RegrasCombate(),
        for (final f in fontes)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
                Catalogo.nomesFontes[asStr(regras[f]!['fonte'])] ??
                    asStr(regras[f]!['fonte'], f),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [
              for (final e in regras[f]!.entries)
                if (e.key != 'fonte')
                  ExpansionTile(
                    tilePadding: const EdgeInsets.only(left: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 8, 12),
                    title: Text(e.value is Map && asStr(e.value['nome']).isNotEmpty
                        ? asStr(e.value['nome'])
                        : _tituloRegra(e.key)),
                    subtitle: e.value is Map && e.value['pag'] != null
                        ? Text('p. ${asStr(e.value['pag'])}',
                            style: const TextStyle(fontSize: 11))
                        : null,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(_textoRegra(e.value),
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
            ],
          ),
      ]),
    );
  }
}
