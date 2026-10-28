import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dano.dart';
import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/catalogo.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/dado3d.dart';
import '../../widgets/runa.dart';
import 'rolar.dart';
import 'tab_listas.dart';
import 'tab_rituais.dart' show rituaisDoIndice, ritualVariavel, livroDoRitual;

/// Aba COMBATE em modo alerta: listras de perigo, painéis com corte diagonal
/// na cor da afinidade, a runa de 3º círculo no topo e o dado do destino.
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
    final elemento = ctx.f.elementoDaFicha;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 28), children: [
      _Cabecalho(elemento: elemento, nome: ctx.f.nome, sobrecarregado: c.sobrecarregado),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _Indicador(rotulo: 'DEFESA', valor: '${c.defesa}')),
        const SizedBox(width: 8),
        Expanded(child: _Indicador(rotulo: 'DESLOC.', valor: '${c.deslocamento} m')),
        const SizedBox(width: 8),
        Expanded(
          child: _Indicador(
            rotulo: 'INICIATIVA',
            valor: '${c.bonusPericia('Iniciativa') >= 0 ? '+' : ''}${c.bonusPericia('Iniciativa')}',
            aoTocar: () => ctx.rolarPericia(context, 'Iniciativa'),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _PainelCortado(
        titulo: 'Dado do destino',
        child: _DadoDestino(ctx: ctx),
      ),
      const SizedBox(height: 12),
      _PainelCortado(
        titulo: 'Testes rápidos',
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in const ['Fortitude', 'Reflexos', 'Vontade', 'Luta', 'Pontaria', 'Percepção'])
            _BotaoTeste(
              rotulo: p,
              bonus: c.bonusPericia(p),
              aoTocar: () => ctx.rolarPericia(context, p),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      _PainelCortado(
        titulo: 'Bloqueio e esquiva',
        child: _ReacoesDefesa(ctx: ctx),
      ),
      const SizedBox(height: 12),
      _PainelCortado(
        titulo: 'Resistência a dano',
        acao: _BotaoSofrerDano(ctx: ctx),
        child: _Resistencias(ctx: ctx),
      ),
      const SizedBox(height: 12),
      _PainelCortado(
        titulo: 'Ataques',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (armas.isEmpty)
            const Text('Nenhuma arma. Adicione itens do tipo "arma" no inventário.',
                style: TextStyle(color: Cores.textoFraco)),
          for (final (k, i) in armas.indexed) ...[
            if (k > 0) const SizedBox(height: 8),
            _Arma(
              item: inv[i],
              aoAtacar: () => ctx.rolarAtaque(context, inv[i]),
              aoSegurar: () async {
                final m = await pedirModificadores(context);
                if (m != null && context.mounted) {
                  ctx.rolarAtaque(context, inv[i], dadosExtra: m.dados, bonusExtra: m.bonus);
                }
              },
              aoEditar: () => editarArma(context, ctx, i),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      _PainelCortado(
        titulo: 'Rituais rápidos',
        acao: TextButton.icon(
          onPressed: () => _escolherRituaisRapidos(context, ctx),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Escolher'),
        ),
        child: _RituaisRapidos(ctx: ctx),
      ),
      const SizedBox(height: 12),
      _PainelCortado(
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
          FilledButton(onPressed: () => _rolarLivre(context), child: const Text('ROLAR')),
        ]),
      ),
    ]);
  }

  void _rolarLivre(BuildContext context) {
    final ctx = widget.ctx;
    final e = Dados.expressao(_expr.text);
    final r = Rolagem(titulo: '${ctx.f.nome}: ${_expr.text}', detalhe: e.detalhe, total: e.total);
    mostrarRolagem(context, r);
    final camp = ctx.camp;
    if (camp != null) Repo.registrarRolagem(camp.id, r, personagem: ctx.f.nome);
  }
}

/// Faixa de alerta com a runa de 3º círculo da afinidade.
class _Cabecalho extends StatelessWidget {
  final String elemento;
  final String nome;
  final bool sobrecarregado;
  const _Cabecalho({required this.elemento, required this.nome, required this.sobrecarregado});
  @override
  Widget build(BuildContext context) => Column(children: [
        const _Listras(altura: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          color: Colors.black.withValues(alpha: 0.35),
          child: Row(children: [
            Runa(
              elemento: elemento.isEmpty ? 'medo' : elemento,
              circulo: 3,
              semente: '$nome combate',
              cor: Cores.destaque,
              tamanho: 64,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ALERTA', style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w700, espaco: 4)),
                Text('Em combate', style: estiloTitulo(24, cor: Cores.texto)),
                if (sobrecarregado)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Etiqueta('SOBRECARREGADO', cor: Cores.pv),
                  ),
              ]),
            ),
          ]),
        ),
        const _Listras(altura: 6),
      ]);
}

/// Listras diagonais de perigo na cor da afinidade.
class _Listras extends StatelessWidget {
  final double altura;
  const _Listras({required this.altura});
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: altura, width: double.infinity, child: CustomPaint(painter: _PintorListras(Cores.destaque)));
}

