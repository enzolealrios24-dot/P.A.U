import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../widgets/catalogo_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/runa.dart';
import '../../widgets/sigilo.dart';
import 'rolar.dart';
import 'tab_listas.dart';

/// Ordem dos elementos como no livro.
const _ordemElementos = ['Conhecimento', 'Energia', 'Morte', 'Sangue', 'Medo'];

/// Vantagem elemental: cada elemento vence o seguinte (Medo é neutro).
const venceDe = {
  'Sangue': 'Conhecimento',
  'Conhecimento': 'Energia',
  'Energia': 'Morte',
  'Morte': 'Sangue',
};
String? perdePara(String e) =>
    venceDe.entries.where((x) => x.value == e).map((x) => x.key).firstOrNull;

/// Livros dos rituais, para o filtro.
const livrosRituais = ['Livro de Regras', 'Sobrevivendo ao Horror', 'Arquivos Secretos'];

String livroDoRitual(Map<String, dynamic> r) {
  final f = asStr(r['fonte']);
  if (f == 'SaH') return 'Sobrevivendo ao Horror';
  if (f.startsWith('AS')) return 'Arquivos Secretos';
  return 'Livro de Regras';
}

/// Ritual de elemento variável (Amaldiçoar Arma): aprende-se num elemento.
bool ritualVariavel(Map<String, dynamic> r) =>
    !_ordemElementos.contains(asStr(r['elemento'])) && !asStr(r['elemento']).contains('/');

/// Rituais de todos os livros como no índice do livro básico (páginas 122 e
/// 123): os de elemento variável aparecem uma vez em cada elemento e os de
/// dois elementos (Sangue/Conhecimento) uma vez em cada um.
List<(Map<String, dynamic>, String)> rituaisDoIndice() {
  final saida = <(Map<String, dynamic>, String)>[];
  for (final r in Catalogo.instance.rituais) {
    final el = asStr(r['elemento']);
    if (_ordemElementos.contains(el)) {
      saida.add((r, el));
    } else if (el.contains('/')) {
      for (final e in el.split('/')) {
        saida.add((r, e.trim()));
      }
    } else {
      for (final e in _ordemElementos.take(4)) {
        saida.add((r, e));
      }
    }
  }
  saida.sort((a, b) {
    final c = asInt(a.$1['circulo']).compareTo(asInt(b.$1['circulo']));
    if (c != 0) return c;
    final e = _ordemElementos.indexOf(a.$2).compareTo(_ordemElementos.indexOf(b.$2));
    if (e != 0) return e;
    return Catalogo.normalizar(asStr(a.$1['nome'])).compareTo(Catalogo.normalizar(asStr(b.$1['nome'])));
  });
  return saida;
}

/// Aba RITUAIS como catálogo: os rituais que o agente conhece e, embaixo, os
/// de todos os livros com runa do elemento e do círculo, filtros e a
/// vantagem elemental. Os da afinidade do agente ficam em destaque.
class TabRituais extends StatefulWidget {
  final CtxFicha ctx;
  const TabRituais({super.key, required this.ctx});
  @override
  State<TabRituais> createState() => _TabRituaisState();
}

