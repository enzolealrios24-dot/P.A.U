import 'package:flutter/material.dart';

import 'common.dart';

import '../core/theme.dart';
import '../data/catalogo.dart';
import '../data/models.dart';

class FiltroCatalogo {
  final String rotulo;
  final bool Function(Map<String, dynamic>) teste;
  const FiltroCatalogo(this.rotulo, this.teste);
}

/// Janela de busca nos dados dos livros. Devolve a entrada escolhida.
Future<Map<String, dynamic>?> escolherDoLivro(
  BuildContext context, {
  required String titulo,
  required List<Map<String, dynamic>> itens,
  List<FiltroCatalogo> filtros = const [],
  int filtroInicial = 0,
  String Function(Map<String, dynamic>)? meta,
  String Function(Map<String, dynamic>)? detalhes,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _Picker(
      titulo: titulo,
      itens: itens,
      filtros: filtros,
      filtroInicial: filtroInicial,
      meta: meta,
      detalhes: detalhes,
    ),
  );
}

class _Picker extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> itens;
  final List<FiltroCatalogo> filtros;
  final int filtroInicial;
  final String Function(Map<String, dynamic>)? meta;
  final String Function(Map<String, dynamic>)? detalhes;
  const _Picker({
    required this.titulo,
    required this.itens,
    required this.filtros,
    required this.filtroInicial,
    required this.meta,
    required this.detalhes,
  });
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  final _busca = TextEditingController();
  late int _filtro = widget.filtros.isEmpty
      ? -1
      : widget.filtroInicial.clamp(0, widget.filtros.length - 1);
  String? _aberto;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visiveis {
    final q = Catalogo.normalizar(_busca.text);
    return widget.itens.where((e) {
      if (_filtro >= 0 && !widget.filtros[_filtro].teste(e)) return false;
      if (q.isEmpty) return true;
      final alvo = Catalogo.normalizar(
          '${asStr(e['nome'])} ${asStr(e['resumo'])} ${asStr(e['elemento'])} ${asStr(e['fonte'])}');
      return alvo.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final l = _visiveis;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      title: Text(widget.titulo),
      content: SizedBox(
        width: tela.width > 700 ? 620 : tela.width - 40,
        height: tela.height * 0.7,
        child: Column(children: [
          TextField(
            controller: _busca,
            autofocus: false,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Buscar no livro…'),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.filtros.isNotEmpty)
            FaixaRolavel(
              altura: 50,
              quebrarAcima: 520,
              children: [
                  for (var i = 0; i < widget.filtros.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 6),
                      child: ChoiceChip(
                        label: Text(widget.filtros[i].rotulo),
                        selected: _filtro == i,
                        onSelected: (_) => setState(() => _filtro = i),
                      ),
                    ),
              ],
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${l.length} resultado(s) • toque para ver, + para adicionar',
                style: const TextStyle(fontSize: 11, color: Cores.textoFraco)),
          ),
          Expanded(
            child: l.isEmpty
                ? const Center(child: Text('Nada encontrado.'))
                : ListView.builder(
                    itemCount: l.length,
                    itemBuilder: (context, i) {
                      final e = l[i];
                      final ref = asStr(e['ref']);
                      final aberto = _aberto == ref;
                      final meta = widget.meta?.call(e) ?? '';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () =>
                              setState(() => _aberto = aberto ? null : ref),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(asStr(e['nome']),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                          [meta, Catalogo.fonteCurta(e)]
                                              .where((s) => s.isNotEmpty)
                                              .join(' • '),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Cores.textoFraco)),
                                      const SizedBox(height: 2),
                                      Text(
                                        aberto
                                            ? (widget.detalhes?.call(e) ??
                                                asStr(e['resumo']))
                                            : asStr(e['resumo']),
                                        maxLines: aberto ? null : 2,
                                        overflow: aberto
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Adicionar',
                                  icon: Icon(Icons.add_circle,
                                      color: Cores.destaque),
                                  onPressed: () => Navigator.pop(context, e),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar')),
      ],
    );
  }
}

/// Texto completo de um ritual do catalogo (para detalhes e descricao).
String textoRitual(Map<String, dynamic> r) {
  final b = StringBuffer(asStr(r['resumo']));
  void linha(String rotulo, dynamic v) {
    final s = asStr(v);
    if (s.isNotEmpty) b.write('\n$rotulo: $s');
  }

  linha('Requisito', r['requisito']);
  if (r['custoDiscente'] != null) {
    b.write('\nDiscente (+${asInt(r['custoDiscente'])} PE): ${asStr(r['discente'])}');
  }
  if (r['custoVerdadeiro'] != null) {
    b.write(
        '\nVerdadeiro (+${asInt(r['custoVerdadeiro'])} PE): ${asStr(r['verdadeiro'])}');
  }
  return b.toString();
}

String metaRitual(Map<String, dynamic> r) =>
    '${asStr(r['elemento'])} ${asInt(r['circulo'], 1)}º • ${asStr(r['execucao'])} • ${asStr(r['alcance'])}';

String detalhesRitual(Map<String, dynamic> r) {
  final cab = [
    'Alvo/área: ${asStr(r['alvo'])}',
    'Duração: ${asStr(r['duracao'])}',
    if (asStr(r['resistencia']).isNotEmpty) 'Resistência: ${asStr(r['resistencia'])}',
  ].join(' • ');
  return '$cab\n\n${textoRitual(r)}';
}

String metaPoder(Map<String, dynamic> p) {
  final tipo = asStr(p['tipo']);
  final partes = [
    tipo.isEmpty ? '' : '${tipo[0].toUpperCase()}${tipo.substring(1)}',
    asStr(p['elemento']),
    if (asStr(p['prereq']).isNotEmpty) 'Req.: ${asStr(p['prereq'])}',
  ];
  return partes.where((s) => s.isNotEmpty).join(' • ');
}

String detalhesPoder(Map<String, dynamic> p) {
  final b = StringBuffer(asStr(p['resumo']));
  if (asStr(p['afinidade']).isNotEmpty) {
    b.write('\nAfinidade: ${asStr(p['afinidade'])}');
  }
  return b.toString();
}

String metaItem(Map<String, dynamic> i) {
  const cats = ['0', 'I', 'II', 'III', 'IV', 'V', 'VI'];
  final cat = asInt(i['categoria']);
  final partes = <String>[
    if (i['categoria'] != null) 'Cat. ${cats[cat.clamp(0, 6)]}',
    if (i['espacos'] is num) '${_espacos(i['espacos'] as num)} esp.',
    if (asStr(i['dano']).isNotEmpty && asStr(i['tipo']) == 'arma')
      '${asStr(i['dano'])} ${asStr(i['critico'])}',
    if (asStr(i['alcance']).isNotEmpty) asStr(i['alcance']),
    if (i['defesa'] != null) 'Defesa +${asInt(i['defesa'])}',
    if (asStr(i['elemento']).isNotEmpty) asStr(i['elemento']),
  ];
  return partes.join(' • ');
}

/// 0.5 vira "0,5"; inteiros ficam sem casa decimal.
String _espacos(num v) => v % 1 == 0 ? '${v.toInt()}' : '$v'.replaceAll('.', ',');