class _PintorListras extends CustomPainter {
  final Color cor;
  _PintorListras(this.cor);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.clipRect(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, Paint()..color = Colors.black.withValues(alpha: 0.8));
    final p = Paint()..color = cor.withValues(alpha: 0.9);
    const passo = 18.0;
    for (var x = -s.height; x < s.width + s.height; x += passo) {
      canvas.drawPath(
        Path()
          ..moveTo(x, s.height)
          ..lineTo(x + s.height, 0)
          ..lineTo(x + s.height + passo / 2, 0)
          ..lineTo(x + passo / 2, s.height)
          ..close(),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorListras old) => old.cor != cor;
}

class _PainelCortado extends StatelessWidget {
  final String titulo;
  final Widget child;
  /// Botão no canto direito do título (opcional).
  final Widget? acao;
  const _PainelCortado({required this.titulo, required this.child, this.acao});
  @override
  Widget build(BuildContext context) => Material(
        color: Cores.painel,
        shape: CorteCantos(cor: Cores.destaque.withValues(alpha: 0.45)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 4, height: 16, color: Cores.destaque),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titulo.toUpperCase(),
                    style: estiloRotulo(14, cor: Cores.destaque, peso: FontWeight.w700, espaco: 2)),
              ),
              if (acao != null) acao!,
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );
}

class _Indicador extends StatelessWidget {
  final String rotulo;
  final String valor;
  final VoidCallback? aoTocar;
  const _Indicador({required this.rotulo, required this.valor, this.aoTocar});
  @override
  Widget build(BuildContext context) => Material(
        color: Cores.destaque.withValues(alpha: 0.08),
        shape: CorteCantos(corte: 10, cor: Cores.destaque.withValues(alpha: 0.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(valor, style: estiloNumero(28, cor: Cores.texto))),
              const SizedBox(height: 3),
              Text(rotulo, style: estiloRotulo(11.5, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.6)),
            ]),
          ),
        ),
      );
}

class _BotaoTeste extends StatelessWidget {
  final String rotulo;
  final int bonus;
  final VoidCallback aoTocar;
  const _BotaoTeste({required this.rotulo, required this.bonus, required this.aoTocar});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: 0.3),
        shape: CorteCantos(corte: 8, cor: Cores.borda),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.casino_outlined, size: 16, color: Cores.destaque),
              const SizedBox(width: 6),
              Text(rotulo, style: estiloRotulo(15, cor: Cores.texto, espaco: 0.3)),
              const SizedBox(width: 6),
              Text('${bonus >= 0 ? '+' : ''}$bonus', style: estiloNumero(15, cor: Cores.destaque)),
            ]),
          ),
        ),
      );
}

class _Arma extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback aoAtacar, aoSegurar, aoEditar;
  const _Arma({required this.item, required this.aoAtacar, required this.aoSegurar, required this.aoEditar});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withValues(alpha: 0.3),
        shape: CorteCantos(corte: 12, cor: Cores.borda),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoEditar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(asStr(item['nome'], 'Arma'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(height: 3),
                  Text(
                      '${asStr(item['pericia'], 'Luta')} · dano ${asStr(item['dano'], '-')} · crítico ${asStr(item['critico'], '20/x2')}${asStr(item['alcance']).isNotEmpty ? ' · ${asStr(item['alcance'])}' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onLongPress: aoSegurar,
                child: FilledButton(onPressed: aoAtacar, child: const Text('ATACAR')),
              ),
            ]),
          ),
        ),
      );
}

/// Escolhe quais rituais ficam no uso rápido: os do agente e os dos livros.
Future<void> _escolherRituaisRapidos(BuildContext context, CtxFicha ctx) async {
  final f = ctx.f;
  final novos = await showDialog<List<String>>(
    context: context,
    builder: (_) => _SeletorRituais(ficha: f),
  );
  if (novos != null) Repo.set(f.id, 'rituaisRapidos', novos);
}

/// Uma linha do seletor: chave do uso rápido, o ritual e o elemento mostrado.
typedef _OpcaoRitual = ({String chave, Map<String, dynamic> r, String elemento, bool doAgente});

/// Janela de escolha dos rituais rápidos: busca, filtro por elemento e
/// marcação livre. Os do agente vêm primeiro; os dos livros não precisam
/// ter sido aprendidos.
class _SeletorRituais extends StatefulWidget {
  final Ficha ficha;
  const _SeletorRituais({required this.ficha});
  @override
  State<_SeletorRituais> createState() => _SeletorRituaisState();
}

class _SeletorRituaisState extends State<_SeletorRituais> {
  static const _elementos = ['Conhecimento', 'Energia', 'Morte', 'Sangue', 'Medo'];
  final _busca = TextEditingController();
  String? _elemento;
  late final List<String> _sel;
  late final List<_OpcaoRitual> _opcoes;

