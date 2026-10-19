import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Determinação (Sobrevivendo ao Horror)'),
            subtitle: const Text(
                'Junta PE e Sanidade em Pontos de Determinação (PD). Ajuste os valores de PD de cada classe abaixo conforme o livro.'),
            value: asBool(r['determinacao']),
            onChanged: (v) => set('determinacao', v),
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
          for (final cl in classes)
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
                            classesPadrao[cl]![e.key]!),
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
