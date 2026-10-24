import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/dano.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/runa.dart';
import 'rolar.dart';
import 'tab_listas.dart';

/// Tipo do item na sala de evidências.
enum TipoEvidencia { equipamento, catalisador, componente }

const _nomesTipo = {
  TipoEvidencia.equipamento: 'Equipamento',
  TipoEvidencia.catalisador: 'Catalisador',
  TipoEvidencia.componente: 'Componente',
};

/// Componentes ritualísticos são componentes; itens paranormais e
/// amaldiçoados (ou com elemento) são catalisadores; o resto é equipamento.
TipoEvidencia tipoEvidencia(Map<String, dynamic> i) {
  final nome = asStr(i['nome']).toLowerCase();
  if (nome.contains('componente')) return TipoEvidencia.componente;
  final cat = asStr(i['categoriaLivro']);
  if (cat == 'paranormal' || cat == 'amaldicoado' || asStr(i['elemento']).isNotEmpty) {
    return TipoEvidencia.catalisador;
  }
  return TipoEvidencia.equipamento;
}

/// Elemento do item para a runa (componentes dizem o elemento no nome).
String elementoDoItem(Map<String, dynamic> i) {
  final el = asStr(i['elemento']);
  if (el.isNotEmpty) return el;
  final nome = asStr(i['nome']).toLowerCase();
  for (final e in const ['Conhecimento', 'Energia', 'Morte', 'Sangue', 'Medo']) {
    if (nome.contains(e.toLowerCase())) return e;
  }
  return '';
}

/// Bônus que o item dá à ficha quando equipado, em texto curto (para a
/// lista de equipados). Segue as mesmas regras do cálculo da ficha.
List<String> bonusDoItem(Map<String, dynamic> i) {
  final cat = Catalogo.instance;
  final r = <String>[];
  String sinal(int v) => v >= 0 ? '+$v' : '$v';
  if (asStr(i['tipo']) == 'protecao') {
    if (asInt(i['defesa']) != 0) r.add('Defesa ${sinal(asInt(i['defesa']))}');
    final pesada = Calc.protecaoPesada(i);
    var rd = i['rd'] != null ? asInt(i['rd']) : (pesada ? 2 : 0);
    if (pesada && rd < 5 && asStrList(i['mods']).any((m) => m.endsWith('mod.blindada'))) rd = 5;
    if (rd > 0) r.add('RD física $rd');
    if (asStrList(i['maldicoes']).any((m) => m.endsWith('mal.cinetica'))) r.add('RD geral ${pesada ? 5 : 2}');
  }
  final base = cat.porRef(asStr(i['ref']));
  final efeitos = [
    if (base != null && asStr(base['tipo']) != 'modificacao') ...asMapList(base['efeitos']),
    for (final m in asStrList(i['maldicoes'])) ...asMapList(cat.porRef(m)?['efeitos']),
  ];
  for (final e in efeitos) {
    final v = asInt(e['valor'], 1);
    final valor = e['attr'] != null ? '+${atributosSigla[asStr(e['attr'])] ?? asStr(e['attr'])}' : sinal(v);
    final texto = switch (asStr(e['alvo'])) {
      'defesa' => 'Defesa $valor',
      'rd' => 'RD ${(tipoDanoPorId(asStr(e['tipo']))?.nome ?? asStr(e['tipo'])).toLowerCase()} $v',
      'rdBloqueio' => 'bloqueio $valor RD',
      'esquiva' => 'esquiva $valor',
      'extraBloqueio' => 'opção no bloqueio',
      'extraEsquiva' => 'opção na esquiva',
      'pericia' => '${asStr(e['pericia'])} $valor',
      'resistencias' => 'resistências $valor',
      'atributo' => '${atributosSigla[asStr(e['attr'])] ?? ''} $valor'.trim(),
      'deslocamento' => 'deslocamento $valor m',
      'carga' => 'carga $valor',
      'pv' => 'PV $valor',
      'pe' => 'PE $valor',
      'dtRitual' => 'DT de rituais $valor',
      _ => '',
    };
    if (texto.isNotEmpty && !r.contains(texto)) r.add(texto);
  }
  return r;
}

/// Itens equipados, acima da lista do inventário: só eles contam na ficha.
/// A chave guarda o item de novo.
class _Equipados extends StatelessWidget {
  final CtxFicha ctx;
  final List<int> indices;
  const _Equipados({required this.ctx, required this.indices});

