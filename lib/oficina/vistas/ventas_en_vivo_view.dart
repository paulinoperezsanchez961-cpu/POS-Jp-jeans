import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/api_service.dart';

class VentasEnVivoView extends StatefulWidget {
  const VentasEnVivoView({super.key});

  @override
  State<VentasEnVivoView> createState() => _VentasEnVivoViewState();
}

class _VentasEnVivoViewState extends State<VentasEnVivoView> {
  List<dynamic> _ventasHoy = [];
  bool _cargando = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarVentasReales();
    // 🚨 AUTO-REFRESH: Se actualiza solo cada 30 segundos
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _cargarVentasReales(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarVentasReales({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    
    final datos = await ApiService.obtenerVentasEnVivo();
    
    if (mounted) {
      setState(() {
        _ventasHoy = datos;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    // Calcular el total vendido HOY en vivo
    double totalHoy = 0;
    for (var v in _ventasHoy) {
      totalHoy += double.tryParse(v['monto'].toString()) ?? 0;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MONITOR DE VENTAS EN VIVO', style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                      const SizedBox(height: 4),
                      const Text('Todas las transacciones de hoy. Se actualiza automáticamente cada 30s.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('FORZAR REFRESH'),
                  onPressed: () => _cargarVentasReales(),
                )
              ],
            ),
            const SizedBox(height: 20),
            
            // 🚨 TARJETA DE TOTAL ACUMULADO HOY
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('INGRESO BRUTO HOY:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text('\$${totalHoy.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Expanded(
              child: _cargando && _ventasHoy.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _ventasHoy.isEmpty
                  ? const Center(child: Text("Aún no hay ventas registradas el día de hoy.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
                  : ListView.separated(
                      itemCount: _ventasHoy.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final v = _ventasHoy[index];
                        final String tipo = v['tipo'] ?? '';
                        final String desc = v['descripcion'] ?? '';
                        final double monto = double.tryParse(v['monto'].toString()) ?? 0;
                        final String hora = v['hora_fmt'] ?? '';

                        // Asignamos colores visuales por tipo de movimiento
                        Color colorIcono = Colors.blue;
                        IconData icono = Icons.shopping_bag;
                        if (tipo == 'VENTA_POS') { colorIcono = Colors.green; icono = Icons.point_of_sale; }
                        else if (tipo.contains('APARTADO')) { colorIcono = Colors.orange; icono = Icons.bookmark; }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: colorIcono.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(icono, color: colorIcono, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(tipo.replaceAll('_', ' '), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: colorIcono)),
                                        const SizedBox(width: 10),
                                        Text('⌚ $hora', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // 🚨 Aquí se muestra el SKU, modelo, talla y vendedor
                                    Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('\$${monto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        );
                      },
                    )
            )
          ],
        ),
      ),
    );
  }
}