class _TabRituaisState extends State<TabRituais> {
  String? _elemento;
  int? _circulo;
  String? _livro;
  String? _aberto;
  late final _indice = rituaisDoIndice();

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final f = ctx.f;
    final c = ctx.calc;
    final afinidade = f.elementoDaFicha;
    final conhecidos = f.rituais;
    final nomesConhecidos = {for (final r in conhecidos) Catalogo.normalizar(asStr(r['nome']))};
    final visiveis = _indice
        .where((x) =>
            (_elemento == null || x.$2 == _elemento) &&
            (_circulo == null || asInt(x.$1['circulo']) == _circulo) &&
            (_livro == null || livroDoRitual(x.$1) == _livro))
        .toList();
    final rapidos = rituaisRapidos(f);
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 28), children: [
      Text('Catálogo de rituais', style: estiloTitulo(26, cor: Cores.texto)),
      const SizedBox(height: 4),
      Text('DT ${c.dtRitual} · limite de ${c.determinacao ? 'PD' : 'PE'} por turno ${c.limitePE} · ${conhecidos.length} conhecidos',
          style: estiloMaquina(12.5, cor: Cores.textoFraco)),
      const SizedBox(height: 12),
      _Vantagem(afinidade: afinidade),
      Secao(
        titulo: 'Seus rituais',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          botoesAdicionarRitual(context, ctx),
          const SizedBox(height: 10),
          if (conhecidos.isEmpty)
            const Text('Nenhum ritual conhecido. Aprenda pelo catálogo abaixo.',
                style: TextStyle(color: Cores.textoFraco)),
          for (var i = 0; i < conhecidos.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _RitualConhecido(
              ctx: ctx,
              indice: i,
              afinidade: afinidade,
              rapido: rapidos.contains(chaveRitual(conhecidos[i])),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        const Losango(),
        const SizedBox(width: 10),
        Text('RITUAIS DO LIVRO', style: estiloRotulo(14, cor: Cores.destaque, peso: FontWeight.w700, espaco: 2)),
        const Spacer(),
        Text('${visiveis.length} de ${_indice.length}', style: estiloRotulo(13, cor: Cores.textoFraco)),
      ]),
      const SizedBox(height: 8),
      FaixaRolavel(altura: 42, quebrarAcima: 520, children: [
        _filtro('Todos', _elemento == null, () => setState(() => _elemento = null)),
        for (final e in _ordemElementos)
          _filtro(e, _elemento == e, () => setState(() => _elemento = e),
              runa: Runa(elemento: e, circulo: 1, semente: e, tamanho: 18)),
      ]),
      FaixaRolavel(altura: 42, quebrarAcima: 520, children: [
        _filtro('Todos os círculos', _circulo == null, () => setState(() => _circulo = null)),
        for (var n = 1; n <= 4; n++) _filtro('$nº círculo', _circulo == n, () => setState(() => _circulo = n)),
      ]),
      FaixaRolavel(altura: 42, quebrarAcima: 520, children: [
        _filtro('Todos os livros', _livro == null, () => setState(() => _livro = null)),
        for (final l in livrosRituais) _filtro(l, _livro == l, () => setState(() => _livro = l)),
      ]),
      const SizedBox(height: 6),
      for (final (r, el) in visiveis)
        _RitualDoLivro(
          r: r,
          elemento: el,
          daAfinidade: afinidade.isNotEmpty && el == afinidade,
          conhecido: nomesConhecidos.contains(Catalogo.normalizar(asStr(r['nome']))),
          aberto: _aberto == '${r['id']}|$el',
          aoAbrir: () => setState(() => _aberto = _aberto == '${r['id']}|$el' ? null : '${r['id']}|$el'),
          aoAprender: () => aprenderRitual(context, ctx, r, elemento: ritualVariavel(r) ? el : null),
        ),
    ]);
  }

  Widget _filtro(String rotulo, bool ativo, VoidCallback aoTocar, {Widget? runa}) => Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 4),
        child: ChoiceChip(
          avatar: runa,
          showCheckmark: runa == null,
          label: Text(rotulo),
          selected: ativo,
          onSelected: (_) => aoTocar(),
        ),
      );
}

/// Ciclo da vantagem elemental com as runas de 4º círculo: Conhecimento no
/// alto, Energia à direita, Morte embaixo e Sangue à esquerda, cada um
/// vencendo o seguinte no sentido das setas. Medo fica no meio, neutro.
class _Vantagem extends StatelessWidget {
  final String afinidade;
  const _Vantagem({required this.afinidade});