  @override
  Widget build(BuildContext context) {
    final l = ctx.f.inventario;
    final c = ctx.calc;
    final resumo = [
      'Defesa ${c.defesa}',
      if (c.podeEsquivar) 'esquiva ${c.defesaEsquiva}',
      if (c.podeBloquear) 'bloqueio RD ${c.rdBloqueio}',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: Cores.painel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cores.destaque.withValues(alpha: 0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.back_hand_outlined, size: 16, color: Cores.destaque),
          const SizedBox(width: 6),
          Text('EQUIPADOS', style: estiloRotulo(12.5, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.8)),
          const SizedBox(width: 6),
          Text('${indices.length}', style: estiloNumero(14, cor: Cores.textoFraco)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(resumo,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: estiloMaquina(11, cor: Cores.textoFraco, espaco: 0.3)),
          ),
          const SizedBox(width: 6),
        ]),
        const SizedBox(height: 6),
        if (indices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 6),
            child: Text('Nada equipado. Ligue a chave de um item para os bônus dele contarem na ficha.',
                style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
          ),
        for (final i in indices)
          _LinhaEquipado(
            item: l[i],
            aoTocar: () => editarItem(context, ctx, i),
            aoGuardar: () => alternarEquipado(ctx, i),
          ),
      ]),
    );
  }
}

class _LinhaEquipado extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback aoTocar, aoGuardar;
  const _LinhaEquipado({required this.item, required this.aoTocar, required this.aoGuardar});
  @override
  Widget build(BuildContext context) {
    final elemento = elementoDoItem(item);
    final equipamento = tipoEvidencia(item) == TipoEvidencia.equipamento;
    final cor = equipamento || elemento.isEmpty ? Cores.destaque : Runa.corDo(elemento);
    final bonus = bonusDoItem(item);
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Runa(
            elemento: elemento.isEmpty ? 'medo' : elemento,
            circulo: max(1, asInt(item['categoria']).clamp(1, 4)),
            semente: asStr(item['nome']),
            cor: equipamento ? Cores.textoFraco : cor,
            tamanho: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asStr(item['nome'], 'Item'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: estiloMao(19, cor: Cores.texto, peso: FontWeight.w700)),
              Text(bonus.isEmpty ? 'sem bônus automático' : bonus.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: estiloMaquina(11, cor: bonus.isEmpty ? Cores.textoFraco : cor, espaco: 0.3)),
            ]),
          ),
          Switch(value: true, onChanged: (_) => aoGuardar()),
        ]),
      ),
    );
  }
}

/// Aba INVENTÁRIO como etiquetas de evidência: furo com barbante, número
/// de evidência, runa do item e código de barras.
class TabInventario extends StatefulWidget {
  final CtxFicha ctx;
  const TabInventario({super.key, required this.ctx});
  @override
  State<TabInventario> createState() => _TabInventarioState();
}

