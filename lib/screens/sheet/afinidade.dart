import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/runa.dart';
import '../../widgets/sigilo.dart';
import 'rolar.dart';

/// Afinidades que podem guiar o visual do dossiê.
const afinidadesDossie = ['Conhecimento', 'Energia', 'Morte', 'Sangue'];

/// Escolha da afinidade do dossiê (cores, fontes, runas e dado em todas as
/// abas), ou nenhuma (tema do app), e do círculo da runa do selo. Só muda o
/// visual: a afinidade das regras, de NEX 50%, continua no campo da
/// Identidade.
class SecaoAfinidade extends StatelessWidget {
  final CtxFicha ctx;
  const SecaoAfinidade({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final f = ctx.f;
    final atual = f.elementoDaFicha;
    final circulo = f.seloCirculo;
    String? aviso;
    if (f.afinidade.isNotEmpty && f.elementoVisual.isEmpty) {
      aviso = 'Usando a afinidade das regras (NEX 50%): ${f.afinidade}.';
    } else if (f.afinidade.isNotEmpty && f.elementoVisual != f.afinidade) {
      aviso = 'A afinidade das regras continua sendo ${f.afinidade}; esta escolha só muda o visual.';
    }
    return Secao(
      titulo: 'Afinidade',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Qual elemento guia este agente? Muda as cores, as fontes, as runas e o dado em todas as abas.',
            style: TextStyle(fontSize: 13, color: Cores.textoFraco)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final porLinha = c.maxWidth >= 360 ? 4 : 2;
          final largura = (c.maxWidth - 8 * (porLinha - 1)) / porLinha;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in afinidadesDossie)
              SizedBox(
                width: largura,
                child: _Opcao(
                  selecionada: atual == e,
                  cor: temasAfinidade[e]!.destaque,
                  aoTocar: () => Repo.set(f.id, 'elementoVisual', e),
                  child: Column(children: [
                    Runa(
                        elemento: e,
                        circulo: circulo,
                        semente: e,
                        cor: temasAfinidade[e]!.destaque,
                        tamanho: 48),
                    const SizedBox(height: 6),
                    Text(e,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: temasAfinidade[e]!.fonteTitulo,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: atual == e ? temasAfinidade[e]!.destaque : Cores.texto)),
                  ]),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 8),
        _Opcao(
          selecionada: atual.isEmpty,
          cor: temaApp.destaque,
          aoTocar: () => Repo.set(f.id, 'elementoVisual', semAfinidadeVisual),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SigiloElemental(elemento: '', tamanho: 36, opacidade: 0.7),
            const SizedBox(width: 10),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Sem afinidade',
                    style: TextStyle(
                        fontFamily: temaApp.fonteTitulo,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: atual.isEmpty ? temaApp.destaque : Cores.texto)),
                const Text('Fica com o tema do app', style: TextStyle(fontSize: 12, color: Cores.textoFraco)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('CÍRCULO DO SELO', style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w700, espaco: 1.8)),
        const SizedBox(height: 8),
        Row(children: [
          for (var n = 1; n <= 4; n++) ...[
            if (n > 1) const SizedBox(width: 8),
            Expanded(
              child: _Opcao(
                selecionada: circulo == n,
                cor: Cores.destaque,
                aoTocar: () => Repo.set(f.id, 'seloCirculo', n),
                child: Column(children: [
                  Runa(
                      elemento: atual.isEmpty ? 'medo' : atual,
                      circulo: n,
                      semente: f.nome,
                      cor: circulo == n ? Cores.destaque : Cores.textoFraco,
                      tamanho: 38),
                  const SizedBox(height: 4),
                  Text('$nº', style: estiloNumero(14, cor: circulo == n ? Cores.destaque : Cores.textoFraco)),
                ]),
              ),
            ),
          ],
        ]),
        if (aviso != null) ...[
          const SizedBox(height: 10),
          Text(aviso, style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
        ],
      ]),
    );
  }
}

class _Opcao extends StatelessWidget {
  final bool selecionada;
  final Color cor;
  final VoidCallback aoTocar;
  final Widget child;
  const _Opcao({required this.selecionada, required this.cor, required this.aoTocar, required this.child});
  @override
  Widget build(BuildContext context) => Material(
        color: selecionada ? cor.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: selecionada ? cor : Cores.borda, width: selecionada ? 1.6 : 1),
        ),
        child: InkWell(
          onTap: aoTocar,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), child: child),
        ),
      );
}
