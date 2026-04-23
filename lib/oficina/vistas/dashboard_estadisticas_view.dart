import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class DashboardEstadisticasView extends StatefulWidget {
  const DashboardEstadisticasView({super.key});

  @override
  State<DashboardEstadisticasView> createState() => _DashboardEstadisticasViewState();
}

class _DashboardEstadisticasViewState extends State<DashboardEstadisticasView> {
  bool _cargando = true;
  bool _generandoReporte = false;
  
  int _diasFiltro = 7; 

  // Métricas Financieras
  double _ingresosReales = 0.0;
  double _gastosReales = 0.0;
  double _gastosFijosCalculados = 0.0;
  double _totalEfectivo = 0.0;
  double _totalTarjeta = 0.0;
  double _totalTransferencia = 0.0;

  // Métricas Operativas
  int _piezasVendidas = 0;
  int _totalApartados = 0;
  int _totalCambios = 0;
  int _stockBodegaActual = 0;

  // Análisis de Tiempo y Rendimiento
  Map<String, int> _ventasPorVendedor = {};
  Map<String, int> _tallasVendidas = {};
  Map<String, int> _productosMasVendidos = {};
  String _mejorDia = "N/A";
  String _mejorHora = "N/A";

  @override
  void initState() {
    super.initState();
    _cargarMetricasRigurosas();
  }

