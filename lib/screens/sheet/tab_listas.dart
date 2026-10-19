import 'package:flutter/material.dart';

import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import 'rolar.dart';

// ---------------- definicoes de formularios (reaproveitadas pelo mestre) ----

const camposItem = [
  CampoDef('nome', 'Nome'),
  CampoDef('tipo', 'Tipo',
      tipo: TipoCampo.opcoes,
      opcoes: ['geral', 'arma', 'protecao'],
      meiaLargura: true),
  CampoDef('categoria', 'Categoria (0 a 4)',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('espacos', 'Espaços', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('qtd', 'Quantidade', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('dano', 'Dano (arma)', dica: 'ex.: 1d8 ou 2d6+2', meiaLargura: true),
  CampoDef('critico', 'Crítico (arma)', dica: 'ex.: 19/x3', meiaLargura: true),
  CampoDef('pericia', 'Perícia de ataque',
      tipo: TipoCampo.opcoes, opcoes: ['Luta', 'Pontaria'], meiaLargura: true),
  CampoDef('alcance', 'Alcance', meiaLargura: true),
  CampoDef('bonusAtaque', 'Bônus de ataque',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('bonusDano', 'Bônus de dano',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('defesa', 'Defesa (proteção)',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('equipado', 'Equipado', tipo: TipoCampo.booleano, meiaLargura: true),
  CampoDef('descricao', 'Descrição / anotações', tipo: TipoCampo.multi),
];

const itemPadrao = {
  'nome': '',
  'tipo': 'geral',
  'categoria': 0,
  'espacos': 1,
  'qtd': 1,
  'pericia': 'Luta',
  'critico': '20/x2',
  'equipado': true,
};

const camposRitual = [
  CampoDef('nome', 'Nome'),
  CampoDef('elemento', 'Elemento',
      tipo: TipoCampo.opcoes, opcoes: elementos, meiaLargura: true),
  CampoDef('circulo', 'Círculo (1 a 4)',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('custo', 'Custo PE (0 = padrão)',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('execucao', 'Execução', meiaLargura: true),
  CampoDef('alcance', 'Alcance', meiaLargura: true),
  CampoDef('alvo', 'Alvo/Área', meiaLargura: true),
  CampoDef('duracao', 'Duração', meiaLargura: true),
  CampoDef('resistencia', 'Resistência', meiaLargura: true),
  CampoDef('dano', 'Dano/cura padrão', dica: 'ex.: 3d6', meiaLargura: true),
  CampoDef('custoDiscente', 'Discente: +PE',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('danoDiscente', 'Discente: dano', meiaLargura: true),
  CampoDef('custoVerdadeiro', 'Verdadeiro: +PE',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('danoVerdadeiro', 'Verdadeiro: dano', meiaLargura: true),
  CampoDef('descricao', 'Efeito (suas anotações)', tipo: TipoCampo.multi),
];

const ritualPadrao = {'nome': '', 'elemento': 'Sangue', 'circulo': 1};

const camposPoder = [
  CampoDef('nome', 'Nome'),
  CampoDef('tipo', 'Tipo',
      tipo: TipoCampo.opcoes,
      opcoes: ['Classe', 'Trilha', 'Origem', 'Paranormal', 'Geral', 'Homebrew']),
  CampoDef('descricao', 'Descrição / efeito', tipo: TipoCampo.multi),
];

const poderPadrao = {'nome': '', 'tipo': 'Classe'};

// ---------------- helpers de lista ----------------

void _salvarLista(CtxFicha ctx, String campo, List<Map<String, dynamic>> l) =>
    Repo.set(ctx.f.id, campo, l);

Future<void> _editarNaLista(
  BuildContext context,
  CtxFicha ctx, {
  required String campo,
  required String titulo,
  required List<CampoDef> campos,
  required Map<String, dynamic> padrao,
  int? indice,
}) async {
  final lista = asMapList(ctx.f.d[campo]);
  final inicial = indice == null
      ? Map<String, dynamic>.from(padrao)
      : lista[indice];
  final r = await editarFormulario(context,
      titulo: titulo,
      inicial: inicial,
      campos: campos,
      podeApagar: indice != null);
  if (r == null) return;
  if (r.apagar && indice != null) {
    lista.removeAt(indice);
  } else if (r.dados != null) {
    if (indice == null) {
      lista.add({...r.dados!, 'id': novoId()});
    } else {
      lista[indice] = r.dados!;
    }
  } else {
    return;
  }
  _salvarLista(ctx, campo, lista);
}

/// Escolhe algo da biblioteca homebrew da mesa.
Future<Map<String, dynamic>?> escolherDaBiblioteca(
    BuildContext context, String cid, String tipo) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Biblioteca da mesa'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: StreamBuilder<List<(String, Map<String, dynamic>)>>(
          stream: Repo.stream(Repo.homebrew(cid)),
          builder: (ctx, s) {
            if (s.hasError) return Text('${s.error}');
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final l = s.data!.where((e) => asStr(e.$2['tipoBiblio']) == tipo);
            if (l.isEmpty) {
              return const Center(
                  child: Text('O mestre ainda não cadastrou nada aqui.'));
            }
            return ListView(children: [
              for (final e in l)
                ListTile(
                  title: Text(asStr(e.$2['nome'])),
                  subtitle: Text(asStr(e.$2['descricao']),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, e.$2),
                ),
            ]);
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))
      ],
    ),
  );
}

Widget _botoesAdicionar(BuildContext context, CtxFicha ctx,
    {required String campo,
    required String titulo,
    required List<CampoDef> campos,
    required Map<String, dynamic> padrao,
    required String tipoBiblio}) {
  final camp = ctx.camp;
  return Wrap(spacing: 8, runSpacing: 8, children: [
    FilledButton.icon(
      onPressed: () => _editarNaLista(context, ctx,
          campo: campo, titulo: titulo, campos: campos, padrao: padrao),
      icon: const Icon(Icons.add),
      label: Text('Adicionar'),
    ),
    if (camp != null)
      OutlinedButton.icon(
        onPressed: () async {
          final m = await escolherDaBiblioteca(context, camp.id, tipoBiblio);
          if (m == null) return;
          final copia = Map<String, dynamic>.from(m)..remove('tipoBiblio');
          final lista = asMapList(ctx.f.d[campo])
            ..add({...copia, 'id': novoId()});
          _salvarLista(ctx, campo, lista);
        },
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Da biblioteca da mesa'),
      ),
  ]);
}

// ---------------- COMBATE ----------------

class TabCombate extends StatefulWidget {
  final CtxFicha ctx;
  const TabCombate({super.key, required this.ctx});
  @override
  State<TabCombate> createState() => _TabCombateState();
}

class _TabCombateState extends State<TabCombate> {
  final _expr = TextEditingController(text: '1d20');

  @override
  void dispose() {
    _expr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final c = ctx.calc;
    final inv = ctx.f.inventario;
    final armas = <int>[
      for (var i = 0; i < inv.length; i++)
        if (asStr(inv[i]['tipo']) == 'arma') i
    ];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Secao(
        titulo: 'Defesa e testes rápidos',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              'Defesa ${c.defesa}   •   Deslocamento ${c.deslocamento} m${c.sobrecarregado ? '   •   SOBRECARREGADO' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in const [
              'Iniciativa',
              'Fortitude',
              'Reflexos',
              'Vontade',
              'Luta',
              'Pontaria',
              'Percepção',
            ])
              ActionChip(
                avatar: const Icon(Icons.casino_outlined, size: 16),
                label: Text(
                    '$p ${c.bonusPericia(p) >= 0 ? '+' : ''}${c.bonusPericia(p)}'),
                onPressed: () => ctx.rolarPericia(context, p),
              ),
          ]),
        ]),
      ),
      Secao(
        titulo: 'Ataques',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (armas.isEmpty)
            const Text(
                'Nenhuma arma. Adicione itens do tipo "arma" no inventário.',
                style: TextStyle(color: Cores.textoFraco)),
          for (final i in armas)
            Card(
              color: Cores.painel2,
              child: ListTile(
                title: Text(asStr(inv[i]['nome'], 'Arma'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${asStr(inv[i]['pericia'], 'Luta')} • dano ${asStr(inv[i]['dano'], '-')} • crítico ${asStr(inv[i]['critico'], '20/x2')}${asStr(inv[i]['alcance']).isNotEmpty ? ' • ${asStr(inv[i]['alcance'])}' : ''}'),
                trailing: FilledButton(
                  onPressed: () => ctx.rolarAtaque(context, inv[i]),
                  onLongPress: () async {
                    final m = await pedirModificadores(context);
                    if (m != null && context.mounted) {
                      ctx.rolarAtaque(context, inv[i],
                          dadosExtra: m.dados, bonusExtra: m.bonus);
                    }
                  },
                  child: const Text('ATACAR'),
                ),
                onTap: () => _editarNaLista(context, ctx,
                    campo: 'inventario',
                    titulo: 'Editar arma',
                    campos: camposItem,
                    padrao: itemPadrao,
                    indice: i),
              ),
            ),
        ]),
      ),
      Secao(
        titulo: 'Rolagem livre',
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _expr,
              decoration: const InputDecoration(hintText: 'ex.: 2d6+3'),
              onSubmitted: (_) => _rolarLivre(context),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: () => _rolarLivre(context), child: const Text('Rolar')),
        ]),
      ),
    ]);
  }

  void _rolarLivre(BuildContext context) {
    final ctx = widget.ctx;
    final e = Dados.expressao(_expr.text);
    final r = Rolagem(
        titulo: '${ctx.f.nome}: ${_expr.text}',
        detalhe: e.detalhe,
        total: e.total);
    mostrarRolagem(context, r);
    final camp = ctx.camp;
    if (camp != null) {
      Repo.registrarRolagem(camp.id, r, personagem: ctx.f.nome);
    }
  }
}

