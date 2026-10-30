import 'dart:convert';

import 'package:cris_ficha/data/repo.dart';
import 'package:cris_ficha/data/seguranca.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('avaliarSenha', () {
    test('recusa senhas fáceis de adivinhar', () {
      expect(avaliarSenha('').bloqueio, 'Digite uma senha.');
      expect(avaliarSenha('k8#mPq2').bloqueio, contains('8 caracteres'));
      expect(avaliarSenha('aaaaaaaaaa').bloqueio, contains('repita'));
      expect(avaliarSenha('12345678').bloqueio, contains('sequências'));
      expect(avaliarSenha('87654321').bloqueio, contains('sequências'));
      expect(avaliarSenha('qwertyuiop').bloqueio, contains('sequências'));
      expect(avaliarSenha('Senha123!').bloqueio, contains('mais usadas'));
      expect(avaliarSenha('Flamengo2024').bloqueio, contains('mais usadas'));
      expect(avaliarSenha('19992024').bloqueio, contains('letras'));
      expect(avaliarSenha('enzo2024xx', email: 'enzo@exemplo.com').bloqueio, contains('nome'));
      expect(avaliarSenha('xxLeal1999', nome: 'Enzo Leal').bloqueio, contains('nome'));
    });

    test('aceita e mede as outras', () {
      expect(avaliarSenha('k8#mPq2z').serve, isTrue);
      expect(avaliarSenha('velhocasarao').forca, 2);
      expect(avaliarSenha('lanterna corvo sal ponte').forca, 3);
      expect(avaliarSenha('trovejar').forca, 1);
    });
  });

  test('inicioDoToken lê o auth_time do token', () {
    String parte(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    final token = '${parte({'alg': 'RS256'})}.${parte({'auth_time': 1761830000, 'sub': 'u1'})}.assinatura';
    expect(inicioDoToken(token), 1761830000);
    expect(inicioDoToken('lixo'), isNull);
  });

  group('vezesQueVazou', () {
    // SHA-1 de "password": 5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8
    test('manda só o começo do código e compara aqui', () async {
      late http.Request pedido;
      final cliente = MockClient((r) async {
        pedido = r;
        return http.Response('0018A45C4D1DEF81644B54AB7F969B88D65:1\r\n'
            '1E4C9B93F3F0682250B6CF8331B7EE68FD8:9545824\r\n', 200);
      });
      expect(await vezesQueVazou('password', cliente: cliente), 9545824);
      // nada além dos 5 primeiros caracteres do código sai do aparelho
      expect(pedido.url.toString(), 'https://api.pwnedpasswords.com/range/5BAA6');
      expect(pedido.body, isEmpty);
      expect(pedido.headers['Add-Padding'], 'true');
    });

    test('0 quando não aparece, null sem resposta', () async {
      final nenhum = MockClient((_) async => http.Response('0018A45C4D1DEF81644B54AB7F969B88D65:0\r\n', 200));
      expect(await vezesQueVazou('password', cliente: nenhum), 0);
      final fora = MockClient((_) async => http.Response('', 503));
      expect(await vezesQueVazou('password', cliente: fora), isNull);
      final semRede = MockClient((_) async => throw http.ClientException('sem rede'));
      expect(await vezesQueVazou('password', cliente: semRede), isNull);
    });
  });

  test('entradasNovas avisa só de entradas que este aparelho não viu', () async {
    SharedPreferences.setMockInitialValues({'pau.aparelho': 'eu'});
    Repo.authTeste = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
    const eu = Aparelho('eu', 'PC', 'windows', 100, null);
    const cel = Aparelho('cel', 'Celular', 'android', 100, null);
    // a primeira vez só anota o que já existia
    expect(await Seguranca.entradasNovas([eu, cel]), isEmpty);
    expect(await Seguranca.entradasNovas([eu, cel]), isEmpty);
    const outro = Aparelho('x', 'Celular estranho', 'android', 300, null);
    expect((await Seguranca.entradasNovas([eu, cel, outro])).map((a) => a.id), ['x']);
    // o celular conhecido entrou de novo com a senha
    const celDeNovo = Aparelho('cel', 'Celular', 'android', 400, null);
    const euDeNovo = Aparelho('eu', 'PC', 'windows', 400, null);
    expect((await Seguranca.entradasNovas([euDeNovo, celDeNovo, outro])).map((a) => a.id), ['cel']);
  });
}
