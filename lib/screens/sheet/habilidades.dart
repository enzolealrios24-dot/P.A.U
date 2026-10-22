import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import 'rolar.dart';

// Habilidades da aba AGENTE. As que vêm do livro (origem, classe e trilha)
// podem ser editadas ou ocultadas; o texto original continua no catálogo.
// Também dá para criar habilidades próprias.
//
// Na ficha:
//   habilidadesProprias: [{id, nome, resumo, fonte}]
//   habilidadesEditadas: {chave: {nome, resumo}}
//   habilidadesOcultas:  [chave]

class _Habilidade {
  final String chave;
  final String tipo; // ORIGEM, CLASSE, TRILHA ou PRÓPRIA
  final String nome;
  final String resumo;
  final String fonte;
  final bool editada;
  final bool propria;
  const _Habilidade({
    required this.chave,
    required this.tipo,
    required this.nome,
    required this.resumo,
    this.fonte = '',
    this.editada = false,
    this.propria = false,
  });
}

class SecaoHabilidades extends StatefulWidget {
  final CtxFicha ctx;
  const SecaoHabilidades({super.key, required this.ctx});
  @override
  State<SecaoHabilidades> createState() => _SecaoHabilidadesState();
}

class _SecaoHabilidadesState extends State<SecaoHabilidades> {
  bool _verOcultas = false;

  Ficha get _f => widget.ctx.f;
  Map<String, dynamic> get _editadas => asMap(_f.d['habilidadesEditadas']);
  List<String> get _ocultas => asStrList(_f.d['habilidadesOcultas']);

  /// Habilidades vindas do livro, já com as edições da pessoa aplicadas.
  List<_Habilidade> _doLivro(Calc c) {
    final f = _f;
    final ed = _editadas;
    final saida = <_Habilidade>[];
    void add(String chave, String tipo, String nome, String resumo, String fonte) {
      final e = asMap(ed[chave]);
      saida.add(_Habilidade(
        chave: chave,
        tipo: tipo,
        nome: e.isEmpty ? nome : asStr(e['nome'], nome),
        resumo: e.isEmpty ? resumo : asStr(e['resumo'], resumo),
        fonte: fonte,
        editada: e.isNotEmpty,
      ));
    }

    final o = c.origemDados;
    if (o != null) {
      final p = asMap(o['poder']);
      add('origem:${asStr(o['nome'])}', 'ORIGEM', '${asStr(p['nome'])} (origem ${asStr(o['nome'])})',
          asStr(p['resumo']), Catalogo.fonteCurta(o));
    }
    final cd = c.classeDados;
    if (cd != null) {
      final limite = c.sobrevivente ? f.estagio : c.nexClasse;
      for (final h in asMapList(cd['habilidades'])) {
        if (asInt(h['nex']) > limite) continue;
        add('classe:${asStr(cd['nome'])}:${asStr(h['nome'])}', 'CLASSE', asStr(h['nome']),
            asStr(h['resumo']), Catalogo.fonteCurta(cd));
      }
    }
    final t = c.trilhaDados;
    if (t != null) {
      for (final h in asMapList(t['habilidades'])) {
        if (!c.trilhaLiberada(asInt(h['nex']))) continue;
        final rotulo = c.sobrevivente ? 'estágio ${asInt(h['nex'])}' : 'NEX ${asInt(h['nex'])}%';
        add('trilha:${asStr(t['nome'])}:${asStr(h['nome'])}', 'TRILHA',
            '${asStr(h['nome'])} (${asStr(t['nome'])}, $rotulo)', asStr(h['resumo']),
            Catalogo.fonteCurta(t));
      }
    }
    return saida;
  }

  List<_Habilidade> get _proprias => [
        for (final h in asMapList(_f.d['habilidadesProprias']))
          _Habilidade(
            chave: asStr(h['id']),
            tipo: 'PRÓPRIA',
            nome: asStr(h['nome'], 'Habilidade'),
            resumo: asStr(h['resumo']),
            fonte: asStr(h['fonte']),
            propria: true,
          ),
      ];

  static const _campos = [
    CampoDef('nome', 'Nome'),
    CampoDef('resumo', 'O que ela faz', tipo: TipoCampo.multi),
    CampoDef('fonte', 'Origem (opcional)', dica: 'ex.: poder do mestre, item amaldiçoado'),
  ];

  Future<void> _nova() async {
    final r = await editarFormulario(context,
        titulo: 'Nova habilidade', inicial: const {}, campos: _campos);
    final d = r?.dados;
    if (d == null || asStr(d['nome']).trim().isEmpty) return;
    Repo.set(_f.id, 'habilidadesProprias', [
      ...asMapList(_f.d['habilidadesProprias']),
      {
        'id': novoId(),
        'nome': asStr(d['nome']).trim(),
        'resumo': asStr(d['resumo']).trim(),
        'fonte': asStr(d['fonte']).trim(),
      },
    ]);
  }

