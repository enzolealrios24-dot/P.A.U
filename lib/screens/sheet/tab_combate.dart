import 'package:flutter/material.dart';

import '../../core/dice.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/dado3d.dart';
import '../../widgets/runa.dart';
import 'rolar.dart';
import 'tab_listas.dart';

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

/// Recorte com os cantos de cima à direita e de baixo à esquerda cortados.
class _Corte extends ShapeBorder {
  final double corte;
  final Color? cor;
  const _Corte({this.corte = 16, this.cor});

  Path _caminho(Rect r) => Path()
    ..moveTo(r.left, r.top)
    ..lineTo(r.right - corte, r.top)
    ..lineTo(r.right, r.top + corte)
    ..lineTo(r.right, r.bottom)
    ..lineTo(r.left + corte, r.bottom)
    ..lineTo(r.left, r.bottom - corte)
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
          ..strokeWidth = 1);
  }

  @override
  ShapeBorder scale(double t) => _Corte(corte: corte * t, cor: cor);
}

class _PainelCortado extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _PainelCortado({required this.titulo, required this.child});
  @override
  Widget build(BuildContext context) => Material(
        color: Cores.painel,
        shape: _Corte(cor: Cores.destaque.withValues(alpha: 0.45)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 4, height: 16, color: Cores.destaque),
              const SizedBox(width: 8),
              Text(titulo.toUpperCase(),
                  style: estiloRotulo(14, cor: Cores.destaque, peso: FontWeight.w700, espaco: 2)),
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
        shape: _Corte(corte: 10, cor: Cores.destaque.withValues(alpha: 0.5)),
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
        shape: _Corte(corte: 8, cor: Cores.borda),
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
        shape: _Corte(corte: 12, cor: Cores.borda),
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