// ---------------- RITUAIS ----------------

class TabRituais extends StatelessWidget {
  final CtxFicha ctx;
  const TabRituais({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final l = ctx.f.rituais;
    final c = ctx.calc;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(
          'DT dos seus rituais: ${c.dtRitual}   •   Limite de PE/turno: ${c.limitePE}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _botoesAdicionar(context, ctx,
          campo: 'rituais',
          titulo: 'Novo ritual',
          campos: camposRitual,
          padrao: ritualPadrao,
          tipoBiblio: 'ritual'),
      const SizedBox(height: 8),
      if (l.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhum ritual conhecido.',
              style: TextStyle(color: Cores.textoFraco)),
        ),
      for (var i = 0; i < l.length; i++)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Cores.elemento(asStr(l[i]['elemento']))),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(asStr(l[i]['nome'], 'Ritual'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  Text(
                      '${asStr(l[i]['elemento'])} • ${asInt(l[i]['circulo'], 1)}º',
                      style: TextStyle(
                          color: Cores.elemento(asStr(l[i]['elemento'])),
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _editarNaLista(context, ctx,
                        campo: 'rituais',
                        titulo: 'Editar ritual',
                        campos: camposRitual,
                        padrao: ritualPadrao,
                        indice: i),
                  ),
                ]),
                Text(
                  [
                    for (final k in const [
                      'execucao',
                      'alcance',
                      'alvo',
                      'duracao',
                      'resistencia'
                    ])
                      if (asStr(l[i][k]).isNotEmpty) asStr(l[i][k])
                  ].join(' • '),
                  style: const TextStyle(color: Cores.textoFraco, fontSize: 12),
                ),
                if (asStr(l[i]['descricao']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(asStr(l[i]['descricao'])),
                  ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final forma in const ['Padrão', 'Discente', 'Verdadeiro'])
                    if (forma == 'Padrão' ||
                        asInt(l[i][forma == 'Discente'
                                ? 'custoDiscente'
                                : 'custoVerdadeiro']) >
                            0)
                      OutlinedButton(
                        onPressed: () =>
                            ctx.conjurar(context, l[i], forma: forma),
                        child: Text('Conjurar ${forma.toLowerCase()}'),
                      ),
                ]),
              ],
            ),
          ),
        ),
    ]);
  }
}