  Future<void> _cargarMetricasRigurosas() async {
    setState(() => _cargando = true);
    
    try {
      final cortes = await ApiService.obtenerHistorialCortes();
      final fijos = await ApiService.obtenerGastosFijos();
      final inventario = await ApiService.obtenerInventario();
      
      // Contadores Financieros y Operativos
      double sumVentas = 0, sumGastos = 0, sumEf = 0, sumTar = 0, sumTrans = 0;
      int sumPiezas = 0, sumApartados = 0, sumCambios = 0, stockTotal = 0;
      
      // Mapas de Análisis
      Map<String, int> mapVendedores = {};
      Map<String, int> mapTallas = {};
      Map<String, int> mapProductos = {};
      Map<String, double> mapDias = {};
      Map<String, double> mapHoras = {};

      final diasSemana = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
      DateTime hoy = DateTime.now();

      // 1. Calcular Stock Actual Total
      for (var p in inventario) {
        stockTotal += int.tryParse(p['stock_bodega'].toString()) ?? 0;
      }

      // 2. Analizar Cortes de Caja (Linea por Linea)
      for (var c in cortes) {
        DateTime? fechaCorte;
        try {
          if (c['fecha_corte'] != null) {
            fechaCorte = DateTime.parse(c['fecha_corte'].toString());
          }
        } catch(e) { 
          debugPrint('Aviso al parsear fecha del corte: $e'); 
        }

        if (fechaCorte != null) {
          int diferenciaDias = hoy.difference(fechaCorte).inDays;
          
          if (_diasFiltro == -1 || diferenciaDias <= _diasFiltro) {
            double ventasDelCorte = double.tryParse(c['ventas_totales'].toString()) ?? 0;
            
            sumVentas += ventasDelCorte;
            sumGastos += double.tryParse(c['gastos_totales'].toString()) ?? 0;
            sumEf += double.tryParse(c['ventas_efectivo']?.toString() ?? '0') ?? 0;
            sumTar += double.tryParse(c['ventas_tarjeta']?.toString() ?? '0') ?? 0;
            sumTrans += double.tryParse(c['ventas_transferencia']?.toString() ?? '0') ?? 0;

            // Análisis de Tiempo (Mejor Día y Hora basados en Volumen de Venta)
            String diaStr = diasSemana[fechaCorte.weekday - 1];
            String horaStr = "${fechaCorte.hour.toString().padLeft(2, '0')}:00 hrs";
            mapDias[diaStr] = (mapDias[diaStr] ?? 0) + ventasDelCorte;
            mapHoras[horaStr] = (mapHoras[horaStr] ?? 0) + ventasDelCorte;

            // Extraer JSON de Detalles Riguroso
            Map<String, dynamic> jsonDetalles = {};
            try { 
              jsonDetalles = jsonDecode(c['detalles'] ?? '{}'); 
            } catch(e) {
              debugPrint('Aviso JSON de detalles: $e');
            }

            List items = jsonDetalles['items'] ?? [];
            List apartados = jsonDetalles['apartados'] ?? [];
            List cambios = jsonDetalles['cambios'] ?? [];

            sumApartados += apartados.length;
            sumCambios += cambios.length;

            // Analizador profundo de tickets
            for (var item in items) {
              int cantidadGral = int.tryParse(item['cantidad']?.toString() ?? '1') ?? 1;
              sumPiezas += cantidadGral;

              String stringTicket = item['nombre']?.toString() ?? '';
              
              // A. Separar Vendedor
              String vendedor = "Mostrador";
              if (stringTicket.contains('| Vendedor:')) {
                vendedor = stringTicket.split('| Vendedor:')[1].trim();
              }
              mapVendedores[vendedor] = (mapVendedores[vendedor] ?? 0) + cantidadGral;

              // B. Extraer Tallas y SKUs con Expresiones Regulares
              RegExp extractor = RegExp(r'(\d+)x\s*\[SKU:\s*(.*?)\]\s*(.*?)\s*\(Talla:\s*(.*?)\)');
              var matches = extractor.allMatches(stringTicket);
              
              for (var m in matches) {
                int cantidadPieza = int.tryParse(m.group(1) ?? '1') ?? 1;
                String skuProd = m.group(2) ?? 'SD';
                String nombreCorto = m.group(3)?.trim() ?? '';
                String tallaPieza = m.group(4) ?? 'UNICA';

                String llaveProducto = "$skuProd - $nombreCorto";

                mapTallas[tallaPieza] = (mapTallas[tallaPieza] ?? 0) + cantidadPieza;
                mapProductos[llaveProducto] = (mapProductos[llaveProducto] ?? 0) + cantidadPieza;
              }
            }
          }
        }
      }

      // 3. Proporción de Gastos Fijos
      double sumFijosSemanales = 0;
      for(var f in fijos) { sumFijosSemanales += double.tryParse(f['monto'].toString()) ?? 0; }

      double fijosCalculados = 0;
      if (_diasFiltro > 0) {
        fijosCalculados = (sumFijosSemanales / 7.0) * _diasFiltro;
      } else {
        if (cortes.isNotEmpty) {
          try {
            DateTime primerCorte = DateTime.parse(cortes.last['fecha_corte'].toString());
            int diasTotales = hoy.difference(primerCorte).inDays;
            if (diasTotales < 1) diasTotales = 1;
            fijosCalculados = (sumFijosSemanales / 7.0) * diasTotales;
          } catch(e) {
            debugPrint('Aviso cálculo gastos: $e');
          }
        }
      }

      // Determinar Mejor Día y Hora
      String mDia = "N/A"; double maxVentaDia = 0;
      mapDias.forEach((key, value) { if(value > maxVentaDia) { maxVentaDia = value; mDia = key; } });
      
      String mHora = "N/A"; double maxVentaHora = 0;
      mapHoras.forEach((key, value) { if(value > maxVentaHora) { maxVentaHora = value; mHora = key; } });

      if (mounted) {
        setState(() {
          _ingresosReales = sumVentas;
          _gastosReales = sumGastos;
          _gastosFijosCalculados = fijosCalculados;
          _totalEfectivo = sumEf;
          _totalTarjeta = sumTar;
          _totalTransferencia = sumTrans;
          _piezasVendidas = sumPiezas;
          _totalApartados = sumApartados;
          _totalCambios = sumCambios;
          _stockBodegaActual = stockTotal;
          _mejorDia = mDia;
          _mejorHora = mHora;
          
          // Ordenar mapas de mayor a menor venta
          _ventasPorVendedor = Map.fromEntries(mapVendedores.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
          _tallasVendidas = Map.fromEntries(mapTallas.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
          _productosMasVendidos = Map.fromEntries(mapProductos.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
          
          _cargando = false;
        });
      }
    } catch (e) { 
      debugPrint("Error al calcular métricas: $e"); 
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _pedirReporteIA() async {
    setState(() => _generandoReporte = true);
    double neto = _ingresosReales - _gastosReales - _gastosFijosCalculados;

    String strVendedores = _ventasPorVendedor.entries.map((e) => "${e.key}: ${e.value} pzs").join(", ");
    String strTallas = _tallasVendidas.entries.map((e) => "${e.key}: ${e.value} pzs").join(", ");
    String strTopProductos = _productosMasVendidos.entries.take(5).map((e) => "${e.key} (${e.value} pzs)").join(", ");

    String promptRiguroso = """
    Eres el Gerente Financiero de JP Jeans. Eres analítico, directo y altamente riguroso.
    Analiza este volcado exacto de datos operativos de los últimos $_diasFiltro días y genera un INFORME EJECUTIVO PROFUNDO (máximo 4 párrafos, usa viñetas). 
    Debes mencionar el flujo de dinero (Efectivo vs Tarjeta vs Transferencia), la eficiencia del stock, horas pico y recomendaciones de reabastecimiento en base a las tallas.

    *** DATOS FINANCIEROS ***
    - Ingresos Brutos: \$${_ingresosReales.toStringAsFixed(2)}
    - Desglose -> Efectivo: \$${_totalEfectivo.toStringAsFixed(2)} | Tarjeta (MP): \$${_totalTarjeta.toStringAsFixed(2)} | Transferencias: \$${_totalTransferencia.toStringAsFixed(2)}
    - Gastos de Operación: \$${(_gastosReales + _gastosFijosCalculados).toStringAsFixed(2)}
    - UTILIDAD NETA: \$${neto.toStringAsFixed(2)}

    *** DATOS OPERATIVOS Y STOCK ***
    - Prendas Vendidas: $_piezasVendidas.
    - Stock Actual Bodega: $_stockBodegaActual piezas.
    - Nuevos Apartados: $_totalApartados.
    - Cambios Físicos: $_totalCambios.
    - Mejor Día de Ventas: $_mejorDia
    - Hora Pico de Flujo: $_mejorHora

    *** RENDIMIENTO ESPECÍFICO ***
    - Ventas por Vendedor: $strVendedores
    - Tallas más vendidas: $strTallas
    - Top 5 Productos Estrella: $strTopProductos
    """;

    final respuesta = await ApiService.preguntarALaIA(promptRiguroso);
    
    if (!mounted) return; 
    setState(() => _generandoReporte = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [Icon(Icons.auto_awesome, color: Colors.deepPurple), SizedBox(width: 10), Text('INFORME EJECUTIVO IA')]),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(child: Text(respuesta, style: const TextStyle(height: 1.5, fontSize: 14))),
        ),
        actions: [ ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('ENTENDIDO')) ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    double neto = _ingresosReales - _gastosReales - _gastosFijosCalculados;

    if (_cargando) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: SingleChildScrollView(
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
                      Text('PANEL DE CONTROL AVANZADO', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                      const SizedBox(height: 4),
                      const Text('Auditoría rigurosa de flujo de efectivo, stock y rendimiento.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
                        child: DropdownButton<int>(
                          value: _diasFiltro,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Último Día (Hoy)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 7, child: Text('Última Semana (7D)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 30, child: Text('Último Mes (30D)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: -1, child: Text('Histórico Completo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) { if (val != null) { setState(() => _diasFiltro = val); _cargarMetricasRigurosas(); } },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20)),
                        icon: _generandoReporte ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_generandoReporte ? 'ANALIZANDO...' : 'INFORME IA', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _generandoReporte ? null : _pedirReporteIA,
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 30),
              
              // SECCIÓN 1: FINANZAS Y MÉTODOS DE PAGO
              const Text('1. FLUJO FINANCIERO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.black54)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: isMobile ? 2 : 5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isMobile ? 1.5 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricCard('INGRESOS BRUTOS', '\$${_ingresosReales.toStringAsFixed(2)}', Colors.black, Colors.grey.shade100, Icons.trending_up, isHero: true),
                  _buildMetricCard('EFECTIVO', '\$${_totalEfectivo.toStringAsFixed(2)}', Colors.green.shade700, Colors.white, Icons.money),
                  _buildMetricCard('TARJETA (MP)', '\$${_totalTarjeta.toStringAsFixed(2)}', Colors.blue.shade700, Colors.white, Icons.credit_card),
                  _buildMetricCard('TRANSFERENCIA', '\$${_totalTransferencia.toStringAsFixed(2)}', Colors.purple.shade700, Colors.white, Icons.account_balance),
                  _buildMetricCard('UTILIDAD NETA', '\$${neto.toStringAsFixed(2)}', Colors.indigo.shade800, Colors.indigo.shade50, Icons.verified, isHero: true),
                ],
              ),
              
              const SizedBox(height: 30),

              // SECCIÓN 2: OPERACIÓN Y BODEGA
              const Text('2. OPERACIÓN E INVENTARIO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.black54)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: isMobile ? 2 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isMobile ? 1.5 : 2.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricCard('PIEZAS VENDIDAS', '$_piezasVendidas', Colors.orange.shade700, Colors.orange.shade50, Icons.checkroom),
                  _buildMetricCard('STOCK BODEGA', '$_stockBodegaActual', Colors.teal.shade700, Colors.teal.shade50, Icons.inventory),
                  _buildMetricCard('NUEVOS APARTADOS', '$_totalApartados', Colors.pink.shade700, Colors.white, Icons.shopping_bag),
                  _buildMetricCard('CAMBIOS FÍSICOS', '$_totalCambios', Colors.red.shade700, Colors.white, Icons.swap_horiz),
                ],
              ),

              const SizedBox(height: 30),

              // SECCIÓN 3: MAPAS DE RENDIMIENTO
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildListCard('🏆 VENDEDORES', _ventasPorVendedor, Icons.person, Colors.amber.shade700)
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildListCard('📏 TALLAS (Pzs)', _tallasVendidas, Icons.straighten, Colors.cyan.shade700)
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time_filled, size: 18, color: Colors.brown.shade700),
                              const SizedBox(width: 8),
                              const Text('HORARIOS PICO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ],
                          ),
                          const Divider(height: 24),
                          Text('Mejor Día de Venta:', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          Text(_mejorDia.toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.brown.shade800)),
                          const SizedBox(height: 16),
                          Text('Hora de Mayor Flujo:', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          Text(_mejorHora, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.brown.shade800)),
                        ],
                      ),
                    )
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildListCard('🔥 TOP 5 PRODUCTOS (SKU)', _productosMasVendidos, Icons.star, Colors.red.shade700),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color colorVal, Color bg, IconData icon, {bool isHero = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isHero ? colorVal : Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHero ? colorVal : Colors.grey, letterSpacing: 1), overflow: TextOverflow.ellipsis)), Icon(icon, color: colorVal, size: 18)]),
          const Spacer(),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: isHero ? 28 : 20, fontWeight: FontWeight.w900, color: colorVal, letterSpacing: -1))),
        ],
      ),
    );
  }

  Widget _buildListCard(String title, Map<String, int> datos, IconData icon, Color colorTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorTheme),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const Divider(height: 24),
          if (datos.isEmpty)
            const Text('Sin datos registrados en este periodo.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))
          else
            ...datos.entries.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  Text('${e.value} pzs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colorTheme)),
                ],
              ),
            )),
        ],
      ),
    );
  }
}