  @override
  void initState() {
    super.initState();
    final f = widget.ficha;
    final doAgente = <_OpcaoRitual>[
      for (final r in f.rituais)
        (chave: chaveRitual(r), r: r, elemento: asStr(r['elemento']), doAgente: true),
    ];
    // os dos livros que o agente já conhece não repetem
    final conhecidos = {
      for (final o in doAgente) '${Catalogo.normalizar(asStr(o.r['nome']))}|${Catalogo.normalizar(o.elemento)}',
    };
    final vistos = <String>{};
    final doLivro = <_OpcaoRitual>[];
    for (final (r, el) in rituaisDoIndice()) {
      final variavel = ritualVariavel(r);
      final elemento = variavel ? el : asStr(r['elemento']);
      final chave = chaveRitualDoLivro(r, elemento: variavel ? el : null);
      if (!vistos.add(chave)) continue;
      if (conhecidos.contains('${Catalogo.normalizar(asStr(r['nome']))}|${Catalogo.normalizar(elemento)}')) continue;
      doLivro.add((chave: chave, r: r, elemento: elemento, doAgente: false));
    }
    _opcoes = [...doAgente, ...doLivro];
    final validas = {for (final o in _opcoes) o.chave};
    _sel = [for (final k in rituaisRapidos(f)) if (validas.contains(k)) k];
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  bool _visivel(_OpcaoRitual o) {
    if (_elemento != null && !Calc.elementosDoRitual(o.elemento).contains(Catalogo.normalizar(_elemento!))) {
      return false;
    }
    final q = Catalogo.normalizar(_busca.text);
    return q.isEmpty || Catalogo.normalizar('${asStr(o.r['nome'])} ${o.elemento} ${asStr(o.r['resumo'])}').contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final doAgente = [for (final o in _opcoes) if (o.doAgente && _visivel(o)) o];
    final doLivro = [for (final o in _opcoes) if (!o.doAgente && _visivel(o)) o];
    Widget cabecalho(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text(t, style: estiloRotulo(12.5, cor: Cores.destaque, peso: FontWeight.w700, espaco: 1.6)),
        );
    final linhas = <Widget>[
      if (doAgente.isNotEmpty) cabecalho('SEUS RITUAIS'),
      for (final o in doAgente) _linha(o),
      if (doLivro.isNotEmpty) cabecalho('RITUAIS DOS LIVROS'),
      for (final o in doLivro) _linha(o),
    ];
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      title: const Text('Rituais rápidos'),
      content: SizedBox(
        width: tela.width > 700 ? 620 : tela.width - 40,
        height: tela.height * 0.7,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _busca,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar ritual…'),
            onChanged: (_) => setState(() {}),
          ),
          FaixaRolavel(altura: 50, quebrarAcima: 520, children: [
            for (final el in [null, ..._elementos])
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 6),
                child: ChoiceChip(
                  avatar: el == null ? null : Runa(elemento: el, circulo: 1, semente: el, tamanho: 18),
                  showCheckmark: el == null,
                  label: Text(el ?? 'Todos'),
                  selected: _elemento == el,
                  onSelected: (_) => setState(() => _elemento = el),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          Text('${_sel.length} ${_sel.length == 1 ? 'marcado' : 'marcados'} · marque quantos quiser',
              style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
          Expanded(
            child: linhas.isEmpty
                ? const Center(child: Text('Nada encontrado.'))
                : ListView.builder(itemCount: linhas.length, itemBuilder: (_, i) => linhas[i]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _sel), child: const Text('Salvar')),
      ],
    );
  }

  Widget _linha(_OpcaoRitual o) {
    final marcado = _sel.contains(o.chave);
    final cor = Runa.corDo(o.elemento);
    return CheckboxListTile(
      dense: true,
      value: marcado,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      secondary: Runa(elemento: o.elemento, circulo: asInt(o.r['circulo'], 1), semente: asStr(o.r['nome']), tamanho: 34),
      title: Text(asStr(o.r['nome'], 'Ritual'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
      subtitle: Text(
        [
          '${o.elemento} ${asInt(o.r['circulo'], 1)}º',
          if (o.doAgente) 'conhecido' else livroDoRitual(o.r),
        ].join(' · '),
        style: TextStyle(fontSize: 12, color: cor.withValues(alpha: 0.9)),
      ),
      onChanged: (v) => setState(() => v == true ? _sel.add(o.chave) : _sel.remove(o.chave)),
    );
  }
}

/// Rituais que o jogador escolheu para conjurar direto do combate (os do
/// agente ou dos livros), um espaço por ritual, e um espaço vazio para pôr
/// mais.
class _RituaisRapidos extends StatelessWidget {
  final CtxFicha ctx;
  const _RituaisRapidos({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final escolhidos = [
      for (final k in rituaisRapidos(f))
        if (ritualRapido(f, k) case final r?) r,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, r) in escolhidos.indexed) ...[
        if (i > 0) const SizedBox(height: 8),
        _RitualRapido(ctx: ctx, ritual: r),
      ],
      if (escolhidos.isNotEmpty) const SizedBox(height: 8),
      Material(
        color: Colors.black.withValues(alpha: 0.18),
        shape: CorteCantos(corte: 12, cor: Cores.borda),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _escolherRituaisRapidos(context, ctx),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Icon(Icons.add_circle_outline, size: 22, color: Cores.destaque),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  escolhidos.isEmpty
                      ? 'Espaço livre: toque para escolher os rituais que você quer ter à mão, seus ou dos livros.'
                      : 'Colocar ou tirar rituais',
                  style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// Um ritual no uso rápido: runa, elemento, DT e um botão por forma com o
/// custo já calculado.
class _RitualRapido extends StatelessWidget {
  final CtxFicha ctx;
  final Map<String, dynamic> ritual;
  const _RitualRapido({required this.ctx, required this.ritual});
  @override
  Widget build(BuildContext context) {
    final c = ctx.calc;
    final r = ritual;
    final elemento = asStr(r['elemento']);
    final circulo = asInt(r['circulo'], 1);
    final cor = Runa.corDo(elemento);
    final pontos = c.determinacao ? 'PD' : 'PE';
    final formas = [
      for (final forma in const ['Padrão', 'Discente', 'Verdadeiro'])
        if (forma == 'Padrão' || asInt(r[forma == 'Discente' ? 'custoDiscente' : 'custoVerdadeiro']) > 0) forma,
    ];
    return Material(
      color: cor.withValues(alpha: 0.07),
      shape: CorteCantos(corte: 12, cor: cor.withValues(alpha: 0.45)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _verRitual(context, r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Runa(elemento: elemento, circulo: circulo, semente: asStr(r['nome']), tamanho: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asStr(r['nome'], 'Ritual'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(
                  [
                    '$elemento $circuloº',
                    if (asStr(r['execucao']).isNotEmpty) asStr(r['execucao']),
                    if (asStr(r['alcance']).isNotEmpty) asStr(r['alcance']),
                    'DT ${c.dtRitualDe(elemento)}',
                  ].join(' · '),
                  style: estiloRotulo(12.5, cor: cor.withValues(alpha: 0.9), peso: FontWeight.w500, espaco: 0.3),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final forma in formas)
                    _BotaoForma(
                      rotulo: forma,
                      custo: '${c.custoConjuracao(r, forma)} $pontos',
                      cor: cor,
                      cheio: forma == 'Padrão',
                      aoTocar: () => ctx.conjurar(context, r, forma: forma),
                    ),
                ]),
              ]),
            ),
            IconButton(
              tooltip: 'Tirar do uso rápido',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: Cores.textoFraco),
              onPressed: () => alternarRitualRapido(context, ctx, r),
            ),
          ]),
        ),
      ),
    );
  }

  static void _verRitual(BuildContext context, Map<String, dynamic> r) {
    final texto = asStr(r['descricao']);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(asStr(r['nome'], 'Ritual')),
        content: SingleChildScrollView(
          child: Text(
            [
              [
                for (final k in const ['execucao', 'alcance', 'alvo', 'duracao', 'resistencia'])
                  if (asStr(r[k]).isNotEmpty) asStr(r[k]),
              ].join(' · '),
              if (texto.isNotEmpty) texto,
            ].join('\n\n'),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }
}

class _BotaoForma extends StatelessWidget {
  final String rotulo, custo;
  final Color cor;
  final bool cheio;
  final VoidCallback aoTocar;
  const _BotaoForma(
      {required this.rotulo, required this.custo, required this.cor, required this.cheio, required this.aoTocar});
  @override
  Widget build(BuildContext context) => Material(
        color: cheio ? cor.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.3),
        shape: CorteCantos(corte: 7, cor: cor.withValues(alpha: cheio ? 0.8 : 0.45)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_fix_high, size: 15, color: cor),
              const SizedBox(width: 6),
              Text(rotulo, style: estiloRotulo(14.5, cor: Cores.texto, espaco: 0.3)),
              const SizedBox(width: 6),
              Text(custo, style: estiloNumero(14, cor: cor)),
            ]),
          ),
        ),
      );
}