// ---------------- INVENTARIO ----------------

class TabInventario extends StatelessWidget {
  final CtxFicha ctx;
  const TabInventario({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final l = ctx.f.inventario;
    final c = ctx.calc;
    final usados = c.itensPorCategoria;
    final lim = c.patente.limites;
    const romanos = ['I', 'II', 'III', 'IV'];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Secao(
        titulo: 'Carga e limites da patente (${c.patente.nome})',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Carga: ${c.cargaAtual} / ${c.cargaMax} espaços',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: c.sobrecarregado ? Cores.destaque : null)),
          if (c.sobrecarregado)
            const Text(
                'Sobrecarregado: -5 em Defesa e perícias de carga, -3 m de deslocamento.',
                style: TextStyle(color: Cores.destaque, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (var i = 0; i < 4; i++)
              Chip(
                label: Text('Cat. ${romanos[i]}: ${usados[i]}/${lim[i]}'),
                backgroundColor: usados[i] > lim[i]
                    ? Cores.destaque.withValues(alpha: 0.3)
                    : null,
              ),
          ]),
          Text('Crédito: ${c.patente.credito}',
              style: const TextStyle(color: Cores.textoFraco, fontSize: 12)),
        ]),
      ),
      _botoesAdicionar(context, ctx,
          campo: 'inventario',
          titulo: 'Novo item',
          campos: camposItem,
          padrao: itemPadrao,
          tipoBiblio: 'item'),
      const SizedBox(height: 8),
      for (var i = 0; i < l.length; i++)
        Card(
          child: ListTile(
            leading: Icon(
              asStr(l[i]['tipo']) == 'arma'
                  ? Icons.gps_fixed
                  : asStr(l[i]['tipo']) == 'protecao'
                      ? Icons.shield_outlined
                      : Icons.inventory_2_outlined,
              color: Cores.textoFraco,
            ),
            title: Text(
                '${asStr(l[i]['nome'], 'Item')}${asInt(l[i]['qtd'], 1) > 1 ? ' x${asInt(l[i]['qtd'], 1)}' : ''}'),
            subtitle: Text(
                'Cat. ${asInt(l[i]['categoria']) == 0 ? '0' : romanos[(asInt(l[i]['categoria']).clamp(1, 4)) - 1]} • ${asInt(l[i]['espacos'], 1)} espaço(s)${asStr(l[i]['descricao']).isNotEmpty ? ' • ${asStr(l[i]['descricao'])}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            onTap: () => _editarNaLista(context, ctx,
                campo: 'inventario',
                titulo: 'Editar item',
                campos: camposItem,
                padrao: itemPadrao,
                indice: i),
          ),
        ),
    ]);
  }
}

