import '../data/models.dart';
import 'dano.dart';
import 'rules.dart';

/// Texto curto de um efeito automático ("Defesa +2", "+1d20 em perícias",
/// "custo de rituais de Sangue −1 PE"...). Null para os que não aparecem.
String? descreverEfeito(Map<String, dynamic> e) {
  final v = asInt(e['valor'], 1);
  String sinal(int n) => n >= 0 ? '+$n' : '−${-n}';
  final sigla = atributosSigla[asStr(e['attr'])] ?? asStr(e['attr']).toUpperCase();
  final por = switch (asStr(e['por'])) {
    'nivel' => ' por NEX',
    'nivelImpar' => ' por NEX ímpar',
    'nivelMetade' => ' a cada 2 NEX',
    _ => '',
  };
  // valor: fixo, por NEX ou igual a um atributo
  final valor = e['attr'] != null && asStr(e['alvo']) != 'atributo' && asStr(e['alvo']) != 'cargaAtributo'
      ? '+$sigla'
      : '${sinal(v)}$por';
  final escopo = switch (asStr(e['escopo'])) {
    'corpo' => ' corpo a corpo',
    'distancia' => ' à distância',
    _ => '',
  };
  final texto = switch (asStr(e['alvo'])) {
    'defesa' => 'Defesa $valor',
    'rd' => 'RD ${(tipoDanoPorId(asStr(e['tipo']))?.nome ?? asStr(e['tipo'])).toLowerCase()} $valor',
    'rdBloqueio' => 'bloqueio $valor RD',
    'esquiva' => 'esquiva $valor',
    'extraBloqueio' => 'opção no bloqueio',
    'extraEsquiva' => 'opção na esquiva',
    'pericia' => '${asStr(e['pericia'])} $valor${asBool(e['seTreinado']) ? ' (se treinado)' : ''}',
    'periciaAttr' => '${asStr(e['pericia'])} +$sigla',
    'resistencias' => 'testes de resistência $valor',
    'atributo' => '$sigla ${sinal(v)}',
    'deslocamento' => 'deslocamento $valor m',
    'deslocamentoMetade' => 'deslocamento pela metade',
    'carga' => 'carga $valor',
    'cargaAtributo' => 'carga soma $sigla',
    'pv' => 'PV $valor',
    'pe' => 'PE $valor',
    'san' => 'Sanidade $valor',
    'pd' => 'PD $valor',
    'sanInicialMetade' => 'Sanidade inicial pela metade',
    'limitePE' => 'limite de PE por turno $valor',
    'dtRitual' => 'DT de rituais${e['elemento'] != null ? ' de ${asStr(e['elemento'])}' : ''} $valor',
    'custoRitual' => 'custo de ${e['elemento'] != null ? 'rituais de ${asStr(e['elemento'])}' : e['ritual'] != null ? asStr(e['ritual']) : e['alcance'] != null ? 'rituais de alcance ${asStr(e['alcance']).toLowerCase()}' : 'rituais'} ${sinal(v)} PE',
    'danoRitual' => 'dano e cura de rituais $valor',
    'danoCorpo' => 'dano corpo a corpo $valor',
    'danoDisparo' => 'dano à distância $valor',
    'danoFogo' => 'dano com armas de fogo $valor',
    'dados' => '${v >= 0 ? '+' : '−'}${v.abs()}d20 em ${switch (asStr(e['escopo'])) {
        'ataque' => 'ataques',
        'ataqueCorpo' => 'ataques corpo a corpo',
        'pericia' => 'perícias',
        'todos' => 'todos os testes',
        final s when s.startsWith('pericia:') => s.substring(8),
        final s when s.startsWith('attr:') => 'testes de ${s.substring(5).split(',').map((a) => atributosSigla[a] ?? a).join('/')}',
        _ => 'testes',
      }}',
    'margem' => 'margem de ameaça$escopo $valor',
    'treino' =>
      'treinado em ${asStr(e['pericia'])}${asInt(e['grau'], 5) > 5 ? ' (veterano)' : ''} (se já for: ${e['ouDados'] != null ? '+${asInt(e['ouDados'])}d20' : '+${asInt(e['ou'])}'})',
    'treinoCascata' => 'treino em ${asStrList(e['pericias']).join(' ou ')} (com todas: +${asInt(e['ou'])})',
    'todasPericias' => 'todas as perícias $valor',
    'atributoPericia' => '${asStr(e['pericia'])} pode usar $sigla',
    'atributoPE' => 'PE podem usar $sigla',
    'atributoDefesa' => 'Defesa pode usar $sigla',
    'atributoDT' => 'DT de rituais pode usar $sigla',
    'multiplicador' => 'multiplicador de crítico$escopo $valor',
    'dadosDano' => '${sinal(v)} dado de dano$escopo',
    _ => '',
  };
  if (texto.isEmpty) return null;
  final se = switch (asStr(e['se'])) {
    'machucado' => ' (machucado)',
    'protecaoPesada' => ' (com proteção pesada)',
    'semProtecao' => ' (sem proteção)',
    'protecaoLeve' => ' (com proteção leve)',
    _ => '',
  };
  return '$texto$se';
}

/// Os textos dos efeitos de uma lista, sem repetir.
List<String> descreverEfeitos(Iterable<Map<String, dynamic>> efeitos) {
  final r = <String>[];
  for (final e in efeitos) {
    final t = descreverEfeito(e);
    if (t != null && !r.contains(t)) r.add(t);
  }
  return r;
}
