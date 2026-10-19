import 'package:flutter/material.dart';

import '../../core/dice.dart';
import '../../core/rules.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/form_dialog.dart';
import 'combate.dart';

const camposAmeaca = [
  CampoDef('nome', 'Nome'),
  CampoDef('vd', 'VD', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('elemento', 'Elemento',
      tipo: TipoCampo.opcoes,
      opcoes: ['Nenhum', ...elementos],
      meiaLargura: true),
  CampoDef('pvMax', 'PV máximo', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('pv', 'PV atual', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('defesa', 'Defesa', tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('deslocamento', 'Deslocamento', meiaLargura: true),
  CampoDef('iniciativaDados', 'Iniciativa: d20s',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('iniciativaBonus', 'Iniciativa: bônus',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('ataqueNome', 'Ataque: nome', meiaLargura: true),
  CampoDef('ataqueDano', 'Ataque: dano', dica: '2d6+3', meiaLargura: true),
  CampoDef('ataqueDados', 'Ataque: d20s',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('ataqueBonus', 'Ataque: bônus',
      tipo: TipoCampo.numero, meiaLargura: true),
  CampoDef('ataqueCritico', 'Ataque: crítico',
      dica: '19/x2', meiaLargura: true),
  CampoDef('presencaPerturbadora', 'Presença perturbadora',
      dica: 'DT / dano mental', meiaLargura: true),
  CampoDef('resistencias', 'Resistências e vulnerabilidades'),
  CampoDef('pericias', 'Perícias', dica: 'Percepção +10, Furtividade +5...'),
  CampoDef('habilidades', 'Habilidades / ações', tipo: TipoCampo.multi),
  CampoDef('notas', 'Notas do mestre', tipo: TipoCampo.multi),
];

const ameacaPadrao = {
  'nome': '',
  'vd': 20,
  'elemento': 'Nenhum',
  'pvMax': 30,
  'pv': 30,
  'defesa': 15,
  'iniciativaDados': 2,
  'iniciativaBonus': 5,
  'ataqueDados': 2,
  'ataqueBonus': 10,
  'ataqueDano': '2d6',
  'ataqueCritico': '20/x2',
};

class AbaAmeacas extends StatelessWidget {
  final Campanha camp;
  const AbaAmeacas({super.key, required this.camp});

  Future<void> _editar(BuildContext context,
      [String? id, Map<String, dynamic>? atual]) async {
    final r = await editarFormulario(context,
        titulo: id == null ? 'Nova ameaça' : 'Editar ameaça',
        inicial: atual ?? Map<String, dynamic>.from(ameacaPadrao),
        campos: camposAmeaca,
        podeApagar: id != null);
    if (r == null) return;
    final col = Repo.ameacas(camp.id);
    if (r.apagar && id != null) {
      Repo.apagarDoc(col, id);
    } else if (r.dados != null) {
      Repo.salvarDoc(col, id, r.dados!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<(String, Map<String, dynamic>)>>(
      stream: Repo.stream(Repo.ameacas(camp.id)),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final l = snap.data!;
        final largura = MediaQuery.sizeOf(context).width;
        final w = largura < 720 ? largura - 24 : 360.0;
        return ListView(padding: const EdgeInsets.all(12), children: [
          Row(children: [
            FilledButton.icon(
              onPressed: () => _editar(context),
              icon: const Icon(Icons.add),
              label: const Text('Nova ameaça'),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Só o mestre vê esta aba.',
                  style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final a in l)
              SizedBox(
                width: w,
                child: _CartaoAmeaca(
                  camp: camp,
                  id: a.$1,
                  d: a.$2,
                  aoEditar: () => _editar(context, a.$1, a.$2),
                ),
              ),
          ]),
        ]);
      },
    );
  }
}

class _CartaoAmeaca extends StatelessWidget {
  final Campanha camp;
  final String id;
  final Map<String, dynamic> d;
  final VoidCallback aoEditar;
  const _CartaoAmeaca(
      {required this.camp,
      required this.id,
      required this.d,
      required this.aoEditar});

  void _atacar(BuildContext context, {required bool secreto}) {
    final crit = Dados.critico(asStr(d['ataqueCritico'], '20/x2'));
    final t = Dados.rolarTeste(
      titulo: '${asStr(d['nome'])}: ${asStr(d['ataqueNome'], 'ataque')}',
      nDados: asInt(d['ataqueDados'], 1),
      bonus: asInt(d['ataqueBonus']),
      margemCritico: crit.margem,
    );
    final dano = Dados.expressao(asStr(d['ataqueDano'], '1d6'),
        multDados: t.critico ? crit.mult : 1);
    final r = Rolagem(
      titulo: t.titulo,
      detalhe: t.detalhe,
      total: t.total,
      critico: t.critico,
      falhaCritica: t.falhaCritica,
      danoTotal: dano.total,
      danoDetalhe: dano.detalhe,
    );
    mostrarRolagem(context, r);
    Repo.registrarRolagem(camp.id, r,
        personagem: asStr(d['nome']), secreta: secreto);
  }

  @override
  Widget build(BuildContext context) {
    final cor = Cores.elemento(asStr(d['elemento']));
    final elem = asStr(d['elemento']);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: elem.isEmpty || elem == 'Nenhum' ? Cores.borda : cor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asStr(d['nome'], 'Ameaça'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(
                      'VD ${asInt(d['vd'])} • ${elem.isEmpty ? 'Nenhum' : elem} • Defesa ${asInt(d['defesa'])}${asStr(d['deslocamento']).isNotEmpty ? ' • ${asStr(d['deslocamento'])}' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Cores.textoFraco)),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                tooltip: 'Duplicar',
                onPressed: () => Repo.salvarDoc(Repo.ameacas(camp.id), null, {
                      ...d,
                      'nome': '${asStr(d['nome'])} 2',
                      'pv': asInt(d['pvMax']),
                      'condicoes': <String>[],
                    })),
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: aoEditar),
          ]),
          const SizedBox(height: 6),
          BarraStatus(
            rotulo: 'PV',
            atual: asInt(d['pv']),
            max: asInt(d['pvMax']),
            cor: Cores.pv,
            aoMudar: (v) =>
                Repo.salvarDoc(Repo.ameacas(camp.id), id, {'pv': v}),
          ),
          for (final k in const [
            'presencaPerturbadora',
            'resistencias',
            'pericias',
            'habilidades',
          ])
            if (asStr(d[k]).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(asStr(d[k]), style: const TextStyle(fontSize: 13)),
              ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            FilledButton.tonal(
              onPressed: () => _atacar(context, secreto: true),
              child: Text(
                  '${asStr(d['ataqueNome'], 'Atacar')} (secreto)'),
            ),
            OutlinedButton(
              onPressed: () => _atacar(context, secreto: false),
              child: const Text('Atacar na mesa'),
            ),
            for (final cd in asStrList(d['condicoes']))
              Chip(
                  label: Text(cd, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact),
            ActionChip(
              label: const Text('Condições', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              onPressed: () => editarCondicoesAmeaca(context, camp, id, d),
            ),
          ]),
        ]),
      ),
    );
  }
}