// ---------------- PODERES & NOTAS ----------------

class TabPoderes extends StatelessWidget {
  final CtxFicha ctx;
  const TabPoderes({super.key, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final l = ctx.f.poderes;
    return ListView(padding: const EdgeInsets.all(12), children: [
      _botoesAdicionar(context, ctx,
          campo: 'poderes',
          titulo: 'Novo poder/habilidade',
          campos: camposPoder,
          padrao: poderPadrao,
          tipoBiblio: 'poder'),
      const SizedBox(height: 8),
      for (var i = 0; i < l.length; i++)
        Card(
          child: ListTile(
            title: Text(asStr(l[i]['nome'], 'Poder'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${asStr(l[i]['tipo'])}${asStr(l[i]['descricao']).isNotEmpty ? '\n${asStr(l[i]['descricao'])}' : ''}'),
            isThreeLine: asStr(l[i]['descricao']).isNotEmpty,
            onTap: () => _editarNaLista(context, ctx,
                campo: 'poderes',
                titulo: 'Editar poder',
                campos: camposPoder,
                padrao: poderPadrao,
                indice: i),
          ),
        ),
      const SizedBox(height: 12),
      Secao(
        titulo: 'Anotações',
        child: CampoSync(
            valor: ctx.f.notas,
            maxLinhas: 14,
            dica: 'Pistas, NPCs, segredos...',
            aoSalvar: (v) => Repo.set(ctx.f.id, 'notas', v)),
      ),
    ]);
  }
}
