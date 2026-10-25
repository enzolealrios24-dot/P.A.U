import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../widgets/catalogo_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/runa.dart';
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

/// Ciclo da vantagem elemental com as runas.
class _Vantagem extends StatelessWidget {
  final String afinidade;
  const _Vantagem({required this.afinidade});
  @override
  Widget build(BuildContext context) {
    final forte = venceDe[afinidade];
    final fraco = perdePara(afinidade);
    Widget elemento(String e) => Column(mainAxisSize: MainAxisSize.min, children: [
          Runa(elemento: e, circulo: e == afinidade ? 3 : 2, semente: e, tamanho: e == afinidade ? 40 : 32),
          const SizedBox(height: 3),
          Text(e.toUpperCase(),
              style: estiloRotulo(10, cor: e == afinidade ? Runa.corDo(e) : Cores.textoFraco, peso: FontWeight.w700, espaco: 1)),
        ]);
    const seta = Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Icon(Icons.arrow_forward, size: 16, color: Cores.textoFraco),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Cores.painel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Cores.borda),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('VANTAGEM ELEMENTAL', style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.8)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            elemento('Sangue'), seta, elemento('Conhecimento'), seta, elemento('Energia'), seta,
            elemento('Morte'), seta, elemento('Sangue'),
          ]),
        ),
        const SizedBox(height: 8),
        Text(
            forte == null
                ? 'Cada elemento vence o seguinte. Medo é neutro: não vence nem perde para ninguém.'
                : 'Sua afinidade, $afinidade, vence $forte e perde para $fraco. Medo é neutro.',
            style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
      ]),
    );
  }
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
