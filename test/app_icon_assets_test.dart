import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validação de Ativos de Ícone do Aplicativo (EcoMonitor Muda & PSA)', () {
    test('Arquivos mestre em assets/icon existem e possuem conteúdo válido', () {
      final masterFiles = [
        'assets/icon/app_icon.png',
        'assets/icon/app_icon_foreground.png',
        'assets/icon/app_icon_background.png',
        'assets/icon/app_icon_monochrome.png',
      ];

      for (final path in masterFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Arquivo $path deve existir');
        expect(file.lengthSync(), greaterThan(1000),
            reason: 'Arquivo $path deve possuir tamanho superior a 1KB');
      }
    });

    test('Estrutura de ícones Android gerada corretamente com suporte adaptativo e monocromático', () {
      final androidMipmaps = [
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ];

      for (final path in androidMipmaps) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Arquivo Android $path deve existir');
        expect(file.lengthSync(), greaterThan(50),
            reason: 'Arquivo Android $path não pode estar vazio');
      }

      // Valida declaração XML do ícone adaptativo e monocromático
      final adaptiveXml = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
      expect(adaptiveXml.contains('adaptive-icon'), isTrue);
      expect(adaptiveXml.contains('ic_launcher_background'), isTrue);
      expect(adaptiveXml.contains('ic_launcher_foreground'), isTrue);
      expect(adaptiveXml.contains('ic_launcher_monochrome'), isTrue);
    });

    test('Estrutura de ícones Web e Favicon gerada com sucesso', () {
      final webFiles = [
        'web/favicon.png',
        'web/icons/Icon-192.png',
        'web/icons/Icon-512.png',
        'web/icons/Icon-maskable-192.png',
        'web/icons/Icon-maskable-512.png',
        'web/manifest.json',
      ];

      for (final path in webFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'Arquivo Web $path deve existir');
        expect(file.lengthSync(), greaterThan(50),
            reason: 'Arquivo Web $path não pode estar vazio');
      }

      final manifest = File('web/manifest.json').readAsStringSync();
      expect(manifest.contains('EcoMonitor'), isTrue);
      expect(manifest.contains('#1B5E20'), isTrue);
    });
  });
}