  /// Ângulo de cada elemento no círculo (0 é a direita, sentido horário).
  static const angulos = {'Energia': 0.0, 'Morte': pi / 2, 'Sangue': pi, 'Conhecimento': 3 * pi / 2};
  static const raio = 78.0, runa = 52.0, runaDestaque = 60.0, rotulo = 58.0, sigilo = 210.0;
  static double _tamanho(String e, String afinidade) => e == afinidade ? runaDestaque : runa;

  @override
  Widget build(BuildContext context) {
    final forte = venceDe[afinidade];
    final fraco = perdePara(afinidade);
    final temAfinidade = forte != null && fraco != null;
    bool emJogo(String e) => !temAfinidade || e == afinidade || e == forte || e == fraco;
    double tamanho(String e) => _tamanho(e, afinidade);

    const largura = 2 * (raio + runaDestaque / 2 + 6 + rotulo);
    const altura = 2 * (raio + runaDestaque / 2 + 4 + 15);
    const centro = Offset(largura / 2, altura / 2);
    Offset posicao(String e) => e == 'Medo' ? centro : centro + Offset(cos(angulos[e]!), sin(angulos[e]!)) * raio;

    Widget simbolo(String e) {
      final p = posicao(e), s = tamanho(e), cor = Runa.corDo(e);
      return Positioned(
        left: p.dx - s / 2,
        top: p.dy - s / 2,
        child: Container(
          decoration: e == afinidade
              ? BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: cor.withValues(alpha: 0.3), blurRadius: 18)])
              : null,
          child: Runa(elemento: e, circulo: 4, semente: e, tamanho: s, cor: emJogo(e) ? cor : cor.withValues(alpha: 0.35)),
        ),
      );
    }

    Widget nome(String e) {
      final p = posicao(e), s = tamanho(e);
      final texto = Text(e.toUpperCase(),
          textAlign: e == 'Sangue' ? TextAlign.right : (e == 'Energia' ? TextAlign.left : TextAlign.center),
          style: estiloRotulo(11,
              cor: temAfinidade && emJogo(e) ? Runa.corDo(e) : Cores.textoFraco, peso: FontWeight.w700, espaco: 1));
      return switch (e) {
        'Energia' => Positioned(left: p.dx + s / 2 + 6, top: p.dy - 7, width: rotulo, child: texto),
        'Sangue' => Positioned(left: p.dx - s / 2 - 6 - rotulo, top: p.dy - 7, width: rotulo, child: texto),
        'Conhecimento' => Positioned(left: p.dx - 60, top: p.dy - s / 2 - 19, width: 120, child: texto),
        _ => Positioned(left: p.dx - 60, top: p.dy + s / 2 + 4, width: 120, child: texto),
      };
    }

    TextSpan elemento(String e) =>
        TextSpan(text: e, style: TextStyle(color: Runa.corDo(e), fontWeight: FontWeight.w700));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Cores.painel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cores.borda),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('VANTAGEM ELEMENTAL', style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.8)),
        const SizedBox(height: 10),
        Semantics(
          label: 'Sangue vence Conhecimento, Conhecimento vence Energia, Energia vence Morte e Morte vence Sangue.',
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: largura,
                height: altura,
                child: Stack(clipBehavior: Clip.none, children: [
                  // sigilo vivo da afinidade, por baixo das runas e das setas
                  Positioned(
                    left: centro.dx - sigilo / 2,
                    top: centro.dy - sigilo / 2,
                    child: SigiloElemental(
                      elemento: temAfinidade ? afinidade : '',
                      tamanho: sigilo,
                      pontas: 4,
                      raioPontas: raio / (sigilo / 2),
                      furos: [for (final e in [...angulos.keys, 'Medo']) (posicao(e) - centro, tamanho(e) / 2 + 3)],
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PintorCiclo(afinidade: temAfinidade ? afinidade : ''),
                    ),
                  ),
                  for (final e in [...angulos.keys, 'Medo']) ...[simbolo(e), nome(e)],
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            if (temAfinidade) ...[
              const TextSpan(text: 'Sua afinidade é '),
              elemento(afinidade),
              const TextSpan(text: ', ela vence '),
              elemento(forte),
              const TextSpan(text: ' e perde para '),
              elemento(fraco),
              const TextSpan(text: '.'),
            ] else
              const TextSpan(text: 'Cada elemento vence o seguinte, no sentido das setas.'),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, height: 1.35, color: Cores.texto),
        ),
        const SizedBox(height: 3),
        const Text('Medo é neutro.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Cores.textoFraco)),
      ]),
    );
  }
}