  Future<void> _editarPropria(_Habilidade h) async {
    final lista = asMapList(_f.d['habilidadesProprias']);
    final i = lista.indexWhere((x) => asStr(x['id']) == h.chave);
    if (i < 0) return;
    final r = await editarFormulario(context,
        titulo: 'Editar habilidade', inicial: lista[i], campos: _campos, podeApagar: true);
    if (r == null) return;
    if (r.apagar) {
      lista.removeAt(i);
    } else if (r.dados != null) {
      lista[i] = {
        ...lista[i],
        'nome': asStr(r.dados!['nome']).trim(),
        'resumo': asStr(r.dados!['resumo']).trim(),
        'fonte': asStr(r.dados!['fonte']).trim(),
      };
    } else {
      return;
    }
    Repo.set(_f.id, 'habilidadesProprias', lista);
  }

  Future<void> _editarDoLivro(_Habilidade h) async {
    final r = await editarFormulario(context,
        titulo: 'Editar habilidade',
        inicial: {'nome': h.nome, 'resumo': h.resumo},
        campos: const [
          CampoDef('nome', 'Nome'),
          CampoDef('resumo', 'O que ela faz', tipo: TipoCampo.multi),
        ]);
    final d = r?.dados;
    if (d == null) return;
    // grava o mapa inteiro: as chaves têm ":" e espaços
    Repo.set(_f.id, 'habilidadesEditadas', {
      ..._editadas,
      h.chave: {'nome': asStr(d['nome']).trim(), 'resumo': asStr(d['resumo']).trim()},
    });
  }

  void _restaurar(_Habilidade h) =>
      Repo.set(_f.id, 'habilidadesEditadas', {..._editadas}..remove(h.chave));

  void _ocultar(_Habilidade h, bool ocultar) {
    final l = _ocultas.toSet();
    ocultar ? l.add(h.chave) : l.remove(h.chave);
    Repo.set(_f.id, 'habilidadesOcultas', l.toList());
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.ctx.calc;
    final ocultas = _ocultas.toSet();
    final todas = [..._doLivro(c), ..._proprias];
    final visiveis = todas.where((h) => !ocultas.contains(h.chave)).toList();
    final escondidas = todas.where((h) => ocultas.contains(h.chave)).toList();
    final prog = c.progressaoAtual;
    return Secao(
      titulo: 'Habilidades',
      acoes: [
        TextButton.icon(
          onPressed: _nova,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nova'),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (todas.isEmpty)
          const Text('Escolha classe, origem e trilha para ver as habilidades, ou crie uma em "Nova".',
              style: TextStyle(color: Cores.textoFraco)),
        for (final (i, h) in visiveis.indexed) ...[
          if (i > 0) const Divider(height: 18),
          _item(h, oculta: false),
        ],
        if (escondidas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _verOcultas = !_verOcultas),
              style: TextButton.styleFrom(foregroundColor: Cores.textoFraco),
              icon: Icon(_verOcultas ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              label: Text(_verOcultas
                  ? 'Esconder as ocultas'
                  : (escondidas.length == 1 ? '1 habilidade oculta' : '${escondidas.length} habilidades ocultas')),
            ),
          ),
          if (_verOcultas)
            for (final h in escondidas)
              Opacity(opacity: 0.55, child: Padding(padding: const EdgeInsets.only(top: 8), child: _item(h, oculta: true))),
        ],
        if (prog.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                title: Text('PROGRESSÃO RECEBIDA',
                    style: estiloRotulo(13, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.6)),
                childrenPadding: const EdgeInsets.only(bottom: 6),
                children: [
                  for (final p in prog)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(p, style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _item(_Habilidade h, {required bool oculta}) {
    final cor = switch (h.tipo) {
      'ORIGEM' => Cores.roxoClaro,
      'TRILHA' => Cores.san,
      'PRÓPRIA' => Cores.ok,
      _ => Cores.destaque,
    };
    return InkWell(
      onTap: () => h.propria ? _editarPropria(h) : _editarDoLivro(h),
      borderRadius: BorderRadius.circular(4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(h.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Etiqueta(h.tipo, cor: cor),
              if (h.editada) Etiqueta('EDITADA', cor: Cores.textoFraco),
            ]),
            if (h.resumo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(h.resumo, style: const TextStyle(fontSize: 13.5, height: 1.35)),
            ],
            if (h.fonte.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(h.fonte, style: const TextStyle(fontSize: 11.5, color: Cores.textoFraco)),
              ),
          ]),
        ),
        PopupMenuButton<String>(
          tooltip: 'Opções',
          icon: const Icon(Icons.more_vert, size: 20, color: Cores.textoFraco),
          onSelected: (v) {
            switch (v) {
              case 'editar':
                h.propria ? _editarPropria(h) : _editarDoLivro(h);
              case 'restaurar':
                _restaurar(h);
              case 'ocultar':
                _ocultar(h, true);
              case 'mostrar':
                _ocultar(h, false);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'editar', child: Text(h.propria ? 'Editar ou apagar' : 'Editar texto')),
            if (h.editada) const PopupMenuItem(value: 'restaurar', child: Text('Voltar ao texto do livro')),
            if (oculta)
              const PopupMenuItem(value: 'mostrar', child: Text('Mostrar de novo'))
            else
              const PopupMenuItem(value: 'ocultar', child: Text('Ocultar')),
          ],
        ),
      ]),
    );
  }
}