/// Dado do destino: d20 3D girando devagar, o modificador (padrão +5) e o
/// botão de rolar. A rolagem abre a mesma janela das outras.
class _DadoDestino extends StatelessWidget {
  final CtxFicha ctx;
  const _DadoDestino({required this.ctx});
  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final mod = f.modDestino;
    void mudar(int v) => Repo.set(f.id, 'modDestino', v.clamp(-20, 40));
    return Row(children: [
      GestureDetector(
        onTap: () => ctx.rolarDestino(context, mod),
        child: const Dado3D(tamanho: 120),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('1d20 + modificador. 20 natural é acerto crítico; 1 é falha crítica.',
              style: TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
          const SizedBox(height: 10),
          Row(children: [
            Text('MOD.', style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.6)),
            const SizedBox(width: 6),
            IconButton(onPressed: () => mudar(mod - 1), icon: const Icon(Icons.remove), visualDensity: VisualDensity.compact),
            InkWell(
              onTap: () async {
                final v = await pedirNumero(context, 'Modificador do destino', mod);
                if (v != null) mudar(v);
              },
              child: SizedBox(
                width: 46,
                child: Center(child: Text('${mod >= 0 ? '+' : ''}$mod', style: estiloNumero(24, cor: Cores.texto))),
              ),
            ),
            IconButton(onPressed: () => mudar(mod + 1), icon: const Icon(Icons.add), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => ctx.rolarDestino(context, mod),
              icon: const Icon(Icons.casino_outlined),
              label: const Text('ROLAR O DESTINO'),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ---------------- resistência a dano ----------------

Color _corDano(String id) {
  if (tiposParanormais.contains(id)) return Runa.corDo(id);
  if (id == 'mental') return Cores.san;
  return Cores.destaque;
}

/// Ícone do tipo de dano; os cinco elementos usam a runa de cada um.
class _IconeDano extends StatelessWidget {
  final String id;
  final double tamanho;
  final Color cor;
  const _IconeDano(this.id, {required this.tamanho, required this.cor});
  @override
  Widget build(BuildContext context) {
    if (tiposParanormais.contains(id)) {
      return Runa(elemento: id, circulo: 1, semente: 'rd $id', cor: cor, tamanho: tamanho + 4);
    }
    final icone = switch (id) {
      'geral' => Icons.shield_outlined,
      'balistico' => Icons.gps_fixed,
      'corte' => Icons.content_cut,
      'impacto' => Icons.gavel,
      'perfuracao' => Icons.north_east,
      'eletricidade' => Icons.bolt,
      'fogo' => Icons.local_fire_department_outlined,
      'frio' => Icons.ac_unit,
      'quimico' => Icons.science_outlined,
      'mental' => Icons.psychology_outlined,
      'vida' => Icons.favorite_border,
      _ => Icons.auto_awesome,
    };
    return Icon(icone, size: tamanho, color: cor);
  }
}

String _tituloRd(TipoDano t) => switch (t.id) {
      'geral' => 'RD geral',
      'paranormal' => 'RD paranormal',
      'mental' => 'RD mental',
      _ => 'RD a ${tiposParanormais.contains(t.id) ? t.nome : t.nome.toLowerCase()}',
    };

/// RD por tipo de dano do livro, em fichas compactas como as dos testes
/// rápidos. Cada uma mostra quanto a ficha ignora daquele tipo (já somando a
/// geral e a paranormal); tocar abre o ajuste.
class _Resistencias extends StatelessWidget {
  final CtxFicha ctx;
  const _Resistencias({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final c = ctx.calc;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final t in const [rdGeral, rdParanormal])
        _ChipRd(tipo: t, valor: c.rdDe(t.id), aoTocar: () => _editarRd(context, ctx, t)),
      for (final t in tiposDano)
        _ChipRd(tipo: t, valor: c.rdContra(t.id), aoTocar: () => _editarRd(context, ctx, t)),
    ]);
  }
}

/// Botão do título do painel de RD: abre a janela de sofrer dano.
class _BotaoSofrerDano extends StatelessWidget {
  final CtxFicha ctx;
  const _BotaoSofrerDano({required this.ctx});
  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _SofrerDano(ctx: ctx),
        ),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
        ),
        icon: const Icon(Icons.heart_broken_outlined, size: 16),
        label: const Text('SOFRER DANO'),
      );
}

class _ChipRd extends StatelessWidget {
  final TipoDano tipo;
  final int valor;
  final VoidCallback aoTocar;
  const _ChipRd({required this.tipo, required this.valor, required this.aoTocar});
  @override
  Widget build(BuildContext context) {
    final cor = _corDano(tipo.id);
    final tem = valor != 0;
    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      shape: CorteCantos(corte: 8, cor: tem ? cor.withValues(alpha: 0.55) : Cores.borda),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // mesma altura para ícone e runa, para as fichas ficarem alinhadas
            SizedBox.square(
              dimension: 17,
              child: FittedBox(child: _IconeDano(tipo.id, tamanho: 16, cor: tem ? cor : Cores.textoFraco)),
            ),
            const SizedBox(width: 6),
            Text(tipo.nome, style: estiloRotulo(15, cor: tem ? Cores.texto : Cores.textoFraco, espaco: 0.3)),
            const SizedBox(width: 6),
            Text('$valor', style: estiloNumero(15, cor: tem ? Cores.destaque : Cores.textoFraco)),
          ]),
        ),
      ),
    );
  }
}

