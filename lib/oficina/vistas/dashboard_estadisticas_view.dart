import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DashboardEstadisticasView extends StatefulWidget {
  const DashboardEstadisticasView({super.key});

  @override
  State<DashboardEstadisticasView> createState() => _DashboardEstadisticasViewState();
}

class _DashboardEstadisticasViewState extends State<DashboardEstadisticasView> {
  bool _generandoReporte = false;
  double _ingresosReales = 0.0;
  double _gastosReales = 0.0;
  double _gastosFijosCalculados = 0.0;
  int _diasFiltro = 7; 

  @override
  void initState() {
    super.initState();
    _cargarMetricasReales();
  }

  DateTime? _parsearFecha(String fechaFormateada) {
    try {
      var partes = fechaFormateada.split(' - ')[0].split('/');
      return DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
    } catch(e) { return null; }
  }

  Future<void> _cargarMetricasReales() async {
    try {
      final cortes = await ApiService.obtenerHistorialCortes();
      final fijos = await ApiService.obtenerGastosFijos();
      
      double sumVentas = 0;
      double sumGastos = 0;
      DateTime hoy = DateTime.now();

      for (var c in cortes) {
        DateTime? fechaCorte = _parsearFecha(c['fecha_formateada'] ?? '');
        if (fechaCorte != null) {
          int diferenciaDias = hoy.difference(fechaCorte).inDays;
          if (_diasFiltro == -1 || diferenciaDias <= _diasFiltro) {
            sumVentas += double.tryParse(c['ventas_totales'].toString()) ?? 0;
            sumGastos += double.tryParse(c['gastos_totales'].toString()) ?? 0;
          }
        }
      }

      double sumFijosSemanales = 0;
      for(var f in fijos) { sumFijosSemanales += double.tryParse(f['monto'].toString()) ?? 0; }

      double fijosCalculados = 0;
      if (_diasFiltro > 0) {
        fijosCalculados = (sumFijosSemanales / 7.0) * _diasFiltro;
      } else {
        if (cortes.isNotEmpty) {
          DateTime? primerCorte = _parsearFecha(cortes.last['fecha_formateada'] ?? '');
          if (primerCorte != null) {
            int diasTotales = hoy.difference(primerCorte).inDays;
            if (diasTotales < 1) diasTotales = 1;
            fijosCalculados = (sumFijosSemanales / 7.0) * diasTotales;
          }
        }
      }

      if (mounted) {
        setState(() {
          _ingresosReales = sumVentas;
          _gastosReales = sumGastos;
          _gastosFijosCalculados = fijosCalculados;
        });
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _pedirReporteIA() async {
    setState(() => _generandoReporte = true);
    
    final respuesta = await ApiService.preguntarALaIA("Dame un resumen ejecutivo super corto (3 líneas máximo) de cómo va el negocio. Estos son los datos de los últimos $_diasFiltro días: INGRESOS \$${_ingresosReales.toStringAsFixed(2)}, GASTOS CAJA \$${_gastosReales.toStringAsFixed(2)}, GASTOS FIJOS \$${_gastosFijosCalculados.toStringAsFixed(2)}.");
    
    if (!mounted) return; 
    setState(() => _generandoReporte = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [Icon(Icons.auto_awesome, color: Colors.deepPurple), SizedBox(width: 10), Text('REPORTE EJECUTIVO')]),
        content: Text(respuesta, style: const TextStyle(height: 1.5)),
        actions: [ ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('ENTENDIDO')) ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    double neto = _ingresosReales - _gastosReales - _gastosFijosCalculados;

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
                      Text('PANEL DE CONTROL', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                      const SizedBox(height: 4),
                      const Text('Métricas de negocio descontando gastos operativos.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                          onChanged: (val) { if (val != null) { setState(() => _diasFiltro = val); _cargarMetricasReales(); } },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20)),
                        icon: _generandoReporte ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_generandoReporte ? 'PENSANDO...' : 'REPORTE IA', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _generandoReporte ? null : _pedirReporteIA,
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 30),
              
              if (isMobile) ...[
                _buildMetricCard('INGRESOS TOTALES', '\$${_ingresosReales.toStringAsFixed(2)}', Colors.green.shade600, Colors.green.shade50, Icons.trending_up, isHero: true),
                const SizedBox(height: 16),
                _buildMetricCard('GASTOS DE CAJA', '\$${_gastosReales.toStringAsFixed(2)}', Colors.orange.shade500, Colors.white, Icons.receipt_long),
                const SizedBox(height: 16),
                _buildMetricCard('GASTOS FIJOS (AJUSTADO)', '\$${_gastosFijosCalculados.toStringAsFixed(2)}', Colors.red.shade500, Colors.white, Icons.business),
                const SizedBox(height: 16),
                _buildMetricCard('NETO ACUMULADO', '\$${neto.toStringAsFixed(2)}', Colors.blue.shade600, Colors.blue.shade50, Icons.account_balance, isHero: true),
              ] else ...[
                Row(
                  children: [
                    Expanded(flex: 2, child: _buildMetricCard('INGRESOS TOTALES', '\$${_ingresosReales.toStringAsFixed(2)}', Colors.green.shade600, Colors.green.shade50, Icons.trending_up, isHero: true)),
                    const SizedBox(width: 20),
                    Expanded(flex: 1, child: Column(
                      children: [
                        _buildMetricCard('GASTOS DE CAJA', '\$${_gastosReales.toStringAsFixed(2)}', Colors.orange.shade500, Colors.white, Icons.receipt_long),
                        const SizedBox(height: 16),
                        _buildMetricCard('GASTOS FIJOS (AJUSTADO)', '\$${_gastosFijosCalculados.toStringAsFixed(2)}', Colors.red.shade500, Colors.white, Icons.business),
                      ],
                    )),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _buildMetricCard('UTILIDAD NETA', '\$${neto.toStringAsFixed(2)}', Colors.blue.shade600, Colors.blue.shade50, Icons.account_balance, isHero: true)),
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color colorVal, Color bg, IconData icon, {bool isHero = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isHero ? 24 : 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isHero ? colorVal.withValues(alpha: 0.3) : Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHero ? colorVal : Colors.grey, letterSpacing: 1), overflow: TextOverflow.ellipsis)), Icon(icon, color: colorVal, size: 18)]),
          SizedBox(height: isHero ? 20 : 16),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: isHero ? 36 : 24, fontWeight: FontWeight.w900, color: colorVal, letterSpacing: -1))),
        ],
      ),
    );
  }
}