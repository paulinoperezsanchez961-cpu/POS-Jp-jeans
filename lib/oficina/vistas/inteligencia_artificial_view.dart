import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class InteligenciaArtificialView extends StatefulWidget {
  const InteligenciaArtificialView({super.key});

  @override
  State<InteligenciaArtificialView> createState() =>
      _InteligenciaArtificialViewState();
}

class _InteligenciaArtificialViewState
    extends State<InteligenciaArtificialView> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _estaCargando = false;

  final List<Map<String, dynamic>> _mensajes = [
    {
      "texto":
          "Hola Jefe. Soy la IA Ejecutiva de JP Jeans. He sido actualizada con Visión Total.\n\nAhora leo en tiempo real tu inventario completo (con SKUs y tallas), los cortes de caja y cada venta que entra en el día. Pregúntame lo que quieras.",
      "esUsuario": false,
    },
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

  // 🚨 EL NUEVO CEREBRO: Extrae toda la base de datos y se la pasa a la IA de forma estructurada
  Future<String> _armarContextoProfundo() async {
    try {
      // Descargamos todo al mismo tiempo para que sea ultra rápido
      final resultados = await Future.wait([
        ApiService.obtenerInventario(),
        ApiService.obtenerVentasEnVivo(), // Por defecto trae las de HOY
        ApiService.obtenerHistorialCortes(),
      ]);

      final List<dynamic> inventario = resultados[0];
      final List<dynamic> ventasHoy = resultados[1];
      final List<dynamic> cortes = resultados[2];

      StringBuffer ctx = StringBuffer();

      // Instrucciones directas de sistema para la IA
      ctx.writeln(
        "INSTRUCCIÓN CRÍTICA PARA LA IA: A continuación se te entrega un volcado en tiempo real de la base de datos. DEBES basar tus respuestas estrictamente en esta información. Si el dueño te pregunta por ventas de hoy, analiza los 'MOVIMIENTOS DE HOY'. Si pregunta por prendas, vestidos, pantalones, o stock, busca en el 'INVENTARIO ACTUAL' y dale la cantidad exacta, nombre y SKU.\n",
      );

      // 1. INYECTAR INVENTARIO DETALLADO
      ctx.writeln("--- INVENTARIO ACTUAL ---");
      if (inventario.isEmpty) {
        ctx.writeln("No hay productos en bodega en este momento.");
      } else {
        for (var p in inventario) {
          // Inyectamos SKU, nombre, categoría, stock general y el JSON de las tallas
          ctx.writeln(
            "- SKU: ${p['sku']} | Nombre: ${p['nombre']} | Categoría: ${p['categoria'] ?? 'Sin categoría'} | Stock Total: ${p['stock_bodega']} | Tallas y piezas: ${p['tallas']} | Precio: \$${p['precio_venta']}",
          );
        }
      }

      // 2. INYECTAR VENTAS DE HOY
      ctx.writeln("\n--- MOVIMIENTOS Y VENTAS DE HOY ---");
      if (ventasHoy.isEmpty) {
        ctx.writeln("No se han registrado ventas ni apartados el día de hoy.");
      } else {
        double totalHoy = 0.0;
        for (var v in ventasHoy) {
          ctx.writeln(
            "- [${v['hora_fmt']}] TIPO: ${v['tipo']} | MONTO: \$${v['monto']} (Pagado en: ${v['metodo_pago'] ?? 'Efectivo'}) | DETALLE: ${v['descripcion']}",
          );
          totalHoy += double.tryParse(v['monto'].toString()) ?? 0.0;
        }
        ctx.writeln(
          ">> TOTAL DE DINERO QUE HA ENTRADO HOY: \$${totalHoy.toStringAsFixed(2)}",
        );
      }

      // 3. INYECTAR ÚLTIMOS CORTES
      ctx.writeln("\n--- ÚLTIMOS 3 CORTES DE CAJA ---");
      if (cortes.isEmpty) {
        ctx.writeln("Aún no hay cortes de caja en el historial.");
      } else {
        int limite = cortes.length > 3 ? 3 : cortes.length;
        for (int i = 0; i < limite; i++) {
          var c = cortes[i];
          ctx.writeln(
            "- Fecha: ${c['fecha_formateada']} | Cajero: ${c['cajero']} | Ventas Totales: \$${c['ventas_totales']} (Efectivo: \$${c['ventas_efectivo']}, Tarjeta: \$${c['ventas_tarjeta']}) | Gastos: \$${c['gastos_totales']}",
          );
        }
      }

      ctx.writeln("\n=========================");
      ctx.writeln("CONSULTA EXACTA DEL DUEÑO:");
      return ctx.toString();
    } catch (e) {
      return "Hubo un pequeño error de red al recolectar el volcado de datos. Usa tu conocimiento anterior. CONSULTA DEL DUEÑO: ";
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

    // Ahora armamos el contexto profundo antes de preguntar
    String contextoGigante = await _armarContextoProfundo();
    String preguntaConContexto = contextoGigante + preguntaVisual;

    // Se manda el paquete completo a Gemini
    final String respuesta = await ApiService.preguntarALaIA(
      preguntaConContexto,
    );

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
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.deepPurpleAccent,
                  size: 30,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'CEREBRO IA',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Copiloto de Inteligencia de Negocios en Tiempo Real.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 30),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
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
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.deepPurple,
                              ),
                            ),
                            SizedBox(width: 10),
                            // 🚨 PARCHE: Flexible evita que el texto se desborde en iPhone Mini
                            Flexible(
                              child: Text(
                                "Extrayendo volcado de base de datos y analizando...",
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                              decoration: const InputDecoration(
                                hintText:
                                    'Ej. ¿Cuántos vestidos tenemos y cuáles son sus SKUs?',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Color(0xFFF9F9F9),
                              ),
                              onSubmitted: (_) => _enviarMensaje(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 20,
                              ),
                            ),
                            onPressed: _estaCargando ? null : _enviarMensaje,
                            child: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
            bottomRight: isUser
                ? const Radius.circular(0)
                : const Radius.circular(16),
            topLeft: !isUser
                ? const Radius.circular(0)
                : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser ? Colors.black : Colors.deepPurple.shade100,
          ),
        ),
        child: Text(
          mensaje,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
