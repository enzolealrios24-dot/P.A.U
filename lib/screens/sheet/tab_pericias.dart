import 'package:flutter/material.dart';

import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/runa.dart';
import 'rolar.dart';

/// Aba PERÍCIAS como um caderno de campo: papel quadriculado, nomes escritos
/// à mão e uma linha pontilhada até o bônus. Cada perícia tem a sua runa:
/// treinada com dois anéis, não treinada com um.
class TabPericias extends StatefulWidget {
  final CtxFicha ctx;
  const TabPericias({super.key, required this.ctx});
  @override
  State<TabPericias> createState() => _TabPericiasState();
}

enum _Filtro { todas, treinadas, naoTreinadas }

class _TabPericiasState extends State<TabPericias> {
  _Filtro _filtro = _Filtro.todas;

  @override
  Widget build(BuildContext context) {
    final f = widget.ctx.f;
    final treinadas = periciasDef.where((p) => f.grau(p.nome) > 0).length;
    final lista = periciasDef.where((p) {
      final t = f.grau(p.nome) > 0;
      return switch (_filtro) {
        _Filtro.todas => true,
        _Filtro.treinadas => t,
        _Filtro.naoTreinadas => !t,
      };
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Caderno de campo', style: estiloMao(30, cor: Cores.texto, peso: FontWeight.w700)),
              Text('${f.nome} · $treinadas treinadas',
                  style: estiloMaquina(12, cor: Cores.textoFraco)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        FaixaRolavel(altura: 42, children: [
          for (final (filtro, rotulo, n) in [
            (_Filtro.todas, 'Todas', periciasDef.length),
            (_Filtro.treinadas, 'Treinadas', treinadas),
            (_Filtro.naoTreinadas, 'Não treinadas', periciasDef.length - treinadas),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$rotulo  $n'),
                selected: _filtro == filtro,
                onSelected: (_) => setState(() => _filtro = filtro),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        _Caderno(
          children: [
            for (final p in lista) _LinhaPericia(ctx: widget.ctx, p: p),
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Nenhuma perícia aqui.', style: estiloMao(22, cor: Cores.textoFraco)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Toque no nome para rolar (segure para modificadores) e no carimbo para mudar o treino. '),
            const TextSpan(text: '* só treinada. ', style: TextStyle(fontWeight: FontWeight.w700)),
            WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.backpack_outlined, size: 14, color: Cores.textoFraco)),
            const TextSpan(text: ' sofre penalidade de carga.'),
          ]),
          style: const TextStyle(fontSize: 12.5, color: Cores.textoFraco),
        ),
      ],
    );
  }
}

/// Folha de caderno: quadriculado na cor da afinidade, margem dupla e furos
/// de fichário à esquerda.
class _Caderno extends StatelessWidget {
  final List<Widget> children;
  const _Caderno({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          // opaco: o bloco deslocado atrás não pode aparecer através do papel
          color: Color.alphaBlend(Cores.painel, Cores.fundo),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Cores.borda),
          boxShadow: [BoxShadow(color: Cores.roxo.withValues(alpha: 0.45), offset: const Offset(5, 5))],
        ),
        child: CustomPaint(
          painter: _PintorPapel(Cores.destaque),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_PintorPapel.margem + 6, 8, 10, 10),
            child: Column(children: children),
          ),
        ),
      );
}

class _PintorPapel extends CustomPainter {
  static const margem = 40.0;
  static const passo = 18.0;
  final Color cor;
  _PintorPapel(this.cor);

  @override
  void paint(Canvas canvas, Size s) {
    final grade = Paint()
      ..color = cor.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var x = margem; x < s.width; x += passo) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), grade);
    }
    for (var y = passo; y < s.height; y += passo) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), grade);
    }
    final linhaMargem = Paint()
      ..color = cor.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(margem - 6, 0), Offset(margem - 6, s.height), linhaMargem);
    canvas.drawLine(const Offset(margem - 2, 0), Offset(margem - 2, s.height), linhaMargem);
    // furos do fichário
    final furo = Paint()..color = Colors.black.withValues(alpha: 0.75);
    final aro = Paint()
      ..color = cor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 36.0; y < s.height - 10; y += 96) {
      canvas.drawCircle(Offset(margem / 2 - 3, y), 6, furo);
      canvas.drawCircle(Offset(margem / 2 - 3, y), 6, aro);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorPapel old) => old.cor != cor;
}

