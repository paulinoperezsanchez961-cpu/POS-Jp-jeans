import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DashboardEstadisticasView extends StatefulWidget {
  const DashboardEstadisticasView({super.key});

  @override
  State<DashboardEstadisticasView> createState() =>
      _DashboardEstadisticasViewState();
}

class _DashboardEstadisticasViewState extends State<DashboardEstadisticasView> {
  bool _cargando = true;
  bool _generandoReporte = false;

  int _diasFiltro = 1;

  // Métricas Financieras Exactas
  double _ingresosReales = 0.0;
  double _gastosReales = 0.0;
  double _gastosFijosCalculados = 0.0;
  double _totalEfectivo = 0.0;
  double _totalTarjeta = 0.0;
  double _totalTransferencia = 0.0;

  // Métricas Operativas Exactas
  int _piezasVendidas = 0;
  int _totalApartados = 0;
  int _totalCambios = 0;
  int _stockBodegaActual = 0;

  // Análisis de Rendimiento
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

  String _formatearFechaBD(DateTime fecha) {
    return '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cargarMetricasRigurosas() async {
    setState(() => _cargando = true);

    try {
      DateTime hoy = DateTime.now();
      String fFin = _formatearFechaBD(hoy);
      String fInicio;

      if (_diasFiltro == 1) {
        fInicio = fFin;
      } else if (_diasFiltro > 1) {
        fInicio = _formatearFechaBD(
          hoy.subtract(Duration(days: _diasFiltro - 1)),
        );
      } else {
        fInicio = '2000-01-01';
        fFin = '2100-01-01';
      }

      final ventas = await ApiService.obtenerVentasEnVivo(
        fechaInicio: fInicio,
        fechaFin: fFin,
      );
      final cortes = await ApiService.obtenerHistorialCortes();
      final fijos = await ApiService.obtenerGastosFijos();
      final inventario = await ApiService.obtenerInventario();

      double sumIngresosBrutos = 0,
          sumGastosComisiones = 0,
          sumGastosCortes = 0;
      double sumEf = 0, sumTar = 0, sumTrans = 0;
      int sumPiezas = 0, sumApartados = 0, sumCambios = 0, stockTotal = 0;

      Map<String, int> mapVendedores = {};
      Map<String, int> mapTallas = {};
      Map<String, int> mapProductos = {};
      Map<String, double> mapDias = {};
      Map<String, double> mapHoras = {};

      for (var p in inventario) {
        stockTotal += int.tryParse(p['stock_bodega'].toString()) ?? 0;
      }

      for (var v in ventas) {
        double monto = double.tryParse(v['monto'].toString()) ?? 0;
        String metodo = v['metodo_pago'] ?? 'Efectivo';
        String tipo = v['tipo'] ?? '';
        String desc = v['descripcion'] ?? '';
        int cant = int.tryParse(v['cantidad'].toString()) ?? 0;
        String fechaFmt = v['fecha_fmt'] ?? '';
        String horaFmt = v['hora_fmt'] ?? '';

        if (monto > 0) {
          sumIngresosBrutos += monto;

          try {
            var partes = fechaFmt.split('/');
            if (partes.length == 3) {
              DateTime d = DateTime(
                int.parse(partes[2]),
                int.parse(partes[1]),
                int.parse(partes[0]),
              );
              final diasSemana = [
                "Lunes",
                "Martes",
                "Miércoles",
                "Jueves",
                "Viernes",
                "Sábado",
                "Domingo",
              ];
              String diaStr = diasSemana[d.weekday - 1];
              mapDias[diaStr] = (mapDias[diaStr] ?? 0) + monto;
            }
          } catch (e) {
            debugPrint('Aviso fecha: $e');
          }

          try {
            String horaCorta =
                '${horaFmt.split(':')[0]} ${horaFmt.split(' ')[1]}';
            mapHoras[horaCorta] = (mapHoras[horaCorta] ?? 0) + monto;
          } catch (e) {
            debugPrint('Aviso hora: $e');
          }
        } else if (monto < 0) {
          sumGastosComisiones += monto.abs();
        }

        if (metodo.contains('Tarjeta')) {
          sumTar += monto;
        } else if (metodo.contains('Transferencia')) {
          sumTrans += monto;
        } else {
          // 🚨 NOTA MATEMÁTICA: Si es un gasto de comisión, el monto es negativo y restará automáticamente al sumEf.
          sumEf += monto;
        }

        if (tipo == 'VENTA_POS' || tipo == 'ENGANCHE_APARTADO') {
          sumPiezas += cant;

          String vendedor = "Mostrador";
          if (desc.contains('| Vendedor:')) {
            String despuesVendedor = desc.split('| Vendedor:')[1];
            vendedor = despuesVendedor.split('|')[0].trim();
          }
          mapVendedores[vendedor] = (mapVendedores[vendedor] ?? 0) + cant;

          RegExp extractor = RegExp(
            r'(\d+)x\s*\[SKU:\s*(.*?)\]\s*(.*?)\s*\((?:Talla|Talla:)\s*(.*?)\)',
          );
          var matches = extractor.allMatches(desc);
          for (var m in matches) {
            int q = int.tryParse(m.group(1) ?? '1') ?? 1;
            String sku = m.group(2) ?? 'SD';
            String nom = m.group(3)?.trim() ?? '';
            String talla = m.group(4) ?? 'UNICA';
            String llaveProducto = "$sku - $nom";

            mapTallas[talla] = (mapTallas[talla] ?? 0) + q;
            mapProductos[llaveProducto] =
                (mapProductos[llaveProducto] ?? 0) + q;
          }
        } else if (tipo == 'CAMBIO_FISICO') {
          sumCambios++;
        }

        if (tipo == 'ENGANCHE_APARTADO') {
          sumApartados++;
        }
      }

      for (var c in cortes) {
        DateTime? fechaCorte;
        try {
          if (c['fecha_corte'] != null) {
            fechaCorte = DateTime.parse(c['fecha_corte'].toString());
          }
        } catch (e) {
          debugPrint('Aviso parseo corte: $e');
        }

        if (fechaCorte != null) {
          String fechaCorteDB = _formatearFechaBD(fechaCorte);
          bool enRango = false;

          if (_diasFiltro == -1) {
            enRango = true;
          } else {
            if (fechaCorteDB.compareTo(fInicio) >= 0 &&
                fechaCorteDB.compareTo(fFin) <= 0) {
              enRango = true;
            }
          }

          if (enRango) {
            double g = double.tryParse(c['gastos_totales'].toString()) ?? 0;
            sumGastosCortes += g;
          }
        }
      }

      // 🚨 CÁLCULO MAESTRO ANTI-DUPLICIDAD
      // sumGastosComisiones: Son las comisiones en VIVO (que ya restaron a sumEf).
      // sumGastosCortes: Son TODOS los gastos reportados al final del día (Comisiones + Comidas + Limpieza, etc).
      // La diferencia entre ambos nos da los "Gastos Extra" que NO eran comisiones.
      double gastosExtrasCaja = sumGastosCortes - sumGastosComisiones;
      if (gastosExtrasCaja < 0) gastosExtrasCaja = 0.0;

      sumEf -=
          gastosExtrasCaja; // Restamos únicamente los gastos adicionales físicos

      double sumFijosSemanales = 0;
      for (var f in fijos) {
        sumFijosSemanales += double.tryParse(f['monto'].toString()) ?? 0;
      }

      double fijosCalculados = 0;
      if (_diasFiltro > 0) {
        fijosCalculados = (sumFijosSemanales / 7.0) * _diasFiltro;
      } else {
        fijosCalculados = (sumFijosSemanales / 7.0) * mapDias.length;
      }

      String mDia = "N/A";
      double maxVentaDia = 0;
      mapDias.forEach((key, value) {
        if (value > maxVentaDia) {
          maxVentaDia = value;
          mDia = key;
        }
      });

      String mHora = "N/A";
      double maxVentaHora = 0;
      mapHoras.forEach((key, value) {
        if (value > maxVentaHora) {
          maxVentaHora = value;
          mHora = key;
        }
      });

      if (mounted) {
        setState(() {
          _ingresosReales = sumIngresosBrutos;
          _gastosReales =
              sumGastosComisiones +
              gastosExtrasCaja; // Los gastos operativos reales
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

          _ventasPorVendedor = Map.fromEntries(
            mapVendedores.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)),
          );
          _tallasVendidas = Map.fromEntries(
            mapTallas.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)),
          );
          _productosMasVendidos = Map.fromEntries(
            mapProductos.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)),
          );

          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error al calcular métricas: $e");
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _pedirReporteIA() async {
    setState(() => _generandoReporte = true);
    double neto = _ingresosReales - _gastosReales - _gastosFijosCalculados;

    String strVendedores = _ventasPorVendedor.entries
        .map((e) => "${e.key}: ${e.value} pzs")
        .join(", ");
    String strTallas = _tallasVendidas.entries
        .map((e) => "${e.key}: ${e.value} pzs")
        .join(", ");
    String strTopProductos = _productosMasVendidos.entries
        .take(5)
        .map((e) => "${e.key} (${e.value} pzs)")
        .join(", ");

    String promptRiguroso =
        """
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
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.deepPurple),
            SizedBox(width: 10),
            Text('INFORME EJECUTIVO IA'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Text(
              respuesta,
              style: const TextStyle(height: 1.5, fontSize: 14),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    double neto = _ingresosReales - _gastosReales - _gastosFijosCalculados;

    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    Widget botonesAccion = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButton<int>(
            value: _diasFiltro,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: 1,
                child: Text(
                  'Solo Hoy (1D)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              DropdownMenuItem(
                value: 7,
                child: Text(
                  'Últimos 7 Días',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              DropdownMenuItem(
                value: 30,
                child: Text(
                  'Último Mes (30D)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              DropdownMenuItem(
                value: -1,
                child: Text(
                  'Histórico Completo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _diasFiltro = val);
                _cargarMetricasRigurosas();
              }
            },
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
          icon: _generandoReporte
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.auto_awesome, size: 16),
          label: Text(
            _generandoReporte ? 'ANALIZANDO...' : 'INFORME IA',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: _generandoReporte ? null : _pedirReporteIA,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // 🚨 Protege contra los bordes curvos de celulares modernos
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PANEL DE CONTROL AVANZADO',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Auditoría rigurosa y exacta del flujo de efectivo, stock y rendimiento.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (!isMobile) const SizedBox(width: 20),
                    if (!isMobile) botonesAccion,
                  ],
                ),
                if (isMobile) ...[const SizedBox(height: 16), botonesAccion],

                const SizedBox(height: 30),

                // SECCIÓN 1: FINANZAS Y MÉTODOS DE PAGO
                const Text(
                  '1. FLUJO FINANCIERO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: isMobile ? 2 : 5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isMobile ? 1.5 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMetricCard(
                      'INGRESOS BRUTOS',
                      '\$${_ingresosReales.toStringAsFixed(2)}',
                      Colors.black,
                      Colors.grey.shade100,
                      Icons.trending_up,
                      isHero: true,
                    ),
                    _buildMetricCard(
                      'EFECTIVO FÍSICO',
                      '\$${_totalEfectivo.toStringAsFixed(2)}',
                      Colors.green.shade700,
                      Colors.white,
                      Icons.money,
                    ),
                    _buildMetricCard(
                      'TARJETA (MP)',
                      '\$${_totalTarjeta.toStringAsFixed(2)}',
                      Colors.blue.shade700,
                      Colors.white,
                      Icons.credit_card,
                    ),
                    _buildMetricCard(
                      'TRANSFERENCIA',
                      '\$${_totalTransferencia.toStringAsFixed(2)}',
                      Colors.purple.shade700,
                      Colors.white,
                      Icons.account_balance,
                    ),
                    _buildMetricCard(
                      'UTILIDAD NETA',
                      '\$${neto.toStringAsFixed(2)}',
                      Colors.indigo.shade800,
                      Colors.indigo.shade50,
                      Icons.verified,
                      isHero: true,
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // SECCIÓN 2: OPERACIÓN Y BODEGA
                const Text(
                  '2. OPERACIÓN E INVENTARIO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: isMobile ? 2 : 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isMobile ? 1.5 : 2.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMetricCard(
                      'PIEZAS VENDIDAS',
                      '$_piezasVendidas',
                      Colors.orange.shade700,
                      Colors.orange.shade50,
                      Icons.checkroom,
                    ),
                    _buildMetricCard(
                      'STOCK BODEGA',
                      '$_stockBodegaActual',
                      Colors.teal.shade700,
                      Colors.teal.shade50,
                      Icons.inventory,
                    ),
                    _buildMetricCard(
                      'NUEVOS APARTADOS',
                      '$_totalApartados',
                      Colors.pink.shade700,
                      Colors.white,
                      Icons.shopping_bag,
                    ),
                    _buildMetricCard(
                      'CAMBIOS FÍSICOS',
                      '$_totalCambios',
                      Colors.red.shade700,
                      Colors.white,
                      Icons.swap_horiz,
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // SECCIÓN 3: MAPAS DE RENDIMIENTO
                if (isMobile) ...[
                  _buildListCard(
                    '🏆 VENDEDORES',
                    _ventasPorVendedor,
                    Icons.person,
                    Colors.amber.shade700,
                  ),
                  const SizedBox(height: 16),
                  _buildListCard(
                    '📏 TALLAS (Pzs)',
                    _tallasVendidas,
                    Icons.straighten,
                    Colors.cyan.shade700,
                  ),
                  const SizedBox(height: 16),
                  _buildHorarioPicoCard(),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildListCard(
                          '🏆 VENDEDORES',
                          _ventasPorVendedor,
                          Icons.person,
                          Colors.amber.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildListCard(
                          '📏 TALLAS (Pzs)',
                          _tallasVendidas,
                          Icons.straighten,
                          Colors.cyan.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildHorarioPicoCard()),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                _buildListCard(
                  '🔥 TOP 5 PRODUCTOS (SKU)',
                  _productosMasVendidos,
                  Icons.star,
                  Colors.red.shade700,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorarioPicoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time_filled,
                size: 18,
                color: Colors.brown.shade700,
              ),
              const SizedBox(width: 8),
              const Text(
                'HORARIOS PICO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Mejor Día de Venta:',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          Text(
            _mejorDia.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.brown.shade800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hora de Mayor Flujo:',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          Text(
            _mejorHora,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.brown.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    Color colorVal,
    Color bg,
    IconData icon, {
    bool isHero = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHero ? colorVal : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isHero ? colorVal : Colors.grey,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: colorVal, size: 18),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isHero ? 28 : 20,
                fontWeight: FontWeight.w900,
                color: colorVal,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(
    String title,
    Map<String, int> datos,
    IconData icon,
    Color colorTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorTheme),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (datos.isEmpty)
            const Text(
              'Sin datos registrados en este periodo.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...datos.entries
                .take(5)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${e.value} pzs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: colorTheme,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
