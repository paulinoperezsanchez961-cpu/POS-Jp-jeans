import 'package:flutter/material.dart';
import 'dart:convert'; 
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
          Expanded(child: IndexedStack(index: _index, children: vistas)),
        ],
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 1: DASHBOARD Y ESTADÍSTICAS
// ============================================================================
class DashboardEstadisticasView extends StatefulWidget {
  const DashboardEstadisticasView({super.key});

  @override
  State<DashboardEstadisticasView> createState() => _DashboardEstadisticasViewState();
}

class _DashboardEstadisticasViewState extends State<DashboardEstadisticasView> {
  bool _generandoReporte = false;
  double _ingresosReales = 0.0;
  double _gastosReales = 0.0;
  double _gastosFijosTotales = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarMetricasReales();
  }

  Future<void> _cargarMetricasReales() async {
    try {
      final cortes = await ApiService.obtenerHistorialCortes();
      final fijos = await ApiService.obtenerGastosFijos();
      
      double sumVentas = 0;
      double sumGastos = 0;
      for (var c in cortes) {
        sumVentas += double.tryParse(c['ventas_totales'].toString()) ?? 0;
        sumGastos += double.tryParse(c['gastos_totales'].toString()) ?? 0;
      }

      double sumFijos = 0;
      for(var f in fijos) { sumFijos += double.tryParse(f['monto'].toString()) ?? 0; }

      if (mounted) {
        setState(() {
          _ingresosReales = sumVentas;
          _gastosReales = sumGastos;
          _gastosFijosTotales = sumFijos;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _pedirReporteIA() async {
    setState(() => _generandoReporte = true);
    final respuesta = await ApiService.preguntarALaIA("Dame un resumen ejecutivo super corto (3 líneas máximo) de cómo va el negocio hoy, mencionando que tenemos $_ingresosReales en ingresos y hemos gastado $_gastosReales en caja y $_gastosFijosTotales en fijos.");
    
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
    double neto = _ingresosReales - _gastosReales - _gastosFijosTotales;

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
                      const Text('Métricas descontando gastos operativos y automáticos (renta, luz).', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
              
              if (isMobile) ...[
                _buildMetricCard('INGRESOS TOTALES', '\$${_ingresosReales.toStringAsFixed(2)}', Colors.green.shade600, Colors.green.shade50, Icons.trending_up, isHero: true),
                const SizedBox(height: 16),
                _buildMetricCard('GASTOS DE CAJA', '\$${_gastosReales.toStringAsFixed(2)}', Colors.orange.shade500, Colors.white, Icons.receipt_long),
                const SizedBox(height: 16),
                _buildMetricCard('GASTOS FIJOS (MES)', '\$${_gastosFijosTotales.toStringAsFixed(2)}', Colors.red.shade500, Colors.white, Icons.business),
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
                        _buildMetricCard('GASTOS FIJOS (MES)', '\$${_gastosFijosTotales.toStringAsFixed(2)}', Colors.red.shade500, Colors.white, Icons.business),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isHero ? colorVal : Colors.grey, letterSpacing: 1), overflow: TextOverflow.ellipsis)), 
              Icon(icon, color: colorVal, size: 18)
            ]
          ),
          SizedBox(height: isHero ? 20 : 16),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: isHero ? 36 : 24, fontWeight: FontWeight.w900, color: colorVal, letterSpacing: -1))),
        ],
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 2: INVENTARIO Y STOCK CENTRALIZADO (CARGA MASIVA EXCEL)
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
    setState(() { _stockReal = datos; _cargando = false; });
  }

  // 🟢 EXCEL A JSON (PEGADO DIRECTO)
  void _abrirCargaMasiva() {
    TextEditingController excelController = TextEditingController();
    bool procesando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (contextDialog) => StatefulBuilder(
        builder: (contextBuilder, setStateDialog) {
          return AlertDialog(
            title: const Text('Carga Masiva de Pantalones', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 600,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Copia los datos de tu Excel y pégalos aquí. El formato de las columnas debe ser exactamente este:', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 5),
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: const Text('SKU | Nombre Producto | Precio | Tallas (Ej: 28:5, 30:2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blue))),
                  const SizedBox(height: 16),
                  TextField(controller: excelController, maxLines: 10, decoration: const InputDecoration(hintText: "Ejemplo:\nC-2001\tJeans Baggy Negro\t550.00\t28:10, 30:5\nC-2002\tPantalón Cargo\t600.00\t32:3, 34:2", border: OutlineInputBorder(), fillColor: Color(0xFFF9F9F9), filled: true)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text('Cerrar', style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                icon: procesando ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.upload_file, size: 16),
                label: Text(procesando ? 'SUBIENDO...' : 'PROCESAR Y SUBIR'),
                onPressed: procesando ? null : () async {
                  String texto = excelController.text.trim();
                  if (texto.isEmpty) return;

                  setStateDialog(() => procesando = true);
                  List<Map<String, dynamic>> productosAEnviar = [];
                  List<String> filas = texto.split('\n');

                  for (String fila in filas) {
                    if (fila.trim().isEmpty) continue;
                    List<String> cols = fila.split('\t'); 
                    if (cols.length >= 4) {
                      String sku = cols[0].trim();
                      String nombre = cols[1].trim();
                      double precio = double.tryParse(cols[2].trim()) ?? 0;
                      
                      List<Map<String, dynamic>> tallasJson = [];
                      int stockTotal = 0;
                      List<String> paresTalla = cols[3].split(',');
                      for (String par in paresTalla) {
                        List<String> kv = par.split(':');
                        if (kv.length == 2) {
                          int cant = int.tryParse(kv[1].trim()) ?? 0;
                          tallasJson.add({"talla": kv[0].trim(), "cantidad": cant});
                          stockTotal += cant;
                        }
                      }

                      productosAEnviar.add({"sku": sku, "nombre_interno": nombre, "precio": precio, "tallas": tallasJson, "stock_total": stockTotal});
                    }
                  }

                  // 🛡️ BLINDAJE CONTRA AVISOS DE LINTER
                  final nav = Navigator.of(contextDialog);
                  final sm = ScaffoldMessenger.of(context);
                  bool exito = await ApiService.cargaMasivaProductos(productosAEnviar);
                  
                  nav.pop(); // Cierra el diálogo de forma segura
                  
                  if (exito) {
                    sm.showSnackBar(SnackBar(content: Text('¡Se subieron ${productosAEnviar.length} productos con éxito!'), backgroundColor: Colors.green));
                    _cargarDatos();
                  } else {
                    sm.showSnackBar(const SnackBar(content: Text('Error al subir los datos. Revisa el formato.'), backgroundColor: Colors.red));
                  }
                }
              )
            ],
          );
        }
      )
    );
  }

  List<Map<String, dynamic>> _parsearTallasOficina(dynamic tallasRawData) {
    List<dynamic> tallasRaw = [];
    if (tallasRawData != null) {
      if (tallasRawData is String) {
        try { tallasRaw = jsonDecode(tallasRawData); } catch (e) { debugPrint('Aviso: $e'); }
      } else if (tallasRawData is List) {
        tallasRaw = tallasRawData;
      }
    }
    return tallasRaw.map((e) {
      if (e is Map) {
        return {
          'talla': (e['talla'] ?? e['nombre'] ?? 'ÚNICA').toString().trim().toUpperCase(),
          'cantidad': int.tryParse(e['cantidad']?.toString() ?? e['stock']?.toString() ?? '0') ?? 0,
        };
      } else {
        return { 'talla': e.toString().trim().toUpperCase(), 'cantidad': 1 };
      }
    }).toList();
  }

  void _abrirGestorResurtido(Map<String, dynamic> prod) {
    List<Map<String, dynamic>> tallasEnEdicion = _parsearTallasOficina(prod['tallas']);
    TextEditingController nuevaTallaCtrl = TextEditingController();
    TextEditingController nuevaCantCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (contextDialog) {
        return StatefulBuilder(
          builder: (contextBuilder, setStateDialog) {
            int stockTotalCalculado = tallasEnEdicion.fold(0, (sum, item) => sum + (item['cantidad'] as int));

            return AlertDialog(
              title: Text('Resurtir: ${prod['sku']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(child: TextField(controller: nuevaTallaCtrl, decoration: const InputDecoration(labelText: 'Talla', isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: nuevaCantCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pzs', isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true))),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                            onPressed: () {
                              String t = nuevaTallaCtrl.text.trim().toUpperCase();
                              int c = int.tryParse(nuevaCantCtrl.text) ?? 0;
                              if (t.isNotEmpty && c > 0) {
                                setStateDialog(() {
                                  int idx = tallasEnEdicion.indexWhere((element) => element['talla'] == t);
                                  if (idx != -1) {
                                    tallasEnEdicion[idx]['cantidad'] += c;
                                  } else {
                                    tallasEnEdicion.add({'talla': t, 'cantidad': c});
                                  }
                                  nuevaTallaCtrl.clear();
                                  nuevaCantCtrl.clear();
                                });
                              }
                            }
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: tallasEnEdicion.length,
                        itemBuilder: (c, i) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Talla: ${tallasEnEdicion[i]['talla']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => setStateDialog(() { if (tallasEnEdicion[i]['cantidad'] > 0) tallasEnEdicion[i]['cantidad']--; })),
                                SizedBox(width: 30, child: Center(child: Text('${tallasEnEdicion[i]['cantidad']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
                                IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => setStateDialog(() => tallasEnEdicion[i]['cantidad']++)),
                                const SizedBox(width: 10),
                                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => setStateDialog(() => tallasEnEdicion.removeAt(i))),
                              ],
                            )
                          );
                        }
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('STOCK TOTAL:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text('$stockTotalCalculado PZS', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 20)),
                      ],
                    ),
                  ]
                )
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () async {
                    // 🛡️ BLINDAJE
                    final nav = Navigator.of(contextDialog);
                    final sm = ScaffoldMessenger.of(context);
                    
                    bool exito = await ApiService.resurtirProducto(prod['id'], tallasEnEdicion, stockTotalCalculado);
                    nav.pop(); // Cierra seguro
                    
                    if (exito) {
                      sm.showSnackBar(const SnackBar(content: Text('Resurtido exitoso. Stock actualizado.'), backgroundColor: Colors.green));
                      _cargarDatos();
                    } else {
                      sm.showSnackBar(const SnackBar(content: Text('Error al resurtir producto.'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('GUARDAR NUEVO STOCK')
                )
              ]
            );
          }
        );
      }
    );
  }

  Future<void> _eliminarProductoReal(int idProducto) async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar producto?', style: TextStyle(color: Colors.red)),
        content: const Text('Se borrará del sistema y dejará de aparecer en el mostrador y en la tienda web.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('SÍ, ELIMINAR')),
        ],
      )
    );

    if (confirmar == true) {
      try {
        final res = await ApiService.eliminarProducto(idProducto);
        
        // 🚨 EL GUARDIA: Detiene todo si el usuario ya cerró la pantalla
        if (!mounted) return; 

        if (res) {
          // Como ya pasamos el guardia, es 100% seguro usar el context
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado exitosamente'), backgroundColor: Colors.green));
          _cargarDatos();
        }
      } catch (e) {
        // 🚨 EL GUARDIA TAMBIÉN VA AQUÍ: Por si da error de red pero la pantalla ya no existe
        if (!mounted) return; 
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red));
      }
    }
  }

  void _abrirGestorOferta(Map<String, dynamic> prod) {
    bool enRebaja = prod['en_rebaja'] == 1 || prod['en_rebaja'] == true;
    TextEditingController precioOfertaController = TextEditingController(text: prod['precio_rebaja']?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (contextDialog) {
        return StatefulBuilder(
          builder: (contextBuilder, setStateDialog) {
            return AlertDialog(
              title: Text('Gestionar Oferta: ${prod['sku']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Precio Normal: \$${prod['precio_venta']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Activar Rebaja', style: TextStyle(fontWeight: FontWeight.bold)),
                    activeThumbColor: Colors.redAccent,
                    activeTrackColor: Colors.red.shade100,
                    value: enRebaja,
                    onChanged: (val) => setStateDialog(() => enRebaja = val),
                  ),
                  if (enRebaja) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: precioOfertaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Nuevo Precio de Oferta (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_offer, color: Colors.redAccent)),
                    )
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () async {
                    double precioNuevo = double.tryParse(precioOfertaController.text) ?? 0;
                    
                    final nav = Navigator.of(contextDialog);
                    final sm = ScaffoldMessenger.of(context);

                    if (enRebaja && precioNuevo <= 0) {
                      sm.showSnackBar(const SnackBar(content: Text('Ingresa un precio válido'), backgroundColor: Colors.orange));
                      return;
                    }
                    
                    bool exito = await ApiService.actualizarOferta(prod['id'], enRebaja, precioNuevo);
                    nav.pop(); 
                    
                    if(exito){
                       _cargarDatos();
                       sm.showSnackBar(const SnackBar(content: Text('Oferta actualizada'), backgroundColor: Colors.green));
                    }
                  },
                  child: const Text('GUARDAR OFERTA'),
                )
              ],
            );
          }
        );
      }
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
                      const Text('Gestión de stock individual o subida masiva vía Excel.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                  icon: const Icon(Icons.table_chart, size: 16),
                  label: const Text('CARGA MASIVA EXCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                  onPressed: _abrirCargaMasiva,
                )
              ],
            ),
            const SizedBox(height: 30),
            
            Expanded(
              child: _cargando 
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _stockReal.isEmpty 
                  ? const Center(child: Text("No hay productos en inventario", style: TextStyle(color: Colors.grey)))
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
                            bool enRebaja = prod['en_rebaja'] == 1 || prod['en_rebaja'] == true;
                            final String fotoUrl = (prod['url_foto_principal'] ?? '').isNotEmpty ? 'https://api.jpjeansvip.com${prod['url_foto_principal']}' : "https://via.placeholder.com/150"; 

                            Widget botonesAccion = Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                                  icon: const Icon(Icons.add_box, size: 14, color: Colors.green),
                                  label: const Text('RESURTIR', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                  onPressed: () => _abrirGestorResurtido(prod),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                                  icon: const Icon(Icons.local_offer, size: 14, color: Colors.blue),
                                  label: const Text('OFERTAS', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                  onPressed: () => _abrirGestorOferta(prod),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                                  icon: const Icon(Icons.delete_outline, size: 14),
                                  label: const Text('ELIMINAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  onPressed: () => _eliminarProductoReal(prod['id']),
                                ),
                              ],
                            );

                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: isMobile 
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl, width: 50, height: 50, fit: BoxFit.cover)),
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
                                          Text('$totalModelo pzs', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (enRebaja)
                                        Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)), child: const Text('OFERTA ACTIVA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1))),
                                      botonesAccion,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl, width: 60, height: 60, fit: BoxFit.cover)),
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
                                                if (enRebaja)
                                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)), child: const Text('REBAJADO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))
                                              ],
                                            ),
                                            Text('SKU/Corte: $corte', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(enRebaja ? '\$${prod['precio_rebaja']}' : '\$${prod['precio_venta']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: enRebaja ? Colors.redAccent : Colors.black)),
                                            if (enRebaja) Text('\$${prod['precio_venta']}', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('$totalModelo pzs', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 5),
                                          botonesAccion
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
// 🚨 VISTA 3: CONTABILIDAD Y GASTOS FIJOS
// ============================================================================
class ContabilidadCortesView extends StatefulWidget {
  const ContabilidadCortesView({super.key});

  @override
  State<ContabilidadCortesView> createState() => _ContabilidadCortesViewState();
}

class _ContabilidadCortesViewState extends State<ContabilidadCortesView> {
  List<dynamic> _historialCortes = [];
  List<dynamic> _gastosFijos = [];
  bool _cargando = true;

  final TextEditingController _conceptoGastoCtrl = TextEditingController();
  final TextEditingController _montoGastoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    final cortes = await ApiService.obtenerHistorialCortes();
    final gastos = await ApiService.obtenerGastosFijos();
    if (!mounted) return;
    setState(() {
      _historialCortes = cortes;
      _gastosFijos = gastos;
      _cargando = false;
    });
  }

  Future<void> _guardarGastoFijo() async {
    if (_conceptoGastoCtrl.text.isEmpty || _montoGastoCtrl.text.isEmpty) return;
    double monto = double.tryParse(_montoGastoCtrl.text) ?? 0;
    
    final sm = ScaffoldMessenger.of(context);
    bool exito = await ApiService.agregarGastoFijo(_conceptoGastoCtrl.text, monto);
    
    if (exito) {
      _conceptoGastoCtrl.clear(); _montoGastoCtrl.clear();
      _cargarTodo();
      sm.showSnackBar(const SnackBar(content: Text('Gasto agregado'), backgroundColor: Colors.green));
    }
  }

  Future<void> _eliminarGastoFijo(int id) async {
    bool exito = await ApiService.eliminarGastoFijo(id);
    if (exito) _cargarTodo();
  }

  Widget _buildPestanaCortes() {
    return _historialCortes.isEmpty
      ? const Center(child: Text("Aún no se han registrado cortes de caja"))
      : ListView.separated(
          itemCount: _historialCortes.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final c = _historialCortes[index];
            final ventas = double.tryParse(c['ventas_totales'].toString()) ?? 0;
            final gastos = double.tryParse(c['gastos_totales'].toString()) ?? 0;
            final neto = ventas - gastos;
            
            // Extraer detalles si el POS los mandó
            String detallesTxt = "No hay desglose (Versión POS antigua)";
            if (c['detalles'] != null && c['detalles'].toString().trim().isNotEmpty) {
              try {
                var json = jsonDecode(c['detalles']);
                detallesTxt = "Piezas Vendidas: ${json['piezas'] ?? 0} | Cambios: ${json['cambios'] ?? 0} | Apartados: ${json['apartados'] ?? 0}";
              } catch(e){
                debugPrint("Error al decodificar detalles: $e");
              }
            }

            return ExpansionTile(
              title: Text(c['fecha_formateada'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Cajero: ${c['cajero']}  |  NETO: \$${neto.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              children: [
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ventas Brutas: \$${ventas.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                      Text('Gastos de Caja: -\$${gastos.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                      const Divider(),
                      const Text('DESGLOSE DETALLADO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                      const SizedBox(height: 5),
                      Text(detallesTxt, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                )
              ],
            );
          },
        );
  }

  Widget _buildPestanaGastosFijos() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Expanded(flex: 2, child: TextField(controller: _conceptoGastoCtrl, decoration: const InputDecoration(labelText: 'Concepto (Renta, Luz)', isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true))),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: TextField(controller: _montoGastoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '\$ Monto', isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true))),
              const SizedBox(width: 10),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: _guardarGastoFijo, child: const Text('AGREGAR'))
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _gastosFijos.isEmpty 
          ? const Center(child: Text("Sin gastos fijos configurados"))
          : ListView.builder(
              itemCount: _gastosFijos.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(_gastosFijos[i]['concepto'], style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\$${_gastosFijos[i]['monto']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.grey, size: 18), onPressed: () => _eliminarGastoFijo(_gastosFijos[i]['id']))
                  ],
                ),
              )
            )
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                      Text('CONTABILIDAD MAESTRA', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                      const SizedBox(height: 8),
                      const Text('Historial de cortes de caja y gestión de gastos automatizados.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  OutlinedButton.icon(onPressed: _cargarTodo, icon: const Icon(Icons.refresh, size: 14), label: const Text('ACTUALIZAR'))
                ],
              ),
              const SizedBox(height: 20),
              const TabBar(labelColor: Colors.black, indicatorColor: Colors.black, tabs: [Tab(text: 'HISTORIAL DE CORTES'), Tab(text: 'GASTOS AUTOMÁTICOS (FIJOS)')]),
              const SizedBox(height: 20),
              
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                  child: _cargando ? const Center(child: CircularProgressIndicator(color: Colors.black)) : TabBarView(
                    children: [ _buildPestanaCortes(), _buildPestanaGastosFijos() ]
                  )
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 4: VENDEDORES (COMISIONES Y DESCUENTOS EN DINERO EXACTO)
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
  final TextEditingController _descuentoController = TextEditingController(); 

  List<dynamic> _vendedoresDB = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarVendedores();
  }

  Future<void> _cargarVendedores() async {
    setState(() => _cargando = true);
    final datos = await ApiService.obtenerVendedores();
    if (mounted) {
      setState(() {
        _vendedoresDB = datos;
        _cargando = false;
      });
    }
  }

  Future<void> _registrarVendedor() async {
    if (_nombreController.text.isEmpty || _codigoController.text.isEmpty) return;
    
    final nombre = _nombreController.text.trim();
    final codigo = _codigoController.text.trim().toUpperCase();
    final comisionDinero = double.tryParse(_comisionController.text) ?? 0;
    final descuentoDinero = double.tryParse(_descuentoController.text) ?? 0; 

    final sm = ScaffoldMessenger.of(context);
    bool exito = await ApiService.registrarVendedor(nombre, codigo, comisionDinero, descuentoDinero);

    if (exito) {
      sm.showSnackBar(const SnackBar(content: Text('✅ Vendedor registrado.'), backgroundColor: Colors.green));
      _nombreController.clear(); _codigoController.clear(); _comisionController.clear(); _descuentoController.clear();
      _cargarVendedores(); 
    } else {
      sm.showSnackBar(const SnackBar(content: Text('❌ Error al registrar. Revisa los datos.'), backgroundColor: Colors.red));
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
          TextField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9), isDense: true)),
          const SizedBox(height: 12),
          TextField(controller: _codigoController, decoration: const InputDecoration(labelText: 'Código Único (Ej. JUAN_JP)', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9), isDense: true)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _comisionController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '\$ Le pagas/pz', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF0FDF4), isDense: true))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _descuentoController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '\$ Dscto Cliente/pz', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFFEF2F2), isDense: true))),
            ],
          ),
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
              const Expanded(child: Text('DEUDA A PROMOTORES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1))),
              OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)), icon: const Icon(Icons.refresh, size: 14), label: const Text('RECARGAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), onPressed: _cargarVendedores)
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
                    final int piezasVendidas = int.tryParse(v['piezas_vendidas']?.toString() ?? '0') ?? 0;
                    final double comisionPorPieza = double.tryParse(v['comision'].toString()) ?? 0.0;
                    final double descuentoCliente = double.tryParse(v['descuento_cliente']?.toString() ?? '0.0') ?? 0.0;
                    
                    // 🚨 MATEMÁTICA EXACTA BASADA EN PIEZAS
                    final double deudaVendedor = piezasVendidas * comisionPorPieza;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Código: ${v['codigo_creador']}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                              Text('Tú le pagas: \$$comisionPorPieza/pz  |  Cliente ahorra: \$$descuentoCliente/pz', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Piezas Vendidas', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                  Text('$piezasVendidas', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(width: 30),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  children: [
                                    const Text('DEUDA ACTUAL', style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold)),
                                    Text('\$${deudaVendedor.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
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
              const Text('Sistema de comisiones fijas por prenda vendida.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
// 🚨 VISTA 5: CEREBRO IA
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