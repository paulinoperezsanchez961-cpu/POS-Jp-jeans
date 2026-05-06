import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class RegistroVipView extends StatefulWidget {
  const RegistroVipView({super.key});

  @override
  State<RegistroVipView> createState() => _RegistroVipViewState();
}

class _RegistroVipViewState extends State<RegistroVipView> {
  // Controladores Registro
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // Variables Ruleta
  String _nivelRuleta = 'todos';
  bool _girandoRuleta = false;

  Future<void> _registrarCliente() async {
    final nombre = _nombreController.text.trim();
    final telefono = _telefonoController.text.trim();
    final email = _emailController.text.trim();

    if (nombre.isEmpty || telefono.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, llena todos los campos.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final sm = ScaffoldMessenger.of(context);

    try {
      var res = await ApiService.registrarVIP(nombre, email, telefono);

      if (!mounted) return;

      if (res['exito'] == true) {
        sm.showSnackBar(
          const SnackBar(
            content: Text(
              '✅ VIP Registrado. Tarjeta digital enviada con éxito.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _nombreController.clear();
        _telefonoController.clear();
        _emailController.clear();
      } else {
        sm.showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${res['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(
        const SnackBar(
          content: Text('Error de red al conectar con el Cerebro.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _girarRuleta() async {
    setState(() => _girandoRuleta = true);

    final sm = ScaffoldMessenger.of(context);

    try {
      final res = await ApiService.sortearVIP(_nivelRuleta);

      // Simulamos suspenso en la tienda
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      if (res['exito'] == true) {
        _mostrarDialogoGanador(res['ganador']);
      } else {
        sm.showSnackBar(
          SnackBar(
            content: Text('❌ ${res['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(
        const SnackBar(
          content: Text('Error al conectar con la ruleta.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _girandoRuleta = false);
    }
  }

  void _mostrarDialogoGanador(Map<String, dynamic> ganador) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: const Text(
          '🎉 ¡TENEMOS UN GANADOR!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 60),
            const SizedBox(height: 15),
            Text(
              ganador['nombre'].toString().toUpperCase(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              'Nivel: ${ganador['nivel_vip'].toString().toUpperCase()}',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(ganador['email'], style: const TextStyle(color: Colors.blue)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '¡Felicidades!',
              style: TextStyle(letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget panelRegistro = Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium, size: 60, color: Colors.amber),
          const SizedBox(height: 10),
          const Text(
            'NUEVO CLIENTE VIP',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Registra al cliente para enviarle su Tarjeta Plata al instante con su bono de bienvenida.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _nombreController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre Completo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
              filled: true,
              fillColor: Color(0xFFF9F9F9),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono (WhatsApp)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_android),
              filled: true,
              fillColor: Color(0xFFF9F9F9),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo Electrónico',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
              filled: true,
              fillColor: Color(0xFFF9F9F9),
            ),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isLoading ? null : _registrarCliente,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'CREAR TARJETA VIP',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );

    Widget panelRuleta = Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF333333)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.casino, color: Colors.amber, size: 70),
          const SizedBox(height: 15),
          const Text(
            'SORTEO EN TIENDA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Elige un nivel y presiona el botón para seleccionar a un cliente al azar y darle una sorpresa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Nivel:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _nivelRuleta,
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'todos',
                        child: Text(
                          'Todos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DropdownMenuItem(value: 'plata', child: Text('Plata')),
                      DropdownMenuItem(value: 'oro', child: Text('Oro')),
                      DropdownMenuItem(
                        value: 'titanio',
                        child: Text('Titanio'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _nivelRuleta = v!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 60,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 10,
              ),
              onPressed: _girandoRuleta ? null : _girarRuleta,
              child: _girandoRuleta
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      'GIRAR RULETA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: isMobile
              ? Column(
                  children: [
                    panelRegistro,
                    const SizedBox(height: 24),
                    panelRuleta,
                  ],
                )
              : Row(
                  // 🚨 CORRECCIÓN: Cambiado a start para que Flutter no intente estirarlo hasta el infinito
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: panelRegistro),
                    const SizedBox(width: 24),
                    Expanded(child: panelRuleta),
                  ],
                ),
        ),
      ),
    );
  }
}