class _BotaoRd extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback aoTocar;
  const _BotaoRd(this.texto, this.cor, this.aoTocar);
  @override
  Widget build(BuildContext context) => Material(
        color: cor.withValues(alpha: 0.12),
        shape: CorteCantos(corte: 8, cor: cor.withValues(alpha: 0.45)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: SizedBox(height: 44, width: 50, child: Center(child: Text(texto, style: estiloNumero(19, cor: cor)))),
        ),
      );
}

/// Ajuste da RD de um tipo: o que a ficha já dá (e de onde vem) e o valor
/// anotado à mão. Acompanha a ficha ao vivo enquanto está aberto.
Future<void> _editarRd(BuildContext context, CtxFicha ctx, TipoDano t) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StreamBuilder<Ficha?>(
        stream: Repo.ficha(ctx.f.id),
        initialData: ctx.f,
        builder: (context, s) {
          final f = s.data;
          if (f == null) return const SizedBox(height: 200);
          final c = Calc(f, ctx.camp?.regras);
          final cor = _corDano(t.id);
          final amplo = t.id == rdGeral.id || t.id == rdParanormal.id;
          final manual = c.rdManual(t.id);
          final fontes = [for (final r in c.rdAutomatica) if (r.tipo == t.id) r];
          void mudar(int v) => Repo.set(f.id, 'rd', {...asMap(f.d['rd']), t.id: v < 0 ? 0 : v});

          // de onde sai o total contra este tipo
          final partes = <String>[
            if (!amplo && t.id != 'mental' && c.rdDe(rdGeral.id) != 0) 'geral ${c.rdDe(rdGeral.id)}',
            if (tiposParanormais.contains(t.id) && c.rdDe(rdParanormal.id) != 0)
              'paranormal ${c.rdDe(rdParanormal.id)}',
            if (!amplo && c.rdDe(t.id) != 0) '${t.nome.toLowerCase()} ${c.rdDe(t.id)}',
          ];
          final explicacao = switch (t.id) {
            'geral' => 'Vale para todos os tipos de dano, menos o mental.',
            'paranormal' => 'Vale para os cinco elementos: Conhecimento, Energia, Medo, Morte e Sangue.',
            'mental' => c.determinacao
                ? 'Diminui o dano mental, que tira PD. A RD geral não vale contra ele.'
                : 'Diminui o dano mental, que tira SAN em vez de PV. A RD geral não vale contra ele.',
            _ => partes.length > 1
                ? 'Contra ${t.nome.toLowerCase()}: ${partes.join(' + ')}.'
                : 'Diminui todo dano de ${t.nome.toLowerCase()} que você sofre.',
          };
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  _IconeDano(t.id, tamanho: 22, cor: cor),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_tituloRd(t), style: estiloTitulo(19, cor: cor))),
                  Text('${amplo ? c.rdDe(t.id) : c.rdContra(t.id)}', style: estiloNumero(34, cor: Cores.texto)),
                ]),
                const SizedBox(height: 4),
                Text(explicacao, style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
                const SizedBox(height: 16),
                Text('DA FICHA', style: estiloRotulo(13, cor: cor, peso: FontWeight.w700, espaco: 1.6)),
                const SizedBox(height: 4),
                if (fontes.isEmpty)
                  const Text('Nenhum item, poder, trilha ou condição da ficha dá esta RD.',
                      style: TextStyle(fontSize: 13.5, color: Cores.textoFraco)),
                for (final r in fontes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                        child: Text(r.fonte.isEmpty ? 'Efeito da ficha' : r.fonte,
                            style: const TextStyle(fontSize: 14.5, color: Cores.texto)),
                      ),
                      Text('+${r.valor}', style: estiloNumero(18, cor: cor)),
                    ]),
                  ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ANOTADA', style: estiloRotulo(13, cor: cor, peso: FontWeight.w700, espaco: 1.6)),
                      const Text('Rituais, itens de outros livros ou o que o mestre der.',
                          style: TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
                    ]),
                  ),
                  _BotaoRd('−1', cor, () => mudar(manual - 1)),
                  SizedBox(
                    width: 52,
                    child: InkWell(
                      onTap: () async {
                        final v = await pedirNumero(context, 'RD anotada: ${t.nome}', manual);
                        if (v != null) mudar(v);
                      },
                      child: Center(child: Text('$manual', style: estiloNumero(24, cor: Cores.texto))),
                    ),
                  ),
                  _BotaoRd('+1', cor, () => mudar(manual + 1)),
                ]),
              ]),
            ),
          );
        },
      ),
    );