/// Setas do ciclo, de cada elemento para o que ele vence, na cor de quem
/// vence. Com afinidade, só as duas setas dela ficam acesas.
class _PintorCiclo extends CustomPainter {
  final String afinidade;
  _PintorCiclo({required this.afinidade});

  @override
  void paint(Canvas canvas, Size size) {
    const raio = _Vantagem.raio;
    final c = size.center(Offset.zero);
    final arco = Rect.fromCircle(center: c, radius: raio);
    final fraco = perdePara(afinidade);
    // distância do centro de cada runa até onde a seta começa ou para
    double folga(String e) => _Vantagem._tamanho(e, afinidade) / 2 + 7;
    for (final MapEntry(key: de, value: para) in venceDe.entries) {
      final a0 = _Vantagem.angulos[de]!;
      var a1 = _Vantagem.angulos[para]!;
      if (a1 <= a0) a1 += 2 * pi;
      final inicio = a0 + folga(de) / raio;
      final fim = a1 - (folga(para) + 6) / raio;
      final acesa = afinidade.isEmpty || de == afinidade || de == fraco;
      final cor = Runa.corDo(de).withValues(alpha: afinidade.isEmpty ? 0.6 : (acesa ? 0.95 : 0.18));
      final linha = Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = afinidade.isNotEmpty && acesa ? 2.2 : 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arco, inicio, fim - inicio, false, linha);
      // ponta da seta, seguindo a tangente do círculo
      final ponta = c + Offset(cos(fim), sin(fim)) * raio;
      final frente = Offset(-sin(fim), cos(fim));
      final lado = Offset(cos(fim), sin(fim));
      canvas.drawPath(
        Path()
          ..moveTo(ponta.dx + frente.dx * 7, ponta.dy + frente.dy * 7)
          ..lineTo(ponta.dx - frente.dx * 2 + lado.dx * 4.5, ponta.dy - frente.dy * 2 + lado.dy * 4.5)
          ..lineTo(ponta.dx - frente.dx * 2 - lado.dx * 4.5, ponta.dy - frente.dy * 2 - lado.dy * 4.5)
          ..close(),
        Paint()..color = cor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorCiclo old) => old.afinidade != afinidade;
}

class _RitualDoLivro extends StatelessWidget {
  final Map<String, dynamic> r;
  final String elemento;
  final bool daAfinidade, conhecido, aberto;
  final VoidCallback aoAbrir, aoAprender;
  const _RitualDoLivro({
    required this.r,
    required this.elemento,
    required this.daAfinidade,
    required this.conhecido,
    required this.aberto,
    required this.aoAbrir,
    required this.aoAprender,
  });