class _LinhaPericia extends StatelessWidget {
  final CtxFicha ctx;
  final PericiaDef p;
  const _LinhaPericia({required this.ctx, required this.p});

  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final c = ctx.calc;
    final treinada = f.grau(p.nome) > 0;
    final bonus = c.bonusPericia(p.nome);
    final dados = c.dadosPericia(p.nome);
    final outros = f.bonusPericia(p.nome);
    final elemento = f.elementoDaFicha;
    final tinta = treinada ? Cores.texto : Cores.texto.withValues(alpha: 0.72);
    return InkWell(
      onTap: () => ctx.rolarPericia(context, p.nome),
      onLongPress: () async {
        final m = await pedirModificadores(context);
        if (m != null && context.mounted) {
          ctx.rolarPericia(context, p.nome, dadosExtra: m.dados, bonusExtra: m.bonus);
        }
      },
      child: SizedBox(
        height: 54,
        child: Row(children: [
          Runa(
            elemento: elemento.isEmpty ? 'medo' : elemento,
            circulo: treinada ? 2 : 1,
            semente: p.nome,
            cor: treinada ? Cores.destaque : Cores.textoFraco.withValues(alpha: 0.55),
            tamanho: 30,
          ),
          const SizedBox(width: 10),
          // nome à mão e, embaixo, atributo e dados à máquina
          Flexible(
            flex: 0,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${p.nome}${p.soTreinada ? '*' : ''}',
                    style: estiloMao(21, cor: tinta, peso: treinada ? FontWeight.w700 : FontWeight.w500)),
                if (p.carga) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.backpack_outlined, size: 13, color: Cores.textoFraco),
                ],
              ]),
              Text('${atributosSigla[p.attr]} · ${dados <= 0 ? 2 - dados : dados}d20${dados <= 0 ? ' (pior)' : ''}',
                  style: estiloMaquina(10.5, cor: Cores.textoFraco, espaco: 0.4)),
            ]),
          ),
          // linha pontilhada até o bônus
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 6, right: 6, top: 8),
              child: CustomPaint(painter: _PintorPontilhado(), size: Size(double.infinity, 2)),
            ),
          ),
          _CarimboGrau(
            grau: f.grau(p.nome),
            aoMudar: (g) => Repo.set(f.id, 'pericias.${p.nome}.grau', g),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Outros bônus',
            child: InkWell(
              onTap: () async {
                final v = await pedirNumero(context, 'Outros bônus: ${p.nome}', outros);
                if (v != null) Repo.set(f.id, 'pericias.${p.nome}.bonus', v);
              },
              child: SizedBox(
                width: 32,
                height: 40,
                child: Center(
                  child: Text(outros == 0 ? '±' : (outros > 0 ? '+$outros' : '$outros'),
                      style: estiloMao(17, cor: outros == 0 ? Cores.textoFraco.withValues(alpha: 0.6) : Cores.destaque)),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('${bonus >= 0 ? '+' : ''}$bonus',
                textAlign: TextAlign.right,
                style: estiloMao(27,
                    cor: treinada || bonus != 0 ? Cores.texto : Cores.textoFraco, peso: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class _PintorPontilhado extends CustomPainter {
  const _PintorPontilhado();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Cores.textoFraco.withValues(alpha: 0.55);
    for (var x = 0.0; x < s.width; x += 6) {
      canvas.drawCircle(Offset(x + 1, s.height / 2), 0.9, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Treino como um carimbo levemente torto.
class _CarimboGrau extends StatelessWidget {
  final int grau;
  final ValueChanged<int> aoMudar;
  const _CarimboGrau({required this.grau, required this.aoMudar});
  @override
  Widget build(BuildContext context) {
    final cores = {
      0: Cores.textoFraco,
      5: Cores.ok,
      10: Cores.san,
      15: Cores.pe,
    };
    final cor = cores[grau] ?? Cores.textoFraco;
    return PopupMenuButton<int>(
      tooltip: 'Grau de treinamento',
      onSelected: aoMudar,
      itemBuilder: (_) => [
        for (final e in grausTreino.entries)
          PopupMenuItem(value: e.key, child: Text('${e.value} (+${e.key})')),
      ],
      child: Transform.rotate(
        angle: grau == 0 ? 0 : -0.06,
        child: Container(
          width: 60,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: cor.withValues(alpha: grau == 0 ? 0.3 : 0.85), width: grau == 0 ? 1 : 1.6),
          ),
          child: Text(
            const {0: 'DESTR.', 5: 'TREIN.', 10: 'VETER.', 15: 'EXPERT'}[grau] ?? '+$grau',
            style: estiloMaquina(11.5, cor: cor.withValues(alpha: grau == 0 ? 0.6 : 1), espaco: 0.6),
          ),
        ),
      ),
    );
  }
}
