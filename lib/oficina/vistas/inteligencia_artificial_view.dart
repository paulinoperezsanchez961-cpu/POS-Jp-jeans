import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class InteligenciaArtificialView extends StatefulWidget {
  const InteligenciaArtificialView({super.key});

  @override
  State<InteligenciaArtificialView> createState() => _InteligenciaArtificialViewState();
}

class _InteligenciaArtificialViewState extends State<InteligenciaArtificialView> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _estaCargando = false;

  final List<Map<String, dynamic>> _mensajes = [
    {
      "texto": "Hola Jefe. Soy la IA Ejecutiva de JP Jeans. Ahora estoy conectada directamente a tus bases de datos. Pregúntame sobre tus ventas de la semana, stock o gastos y te daré respuestas 100% exactas.", 
      "esUsuario": false
    }
  ];

  void _hacerScrollAlFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  DateTime? _parsearFecha(String fechaFormateada) {
    try {
      var partes = fechaFormateada.split(' - ')[0].split('/');
      return DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
    } catch(e) { return null; }
  }

  Future<String> _armarContextoReal() async {
    try {
      final cortes = await ApiService.obtenerHistorialCortes();
      final inventario = await ApiService.obtenerInventario();
      
      double ventasSemana = 0;
      double gastosSemana = 0;
      int stockTotal = 0;
      DateTime hoy = DateTime.now();

      for (var c in cortes) {
        DateTime? f = _parsearFecha(c['fecha_formateada'] ?? '');
        if (f != null && hoy.difference(f).inDays <= 7) {
          ventasSemana += double.tryParse(c['ventas_totales'].toString()) ?? 0;
          gastosSemana += double.tryParse(c['gastos_totales'].toString()) ?? 0;
        }
      }
      
      for (var p in inventario) {
        stockTotal += int.tryParse(p['stock_bodega'].toString()) ?? 0;
      }

      // 🚨 SINTAXIS PERFECTA DART 
      return "DATOS REALES DEL NEGOCIO (NO INVENTES NADA, BASATE SOLO EN ESTO): En los últimos 7 días hemos vendido \$${ventasSemana.toStringAsFixed(2)} y gastado en caja \$${gastosSemana.toStringAsFixed(2)}. Tenemos $stockTotal pantalones en bodega en total. \n\n PREGUNTA DEL DUEÑO: ";
    } catch (e) {
      return "PREGUNTA DEL DUEÑO: ";
    }
  }

  Future<void> _enviarMensaje() async {
    final String preguntaVisual = _mensajeController.text.trim();
    if (preguntaVisual.isEmpty) return;

    setState(() {
      _mensajes.add({"texto": preguntaVisual, "esUsuario": true});
      _estaCargando = true;
    });
    _mensajeController.clear();
    _hacerScrollAlFondo();

    String contextoReal = await _armarContextoReal();
    String preguntaConContexto = contextoReal + preguntaVisual;

    final String respuesta = await ApiService.preguntarALaIA(preguntaConContexto);

    if (!mounted) return; 
    setState(() {
      _estaCargando = false;
      _mensajes.add({"texto": respuesta, "esUsuario": false});
    });
    _hacerScrollAlFondo();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent, size: 30),
                const SizedBox(width: 16),
                Text('CEREBRO IA', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Copiloto inteligente conectado a tu BD.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 30),
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.deepPurple.shade100)),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(24),
                        itemCount: _mensajes.length,
                        itemBuilder: (context, index) {
                          final msg = _mensajes[index];
                          return _burbujaChat(msg["texto"], msg["esUsuario"]);
                        },
                      ),
                    ),
                    if (_estaCargando)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple)),
                            SizedBox(width: 10),
                            Text("Analizando datos...", style: TextStyle(color: Colors.deepPurple, fontSize: 12)),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _mensajeController,
                              decoration: const InputDecoration(hintText: 'Escribe tu pregunta...', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9)),
                              onSubmitted: (_) => _enviarMensaje(),
                            )
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20)), 
                            onPressed: _estaCargando ? null : _enviarMensaje, 
                            child: const Icon(Icons.send)
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _burbujaChat(String mensaje, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: isUser ? Colors.black : Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
            topLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: Border.all(color: isUser ? Colors.black : Colors.deepPurple.shade100)
        ),
        child: Text(mensaje, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 13, height: 1.5)),
      ),
    );
  }
}