  @override
  Widget build(BuildContext context) {
    final cor = Runa.corDo(elemento);
    final circulo = asInt(r['circulo'], 1);
    final forte = venceDe[elemento];
    final fraco = perdePara(elemento);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: daAfinidade ? cor.withValues(alpha: 0.08) : Cores.painel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: daAfinidade ? cor.withValues(alpha: 0.7) : Cores.borda, width: daAfinidade ? 1.4 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoAbrir,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Runa(elemento: elemento, circulo: circulo, semente: asStr(r['nome']), tamanho: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(asStr(r['nome']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    if (daAfinidade) Etiqueta('AFINIDADE', cor: cor),
                    if (conhecido) Etiqueta('CONHECIDO', cor: Cores.ok),
                  ]),
                  const SizedBox(height: 2),
                  Text('${ritualVariavel(r) ? elemento : asStr(r['elemento'])} · $circuloº círculo · ${asStr(r['execucao'])} · ${asStr(r['alcance'])}',
                      style: estiloRotulo(13, cor: cor.withValues(alpha: 0.9), peso: FontWeight.w500, espaco: 0.3)),
                  const SizedBox(height: 4),
                  Text(aberto ? detalhesRitual(r) : asStr(r['resumo']),
                      maxLines: aberto ? null : 2,
                      overflow: aberto ? null : TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, height: 1.35)),
                  if (forte != null || elemento == 'Medo')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          elemento == 'Medo' ? 'Neutro' : 'Vence $forte · perde para $fraco',
                          style: const TextStyle(fontSize: 11.5, color: Cores.textoFraco)),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(Catalogo.fonteCurta(r), style: const TextStyle(fontSize: 11, color: Cores.textoFraco)),
                  ),
                ]),
              ),
              IconButton(
                tooltip: conhecido ? 'Aprender de novo' : 'Aprender',
                onPressed: aoAprender,
                icon: Icon(conhecido ? Icons.check_circle : Icons.add_circle, color: conhecido ? Cores.ok : Cores.destaque),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RitualConhecido extends StatelessWidget {
  final CtxFicha ctx;
  final int indice;
  final String afinidade;
  /// Está no uso rápido da aba Combate.
  final bool rapido;
  const _RitualConhecido({required this.ctx, required this.indice, required this.afinidade, required this.rapido});
  @override
  Widget build(BuildContext context) {
    final r = ctx.f.rituais[indice];
    final elemento = asStr(r['elemento']);
    final circulo = asInt(r['circulo'], 1);
    final cor = Runa.corDo(elemento);
    final daAfinidade = afinidade.isNotEmpty && elemento == afinidade;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cor.withValues(alpha: daAfinidade ? 0.8 : 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Runa(elemento: elemento, circulo: circulo, semente: asStr(r['nome']), tamanho: 54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(asStr(r['nome'], 'Ritual'), style: estiloTitulo(17, cor: Cores.texto)),
              ),
              IconButton(
                tooltip: rapido ? 'Tirar do uso rápido no Combate' : 'Pôr no uso rápido no Combate',
                visualDensity: VisualDensity.compact,
                icon: Icon(rapido ? Icons.bolt : Icons.bolt_outlined,
                    size: 20, color: rapido ? Cores.destaque : Cores.textoFraco),
                onPressed: () => alternarRitualRapido(context, ctx, r),
              ),
              IconButton(
                tooltip: 'Editar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18, color: Cores.textoFraco),
                onPressed: () => editarRitual(context, ctx, indice),
              ),
            ]),
            Text(
              [
                '$elemento $circuloº',
                for (final k in const ['execucao', 'alcance', 'alvo', 'duracao', 'resistencia'])
                  if (asStr(r[k]).isNotEmpty) asStr(r[k])
              ].join(' · '),
              style: estiloRotulo(13, cor: cor.withValues(alpha: 0.9), peso: FontWeight.w500, espaco: 0.3),
            ),
            if (asStr(r['descricao']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Text(asStr(r['descricao']), style: const TextStyle(fontSize: 13.5, height: 1.35)),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('CONJURAR', style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.6)),
              for (final forma in const ['Padrão', 'Discente', 'Verdadeiro'])
                if (forma == 'Padrão' ||
                    asInt(r[forma == 'Discente' ? 'custoDiscente' : 'custoVerdadeiro']) > 0)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      foregroundColor: cor,
                      side: BorderSide(color: cor.withValues(alpha: 0.5)),
                    ),
                    onPressed: () => ctx.conjurar(context, r, forma: forma),
                    child: Text(forma),
                  ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