class _TabInventarioState extends State<TabInventario> {
  TipoEvidencia? _tipo;

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final l = ctx.f.inventario;
    final c = ctx.calc;
    final usados = c.itensPorCategoria;
    final lim = c.patente.limites;
    const romanos = ['I', 'II', 'III', 'IV'];
    int conta(TipoEvidencia t) => l.where((i) => tipoEvidencia(i) == t).length;
    final indices = [
      for (var i = 0; i < l.length; i++)
        if (_tipo == null || tipoEvidencia(l[i]) == _tipo) i
    ];
    final equipados = [
      for (var i = 0; i < l.length; i++)
        if (asBool(l[i]['equipado'], true)) i
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 28), children: [
      Text('Sala de evidências', style: estiloTitulo(26, cor: Cores.texto)),
      const SizedBox(height: 4),
      Text('${l.length} ${l.length == 1 ? 'item catalogado' : 'itens catalogados'} · patente ${c.patente.nome}',
          style: estiloMaquina(12.5, cor: Cores.textoFraco)),
      const SizedBox(height: 12),
      // carga e limites por categoria
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Cores.painel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.sobrecarregado ? Cores.pv : Cores.borda),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('CARGA', style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.8)),
            const Spacer(),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${c.cargaAtual}', style: estiloNumero(22, cor: c.sobrecarregado ? Cores.pv : Cores.texto)),
              TextSpan(text: ' / ${c.cargaMax} espaços', style: estiloNumero(14, cor: Cores.textoFraco, peso: FontWeight.w600)),
            ])),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: c.cargaMax <= 0 ? 0 : (c.cargaAtual / c.cargaMax).clamp(0.0, 1.0),
              minHeight: 5,
              color: c.sobrecarregado ? Cores.pv : Cores.destaque,
              backgroundColor: Cores.destaque.withValues(alpha: 0.12),
            ),
          ),
          if (c.sobrecarregado)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Sobrecarregado: −5 em Defesa e perícias de carga, −3 m de deslocamento.',
                  style: TextStyle(color: Cores.pv, fontSize: 12.5)),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < 4; i++)
              Selo('CAT. ${romanos[i]}  ${usados[i]}/${lim[i]}',
                  cor: usados[i] > lim[i] ? Cores.pv : Cores.textoFraco, cheio: usados[i] > lim[i]),
            Selo('CRÉDITO ${c.patente.credito.toUpperCase()}', cor: Cores.destaque),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      botoesAdicionarItem(context, ctx),
      const SizedBox(height: 12),
      _Equipados(ctx: ctx, indices: equipados),
      const SizedBox(height: 12),
      // poucas opções: quebram em linhas em vez de rolar
      FaixaRolavel(altura: 42, quebrarAcima: 0, children: [
        Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: ChoiceChip(
            label: Text('Todos  ${l.length}'),
            selected: _tipo == null,
            onSelected: (_) => setState(() => _tipo = null),
          ),
        ),
        for (final t in TipoEvidencia.values)
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: ChoiceChip(
              label: Text('${_nomesTipo[t]}  ${conta(t)}'),
              selected: _tipo == t,
              onSelected: (_) => setState(() => _tipo = t),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      if (indices.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l.isEmpty ? 'Nenhuma evidência catalogada.' : 'Nada deste tipo.',
              textAlign: TextAlign.center, style: estiloMao(22, cor: Cores.textoFraco)),
        ),
      for (final i in indices)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EtiquetaEvidencia(
            item: l[i],
            numero: i + 1,
            aoTocar: () => editarItem(context, ctx, i),
            aoModificar: () => editarModificacoes(context, ctx, i),
            aoEquipar: () => alternarEquipado(ctx, i),
          ),
        ),
    ]);
  }
}

/// Etiqueta de evidência de um item.
class EtiquetaEvidencia extends StatelessWidget {
  final Map<String, dynamic> item;
  final int numero;
  final VoidCallback aoTocar, aoModificar;
  /// Liga e desliga "equipado" (a chave da etiqueta).
  final VoidCallback aoEquipar;
  const EtiquetaEvidencia(
      {super.key,
      required this.item,
      required this.numero,
      required this.aoTocar,
      required this.aoModificar,
      required this.aoEquipar});