/// Último tipo escolhido ao sofrer dano (a próxima janela abre nele).
String _ultimoTipoDano = 'corte';

/// Tira da ficha o dano já reduzido pela RD: PV, gastando antes os
/// temporários, ou, se for mental, SAN (PD na regra de determinação).
void tirarDano(Ficha f, Calc c, int sofrido, {bool mental = false}) {
  if (sofrido <= 0) return;
  if (mental && !c.determinacao) {
    Repo.mudarRecursos(f, {'sanAtual': max(0, f.sanAtual - sofrido)});
    return;
  }
  // o valor alvo faz mudarPontos gastar os temporários antes e parar em
  // zero (não existem PV negativos)
  final campo = mental ? 'pdAtual' : 'pvAtual';
  final atual = mental ? f.pdAtual : f.pvAtual;
  final temp = mental ? f.peTemp : f.pvTemp;
  Repo.mudarPontos(f, campo, atual - min(sofrido, atual + temp));
}

/// Sofrer dano: valor, tipo e metade por teste de resistência. A metade vem
/// antes da RD, como no livro; perda de vida ignora RD; dano mental sai da
/// SAN (ou dos PD). Os pontos temporários são gastos primeiro.
class _SofrerDano extends StatefulWidget {
  final CtxFicha ctx;
  const _SofrerDano({required this.ctx});
  @override
  State<_SofrerDano> createState() => _SofrerDanoState();
}

class _SofrerDanoState extends State<_SofrerDano> {
  final _valor = TextEditingController();
  String _tipo = _ultimoTipoDano;
  bool _metade = false;
  bool _bloqueou = false;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.ctx.f;
    final c = widget.ctx.calc;
    final dano = int.tryParse(_valor.text) ?? 0;
    final vida = _tipo == 'vida';
    final mental = _tipo == 'mental';
    // bloqueio: a RD dele soma contra este ataque (não vale para dano mental)
    final bloqueio = c.podeBloquear && _bloqueou && !vida && !mental ? c.rdBloqueio : 0;
    final rd = vida ? 0 : c.rdContra(_tipo) + bloqueio;
    final sofrido = vida ? (_metade ? dano ~/ 2 : dano) : danoFinal(dano, rd, metade: _metade);
    final recurso = mental ? (c.determinacao ? 'PD' : 'SAN') : 'PV';
    final corRecurso = mental ? (c.determinacao ? Cores.pd : Cores.san) : Cores.pv;
    final atual = mental ? (c.determinacao ? f.pdAtual : f.sanAtual) : f.pvAtual;
    final temp = mental ? (c.determinacao ? f.peTemp : 0) : f.pvTemp;
    final doTemp = min(sofrido, temp);
    final depois = max(0, atual - (sofrido - doTemp));
    final nomeTipo = vida ? 'perda de vida' : (tipoDanoPorId(_tipo)?.nome.toLowerCase() ?? _tipo);

