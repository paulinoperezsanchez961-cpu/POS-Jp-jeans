import 'package:flutter/material.dart';
import 'dart:convert'; 
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; 

// ============================================================================
// MÓDULO MAESTRO: OFICINA CENTRAL JP JEANS
// ============================================================================
class ModuloOficina extends StatefulWidget {
  const ModuloOficina({super.key});

  @override
  State<ModuloOficina> createState() => _ModuloOficinaState();
}

class _ModuloOficinaState extends State<ModuloOficina> {
  int _index = 0;

  void _cambiarPestana(int nuevaPestana) {
    setState(() {
      _index = nuevaPestana;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    final List<Widget> vistas = [
      const DashboardEstadisticasView(), 
      const InventarioOficinaView(),     
      const ContabilidadCortesView(),    
      const PromotoresVendedoresView(),  
      const InteligenciaArtificialView(),
      const ConfiguracionOficinaView(),  
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: isMobile ? BottomNavigationBar(
        currentIndex: _index,
        onTap: _cambiarPestana,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'DASHBOARD'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'STOCK'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'CORTES'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'VENDEDORES'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'IA'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'AJUSTES'),
        ],
      ) : null,
      body: Row(
        children: [
          if (!isMobile) NavigationRail(
            backgroundColor: const Color(0xFF1E1E1E),
            selectedIndex: _index,
            onDestinationSelected: _cambiarPestana,
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.analytics_outlined), label: Text('DASHBOARD')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('INVENTARIO')),
              NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: Text('CONTABILIDAD')),
              NavigationRailDestination(icon: Icon(Icons.groups_outlined), label: Text('VENDEDORES')),
              NavigationRailDestination(icon: Icon(Icons.auto_awesome), label: Text('CEREBRO IA')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('AJUSTES')),
            ],
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: vistas,
            )
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 1: DASHBOARD Y ESTADÍSTICAS (CONECTADO A IA)
// ============================================================================
class DashboardEstadisticasView extends StatefulWidget {
  const DashboardEstadisticasView({super.key});

  @override
  State<DashboardEstadisticasView> createState() => _DashboardEstadisticasViewState();
}

class _DashboardEstadisticasViewState extends State<DashboardEstadisticasView> {
  bool _generandoReporte = false;

  Future<void> _pedirReporteIA() async {
    setState(() => _generandoReporte = true);
    
    final respuesta = await ApiService.preguntarALaIA("Dame un resumen ejecutivo super corto (3 líneas máximo) de cómo va el negocio hoy, mencionando ventas o pendientes.");
    
    if (!mounted) return;
    setState(() => _generandoReporte = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [Icon(Icons.auto_awesome, color: Colors.deepPurple), SizedBox(width: 10), Text('REPORTE EJECUTIVO')]),
        content: Text(respuesta, style: const TextStyle(height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget tarjetasMetricas = isMobile
      ? Column(
          children: [
            _buildMetricCard('INGRESOS (MES)', '\$145,230.00', Colors.green.shade600, Colors.green.shade50, Icons.trending_up, isHero: true),
            const SizedBox(height: 16),
            _buildMetricCard('GASTOS', '\$12,150.00', Colors.red.shade500, Colors.white, Icons.trending_down),
            const SizedBox(height: 16),
            _buildMetricCard('CRECIMIENTO', '+18%', Colors.blue.shade600, Colors.white, Icons.rocket_launch),
          ],
        )
      : Row(
          children: [
            Expanded(flex: 2, child: _buildMetricCard('INGRESOS TOTALES (MES)', '\$145,230.00', Colors.green.shade600, Colors.green.shade50, Icons.trending_up, isHero: true)),
            const SizedBox(width: 20),
            Expanded(flex: 1, child: _buildMetricCard('GASTOS OPERATIVOS', '\$12,150.00', Colors.red.shade500, Colors.white, Icons.trending_down)),
            const SizedBox(width: 20),
            Expanded(flex: 1, child: _buildMetricCard('CRECIMIENTO', '+18%', Colors.blue.shade600, Colors.white, Icons.rocket_launch)),
          ],
        );

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
                      const Text('Visión general del rendimiento de JP Jeans.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20)),
                    icon: _generandoReporte 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(_generandoReporte ? 'PENSANDO...' : 'REPORTE IA', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _generandoReporte ? null : _pedirReporteIA,
                  )
                ],
              ),
              const SizedBox(height: 30),
              
              tarjetasMetricas,
              
              const SizedBox(height: 30),
              
              Container(
                width: double.infinity,
                height: 300, 
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 80, color: Colors.black12),
                      SizedBox(height: 16),
                      Text('ZONA DE GRÁFICOS FL_CHART', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      Text('Aquí se mostrará la evolución de ingresos vs gastos.', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHero ? colorVal : Colors.grey, letterSpacing: 1), overflow: TextOverflow.ellipsis)), 
              Icon(icon, color: colorVal, size: 18)
            ]
          ),
          SizedBox(height: isHero ? 20 : 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: isHero ? 36 : 24, fontWeight: FontWeight.w900, color: colorVal, letterSpacing: -1)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 2: INVENTARIO Y STOCK CENTRALIZADO (LIGADO A LA API)
// ============================================================================
class InventarioOficinaView extends StatefulWidget {
  const InventarioOficinaView({super.key});