  @override
  Widget build(BuildContext context) {
    const romanos = ['0', 'I', 'II', 'III', 'IV'];
    final tipo = tipoEvidencia(item);
    final elemento = elementoDoItem(item);
    final cor = tipo == TipoEvidencia.equipamento || elemento.isEmpty ? Cores.destaque : Runa.corDo(elemento);
    final categoria = asInt(item['categoria']).clamp(0, 4);
    final qtd = asInt(item['qtd'], 1);
    final mods = nomesModificacoes(item);
    final equipado = asBool(item['equipado'], true);
    final codigo = numero.toString().padLeft(4, '0');
    final detalhe = [
      'Cat. ${romanos[categoria]}',
      '${espacosTexto(item['espacos'])} espaço(s)',
      if (asStr(item['dano']).isNotEmpty) 'dano ${asStr(item['dano'])}',
      if (asInt(item['defesa']) > 0) 'Defesa +${asInt(item['defesa'])}',
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: aoTocar,
        customBorder: const _FormaEtiqueta(),
        child: Container(
          decoration: ShapeDecoration(
            shape: _FormaEtiqueta(cor: cor.withValues(alpha: 0.55)),
            color: Cores.painel,
          ),
          child: Stack(children: [
            // barbante saindo do furo
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 40,
              child: CustomPaint(painter: _PintorFuro(cor)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(44, 10, 8, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Runa(
                    elemento: elemento.isEmpty ? 'medo' : elemento,
                    circulo: max(1, categoria),
                    semente: asStr(item['nome']),
                    cor: tipo == TipoEvidencia.equipamento ? Cores.textoFraco : cor,
                    tamanho: 44,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('EVIDÊNCIA Nº $codigo', style: estiloMaquina(11.5, cor: cor, espaco: 1)),
                      const SizedBox(width: 6),
                      Etiqueta(_nomesTipo[tipo]!.toUpperCase(), cor: cor.withValues(alpha: 0.85)),
                    ]),
                    const SizedBox(height: 3),
                    Text('${asStr(item['nome'], 'Item')}${qtd > 1 ? '  x$qtd' : ''}',
                        style: estiloMao(23, cor: Cores.texto, peso: FontWeight.w700)),
                    Text(detalhe, style: estiloMaquina(11, cor: Cores.textoFraco, espaco: 0.3)),
                    if (mods.isNotEmpty || asStr(item['descricao']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          [if (mods.isNotEmpty) mods, if (asStr(item['descricao']).isNotEmpty) asStr(item['descricao'])].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco, height: 1.3),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  SizedBox(
                    width: 62,
                    height: 34,
                    child: CustomPaint(painter: _PintorCodigoBarras('${asStr(item['nome'])}$codigo', Cores.texto)),
                  ),
                  const SizedBox(height: 2),
                  // chave de equipar: ligada, o item vai para os equipados
                  Text(equipado ? 'EQUIPADO' : 'GUARDADO',
                      style: estiloMaquina(9.5, cor: equipado ? cor : Cores.textoFraco, espaco: 0.8)),
                  SizedBox(
                    height: 30,
                    child: FittedBox(
                      child: Switch(value: equipado, onChanged: (_) => aoEquipar()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Modificações e maldições',
                    visualDensity: VisualDensity.compact,
                    onPressed: aoModificar,
                    icon: const Icon(Icons.tune, size: 19, color: Cores.textoFraco),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Etiqueta com a ponta esquerda cortada nos dois cantos.
class _FormaEtiqueta extends ShapeBorder {
  final Color? cor;
  const _FormaEtiqueta({this.cor});
  static const _ponta = 18.0;

  Path _caminho(Rect r) => Path()
    ..moveTo(r.left + _ponta, r.top)
    ..lineTo(r.right - 3, r.top)
    ..quadraticBezierTo(r.right, r.top, r.right, r.top + 3)
    ..lineTo(r.right, r.bottom - 3)
    ..quadraticBezierTo(r.right, r.bottom, r.right - 3, r.bottom)
    ..lineTo(r.left + _ponta, r.bottom)
    ..lineTo(r.left, r.bottom - _ponta)
    ..lineTo(r.left, r.top + _ponta)
    ..close();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _caminho(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _caminho(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final c = cor;
    if (c == null) return;
    canvas.drawPath(
        _caminho(rect.deflate(0.5)),
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
    // picote vertical separando a ponta da etiqueta
    final p = Paint()..color = c.withValues(alpha: 0.6);
    for (var y = rect.top + 6; y < rect.bottom - 6; y += 6) {
      canvas.drawCircle(Offset(rect.left + 38, y), 0.9, p);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// Furo reforçado com um ilhós e o barbante saindo para a esquerda.
class _PintorFuro extends CustomPainter {
  final Color cor;
  _PintorFuro(this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(20, s.height / 2);
    final barbante = Paint()
      ..color = const Color(0xFFCDB892).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy)
        ..cubicTo(c.dx - 14, c.dy - 18, c.dx - 26, c.dy + 10, c.dx - 40, c.dy - 6),
      barbante,
    );
    canvas.drawCircle(c, 8, Paint()..color = cor.withValues(alpha: 0.85));
    canvas.drawCircle(c, 4.5, Paint()..color = Colors.black);
    canvas.drawCircle(
        c,
        8,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _PintorFuro old) => old.cor != cor;
}

/// Código de barras de mentira, sempre igual para o mesmo texto.
class _PintorCodigoBarras extends CustomPainter {
  final String texto;
  final Color cor;
  _PintorCodigoBarras(this.texto, this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    var h = 7;
    for (final u in texto.codeUnits) {
      h = (h * 131 + u) & 0x7fffffff;
    }
    final r = Random(h);
    final p = Paint()..color = cor.withValues(alpha: 0.9);
    var x = 0.0;
    var barra = true;
    while (x < s.width) {
      final w = 0.8 + r.nextInt(3) * 0.9;
      if (barra) canvas.drawRect(Rect.fromLTWH(x, 0, w, s.height), p);
      x += w + (barra ? 0.6 + r.nextInt(2) * 0.8 : 0);
      barra = !barra;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorCodigoBarras old) => old.texto != texto || old.cor != cor;
}