    void aplicar() {
      _ultimoTipoDano = _tipo;
      tirarDano(f, c, sofrido, mental: mental);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sofrido > 0
            ? '${f.nome} perdeu $sofrido $recurso ($nomeTipo${vida ? '' : ', RD $rd'}).'
            : 'A RD $rd de ${f.nome} absorveu todo o dano de $nomeTipo.'),
      ));
    }

    Widget opcao(String id, String nome) {
      final cor = id == 'vida' ? Cores.pv : _corDano(id);
      return ChoiceChip(
        avatar: _IconeDano(id, tamanho: 15, cor: _tipo == id ? cor : Cores.textoFraco),
        label: Text(nome),
        selected: _tipo == id,
        showCheckmark: false,
        onSelected: (_) => setState(() => _tipo = id),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Sofrer dano', style: estiloTitulo(20, cor: Cores.pv)),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _valor,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: estiloNumero(24, cor: Cores.texto),
                  decoration: const InputDecoration(labelText: 'Dano'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CheckboxListTile(
                  value: _metade,
                  onChanged: (v) => setState(() => _metade = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Passou no teste: metade'),
                ),
              ),
            ]),
            if (c.podeBloquear && !vida && !mental)
              CheckboxListTile(
                value: _bloqueou,
                onChanged: (v) => setState(() => _bloqueou = v ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Bloqueei: RD +${c.rdBloqueio} contra este ataque'),
              ),
            const SizedBox(height: 12),
            Text('TIPO', style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.6)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in tiposDano) opcao(t.id, t.nome),
              opcao('vida', 'Perda de vida'),
            ]),
            const SizedBox(height: 14),
            Material(
              color: corRecurso.withValues(alpha: 0.1),
              shape: CorteCantos(corte: 10, cor: corRecurso.withValues(alpha: 0.5)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    [
                      '$dano de $nomeTipo',
                      if (_metade) 'metade: ${dano ~/ 2}',
                      vida ? 'ignora RD' : (bloqueio > 0 ? 'RD $rd (bloqueio $bloqueio)' : 'RD $rd'),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco),
                  ),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$sofrido', style: estiloNumero(34, cor: corRecurso)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('de $recurso', style: estiloRotulo(15, cor: corRecurso, peso: FontWeight.w700)),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('$recurso fica em $depois', style: estiloNumero(16, cor: Cores.texto, peso: FontWeight.w600)),
                        if (doTemp > 0)
                          Text('$doTemp saem dos temporários',
                              style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: dano > 0 ? aplicar : null,
              style: FilledButton.styleFrom(backgroundColor: Cores.pv, minimumSize: const Size(0, 48)),
              child: const Text('APLICAR DANO'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------- bloqueio e esquiva ----------------

/// Bloqueio e esquiva (reações de defesa), já calculados com os itens
/// equipados e as habilidades. Tocar mostra de onde vem cada parte.
class _ReacoesDefesa extends StatelessWidget {
  final CtxFicha ctx;
  const _ReacoesDefesa({required this.ctx});

  @override
  Widget build(BuildContext context) {
    final c = ctx.calc;
    final extras = [
      for (final e in c.extrasDefesa('extraBloqueio')) ('Bloqueio', e),
      for (final e in c.extrasDefesa('extraEsquiva')) ('Esquiva', e),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: _Reacao(
            rotulo: 'Bloqueio',
            icone: Icons.shield_outlined,
            valor: '+${c.rdBloqueio}',
            unidade: 'RD',
            detalhe: c.podeBloquear ? 'contra corpo a corpo' : 'exige Fortitude treinada',
            ativo: c.podeBloquear,
            aoTocar: () => _detalharReacao(context, ctx, bloqueio: true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Reacao(
            rotulo: 'Esquiva',
            icone: Icons.directions_run,
            valor: '${c.defesaEsquiva}',
            unidade: 'DEFESA',
            detalhe: c.podeEsquivar ? 'contra um ataque' : 'exige Reflexos treinado',
            ativo: c.podeEsquivar,
            aoTocar: () => _detalharReacao(context, ctx, bloqueio: false),
          ),
        ),
      ]),
      for (final (qual, e) in extras)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$qual · ${e.fonte}: ',
                  style: estiloRotulo(13, cor: Cores.destaque, peso: FontWeight.w700, espaco: 0.3)),
              TextSpan(text: e.texto),
            ]),
            style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco),
          ),
        ),
      const SizedBox(height: 6),
      const Text('Uma reação de defesa por rodada, escolhida antes de o atacante rolar.',
          style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
    ]);
  }
}

