import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ConfiguracionOficinaView extends StatefulWidget {
  const ConfiguracionOficinaView({super.key});

  @override
  State<ConfiguracionOficinaView> createState() => _ConfiguracionOficinaViewState();
}

class _ConfiguracionOficinaViewState extends State<ConfiguracionOficinaView> {
  final TextEditingController _clavePosCtrl = TextEditingController();
  final TextEditingController _claveOficinaCtrl = TextEditingController();
  bool _actualizando = false;

  Future<void> _actualizarClaves() async {
    final clavePos = _clavePosCtrl.text.trim();
    final claveOficina = _claveOficinaCtrl.text.trim();

    if (clavePos.isEmpty && claveOficina.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe al menos una contraseña para actualizar'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _actualizando = true);
    final sm = ScaffoldMessenger.of(context);

    bool exito = await ApiService.cambiarClaves(clavePos, claveOficina);

    if (!mounted) return;

    if (exito) {
      sm.showSnackBar(const SnackBar(content: Text('Contraseñas actualizadas con éxito'), backgroundColor: Colors.green));
      _clavePosCtrl.clear();
      _claveOficinaCtrl.clear();
    } else {
      sm.showSnackBar(const SnackBar(content: Text('Error al actualizar las contraseñas'), backgroundColor: Colors.red));
    }
    
    if (mounted) setState(() => _actualizando = false);
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AJUSTES Y SEGURIDAD', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
              const SizedBox(height: 30),
              
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 400,
                    child: _panelAjustes(
                      'PERSONALIDAD IA', 
                      'Define cómo debe comportarse tu Copiloto.', 
                      Colors.deepPurple,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TextField(maxLines: 3, decoration: InputDecoration(hintText: 'Ej: Eres la IA Ejecutiva de JP Jeans...', border: OutlineInputBorder(), isDense: true)),
                          const SizedBox(height: 10),
                          SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white), onPressed: () {}, child: const Text('GUARDAR CEREBRO'))),
                        ],
                      )
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 400,
                    child: _panelAjustes(
                      'SEGURIDAD MAESTRA', 
                      'Cambia las contraseñas de acceso al sistema.', 
                      Colors.red,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(controller: _clavePosCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva Contraseña Cajero (POS)', border: OutlineInputBorder(), isDense: true)),
                          const SizedBox(height: 10),
                          TextField(controller: _claveOficinaCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva Contraseña Director (Oficina)', border: OutlineInputBorder(), isDense: true)),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity, 
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
                              onPressed: _actualizando ? null : _actualizarClaves, 
                              child: _actualizando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('ACTUALIZAR CLAVES')
                            )
                          ),
                        ],
                      )
                    ),
                  )
                ],
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelAjustes(String titulo, String subtitulo, Color colorLinea, Widget contenido) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 6, height: 250, decoration: BoxDecoration(color: colorLinea, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: colorLinea, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(subtitulo, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  contenido
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}