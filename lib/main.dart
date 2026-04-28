import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 🚨 IMPORTAMOS LOS MÓDULOS SEPARADOS Y EL API SERVICE
import 'oficina/modulo_oficina.dart';
import 'pos/modulo_pos.dart';
import 'services/api_service.dart'; 

void main() {
  // 🚨 Garantiza que los puentes nativos de iOS/Android/Windows estén listos
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JPJeansApp());
}

// ============================================================================
// 🖱️ MOTOR DE SCROLL CROSS-PLATFORM (VITAL PARA WINDOWS Y WEB)
// ============================================================================
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,      // Dedos en iOS/Android
        PointerDeviceKind.mouse,      // Mouse en Windows
        PointerDeviceKind.trackpad,   // Trackpad en Mac/Laptops
      };
}

// ============================================================================
// 🎨 TEMA GLOBAL SOFISTICADO (MATERIAL 3)
// ============================================================================
class JPJeansApp extends StatelessWidget {
  const JPJeansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JP Jeans POS',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(), // Inyectamos el scroll universal
      theme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          surface: const Color(0xFFF6F8FA), // Fondo premium estilo Dashboard
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 1, // Sombra sutil estilo iOS al hacer scroll
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: Colors.black12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        // 🚨 Bloque de CardTheme eliminado para evitar conflictos con el SDK
      ),
      home: const LoginScreen(),
    );
  }
}

// ============================================================================
// 1. EL GUARDIA DE SEGURIDAD (LOGIN OPTIMIZADO PARA TECLADOS MÓVILES)
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa usuario y contraseña'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      var resOficina = await http.post(
        Uri.parse('${ApiService.baseUrl}/oficina/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"usuario": user, "password": pass})
      );

      if (!mounted) return;

      if (resOficina.statusCode == 200) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CentroDeControlAdmin()));
        return;
      }

      var resCajero = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"usuario": user, "password": pass})
      );

      if (!mounted) return;

      if (resCajero.statusCode == 200) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MostradorCajero()));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Credenciales incorrectas o usuario inactivo'), backgroundColor: Colors.red));

    } catch (e) {
      debugPrint("Error de Login: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error de conexión con el servidor (503 o caído)'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 🚨 SafeArea e Inyección de Scroll evitan que el teclado de iOS/Android rompa la pantalla
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 24, spreadRadius: 8, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text('JP', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold));
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('JP Jeans', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, letterSpacing: 2)),
                  const Text('SISTEMA CENTRAL', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 3, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _userController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                    onSubmitted: (_) => _login(), 
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('ACCEDER AL SISTEMA', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Colors.green),
                      SizedBox(width: 6),
                      Text('Conexión encriptada con BD Central', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. ENTORNO DEL DUEÑO (CENTRO DE CONTROL + POS)
// ============================================================================
class CentroDeControlAdmin extends StatelessWidget {
  const CentroDeControlAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('JP Jeans', style: TextStyle(fontWeight: FontWeight.w300, fontSize: 24, letterSpacing: 2)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())))
          ],
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12),
            tabs: [
              Tab(text: 'CENTRO DE CONTROL'),
              Tab(text: 'MOSTRADOR (CAJA)'),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(), // Evita cambiar de módulo por accidente al arrastrar
          children: [
            ModuloOficina(),
            ModuloPOS(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. ENTORNO DEL CAJERO (SOLO POS LOCAL)
// ============================================================================
class MostradorCajero extends StatelessWidget {
  const MostradorCajero({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PUNTO DE VENTA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())))
        ],
      ),
      body: const ModuloPOS(),
    );
  }
}