class _Reacao extends StatelessWidget {
  final String rotulo, valor, unidade, detalhe;
  final IconData icone;
  final bool ativo;
  final VoidCallback aoTocar;
  const _Reacao({
    required this.rotulo,
    required this.icone,
    required this.valor,
    required this.unidade,
    required this.detalhe,
    required this.ativo,
    required this.aoTocar,
  });
  @override
  Widget build(BuildContext context) {
    final cor = ativo ? Cores.destaque : Cores.textoFraco;
    return Material(
      color: ativo ? Cores.destaque.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.3),
      shape: CorteCantos(corte: 10, cor: ativo ? Cores.destaque.withValues(alpha: 0.5) : Cores.borda),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icone, size: 16, color: cor),
              const SizedBox(width: 6),
              Text(rotulo.toUpperCase(), style: estiloRotulo(12.5, cor: cor, peso: FontWeight.w700, espaco: 1.6)),
            ]),
            const SizedBox(height: 2),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(valor, style: estiloNumero(28, cor: ativo ? Cores.texto : Cores.textoFraco)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unidade, style: estiloRotulo(12, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1)),
              ),
            ]),
            Text(detalhe, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
          ]),
        ),
      ),
    );
  }
}

/// De onde vem o bloqueio (ou a esquiva), as opções com custo e o bônus
/// anotado à mão. Acompanha a ficha ao vivo enquanto está aberto.
Future<void> _detalharReacao(BuildContext context, CtxFicha ctx, {required bool bloqueio}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StreamBuilder<Ficha?>(
        stream: Repo.ficha(ctx.f.id),
        initialData: ctx.f,
        builder: (context, s) {
          final f = s.data;
          if (f == null) return const SizedBox(height: 200);
          final c = Calc(f, ctx.camp?.regras);
          final campo = bloqueio ? 'bonusBloqueio' : 'bonusEsquiva';
          final anotado = asInt(f.d[campo]);
          final partes = [
            for (final p in bloqueio ? c.partesBloqueio : c.partesEsquiva)
              if (p.fonte != 'Anotado') p
          ];
          final extras = c.extrasDefesa(bloqueio ? 'extraBloqueio' : 'extraEsquiva');
          final pode = bloqueio ? c.podeBloquear : c.podeEsquivar;
          final cor = pode ? Cores.destaque : Cores.textoFraco;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Icon(bloqueio ? Icons.shield_outlined : Icons.directions_run, size: 22, color: cor),
                  const SizedBox(width: 10),
                  Expanded(child: Text(bloqueio ? 'Bloqueio' : 'Esquiva', style: estiloTitulo(20, cor: cor))),
                  Text(bloqueio ? '+${c.rdBloqueio}' : '${c.defesaEsquiva}', style: estiloNumero(34, cor: Cores.texto)),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(bloqueio ? 'RD' : 'DEFESA',
                        style: estiloRotulo(13, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  bloqueio
                      ? 'Reação ao ser alvo de um ataque corpo a corpo: você recebe essa RD contra ele. '
                          'Exige Fortitude treinada.'
                      : 'Reação ao ser alvo de um ataque: você usa essa Defesa contra ele. '
                          'Exige Reflexos treinado.',
                  style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco),
                ),
                if (!pode)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        bloqueio
                            ? 'Esta ficha não é treinada em Fortitude, então ainda não pode bloquear.'
                            : 'Esta ficha não é treinada em Reflexos, então ainda não pode se esquivar.',
                        style: TextStyle(fontSize: 12.5, color: Cores.pv)),
                  ),
                const SizedBox(height: 16),
                Text('DE ONDE VEM', style: estiloRotulo(13, cor: cor, peso: FontWeight.w700, espaco: 1.6)),
                const SizedBox(height: 4),
                for (final p in partes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                        child: Text(p.fonte.isEmpty ? 'Efeito da ficha' : p.fonte,
                            style: const TextStyle(fontSize: 14.5, color: Cores.texto)),
                      ),
                      Text(p.valor >= 0 && p.fonte != 'Defesa' ? '+${p.valor}' : '${p.valor}',
                          style: estiloNumero(18, cor: cor)),
                    ]),
                  ),
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('OPÇÕES COM CUSTO', style: estiloRotulo(13, cor: cor, peso: FontWeight.w700, espaco: 1.6)),
                  const SizedBox(height: 4),
                  for (final e in extras)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: '${e.fonte}: ', style: const TextStyle(color: Cores.texto, fontWeight: FontWeight.w600)),
                        TextSpan(text: e.texto),
                      ]), style: const TextStyle(fontSize: 13.5, color: Cores.textoFraco)),
                    ),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ANOTADO', style: estiloRotulo(13, cor: cor, peso: FontWeight.w700, espaco: 1.6)),
                      const Text('Bônus que o app não calcula sozinho.',
                          style: TextStyle(fontSize: 12.5, color: Cores.textoFraco)),
                    ]),
                  ),
                  _BotaoRd('−1', Cores.destaque, () => Repo.set(f.id, campo, anotado - 1)),
                  SizedBox(
                    width: 52,
                    child: InkWell(
                      onTap: () async {
                        final v = await pedirNumero(context, bloqueio ? 'Bônus no bloqueio' : 'Bônus na esquiva', anotado);
                        if (v != null) Repo.set(f.id, campo, v);
                      },
                      child: Center(child: Text('$anotado', style: estiloNumero(24, cor: Cores.texto))),
                    ),
                  ),
                  _BotaoRd('+1', Cores.destaque, () => Repo.set(f.id, campo, anotado + 1)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
