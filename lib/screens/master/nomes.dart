import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot, FieldValue, SetOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/nomes.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';

/// Gerador de nomes do mestre: nomes brasileiros para NPCs, testemunhas e
/// cultistas. Tocar copia o nome; a estrela guarda na lista da mesa (só o
/// mestre vê).
class AbaNomes extends StatefulWidget {
  final Campanha camp;
  const AbaNomes({super.key, required this.camp});

  @override
  State<AbaNomes> createState() => _AbaNomesState();
}

class _AbaNomesState extends State<AbaNomes> {
  final _r = Random();
  String _genero = '';
  bool _meio = false;
  bool _doisSobrenomes = false;
  late List<String> _nomes = _gerar();

  List<String> _gerar() {
    final vistos = <String>{};
    while (vistos.length < 12) {
      vistos.add(gerarNome(_r, genero: _genero, nomeDoMeio: _meio, doisSobrenomes: _doisSobrenomes));
    }
    return vistos.toList();
  }

  void _gerarOutros() => setState(() => _nomes = _gerar());

  void _copiar(String nome) {
    Clipboard.setData(ClipboardData(text: nome));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$nome copiado.'), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final doc = Repo.nomesGuardados(widget.camp.id);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snap) {
        final guardados = asStrList(snap.data?.data()?['lista']);
        void guardar(String nome, bool sim) => doc.set({
              'lista': sim ? FieldValue.arrayUnion([nome]) : FieldValue.arrayRemove([nome]),
            }, SetOptions(merge: true));
        Widget cartao(String nome) {
          final guardado = guardados.contains(nome);
          return Material(
            color: Cores.painel,
            shape: CorteCantos(corte: 10, cor: Cores.destaque.withValues(alpha: guardado ? 0.8 : 0.35)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _copiar(nome),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                child: Row(children: [
                  Expanded(
                    child: Text(nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: guardado ? 'Tirar dos guardados' : 'Guardar',
                    icon: Icon(guardado ? Icons.star : Icons.star_border,
                        color: guardado ? Cores.destaque : Cores.textoFraco),
                    onPressed: () => guardar(nome, !guardado),
                  ),
                ]),
              ),
            ),
          );
        }

        return LayoutBuilder(builder: (context, c) {
          final colunas = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
          final largura = (c.maxWidth - 24 - 8 * (colunas - 1)) / colunas;
          return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 28), children: [
            Text('GERADOR DE NOMES', style: estiloTitulo(20, cor: Cores.destaque)),
            const SizedBox(height: 2),
            const Text(
                'Nomes para NPCs, testemunhas e cultistas. Toque num nome para copiar; a estrela guarda na lista da mesa, que só você vê.',
                style: TextStyle(fontSize: 13.5, color: Cores.textoFraco)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '', label: Text('Qualquer')),
                  ButtonSegment(value: 'f', label: Text('Femininos')),
                  ButtonSegment(value: 'm', label: Text('Masculinos')),
                ],
                selected: {_genero},
                onSelectionChanged: (s) {
                  _genero = s.first;
                  _gerarOutros();
                },
              ),
              FilterChip(
                label: const Text('Nome do meio'),
                selected: _meio,
                onSelected: (v) {
                  _meio = v;
                  _gerarOutros();
                },
              ),
              FilterChip(
                label: const Text('Dois sobrenomes'),
                selected: _doisSobrenomes,
                onSelected: (v) {
                  _doisSobrenomes = v;
                  _gerarOutros();
                },
              ),
              FilledButton.icon(
                onPressed: _gerarOutros,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Gerar outros'),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final n in _nomes) SizedBox(width: largura, child: cartao(n)),
            ]),
            if (guardados.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 8),
                child: Text('GUARDADOS',
                    style: estiloRotulo(12.5, cor: Cores.textoFraco, peso: FontWeight.w600, espaco: 1.6)),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final n in guardados.reversed) SizedBox(width: largura, child: cartao(n)),
              ]),
            ],
          ]);
        });
      },
    );
  }
}