  @override
  State<InventarioOficinaView> createState() => _InventarioOficinaViewState();
}

class _InventarioOficinaViewState extends State<InventarioOficinaView> {
  List<dynamic> _stockReal = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final datos = await ApiService.obtenerInventario();
    if (!mounted) return;
    setState(() {
      _stockReal = datos;
      _cargando = false;
    });
  }

  void _eliminarProducto(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ACCIÓN NO PERMITIDA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Por seguridad, la eliminación y gestión de drops del producto ${_stockReal[index]['sku']} debe realizarse desde el E-commerce Manager.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          )
        ],
      )
    );
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AUDITORÍA DE INVENTARIO', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                      const SizedBox(height: 8),
                      const Text('Supervisa todo lo pre-registrado desde los mostradores.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                if (!isMobile)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text('${_stockReal.length} MODELOS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  )
              ],
            ),
            const SizedBox(height: 30),
            
            Expanded(
              child: _cargando 
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _stockReal.isEmpty 
                  ? const Center(child: Text("No hay productos pre-registrados en inventario", style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _cargarDatos,
                      color: Colors.black,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                        child: ListView.separated(
                          itemCount: _stockReal.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final prod = _stockReal[index];
                            
                            final String nombre = prod['nombre'] ?? 'Sin nombre';
                            final String corte = prod['sku'] ?? 'N/A';
                            final int totalModelo = prod['stock_bodega'] ?? 0;
                            final int estadoWeb = prod['estado_web'] ?? 0;
                            
                            List<dynamic> tallasRaw = [];
                            if (prod['tallas'] != null) {
                              if (prod['tallas'] is String) {
                                tallasRaw = jsonDecode(prod['tallas']);
                              } else {
                                tallasRaw = prod['tallas'];
                              }
                            }

                            final String fotoDb = prod['url_foto_principal'] ?? '';
                            final String fotoUrl = fotoDb.isNotEmpty 
                                ? 'https://api.jpjeansvip.com$fotoDb' 
                                : "https://picsum.photos/200?random=$index"; 

                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: isMobile 
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 50, height: 50, color: Colors.grey.shade200, child: const Icon(Icons.checkroom, color: Colors.grey)))),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                Text('SKU: $corte', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('$totalModelo pzs', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => _eliminarProducto(index), padding: EdgeInsets.zero, constraints: const BoxConstraints())
                                            ],
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Wrap(
                                              spacing: 8, runSpacing: 8,
                                              children: tallasRaw.map((e) {
                                                bool agotado = (e['stock'] ?? 0) == 0;
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: agotado ? Colors.red.shade50 : Colors.green.shade50, border: Border.all(color: agotado ? Colors.red.shade200 : Colors.green.shade200), borderRadius: BorderRadius.circular(4)),
                                                  child: Text('${e['talla']}: ${e['stock']} pz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: agotado ? Colors.red : Colors.green)),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(color: estadoWeb == 1 ? Colors.blue.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                                            child: Text(estadoWeb == 1 ? 'EN LÍNEA' : 'BORRADOR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: estadoWeb == 1 ? Colors.blue : Colors.orange.shade800, letterSpacing: 1)),
                                          )
                                        ],
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 60, color: Colors.grey.shade200, child: const Icon(Icons.checkroom, color: Colors.grey)))),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: estadoWeb == 1 ? Colors.blue.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(estadoWeb == 1 ? 'EN LÍNEA' : 'BORRADOR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: estadoWeb == 1 ? Colors.blue : Colors.orange.shade800, letterSpacing: 1)),
                                                )
                                              ],
                                            ),
                                            Text('SKU/Corte: $corte', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Wrap(
                                          spacing: 8, runSpacing: 8,
                                          children: tallasRaw.map((e) {
                                            bool agotado = (e['stock'] ?? 0) == 0;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: agotado ? Colors.red.shade50 : Colors.green.shade50, border: Border.all(color: agotado ? Colors.red.shade200 : Colors.green.shade200), borderRadius: BorderRadius.circular(4)),
                                              child: Text('${e['talla']}: ${e['stock']} pz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: agotado ? Colors.red : Colors.green)),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('$totalModelo pzs', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 5),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                                            icon: const Icon(Icons.delete_outline, size: 14),
                                            label: const Text('ELIMINAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            onPressed: () => _eliminarProducto(index),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                            );
                          },
                        ),
                      ),
                    )
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 3: CONTABILIDAD (Historial de Cortes de Caja REAL)
// ============================================================================
class ContabilidadCortesView extends StatefulWidget {
  const ContabilidadCortesView({super.key});

  @override
  State<ContabilidadCortesView> createState() => _ContabilidadCortesViewState();
}

class _ContabilidadCortesViewState extends State<ContabilidadCortesView> {
  List<dynamic> _historialCortes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCortes();
  }

  Future<void> _cargarCortes() async {
    setState(() => _cargando = true);
    final datos = await ApiService.obtenerHistorialCortes();
    if (!mounted) return;
    setState(() {
      _historialCortes = datos;
      _cargando = false;
    });
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONTABILIDAD Y CIERRES', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                    const SizedBox(height: 8),
                    const Text('Historial detallado de los cortes de caja realizados en mostrador.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _cargarCortes, 
                  icon: const Icon(Icons.refresh, size: 14), 
                  label: const Text('ACTUALIZAR')
                )
              ],
            ),
            const SizedBox(height: 30),
            
            Expanded(
              child: Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HISTORIAL DE CORTES (BD REAL)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    const Divider(height: 30),
                    Expanded(
                      child: _cargando 
                      ? const Center(child: CircularProgressIndicator(color: Colors.black))
                      : _historialCortes.isEmpty
                        ? const Center(child: Text("Aún no se han registrado cortes de caja", style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: _historialCortes.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final c = _historialCortes[index];
                              final ventas = double.tryParse(c['ventas_totales'].toString()) ?? 0;
                              final gastos = double.tryParse(c['gastos_totales'].toString()) ?? 0;
                              final neto = ventas - gastos;
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: isMobile 
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(c['fecha_formateada'] ?? 'Sin fecha', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)), child: Text('\$${neto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12))),
                                        ],
                                      ),
                                      Text('Cajero: ${c['cajero']}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Ventas: +\$${ventas.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                          Text('Gastos: -\$${gastos.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                                        ],
                                      )
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c['fecha_formateada'] ?? 'Sin fecha', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text('Cajero: ${c['cajero']}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Ventas Totales', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                              Text('+\$${ventas.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                            ],
                                          ),
                                          const SizedBox(width: 20),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Gastos', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                              Text('-\$${gastos.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                            ],
                                          ),
                                          const SizedBox(width: 30),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                                            child: Column(
                                              children: [
                                                const Text('NETO EN CAJA', style: TextStyle(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold)),
                                                Text('\$${neto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                                              ],
                                            ),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                              );
                            },
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
}

// ============================================================================
// 🚨 VISTA 4: VENDEDORES Y CÓDIGOS DE CREADOR (CONECTADO A LA API)
// ============================================================================
class PromotoresVendedoresView extends StatefulWidget {
  const PromotoresVendedoresView({super.key});

  @override
  State<PromotoresVendedoresView> createState() => _PromotoresVendedoresViewState();
}

class _PromotoresVendedoresViewState extends State<PromotoresVendedoresView> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _comisionController = TextEditingController();

  List<dynamic> _vendedoresDB = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarVendedores();
  }

  Future<void> _cargarVendedores() async {
    setState(() => _cargando = true);
    
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/oficina/vendedores'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['exito']) {
          if (mounted) {
            setState(() {
              _vendedoresDB = data['vendedores'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error al cargar vendedores: $e");
    }
    
    if (mounted) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _registrarVendedor() async {
    if (_nombreController.text.isEmpty || _codigoController.text.isEmpty || _comisionController.text.isEmpty) return;
    
    final nombre = _nombreController.text.trim();
    final codigo = _codigoController.text.trim().toUpperCase();
    final comision = double.tryParse(_comisionController.text) ?? 0;

    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/oficina/vendedores'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nombre": nombre,
          "codigo_creador": codigo,
          "comision_porcentaje": comision
        })
      );

      if (!mounted) return; 

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Vendedor registrado. Listo para vender.'), backgroundColor: Colors.green));
        _nombreController.clear(); _codigoController.clear(); _comisionController.clear();
        _cargarVendedores(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error al registrar. Revisa los datos.'), backgroundColor: Colors.red));
      }
    } catch (e) {
       if (!mounted) return; 
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error de conexión.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget panelAlta = Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ALTA DE VENDEDOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 20),
          TextField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9))),
          const SizedBox(height: 16),
          TextField(controller: _codigoController, decoration: const InputDecoration(labelText: 'Código Único (Ej. JUAN_JP)', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9))),
          const SizedBox(height: 16),
          TextField(controller: _comisionController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% Comisión (Ej. 15)', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9))),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 45, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: _registrarVendedor, child: const Text('REGISTRAR EN BD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))))
        ],
      ),
    );

    Widget panelLista = Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('COMISIONES ACUMULADAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1))),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)), 
                icon: const Icon(Icons.refresh, size: 14), 
                label: const Text('RECARGAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), 
                onPressed: _cargarVendedores
              )
            ],
          ),
          const Divider(height: 30),
          _cargando 
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : _vendedoresDB.isEmpty
              ? const Center(child: Text('No hay vendedores registrados', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _vendedoresDB.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final v = _vendedoresDB[index];
                    final double totalGenerado = double.tryParse(v['ventas_totales'].toString()) ?? 0.0;
                    final double comisionPorcentaje = double.tryParse(v['comision'].toString()) ?? 0.0;
                    final comisionPagar = totalGenerado * (comisionPorcentaje / 100);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Código: ${v['codigo_creador']} | Com: $comisionPorcentaje%', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Ventas: \$${totalGenerado.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)), child: Text('A Pagar: \$${comisionPagar.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12))),
                                ],
                              )
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Código: ${v['codigo_creador']} | Comisión: $comisionPorcentaje%', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Ventas Generadas', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                      Text('\$${totalGenerado.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                    ],
                                  ),
                                  const SizedBox(width: 30),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(8)),
                                    child: Column(
                                      children: [
                                        const Text('COMISIÓN A PAGAR', style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold)),
                                        Text('\$${comisionPagar.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
                                      ],
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                    );
                  },
                )
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GESTIÓN DE VENDEDORES', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
              const SizedBox(height: 8),
              const Text('Da de alta a promotores y revisa sus comisiones. BD en Tiempo Real.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 30),
              if (isMobile) ...[
                panelAlta,
                const SizedBox(height: 20),
                panelLista,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: panelAlta),
                    const SizedBox(width: 32),
                    Expanded(flex: 2, child: panelLista),
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 5: CEREBRO IA (CHAT CON GEMINI CONECTADO AL SERVIDOR)
// ============================================================================
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
      "texto": "Hola Jefe. Soy la IA Ejecutiva de JP Jeans. Estoy conectada a tu inventario y metricas en tiempo real. ¿Que analizamos hoy?", 
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

  Future<void> _enviarMensaje() async {
    final String pregunta = _mensajeController.text.trim();
    if (pregunta.isEmpty) return;

    setState(() {
      _mensajes.add({"texto": pregunta, "esUsuario": true});
      _estaCargando = true;
    });
    _mensajeController.clear();
    _hacerScrollAlFondo();

    final String respuesta = await ApiService.preguntarALaIA(pregunta);

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

// ============================================================================
// 🚨 VISTA 6: CONFIGURACIÓN Y AJUSTES
// ============================================================================
class ConfiguracionOficinaView extends StatelessWidget {
  const ConfiguracionOficinaView({super.key});

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
                          const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Contraseña Cajero (POS)', border: OutlineInputBorder(), isDense: true)),
                          const SizedBox(height: 10),
                          const TextField(obscureText: true, decoration: InputDecoration(labelText: 'Contraseña Director (Oficina)', border: OutlineInputBorder(), isDense: true)),
                          const SizedBox(height: 10),
                          SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () {}, child: const Text('ACTUALIZAR CLAVES'))),
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