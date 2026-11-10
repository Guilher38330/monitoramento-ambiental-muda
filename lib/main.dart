import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'screens/home_shell_screen.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final appState = AppState();
  appState.initialize();
  runApp(MudaPsaApp(appState: appState));
}

class MudaPsaApp extends StatelessWidget {
  final AppState appState;

  const MudaPsaApp({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoramento Muda & PSA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFF00695C),
          surface: const Color(0xFFF3F7F4),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 68,
          indicatorColor: const Color(0xFFC8E6C9),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF37474F),
              letterSpacing: -0.2,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 23,
              color: isSelected ? const Color(0xFF1B5E20) : const Color(0xFF455A64),
            );
          }),
        ),
      ),
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (!appState.isInitialized) {
            if (appState.initError != null) {
              return Scaffold(
                backgroundColor: const Color(0xFFF3F7F4),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFC62828),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Falha ao inicializar banco local',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC62828),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appState.initError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => appState.initialize(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Tentar Novamente'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  appState.resetDatabaseAndReload(),
                              icon: const Icon(Icons.restore_page_rounded),
                              label: const Text('Recriar Banco'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return const Scaffold(
              backgroundColor: Color(0xFFF3F7F4),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1B5E20)),
                    SizedBox(height: 16),
                    Text(
                      'Inicializando banco SQLite local (Projetos Muda & PSA)...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!appState.isAuthenticated) {
            return LoginScreen(appState: appState);
          }

          return HomeShellScreen(appState: appState);
        },
      ),
    );
  }
}
