import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 🚨 IMPORTAMOS LOS MÓDULOS SEPARADOS Y EL API SERVICE
import 'oficina/modulo_oficina.dart';
import 'pos/modulo_pos.dart';
import 'services/api_service.dart'; // IMPORTANTE: Asegúrate de tener este archivo con tu baseUrl

void main() {
  runApp(const JPJeansApp());
}

class JPJeansApp extends StatelessWidget {
  const JPJeansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JP Jeans POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.white,
          surface: Color(0xFFF9F9F9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ============================================================================
// 1. EL GUARDIA DE SEGURIDAD (LOGIN 100% REAL CON BASE DE DATOS)
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
      // 1. Intentamos entrar como ADMINISTRADOR DE OFICINA
      var resOficina = await http.post(
        Uri.parse('${ApiService.baseUrl}/oficina/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"usuario": user, "password": pass})
      );

      if (!mounted) return;

      if (resOficina.statusCode == 200) {
        // Credenciales de Director Correctas
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CentroDeControlAdmin()));
        return;
      }

      // 2. Si no es admin, intentamos entrar como CAJERO POS
      var resCajero = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"usuario": user, "password": pass})
      );

      if (!mounted) return;

      if (resCajero.statusCode == 200) {
        // Credenciales de Cajero Correctas
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MostradorCajero()));
        return;
      }

      // 3. Si ambos fallan, el usuario no existe o la clave está mal
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
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text('JP', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold));
                },
              ),
              const SizedBox(height: 10),
              const Text('JP Jeans', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 2)),
              const Text('SISTEMA CENTRAL', style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 3)),
              const SizedBox(height: 40),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                onSubmitted: (_) => _login(), 
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('ACCEDER', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Conexión encriptada con BD Central', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
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
            tabs: [
              Tab(text: 'MI CENTRO DE CONTROL'),
              Tab(text: 'MOSTRADOR (CAJA)'),
            ],
          ),
        ),
        body: const TabBarView(
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