import 'package:flutter/material.dart';
import 'screens/home_shell_screen.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      ),
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (!appState.isInitialized) {
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
