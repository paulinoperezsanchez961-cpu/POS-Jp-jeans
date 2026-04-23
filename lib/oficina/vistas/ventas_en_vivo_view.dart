import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/api_service.dart';

class VentasEnVivoView extends StatefulWidget {
  const VentasEnVivoView({super.key});

  @override
  State<VentasEnVivoView> createState() => _VentasEnVivoViewState();
}

class _VentasEnVivoViewState extends State<VentasEnVivoView> {
  List<dynamic> _ventasVisibles = [];
  bool _cargando = true;
  Timer? _timer;
  String _filtroActivo = 'Hoy'; 

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

  String _formatearFechaBD(DateTime fecha) {
    return '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cargarVentasReales({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    
    DateTime hoy = DateTime.now();
    String? fechaInicio;
    String? fechaFin;

    if (_filtroActivo == 'Esta Semana') {
      int diasRestar = hoy.weekday == 7 ? 0 : hoy.weekday;
      DateTime ultimoDomingo = hoy.subtract(Duration(days: diasRestar));
      
      fechaInicio = _formatearFechaBD(ultimoDomingo);
      fechaFin = _formatearFechaBD(hoy);
    } else {
      fechaInicio = _formatearFechaBD(hoy);
      fechaFin = _formatearFechaBD(hoy);
    }

    final datos = await ApiService.obtenerVentasEnVivo(fechaInicio: fechaInicio, fechaFin: fechaFin);
    
    if (mounted) {
      setState(() {
        _ventasVisibles = datos;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    // 🚨 CÁLCULO FINANCIERO RIGUROSO EN VIVO
    double totalPeriodo = 0;
    double totalEfectivo = 0;
    double totalTarjeta = 0;
    double totalTransferencia = 0;

    for (var v in _ventasVisibles) {
      double monto = double.tryParse(v['monto'].toString()) ?? 0;
      String metodo = v['metodo_pago'] ?? 'Efectivo';

      totalPeriodo += monto;
      if (metodo.contains('Tarjeta')) {
        totalTarjeta += monto;
      } else if (metodo.contains('Transferencia')) {
        totalTransferencia += monto;
      } else {
        totalEfectivo += monto;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MONITOR DE VENTAS EN VIVO', style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                    const SizedBox(height: 4),
                    const Text('Todas las transacciones recientes. Se actualiza automáticamente cada 30s.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
                      child: DropdownButton<String>(
                        value: _filtroActivo,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'Hoy', child: Text('Solo Hoy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DropdownMenuItem(value: 'Esta Semana', child: Text('Esta Semana (Desde Domingo)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))),
                        ],
                        onChanged: (val) { if (val != null) { setState(() => _filtroActivo = val); _cargarVentasReales(); } },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('FORZAR REFRESH'),
                      onPressed: () => _cargarVentasReales(),
                    )
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            
            // 🚨 DASHBOARD FINANCIERO EN VIVO (4 COLUMNAS)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_filtroActivo == 'Hoy' ? 'CAJA ACTUAL (HOY)' : 'CAJA ACUMULADA (SEMANA)', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black54)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TOTAL BRUTO', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              FittedBox(fit: BoxFit.scaleDown, child: Text('\$${totalPeriodo.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black))),
                            ],
                          ),
                        )
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('EFECTIVO', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              FittedBox(fit: BoxFit.scaleDown, child: Text('\$${totalEfectivo.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green.shade800))),
                            ],
                          ),
                        )
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TARJETA MP', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              FittedBox(fit: BoxFit.scaleDown, child: Text('\$${totalTarjeta.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue.shade800))),
                            ],
                          ),
                        )
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TRANSF.', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              FittedBox(fit: BoxFit.scaleDown, child: Text('\$${totalTransferencia.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purple.shade800))),
                            ],
                          ),
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Expanded(
              child: _cargando && _ventasVisibles.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _ventasVisibles.isEmpty
                  ? const Center(child: Text("Aún no hay ventas registradas en este periodo.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
                  : ListView.builder(
                      itemCount: _ventasVisibles.length,
                      itemBuilder: (context, index) {
                        final v = _ventasVisibles[index];
                        final String tipo = v['tipo'] ?? '';
                        final String desc = v['descripcion'] ?? '';
                        final double monto = double.tryParse(v['monto'].toString()) ?? 0;
                        final String hora = v['hora_fmt'] ?? '';
                        final String fecha = v['fecha_fmt'] ?? '';
                        final String metodoPago = v['metodo_pago'] ?? 'Efectivo';

                        bool mostrarFecha = false;
                        if (index == 0) {
                          mostrarFecha = true;
                        } else {
                          final String fechaAnterior = _ventasVisibles[index - 1]['fecha_fmt'] ?? '';
                          if (fecha != fechaAnterior) mostrarFecha = true;
                        }

                        // 🚨 SEMÁFORO VISUAL POR TIPO DE MOVIMIENTO
                        Color colorIcono = Colors.grey;
                        IconData icono = Icons.info;
                        
                        if (tipo == 'VENTA_POS') { 
                          colorIcono = Colors.green; 
                          icono = Icons.point_of_sale; 
                        } else if (tipo == 'LIQUIDACION_APARTADO') { 
                          colorIcono = Colors.red; // LIQUIDADO = ROJO
                          icono = Icons.task_alt; 
                        } else if (tipo == 'ABONO_APARTADO') { 
                          colorIcono = Colors.green.shade700; // ABONO = VERDE
                          icono = Icons.payments; 
                        } else if (tipo == 'ENGANCHE_APARTADO') { 
                          colorIcono = Colors.amber.shade700; // NUEVO APARTADO = AMARILLO/ÁMBAR
                          icono = Icons.bookmark; 
                        } else if (tipo == 'CAMBIO_FISICO') { 
                          colorIcono = Colors.purple; 
                          icono = Icons.swap_horiz; 
                        }
                        
                        // 🚨 COLORES PARA ETIQUETAS DE MÉTODO DE PAGO
                        bool esTarjeta = metodoPago.contains('Tarjeta');
                        bool esTransf = metodoPago.contains('Transferencia');
                        
                        Color colorMetodo = Colors.green.shade700;
                        Color bgMetodo = Colors.green.shade50;
                        IconData iconMetodo = Icons.money;

                        if (esTarjeta) {
                          colorMetodo = Colors.blue.shade700;
                          bgMetodo = Colors.blue.shade50;
                          iconMetodo = Icons.credit_card;
                        } else if (esTransf) {
                          colorMetodo = Colors.purple.shade700;
                          bgMetodo = Colors.purple.shade50;
                          iconMetodo = Icons.account_balance;
                        }

                        Widget tarjetaVenta = Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
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
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 5,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(tipo.replaceAll('_', ' '), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: colorIcono)),
                                        Text('⌚ $hora', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                        // ETIQUETA DEL MÉTODO DE PAGO MEJORADA
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: bgMetodo,
                                            border: Border.all(color: colorMetodo.withValues(alpha: 0.5)),
                                            borderRadius: BorderRadius.circular(4)
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(iconMetodo, size: 10, color: colorMetodo),
                                              const SizedBox(width: 4),
                                              Text(metodoPago, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: colorMetodo)),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('\$${monto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        );

                        if (mostrarFecha) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                color: Colors.grey.shade100,
                                child: Text('🗓️ FECHA: $fecha', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87, letterSpacing: 1)),
                              ),
                              tarjetaVenta,
                              if (index != _ventasVisibles.length - 1) const Divider(height: 1),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            tarjetaVenta,
                            if (index != _ventasVisibles.length - 1) const Divider(height: 1),
                          ],
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