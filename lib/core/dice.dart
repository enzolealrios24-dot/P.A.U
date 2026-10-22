import 'dart:math';

class Rolagem {
  final String titulo;
  final String detalhe;
  final int total;
  final bool critico;
  final bool falhaCritica;
  final String? danoDetalhe;
  final int? danoTotal;
  /// Teste de d20: os dados rolados, o que valeu (natural) e o bônus somado.
  /// Só servem para a animação; o registro da mesa usa o detalhe.
  final List<int> dados;
  final int? natural;
  final int bonus;
  final bool pegouMenor;
  Rolagem({
    required this.titulo,
    required this.detalhe,
    required this.total,
    this.critico = false,
    this.falhaCritica = false,
    this.danoDetalhe,
    this.danoTotal,
    this.dados = const [],
    this.natural,
    this.bonus = 0,
    this.pegouMenor = false,
  });

  Map<String, dynamic> toMap() => {
        'titulo': titulo,
        'detalhe': detalhe,
        'total': total,
        'critico': critico,
        'falhaCritica': falhaCritica,
        'danoDetalhe': danoDetalhe,
        'danoTotal': danoTotal,
      };
}

class Dados {
  static final _r = Random();
  static int d(int faces) => faces <= 0 ? 0 : _r.nextInt(faces) + 1;

  /// Teste de Ordem Paranormal: rola N d20 (N = atributo + modificador) e
  /// fica com o maior. Com N <= 0 rola (2 - N) d20 e fica com o menor.
  static ({List<int> dados, int escolhido, bool pegouMenor}) teste(int n) {
    final pegaMenor = n <= 0;
    final qtd = pegaMenor ? 2 - n : n;
    final dados = List.generate(qtd, (_) => d(20));
    final esc = pegaMenor ? dados.reduce(min) : dados.reduce(max);
    return (dados: dados, escolhido: esc, pegouMenor: pegaMenor);
  }

  static Rolagem rolarTeste({
    required String titulo,
    required int nDados,
    required int bonus,
    int margemCritico = 20,
  }) {
    final t = teste(nDados);
    final total = t.escolhido + bonus;
    final sinal = bonus >= 0 ? '+' : '-';
    final det =
        '${t.dados.length}d20${t.pegouMenor ? ' (menor)' : ''} [${t.dados.join(', ')}] → ${t.escolhido} $sinal ${bonus.abs()}';
    return Rolagem(
      titulo: titulo,
      detalhe: det,
      total: total,
      critico: t.escolhido >= margemCritico,
      falhaCritica: t.escolhido == 1,
      dados: t.dados,
      natural: t.escolhido,
      bonus: bonus,
      pegouMenor: t.pegouMenor,
    );
  }

  static final _termo = RegExp(r'([+-]?)\s*(\d*)\s*[dD]\s*(\d+)|([+-]?)\s*(\d+)');

  /// Rola expressoes como "2d6+1d4+3". multDados multiplica a quantidade
  /// de dados (critico).
  static ({int total, String detalhe}) expressao(String e, {int multDados = 1}) {
    var total = 0;
    final partes = <String>[];
    for (final m in _termo.allMatches(e)) {
      if (m.group(3) != null) {
        final neg = m.group(1) == '-';
        final qtd = (int.tryParse(m.group(2) ?? '') ?? 1) * multDados;
        final faces = int.parse(m.group(3)!);
        final rs = List.generate(qtd.clamp(0, 200), (_) => d(faces));
        final s = rs.fold<int>(0, (a, b) => a + b);
        total += neg ? -s : s;
        partes.add('${neg ? '-' : ''}${qtd}d$faces[${rs.join(',')}]');
      } else if (m.group(5) != null) {
        final neg = m.group(4) == '-';
        final v = int.parse(m.group(5)!);
        total += neg ? -v : v;
        partes.add('${neg ? '-' : '+'}$v');
      }
    }
    var det = partes.join(' ');
    if (det.startsWith('+')) det = det.substring(1);
    return (total: total, detalhe: det.isEmpty ? '0' : det);
  }

  /// "19/x3" -> (margem 19, mult 3). "x2" -> (20, 2)
  static ({int margem, int mult}) critico(String s) {
    var margem = 20, mult = 2;
    final mm = RegExp(r'(\d+)\s*/').firstMatch(s);
    if (mm != null) margem = int.parse(mm.group(1)!);
    final mx = RegExp(r'[xX]\s*(\d+)').firstMatch(s);
    if (mx != null) mult = int.parse(mx.group(1)!);
    if (mm == null && mx == null) {
      final so = int.tryParse(s.trim());
      if (so != null && so > 1 && so <= 20) margem = so;
    }
    return (margem: margem, mult: mult);
  }
}
