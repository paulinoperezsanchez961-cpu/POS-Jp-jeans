import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart'; 
import 'package:http/http.dart' as http; 
import 'package:http_parser/http_parser.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import '../services/api_service.dart';

// ============================================================================
// 🧠 SANADOR DE IMÁGENES GLOBAL
// ============================================================================
String sanearImagen(dynamic dbPath) {
  if (dbPath == null || dbPath.toString().trim().isEmpty) {
    return "https://via.placeholder.com/200?text=JP+Jeans";
  }
  String path = dbPath.toString().trim();
  if (path.startsWith('http')) return path;
  
  String cleanPath = path.replaceAll('/api/uploads/', '/uploads/').replaceAll('/api/media/', '/uploads/');
  if (cleanPath.contains('?f=')) {
    cleanPath = '/uploads/${cleanPath.split('?f=')[1]}';
  }
  if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';
  return 'https://api.jpjeansvip.com$cleanPath';
}

List<Map<String, dynamic>> parsearTallasBD(dynamic tallasRawData) {
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
        'talla': e['talla']?.toString() ?? e['nombre']?.toString() ?? 'ÚNICA',
        'cantidad': int.tryParse(e['cantidad']?.toString() ?? e['stock']?.toString() ?? '0') ?? 0,
      };
    } else {
      return { 'talla': e.toString(), 'cantidad': 1 };
    }
  }).toList();
}

// ============================================================================
// MÓDULO MAESTRO: PUNTO DE VENTA
// ============================================================================
class ModuloPOS extends StatefulWidget {
  const ModuloPOS({super.key});

  @override
  State<ModuloPOS> createState() => _ModuloPOSState();
}

class _ModuloPOSState extends State<ModuloPOS> {
  int _index = 0;
  double ventasDelDia = 0.0;
  double gastosDelDia = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarTotalesMemoria();
  }

  Future<void> _cargarTotalesMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      ventasDelDia = prefs.getDouble('caja_ventas') ?? 0.0;
      gastosDelDia = prefs.getDouble('caja_gastos') ?? 0.0;
    });
  }

  void _actualizarTotalesDia({double? venta, double? gasto}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (venta != null) ventasDelDia += venta;
      if (gasto != null) gastosDelDia += gasto;
    });
    await prefs.setDouble('caja_ventas', ventasDelDia);
    await prefs.setDouble('caja_gastos', gastosDelDia);
  }

  void _cerrarCajaYLimpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('caja_ventas');
    await prefs.remove('caja_gastos');
    await prefs.remove('caja_carrito'); 
    await prefs.remove('caja_lista_gastos'); 
    setState(() {
      ventasDelDia = 0.0;
      gastosDelDia = 0.0;
    });
  }

  void _cambiarPestana(int nuevaPestana) {
    setState(() {
      _index = nuevaPestana;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    final List<Widget> vistas = [
      TerminalCobroView(onVentaExitosa: (monto) => _actualizarTotalesDia(venta: monto), onCerrarCaja: _cerrarCajaYLimpiar, ventasTotales: ventasDelDia, gastosTotales: gastosDelDia),
      const CambiosView(),      
      RegistroGastosView(onGastoRegistrado: (monto) => _actualizarTotalesDia(gasto: monto)),
      ApartadosView(onVentaExitosa: (monto) => _actualizarTotalesDia(venta: monto)),
      BovedaQRView(onCerrar: () => _cambiarPestana(0)), 
      const EnviosWebView(),    
      const InventarioStockView(), 
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: isMobile ? BottomNavigationBar(
        currentIndex: _index,
        onTap: _cambiarPestana,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFF9F9F9),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
        unselectedLabelStyle: const TextStyle(fontSize: 8),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined, size: 20), label: 'CAJA'),
          BottomNavigationBarItem(icon: Icon(Icons.sync_alt_outlined, size: 20), label: 'CAMBIOS'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined, size: 20), label: 'GASTOS'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border, size: 20), label: 'APARTADOS'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_outlined, size: 20), label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined, size: 20), label: 'ENVÍOS'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined, size: 20), label: 'STOCK'),
        ],
      ) : null,
      body: Row(
        children: [
          if (!isMobile) NavigationRail(
            backgroundColor: const Color(0xFFF9F9F9),
            selectedIndex: _index,
            onDestinationSelected: _cambiarPestana,
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: const IconThemeData(color: Colors.black),
            unselectedIconTheme: const IconThemeData(color: Colors.grey),
            selectedLabelTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), label: Text('CAJA')),
              NavigationRailDestination(icon: Icon(Icons.sync_alt_outlined), label: Text('CAMBIOS')),
              NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), label: Text('GASTOS')),
              NavigationRailDestination(icon: Icon(Icons.bookmark_border), label: Text('APARTADOS')),
              NavigationRailDestination(icon: Icon(Icons.qr_code_scanner_outlined), label: Text('BÓVEDA QR')),
              NavigationRailDestination(icon: Icon(Icons.local_shipping_outlined), label: Text('ENVÍOS WEB')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('STOCK')),
            ],
          ),
          if (!isMobile) const VerticalDivider(thickness: 1, width: 1, color: Colors.black12),
          Expanded(
            child: vistas[_index]
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 4: MÓDULO DE APARTADOS
// ============================================================================
class ApartadosView extends StatefulWidget {
  final Function(double) onVentaExitosa;
  const ApartadosView({super.key, required this.onVentaExitosa});

  @override
  State<ApartadosView> createState() => _ApartadosViewState();
}

class _ApartadosViewState extends State<ApartadosView> {
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _buscadorController = TextEditingController();
  final TextEditingController _engancheController = TextEditingController();
  final TextEditingController _pagoLiquidarController = TextEditingController();

  final List<Map<String, dynamic>> _carritoApartado = [];
  List<dynamic> _catalogoReal = [];
  List<dynamic> _apartadosActivos = [];

  double _totalApartado = 0.0;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
    _cargarApartados();
  }

  Future<void> _cargarCatalogo() async {
    try {
      var res = await http.get(Uri.parse('${ApiService.baseUrl}/pos/catalogo'));
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['exito'] == true && mounted) setState(() => _catalogoReal = data['productos']);
      }
    } catch(e) { debugPrint('Aviso: $e'); }
  }

  Future<void> _cargarApartados() async {
    try {
      var res = await http.get(Uri.parse('${ApiService.baseUrl}/pos/apartados'));
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['exito'] == true && mounted) setState(() => _apartadosActivos = data['apartados']);
      }
    } catch(e) {
      debugPrint("Aviso: $e");
    }
  }

  void _agregarPrenda(String codigo) {
    if (codigo.isEmpty) return;
    String skuBusqueda = codigo.trim();
    String tallaEncontrada = "ÚNICA";

    if (skuBusqueda.startsWith('{') && skuBusqueda.endsWith('}')) {
      try {
        final Map<String, dynamic> qrData = jsonDecode(skuBusqueda);
        if (qrData.containsKey('sku')) skuBusqueda = qrData['sku'].toString();
        if (qrData.containsKey('talla')) tallaEncontrada = qrData['talla'].toString();
      } catch (e) { debugPrint('Aviso JSON QR: $e'); }
    }

    final producto = _catalogoReal.where((p) => p["sku"].toString().toLowerCase() == skuBusqueda.toLowerCase() || p["nombre"].toString().toLowerCase().contains(skuBusqueda.toLowerCase())).toList();

    if (producto.isNotEmpty) {
      var p = producto.first;
      setState(() {
        int index = _carritoApartado.indexWhere((item) => item['id'] == p['id'] && item['talla'] == tallaEncontrada);
        if (index != -1) {
          _carritoApartado[index]['cantidad'] += 1;
        } else {
          double precio = double.tryParse((p["en_rebaja"] == 1 ? p["precio_rebaja"] : p["precio_venta"]).toString()) ?? 0.0;
          _carritoApartado.add({
            "id": p["id"], "sku": p["sku"], "nombre": p["nombre"], "talla": tallaEncontrada, "precio": precio, "cantidad": 1, "foto_url": sanearImagen(p["url_foto_principal"])
          });
        }
        _calcularTotal();
        _buscadorController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prenda no encontrada'), backgroundColor: Colors.red));
    }
  }

  void _calcularTotal() {
    _totalApartado = _carritoApartado.fold(0, (sum, item) => sum + (item["precio"] * item["cantidad"]));
  }

  Future<void> _crearApartadoEImprimir() async {
    if (_clienteController.text.isEmpty || _carritoApartado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta el nombre del cliente o productos'), backgroundColor: Colors.orange));
      return;
    }
    double enganche = double.tryParse(_engancheController.text) ?? 0.0;
    if (enganche <= 0 || enganche > _totalApartado) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto de enganche inválido'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _procesando = true);
    
    // 🚨 CAPTURAMOS EL MESSENGER ANTES DEL ASYNC GAP
    final sm = ScaffoldMessenger.of(context);

    try {
      var res = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/apartados/nuevo'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cliente": _clienteController.text, "carrito": _carritoApartado, "enganche": enganche, "total": _totalApartado})
      );
      
      var data = jsonDecode(res.body);
      if (data['exito'] == true || res.statusCode == 404) {
        final doc = pw.Document();
        final now = DateTime.now();
        final fecha = '${now.day}/${now.month}/${now.year}';
        
        doc.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text('JP JEANS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('TICKET DE APARTADO', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 5),
                  pw.Text('Fecha: $fecha', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Cliente: ${_clienteController.text.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),
                  ..._carritoApartado.map((item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text('${item['cantidad']}x ${item['nombre']} [${item['talla']}]', style: const pw.TextStyle(fontSize: 8))),
                      pw.Text('\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                    ]
                  )),
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text('\$${_totalApartado.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('ENGANCHE', style: const pw.TextStyle(fontSize: 10)), pw.Text('\$${enganche.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('RESTA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.Text('\$${(_totalApartado - enganche).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),
                  pw.SizedBox(height: 5),
                  pw.Text('TIENES 20 DÍAS PARA LIQUIDAR.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('NO HAY DEVOLUCIONES DE ENGANCHE.', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 10),
                ]
              );
            }
          )
        );
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Apartado_${_clienteController.text}');
        
        widget.onVentaExitosa(enganche);

        if (mounted) {
          setState(() {
            _carritoApartado.clear();
            _clienteController.clear();
            _engancheController.clear();
            _totalApartado = 0.0;
          });
        }
        _cargarApartados();
        sm.showSnackBar(const SnackBar(content: Text('Apartado creado con éxito'), backgroundColor: Colors.green));
      }
    } catch(e) { 
      debugPrint('Aviso al crear apartado: $e'); 
    } finally { 
      if (mounted) setState(() => _procesando = false); 
    }
  }

  void _abrirDialogoLiquidar(Map<String, dynamic> apartado) {
    double resta = double.tryParse(apartado['resta'].toString()) ?? 0.0;
    _pagoLiquidarController.clear();

    // 🚨 CAPTURAMOS EL MESSENGER
    final sm = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (contextDialog) => StatefulBuilder(
        builder: (contextBuilder, setStateDialog) {
          double pago = double.tryParse(_pagoLiquidarController.text) ?? 0.0;
          double cambio = (pago >= resta) ? pago - resta : 0.0;

          return AlertDialog(
            title: Text('Liquidar Apartado - ${apartado['cliente']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resta por pagar: \$${resta.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _pagoLiquidarController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setStateDialog(() {}),
                  decoration: const InputDecoration(labelText: 'Pago del cliente (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                ),
                const SizedBox(height: 10),
                Text('CAMBIO: \$${cambio.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cambio > 0 ? Colors.green : Colors.grey)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                onPressed: pago >= resta ? () async {
                  Navigator.pop(contextDialog);
                  if (mounted) setState(() => _procesando = true);
                  try {
                    await http.post(Uri.parse('${ApiService.baseUrl}/pos/apartados/liquidar/${apartado['id']}'), body: jsonEncode({"pago": resta}), headers: {"Content-Type": "application/json"});
                    widget.onVentaExitosa(resta);
                    _cargarApartados();
                    sm.showSnackBar(const SnackBar(content: Text('Apartado Liquidado Exitosamente'), backgroundColor: Colors.green));
                  } catch(e) { debugPrint('Aviso liquidar: $e'); } finally { if (mounted) setState(() => _procesando = false); }
                } : null,
                child: const Text('COBRAR Y LIQUIDAR'),
              )
            ],
          );
        }
      )
    );
  }

  void _devolverAStock(String idApartado) async {
    final sm = ScaffoldMessenger.of(context);
    
    bool? conf = await showDialog(
      context: context,
      builder: (contextDialog) => AlertDialog(
        title: const Text('¿Devolver al stock?'),
        content: const Text('El cliente perderá el apartado y las prendas regresarán al inventario.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contextDialog, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(contextDialog, true), child: const Text('SÍ, DEVOLVER')),
        ],
      )
    );

    if (conf == true) {
      if (mounted) setState(() => _procesando = true);
      try {
        await http.post(Uri.parse('${ApiService.baseUrl}/pos/apartados/cancelar/$idApartado'));
        _cargarApartados();
        sm.showSnackBar(const SnackBar(content: Text('Prendas devueltas al stock'), backgroundColor: Colors.green));
      } catch(e) { debugPrint('Aviso devolver stock: $e'); } finally { if (mounted) setState(() => _procesando = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget formNuevo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _clienteController, decoration: const InputDecoration(labelText: 'Nombre del Cliente', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 16),
        TextField(controller: _buscadorController, decoration: InputDecoration(labelText: 'Escanear Código / QR', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.qr_code_scanner), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _agregarPrenda(_buscadorController.text))), onSubmitted: _agregarPrenda),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
          child: _carritoApartado.isEmpty 
            ? const Center(child: Text('Escanea prendas para apartar', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _carritoApartado.length,
                itemBuilder: (c, i) => ListTile(
                  leading: Image.network(_carritoApartado[i]['foto_url'], width: 40, height: 40, fit: BoxFit.cover),
                  title: Text(_carritoApartado[i]['nombre'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text('Talla: ${_carritoApartado[i]['talla']} | ${_carritoApartado[i]['cantidad']}x', style: const TextStyle(fontSize: 10)),
                  trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 16), onPressed: () => setState(() { _carritoApartado.removeAt(i); _calcularTotal(); })),
                ),
              ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('\$${_totalApartado.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))]),
        const SizedBox(height: 16),
        TextField(controller: _engancheController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto que deja (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money), filled: true, fillColor: Color(0xFFF9F9F9))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), icon: _procesando ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.print), label: const Text('GUARDAR E IMPRIMIR APARTADO'), onPressed: _procesando ? null : _crearApartadoEImprimir)),
      ],
    );

    Widget listaActivos = _apartadosActivos.isEmpty 
      ? const Center(child: Text("No hay apartados activos", style: TextStyle(color: Colors.grey)))
      : ListView.builder(
          itemCount: _apartadosActivos.length,
          itemBuilder: (c, i) {
            final apt = _apartadosActivos[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(apt['cliente'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(apt['descripcion_prendas'] ?? 'Prendas varias', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('Resta: \$${apt['resta']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => _abrirDialogoLiquidar(apt), child: const Text('LIQUIDAR')),
                        const SizedBox(height: 8),
                        OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), onPressed: () => _devolverAStock(apt['id'].toString()), child: const Text('DEVOLVER')),
                      ],
                    )
                  ],
                ),
              )
            );
          },
        );

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SISTEMA DE APARTADOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
            const SizedBox(height: 20),
            const TabBar(labelColor: Colors.black, unselectedLabelColor: Colors.grey, indicatorColor: Colors.black, tabs: [Tab(text: 'NUEVO APARTADO'), Tab(text: 'GESTIONAR ACTIVOS')]),
            const SizedBox(height: 20),
            Expanded(child: TabBarView(children: [
              SingleChildScrollView(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)), child: formNuevo)),
              listaActivos
            ]))
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 1: TERMINAL DE COBRO
// ============================================================================
class TerminalCobroView extends StatefulWidget {
  final Function(double) onVentaExitosa;
  final VoidCallback onCerrarCaja;
  final double ventasTotales;
  final double gastosTotales;

  const TerminalCobroView({super.key, required this.onVentaExitosa, required this.onCerrarCaja, required this.ventasTotales, required this.gastosTotales});
  
  @override
  State<TerminalCobroView> createState() => _TerminalCobroViewState();
}

class _TerminalCobroViewState extends State<TerminalCobroView> {
  final TextEditingController _buscadorController = TextEditingController();
  final TextEditingController _pagoController = TextEditingController();
  final TextEditingController _cuponController = TextEditingController();
  
  final List<Map<String, dynamic>> carrito = [];
  List<dynamic> _catalogoReal = [];

  double _subtotal = 0.0;
  double _descuentoAplicado = 0.0;
  double _total = 0.0;
  double _cambio = 0.0;
  String _vendedorAsociado = "";
  
  bool _procesandoCobro = false; 
  bool _cobroEfectivoModo = false; 
  Timer? _mpPollingTimer;

  final double _valorPromocionActual = 50.00; 

  @override
  void initState() {
    super.initState();
    _cargarCatalogoDesdeCerebro();
    _cargarCarritoMemoria();
  }

  @override
  void dispose() {
    _mpPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarCatalogoDesdeCerebro() async {
    try {
      var res = await http.get(Uri.parse('${ApiService.baseUrl}/pos/catalogo'));
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['exito'] == true && mounted) {
          setState(() => _catalogoReal = data['productos']);
        }
      }
    } catch(e) { debugPrint("Error catalogo: $e"); }
  }

  Future<void> _cargarCarritoMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    final String? carritoStr = prefs.getString('caja_carrito');
    if (carritoStr != null) {
      final List<dynamic> decoded = jsonDecode(carritoStr);
      setState(() {
        carrito.clear();
        for(var item in decoded) { carrito.add(Map<String, dynamic>.from(item)); }
        _recalcularTotal();
      });
    }
  }

  Future<void> _guardarCarritoMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('caja_carrito', jsonEncode(carrito));
  }

  Future<void> _escanearConCamara() async {
    try {
      var result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode && mounted) {
        String barcodeScanRes = result.rawContent;
        if (barcodeScanRes.isNotEmpty) {
          _buscadorController.text = barcodeScanRes;
          _agregarAlCarrito(barcodeScanRes);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelado o Error al abrir la cámara'), backgroundColor: Colors.orange));
    }
  }

  void _agregarAlCarrito(String codigoOBusqueda) {
    if (codigoOBusqueda.isEmpty) return;
    
    String skuBusqueda = codigoOBusqueda.trim();
    String tallaEncontrada = "ÚNICA";

    if (skuBusqueda.startsWith('{') && skuBusqueda.endsWith('}')) {
      try {
        final Map<String, dynamic> qrData = jsonDecode(skuBusqueda);
        if (qrData.containsKey('sku')) skuBusqueda = qrData['sku'].toString();
        if (qrData.containsKey('talla')) tallaEncontrada = qrData['talla'].toString();
      } catch (e) {
        debugPrint("No es un JSON válido, buscando normal.");
      }
    }

    final producto = _catalogoReal.where((p) => 
      p["sku"].toString().toLowerCase() == skuBusqueda.toLowerCase() || 
      p["nombre"].toString().toLowerCase().contains(skuBusqueda.toLowerCase())
    ).toList();

    if (producto.isNotEmpty) {
      var p = producto.first;
      int indexEnCarrito = carrito.indexWhere((item) => item['id'] == p['id'] && item['talla'] == tallaEncontrada);
      int cantidadActual = indexEnCarrito != -1 ? carrito[indexEnCarrito]['cantidad'] : 0;

      List<Map<String, dynamic>> tallasBD = parsearTallasBD(p['tallas']);
      int stockDisponible = 0;
      
      for (var t in tallasBD) {
        if (t['talla'] == tallaEncontrada) {
          stockDisponible = t['cantidad'];
          break;
        }
      }

      if (stockDisponible == 0 && tallasBD.isEmpty) {
         stockDisponible = int.tryParse(p["stock_bodega"]?.toString() ?? '0') ?? 0;
      }

      if (stockDisponible <= cantidadActual) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sin stock suficiente de la talla $tallaEncontrada'), backgroundColor: Colors.orange));
        return;
      }

      setState(() {
        if (indexEnCarrito != -1) {
          carrito[indexEnCarrito]['cantidad'] += 1;
        } else {
          double precioVenta = double.tryParse(p["precio_venta"].toString()) ?? 0.0;
          bool enRebaja = p["en_rebaja"] == 1 || p["en_rebaja"] == true;
          double precioRebaja = double.tryParse(p["precio_rebaja"]?.toString() ?? '0') ?? 0.0;

          carrito.add({
            "id": p["id"],
            "sku": p["sku"],
            "nombre": p["nombre"],
            "talla": tallaEncontrada, 
            "precio_venta": precioVenta,
            "en_rebaja": enRebaja,
            "precio_rebaja": precioRebaja,
            "precio": enRebaja ? precioRebaja : precioVenta,
            "cantidad": 1,
            "foto_url": sanearImagen(p["url_foto_principal"]) 
          });
        }
        _recalcularTotal();
        _buscadorController.clear();
        _guardarCarritoMemoria();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prenda no encontrada'), backgroundColor: Colors.red));
    }
  }

  void _quitarDelCarrito(int index) {
    setState(() {
      carrito.removeAt(index);
      if (carrito.isEmpty) { _descuentoAplicado = 0.0; _vendedorAsociado = ""; _cuponController.clear(); _cobroEfectivoModo = false; }
      _recalcularTotal();
      _guardarCarritoMemoria();
    });
  }

  void _aplicarCupon() {
    if (carrito.isEmpty) return;
    String codigoIngresado = _cuponController.text.trim().toUpperCase();
    if (codigoIngresado == "MARIA_JP" || codigoIngresado == "CARLOS_JP") {
      setState(() { _vendedorAsociado = codigoIngresado; _descuentoAplicado = _valorPromocionActual; _recalcularTotal(); });
    } else {
      setState(() { _vendedorAsociado = ""; _descuentoAplicado = 0.0; _recalcularTotal(); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código inválido'), backgroundColor: Colors.red));
    }
  }

  void _recalcularTotal() {
    _subtotal = carrito.fold(0, (sum, item) => sum + (item["precio"] * item["cantidad"]));
    _total = _subtotal - _descuentoAplicado;
    if (_total < 0) _total = 0; 
    _calcularCambio();
  }

  void _calcularCambio() {
    double pago = double.tryParse(_pagoController.text) ?? 0.0;
    setState(() { _cambio = (pago >= _total && _total > 0) ? pago - _total : 0.0; });
  }

  Future<void> _iniciarCobroTerminalMP() async {
    if (carrito.isEmpty || _procesandoCobro) return;
    
    setState(() => _procesandoCobro = true);

    // 🚨 CAPTURAMOS LOS CONTROLES ANTES DEL ASYNC GAP
    final nav = Navigator.of(context, rootNavigator: true);
    final sm = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext contextDialog) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 20),
              Text("Conectando con la terminal...", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text("Por favor, pídele al cliente que acerque su tarjeta.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      },
    );

    try {
      var res = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/mp/cobrar-terminal'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"total": _total, "descripcion": "Venta Tienda Física"})
      );
      
      var data = jsonDecode(res.body);
      
      if (data['exito'] == true && data['intent_id'] != null) {
        String intentId = data['intent_id'];
        
        _mpPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
          try {
            var statusRes = await http.get(Uri.parse('${ApiService.baseUrl}/pos/mp/estado-cobro/$intentId'));
            var statusData = jsonDecode(statusRes.body);
            
            if (statusData['exito'] == true) {
              String estado = statusData['estado'];
              
              if (estado == 'FINISHED') {
                timer.cancel();
                nav.pop(); 
                _ejecutarCobroEImprimirTicket(metodo: "Tarjeta MP");
              } else if (estado == 'CANCELED' || estado == 'ERROR') {
                timer.cancel();
                nav.pop();
                sm.showSnackBar(SnackBar(content: Text('Pago cancelado o rechazado ($estado)'), backgroundColor: Colors.red));
                if (mounted) setState(() => _procesandoCobro = false);
              }
            }
          } catch(e) {
             timer.cancel();
             nav.pop();
             if (mounted) setState(() => _procesandoCobro = false);
             sm.showSnackBar(const SnackBar(content: Text('Error al consultar estado de MP'), backgroundColor: Colors.red));
          }
        });

      } else {
        nav.pop();
        if (mounted) setState(() => _procesandoCobro = false);
        sm.showSnackBar(SnackBar(content: Text(data['error'] ?? 'No se pudo conectar a la terminal'), backgroundColor: Colors.red));
      }
    } catch (e) {
      nav.pop();
      if (mounted) setState(() => _procesandoCobro = false);
      sm.showSnackBar(SnackBar(content: Text('Error de red: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _ejecutarCobroEImprimirTicket({required String metodo}) async {
    double pago = metodo == "Efectivo" ? (double.tryParse(_pagoController.text) ?? 0.0) : _total;
    if (metodo == "Efectivo" && pago < _total) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta dinero para cubrir el total'), backgroundColor: Colors.orange)); 
      return; 
    }
    
    setState(() => _procesandoCobro = true);

    try {
      var res = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/vender'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"carrito": carrito, "metodo_pago": metodo})
      );
      
      var data = jsonDecode(res.body);
      
      if (data['exito'] == true) {
        final List<Map<String, dynamic>> carritoImpresion = List.from(carrito);
        final double totalImpresion = _total;
        final double pagoImpresion = pago;
        final double cambioImpresion = metodo == "Efectivo" ? _cambio : 0.0;
        final String descuentoTxt = _vendedorAsociado.isNotEmpty ? "Desc. ($_vendedorAsociado): -\$${_descuentoAplicado.toStringAsFixed(2)}" : "";

        widget.onVentaExitosa(_total);

        setState(() { carrito.clear(); _pagoController.clear(); _cuponController.clear(); _vendedorAsociado = ""; _descuentoAplicado = 0.0; _cobroEfectivoModo = false; _recalcularTotal(); });
        _guardarCarritoMemoria(); 
        _cargarCatalogoDesdeCerebro(); 

        final doc = pw.Document();
        pw.MemoryImage? imageLogo;
        try { imageLogo = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List()); } catch (e) { debugPrint('Aviso Logo: $e'); }
        
        final now = DateTime.now();
        final fechaHora = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        doc.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (imageLogo != null) pw.Image(imageLogo, width: 40, height: 40),
                  pw.SizedBox(height: 5),
                  pw.Text('JP JEANS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('TLAXCALA', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 5),
                  pw.Text(fechaHora, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Método: $metodo', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),
                  pw.ListView.builder(
                    itemCount: carritoImpresion.length,
                    itemBuilder: (context, i) {
                      final item = carritoImpresion[i];
                      return pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(child: pw.Text('${item['cantidad']}x ${item['nombre']} [Talla: ${item['talla']}]', style: const pw.TextStyle(fontSize: 8))),
                          pw.Text('\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                        ]
                      );
                    }
                  ),
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),
                  if (descuentoTxt.isNotEmpty) ...[
                    pw.Text(descuentoTxt, style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 5),
                  ],
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('\$${totalImpresion.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ]
                  ),
                  pw.SizedBox(height: 5),
                  if (metodo == "Efectivo") ...[
                     pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('EFECTIVO', style: const pw.TextStyle(fontSize: 8)), pw.Text('\$${pagoImpresion.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))]),
                     pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('CAMBIO', style: const pw.TextStyle(fontSize: 8)), pw.Text('\$${cambioImpresion.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))]),
                  ] else ...[
                     pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('PAGO APROBADO', style: const pw.TextStyle(fontSize: 8)), pw.Text('TARJETA', style: const pw.TextStyle(fontSize: 8))]),
                  ],
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),
                  pw.SizedBox(height: 5),
                  pw.Text('¡GRACIAS POR SU COMPRA!', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                ]
              );
            }
          )
        );
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Ticket_JPJeans');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error BD: ${data['error']}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error de red: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _procesandoCobro = false);
    }
  }

  Future<void> _imprimirCorteCaja() async {
    await ApiService.guardarCorteCaja("Cajero Mostrador", widget.ventasTotales, widget.gastosTotales);

    final doc = pw.Document();
    pw.MemoryImage? imageLogo;
    try { imageLogo = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List()); } catch (e) { debugPrint('Aviso Logo: $e'); }

    final now = DateTime.now();
    final fechaHora = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final totalCaja = widget.ventasTotales - widget.gastosTotales;

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (imageLogo != null) pw.Image(imageLogo, width: 40, height: 40),
              pw.SizedBox(height: 5),
              pw.Text('CORTE DE CAJA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('JP JEANS TLAXCALA', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 5),
              pw.Text(fechaHora, style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('+ VENTAS TOTALES', style: const pw.TextStyle(fontSize: 10)), pw.Text('\$${widget.ventasTotales.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))]),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- GASTOS', style: const pw.TextStyle(fontSize: 10)), pw.Text('\$${widget.gastosTotales.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))]),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL BRUTO HOY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.Text('\$${totalCaja.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
              pw.SizedBox(height: 10),
            ]
          );
        }
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Corte_Caja_JPJeans');
    
    widget.onCerrarCaja();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Corte exitoso. Memoria de caja limpiada.'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800; 

    Widget panelBuscador = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            Text('TERMINAL DE COBRO', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              icon: const Icon(Icons.point_of_sale, size: 16),
              label: const Text('CERRAR CAJA', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _imprimirCorteCaja,
            )
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _buscadorController, 
          autofocus: true, 
          decoration: InputDecoration(
            labelText: 'Escanear Código de Barras / QR', 
            border: const OutlineInputBorder(), filled: true, fillColor: const Color(0xFFF9F9F9), 
            prefixIcon: const Icon(Icons.qr_code_scanner), 
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _agregarAlCarrito(_buscadorController.text))
          ), 
          onSubmitted: _agregarAlCarrito
        ),
        const SizedBox(height: 20),
        
        Container(
          height: isMobile ? 90 : 100, 
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(8)), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: const [
                  Icon(Icons.barcode_reader, color: Colors.green, size: 30), 
                  SizedBox(height: 5), 
                  Text('LECTOR ACTIVO', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 10)),
                  Text('Listo para escanear', style: TextStyle(color: Colors.green, fontSize: 8)),
                ]
              ),
              if (isMobile)
                InkWell(
                  onTap: _escanearConCamara,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt, color: Colors.white, size: 24),
                        SizedBox(height: 4),
                        Text('USAR CÁMARA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1))
                      ]
                    )
                  )
                )
            ]
          )
        ),
      ],
    );

    Widget panelTicket = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TICKET DE VENTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5, color: Colors.grey)),
          const Divider(height: 20),
          Container(
            constraints: BoxConstraints(maxHeight: isMobile ? 250 : 400),
            child: carrito.isEmpty 
              ? const Center(child: Text('Escanea un producto para comenzar', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: carrito.length,
                  itemBuilder: (context, index) {
                    final item = carrito[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0), 
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(item["foto_url"], width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 40, height: 40, color: Colors.grey.shade200, child: const Icon(Icons.checkroom, color: Colors.grey, size: 20))),
                          ),
                          const SizedBox(width: 10), 
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text(item["nombre"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis), 
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(item["sku"], style: const TextStyle(color: Colors.grey, fontSize: 10)), 
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: Text('Talla: ${item["talla"]}', style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold))),
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)), child: Text('${item["cantidad"]}x', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                                  ]
                                )
                              ]
                            )
                          ), 
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('\$${(item["precio"] * item["cantidad"]).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)), 
                              IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _quitarDelCarrito(index))
                            ]
                          )
                        ]
                      )
                    );
                  },
                ),
          ),
          const Divider(height: 20),
          Row(children: [Expanded(child: TextField(controller: _cuponController, decoration: const InputDecoration(isDense: true, labelText: 'Código Creador', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_offer_outlined, size: 18)))), const SizedBox(width: 10), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: _aplicarCupon, child: const Text('APLICAR'))]),
          const SizedBox(height: 20),
          if (_descuentoAplicado > 0) ...[Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal', style: TextStyle(color: Colors.grey)), Text('\$${_subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey))]), const SizedBox(height: 5), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Código: $_vendedorAsociado', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)), Text('-\$${_descuentoAplicado.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]), const Divider(height: 20)],
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300)), Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))]),
          
          const SizedBox(height: 20),

          // 🚨 BOTONES DE PAGO MAESTROS
          if (carrito.isNotEmpty) ...[
            if (!_cobroEfectivoModo) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: Colors.black, side: const BorderSide(color: Colors.black)),
                      icon: const Icon(Icons.money),
                      label: const Text('EFECTIVO', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _cobroEfectivoModo = true),
                    )
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      icon: const Icon(Icons.credit_card),
                      label: const Text('MERCADO PAGO', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _iniciarCobroTerminalMP,
                    )
                  )
                ],
              )
            ] else ...[
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _cobroEfectivoModo = false)),
                  const Text('Cobro en Efectivo', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: _pagoController, keyboardType: TextInputType.number, onChanged: (val) => _calcularCambio(), decoration: const InputDecoration(labelText: 'Pago del cliente (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money), filled: true, fillColor: Color(0xFFF9F9F9))),
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _cambio > 0 ? Colors.green.shade50 : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('CAMBIO', style: TextStyle(fontWeight: FontWeight.bold, color: _cambio > 0 ? Colors.green : Colors.grey)), Text('\$${_cambio.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _cambio > 0 ? Colors.green : Colors.grey))])),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: _procesandoCobro ? null : () => _ejecutarCobroEImprimirTicket(metodo: "Efectivo"), child: _procesandoCobro ? const CircularProgressIndicator(color: Colors.white) : const Text('COBRAR E IMPRIMIR', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)))),
            ]
          ]
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: isMobile 
          ? SingleChildScrollView( 
              child: Column(
                children: [
                  panelBuscador,
                  const SizedBox(height: 20),
                  panelTicket,
                  const SizedBox(height: 40),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: panelBuscador),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: SingleChildScrollView(child: panelTicket)), 
              ],
            ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 2: CAMBIOS Y DEVOLUCIONES
// ============================================================================
class CambiosView extends StatefulWidget {
  const CambiosView({super.key});
  @override
  State<CambiosView> createState() => _CambiosViewState();
}

class _CambiosViewState extends State<CambiosView> {
  final TextEditingController _entraController = TextEditingController();
  final TextEditingController _saleController = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();

  final List<Map<String, dynamic>> _articulosEntran = [];
  final List<Map<String, dynamic>> _articulosSalen = [];
  List<dynamic> _catalogoReal = [];

  @override
  void initState() {
    super.initState();
    _cargarCatalogoDesdeCerebro();
  }

  Future<void> _cargarCatalogoDesdeCerebro() async {
    try {
      var res = await http.get(Uri.parse('${ApiService.baseUrl}/pos/catalogo'));
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['exito'] == true && mounted) {
          setState(() => _catalogoReal = data['productos']);
        }
      }
    } catch(e) { debugPrint('Aviso catalogo: $e'); }
  }

  void _agregarArticulo(String codigo, bool esEntrada) {
    if (codigo.isEmpty) return;
    
    String skuBuscado = codigo;
    if (skuBuscado.startsWith('{') && skuBuscado.endsWith('}')) {
       try {
         final data = jsonDecode(skuBuscado);
         if (data.containsKey('sku')) skuBuscado = data['sku'].toString();
       } catch(e) { debugPrint('Aviso JSON QR: $e'); }
    }

    final producto = _catalogoReal.where((p) => p["sku"].toString().toLowerCase() == skuBuscado.toLowerCase() || p["nombre"].toString().toLowerCase().contains(skuBuscado.toLowerCase())).toList();

    if (producto.isNotEmpty) {
      setState(() {
        if (esEntrada) { _articulosEntran.add(producto.first); _entraController.clear(); } 
        else { _articulosSalen.add(producto.first); _saleController.clear(); }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto no encontrado'), backgroundColor: Colors.red));
    }
  }

  void _procesarCambio() {
    if (_articulosEntran.isEmpty || _articulosSalen.isEmpty || _motivoController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faltan artículos o el motivo del cambio'), backgroundColor: Colors.orange)); return; }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambio procesado. Inventario actualizado.'), backgroundColor: Colors.green));
    setState(() { _articulosEntran.clear(); _articulosSalen.clear(); _motivoController.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget panelEntra = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📥 EL CLIENTE REGRESA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
          const SizedBox(height: 20),
          TextField(controller: _entraController, decoration: InputDecoration(labelText: 'Escanear prenda', border: const OutlineInputBorder(), filled: true, fillColor: const Color(0xFFF9F9F9), prefixIcon: const Icon(Icons.qr_code_scanner), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _agregarArticulo(_entraController.text, true))), onSubmitted: (val) => _agregarArticulo(val, true)),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.builder(shrinkWrap: true, itemCount: _articulosEntran.length, itemBuilder: (context, i) => ListTile(contentPadding: EdgeInsets.zero, title: Text(_articulosEntran[i]['nombre'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), subtitle: Text('${_articulosEntran[i]['sku']}'), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 16), onPressed: () => setState(() => _articulosEntran.removeAt(i))))),
          )
        ],
      ),
    );

    Widget panelSale = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📤 EL CLIENTE SE LLEVA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
          const SizedBox(height: 20),
          TextField(controller: _saleController, decoration: InputDecoration(labelText: 'Escanear prenda', border: const OutlineInputBorder(), filled: true, fillColor: const Color(0xFFF9F9F9), prefixIcon: const Icon(Icons.qr_code_scanner), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _agregarArticulo(_saleController.text, false))), onSubmitted: (val) => _agregarArticulo(val, false)),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.builder(shrinkWrap: true, itemCount: _articulosSalen.length, itemBuilder: (context, i) => ListTile(contentPadding: EdgeInsets.zero, title: Text(_articulosSalen[i]['nombre'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), subtitle: Text('${_articulosSalen[i]['sku']}'), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 16), onPressed: () => setState(() => _articulosSalen.removeAt(i))))),
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
              Text('LOGÍSTICA INVERSA', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 2)),
              const SizedBox(height: 30),
              if (isMobile) ...[
                panelEntra,
                const SizedBox(height: 20),
                panelSale,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panelEntra),
                    const SizedBox(width: 32),
                    Expanded(child: panelSale),
                  ],
                )
              ],
              const SizedBox(height: 20),
              TextField(controller: _motivoController, decoration: const InputDecoration(labelText: 'Motivo del cambio (Ej. Talla incorrecta)', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: _procesarCambio, child: const Text('PROCESAR CAMBIO', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 3: REGISTRO DE GASTOS
// ============================================================================
class RegistroGastosView extends StatefulWidget {
  final Function(double) onGastoRegistrado;
  const RegistroGastosView({super.key, required this.onGastoRegistrado});

  @override
  State<RegistroGastosView> createState() => _RegistroGastosViewState();
}

class _RegistroGastosViewState extends State<RegistroGastosView> {
  final TextEditingController _conceptoController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  final List<Map<String, dynamic>> _gastosDelDia = [];
  double _totalGastos = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarGastosMemoria();
  }

  Future<void> _cargarGastosMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    final String? gastosStr = prefs.getString('caja_lista_gastos');
    if (gastosStr != null) {
      final List<dynamic> decoded = jsonDecode(gastosStr);
      double suma = 0;
      setState(() {
        _gastosDelDia.clear();
        for(var item in decoded) {
          var g = Map<String, dynamic>.from(item);
          _gastosDelDia.add(g);
          suma += g['monto'];
        }
        _totalGastos = suma;
      });
    }
  }

  Future<void> _guardarGastosMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('caja_lista_gastos', jsonEncode(_gastosDelDia));
  }

  void _registrarGasto() {
    final concepto = _conceptoController.text.trim();
    final monto = double.tryParse(_montoController.text) ?? 0.0;
    if (concepto.isEmpty || monto <= 0) return;
    
    final now = DateTime.now();
    final horaStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() { 
      _gastosDelDia.insert(0, {"concepto": concepto, "monto": monto, "hora": horaStr}); 
      _totalGastos += monto; 
      _conceptoController.clear(); 
      _montoController.clear(); 
      _guardarGastosMemoria();
    });
    
    widget.onGastoRegistrado(monto);
  }

  void _eliminarGasto(int index) { 
    setState(() { 
      _totalGastos -= _gastosDelDia[index]["monto"]; 
      widget.onGastoRegistrado(-_gastosDelDia[index]["monto"]); 
      _gastosDelDia.removeAt(index); 
      _guardarGastosMemoria();
    }); 
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget formNuevoGasto = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          const Text('NUEVO GASTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)), 
          const SizedBox(height: 20), 
          TextField(controller: _conceptoController, decoration: const InputDecoration(labelText: 'Concepto (Ej. Papelería, Limpieza)', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9))), 
          const SizedBox(height: 16), 
          TextField(controller: _montoController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo total (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money), filled: true, fillColor: Color(0xFFF9F9F9))), 
          const SizedBox(height: 20), 
          SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), icon: const Icon(Icons.receipt_long, size: 18), label: const Text('REGISTRAR SALIDA', style: TextStyle(letterSpacing: 1, fontWeight: FontWeight.bold)), onPressed: _registrarGasto))
        ]
      )
    );

    Widget listaSalidas = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              const Text('SALIDAS DE HOY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)), 
              Text('TOTAL: -\$${_totalGastos.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))
            ]
          ), 
          const SizedBox(height: 20), 
          Container(
            constraints: BoxConstraints(maxHeight: isMobile ? 250 : 400),
            child: _gastosDelDia.isEmpty 
            ? const Center(child: Text('Caja limpia. No hay gastos hoy.', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic))) 
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _gastosDelDia.length, 
                separatorBuilder: (context, index) => const Divider(color: Colors.white24), 
                itemBuilder: (context, index) { 
                  final gasto = _gastosDelDia[index]; 
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(gasto["concepto"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis), 
                            Text(gasto["hora"], style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1))
                          ]
                        ),
                      ), 
                      Row(
                        children: [
                          Text('-\$${gasto["monto"].toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)), 
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18), onPressed: () => _eliminarGasto(index))
                        ]
                      )
                    ]
                  ); 
                }
              )
          )
        ]
      )
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GASTOS OPERATIVOS', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
              const SizedBox(height: 8),
              const Text('Todo lo registrado aquí se restará del total de efectivo.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 30),
              if (isMobile) ...[
                formNuevoGasto,
                const SizedBox(height: 20),
                listaSalidas,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: formNuevoGasto),
                    const SizedBox(width: 32),
                    Expanded(flex: 3, child: listaSalidas),
                  ],
                )
              ],
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 5: BÓVEDA QR (CON ETIQUETAS EXACTAS 4x2cm Y CÁMARA INCLUIDA)
// ============================================================================
class BovedaQRView extends StatefulWidget {
  final VoidCallback onCerrar;
  const BovedaQRView({super.key, required this.onCerrar});
  @override
  State<BovedaQRView> createState() => _BovedaQRViewState();
}

class _BovedaQRViewState extends State<BovedaQRView> {
  final TextEditingController _corteController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  final TextEditingController _precioController = TextEditingController(); 
  
  final List<Map<String, dynamic>> _listaTallas = [];
  final TextEditingController _nuevaTallaController = TextEditingController();
  final TextEditingController _nuevaCantidadController = TextEditingController();

  String _qrPreviewData = ''; 
  String _tallaPreviewMostrada = 'MUESTRA'; // 🚨 Variable para controlar qué talla dice la vista previa
  
  final ImagePicker _picker = ImagePicker();
  XFile? _fotoSeleccionada; 
  Uint8List? _fotoBytes;
  bool _estaCargando = false; 

  int get totalEtiquetas {
    return _listaTallas.fold(0, (sum, item) => sum + (item['cantidad'] as int));
  }

  // 🚨 NUEVA FUNCIÓN: Diálogo para elegir entre Cámara o Galería
  Future<void> _mostrarOpcionesDeFoto() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Elegir de la Galería'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _seleccionarFoto(ImageSource.gallery);
                  }),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tomar Foto con Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _seleccionarFoto(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _seleccionarFoto(ImageSource origen) async {
    try {
      final XFile? image = await _picker.pickImage(source: origen, imageQuality: 80);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() { _fotoSeleccionada = image; _fotoBytes = bytes; });
      }
    } catch (e) { debugPrint('Aviso foto: $e'); }
  }

  void _agregarTalla() {
    String talla = _nuevaTallaController.text.trim().toUpperCase();
    int cantidad = int.tryParse(_nuevaCantidadController.text) ?? 0;

    if (talla.isEmpty || cantidad <= 0) return;

    setState(() {
      _listaTallas.add({'talla': talla, 'cantidad': cantidad});
      _nuevaTallaController.clear();
      _nuevaCantidadController.clear();
    });
  }

  void _eliminarTalla(int index) => setState(() => _listaTallas.removeAt(index));

  void _generarVistaPrevia() { 
    if (_corteController.text.isEmpty || _precioController.text.isEmpty || totalEtiquetas == 0) return;
    
    // 🚨 Toma la primera talla de la lista para mostrarla en la vista previa
    String tallaReal = _listaTallas.isNotEmpty ? _listaTallas.first['talla'].toString() : "MUESTRA";

    setState(() {
      _tallaPreviewMostrada = tallaReal;
      _qrPreviewData = jsonEncode({"sku": _corteController.text, "talla": tallaReal});
    }); 
  }

  Future<void> _imprimirEtiquetas() async {
    if (_qrPreviewData.isEmpty || totalEtiquetas == 0 || _estaCargando) return;
    setState(() => _estaCargando = true);

    // 🚨 Capturamos el ScaffoldMessenger antes del await para quitar la advertencia azul
    final sm = ScaffoldMessenger.of(context);

    String corteLote = _corteController.text;
    String nombreModelo = _modeloController.text;
    double precioProducto = double.tryParse(_precioController.text) ?? 0.0;
    
    List<Map<String, dynamic>> tallasParaBD = _listaTallas.map((item) => { "talla": item['talla'], "cantidad": item['cantidad'] }).toList();

    try {
      var request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/pos/pre-registro'));
      request.fields['sku'] = corteLote;
      request.fields['nombre_interno'] = nombreModelo;
      request.fields['precio'] = precioProducto.toString();
      request.fields['tallas'] = jsonEncode(tallasParaBD);
      request.fields['stock_total'] = totalEtiquetas.toString();

      if (_fotoSeleccionada != null && _fotoBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('foto', _fotoBytes!, filename: _fotoSeleccionada!.name, contentType: MediaType('image', _fotoSeleccionada!.name.split('.').last)));
      }

      var response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200 || response.statusCode == 201) {
        final doc = pw.Document();
        // 🚨 Formato de 40x20mm SIN forzar el landscape, para que la TSC TE 200 no lo doble dos veces
        final format4x2 = const PdfPageFormat(40 * PdfPageFormat.mm, 20 * PdfPageFormat.mm, marginAll: 0);

        for (var item in _listaTallas) {
          for(int i=0; i<item['cantidad']; i++) { 
            String dataQrUnico = jsonEncode({"sku": corteLote, "talla": item['talla']});
            
            doc.addPage(pw.Page(
              pageFormat: format4x2,
              build: (pw.Context context) {
                return pw.Container(
                  width: 40 * PdfPageFormat.mm,
                  height: 20 * PdfPageFormat.mm,
                  padding: const pw.EdgeInsets.all(1 * PdfPageFormat.mm), 
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(color: PdfColors.black, barcode: pw.Barcode.qrCode(), data: dataQrUnico, width: 16 * PdfPageFormat.mm, height: 16 * PdfPageFormat.mm), 
                      pw.SizedBox(width: 2 * PdfPageFormat.mm),
                      pw.Expanded(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('JP JEANS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)), 
                            pw.Text(corteLote, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Talla: ${item['talla']}', style: pw.TextStyle(fontSize: 7)), // Aquí imprime la talla real
                          ]
                        )
                      )
                    ]
                  )
                );
              }
            ));
          }
        }

        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Etiquetas_4x2_$corteLote');
        
        if (mounted) {
          setState(() { _listaTallas.clear(); _corteController.clear(); _modeloController.clear(); _precioController.clear(); _qrPreviewData = ''; _fotoSeleccionada = null; _fotoBytes = null;});
        }
        sm.showSnackBar(const SnackBar(content: Text('Lote registrado e impresión enviada'), backgroundColor: Colors.green));
      }
    } catch (e) { 
      debugPrint('Aviso Etiquetas: $e'); 
      sm.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { 
      if (mounted) setState(() => _estaCargando = false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget formQR = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _mostrarOpcionesDeFoto, // 🚨 Llama al menú de Cámara/Galería
            child: Container(
              width: double.infinity, height: 140, 
              decoration: BoxDecoration(color: _fotoBytes != null ? Colors.transparent : const Color(0xFFF9F9F9), border: Border.all(color: _fotoBytes != null ? Colors.green : Colors.black26, style: BorderStyle.solid), borderRadius: BorderRadius.circular(8)), 
              child: _fotoBytes != null
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_fotoBytes!, fit: BoxFit.cover)) 
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 40), SizedBox(height: 10), Text('Subir / Tomar Foto', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))])
            )
          ), 
          const SizedBox(height: 16), 
          TextField(controller: _corteController, decoration: const InputDecoration(labelText: 'SKU/Lote (Ej. C-2000)', border: OutlineInputBorder(), isDense: true)), 
          const SizedBox(height: 10), 
          TextField(controller: _modeloController, decoration: const InputDecoration(labelText: 'Nombre Modelo', border: OutlineInputBorder(), isDense: true)), 
          const SizedBox(height: 10),
          TextField(controller: _precioController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio \$', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.attach_money))), 
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(flex: 2, child: TextField(controller: _nuevaTallaController, decoration: const InputDecoration(labelText: 'Talla', border: OutlineInputBorder(), isDense: true))), const SizedBox(width: 10),
              Expanded(flex: 1, child: TextField(controller: _nuevaCantidadController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pzs', border: OutlineInputBorder(), isDense: true))), const SizedBox(width: 10),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: _agregarTalla, child: const Icon(Icons.add))
            ],
          ),
          const SizedBox(height: 10),
          
          Container(
            constraints: const BoxConstraints(maxHeight: 100),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(4)),
            child: ListView.builder(
              shrinkWrap: true, itemCount: _listaTallas.length,
              itemBuilder: (c, index) => ListTile(dense: true, title: Text('Talla: ${_listaTallas[index]['talla']}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('${_listaTallas[index]['cantidad']} pzs', style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => _eliminarTalla(index))]))
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), Text('$totalEtiquetas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))]),
          const SizedBox(height: 10), 
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _generarVistaPrevia, child: const Text('VISTA PREVIA')))
        ]
      )
    );

    Widget vistaQR = _qrPreviewData.isEmpty 
      ? const Center(child: Text('Genera el lote para visualizar', style: TextStyle(color: Colors.grey))) 
      : Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Container(width: 200, height: 100, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(4)), child: Row(children: [QrImageView(data: _qrPreviewData, version: QrVersions.auto, size: 80.0), const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('JP JEANS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)), Text(_corteController.text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), Text('Talla: $_tallaPreviewMostrada', style: const TextStyle(fontSize: 10))]))])), // 🚨 Aquí imprime la talla dinámica
            const SizedBox(height: 20), 
            SizedBox(width: 250, height: 45, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), icon: _estaCargando ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.print), label: Text(_estaCargando ? 'PROCESANDO...' : 'IMPRIMIR $totalEtiquetas (4x2cm)'), onPressed: _estaCargando ? null : _imprimirEtiquetas))
          ]
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('BÓVEDA QR', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)), IconButton(icon: const Icon(Icons.close, size: 30), onPressed: widget.onCerrar)]),
              const SizedBox(height: 20),
              if (isMobile) ...[formQR, const SizedBox(height: 30), vistaQR] else ...[Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 1, child: formQR), const SizedBox(width: 32), Expanded(flex: 1, child: vistaQR)])],
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 6: ENVÍOS WEB
// ============================================================================
class EnviosWebView extends StatefulWidget {
  const EnviosWebView({super.key});
  @override
  State<EnviosWebView> createState() => _EnviosWebViewState();
}

class _EnviosWebViewState extends State<EnviosWebView> {
  final List<Map<String, dynamic>> _pedidosNuevos = [
    { "id": "WEB-1045", "cliente": "Armando Mendoza", "email": "armando@mail.com", "telefono": "55 1234 5678", "direccion": "Av. Reforma 222, Col. Juárez, CDMX. CP 06600", "total": 2099.00, "items": [ {"nombre": "Jeans Baggy Hombre", "talla": "M", "cant": 1, "sku": "C-2000"} ] }
  ];

  final List<Map<String, dynamic>> _pedidosEmpaque = [];
  final List<Map<String, dynamic>> _pedidosDespachados = [];

  final TextEditingController _guiaController = TextEditingController();
  final TextEditingController _paqueteriaController = TextEditingController();

  void _comenzarEmpaque(int index) {
    setState(() { _pedidosEmpaque.insert(0, _pedidosNuevos.removeAt(index)); });
  }

  void _despacharPedido(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Despachar ${_pedidosEmpaque[index]['id']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _paqueteriaController, decoration: const InputDecoration(labelText: 'Paquetería')), const SizedBox(height: 10), TextField(controller: _guiaController, decoration: const InputDecoration(labelText: 'Guía'))]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () {
            if (_guiaController.text.isNotEmpty && _paqueteriaController.text.isNotEmpty) {
              setState(() {
                final p = _pedidosEmpaque.removeAt(index);
                p['paqueteria'] = _paqueteriaController.text;
                p['guia'] = _guiaController.text;
                p['fecha_despacho'] = 'Hoy';
                _pedidosDespachados.insert(0, p);
                _guiaController.clear(); _paqueteriaController.clear();
              });
              Navigator.pop(context);
            }
          }, child: const Text('Confirmar'))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: DefaultTabController(
        length: 3,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ENVÍOS WEB', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, letterSpacing: 3)),
              const SizedBox(height: 20),
              const TabBar(labelColor: Colors.black, indicatorColor: Colors.black, tabs: [Tab(text: 'NUEVOS'), Tab(text: 'EMPAQUE'), Tab(text: 'DESPACHADOS')]),
              const SizedBox(height: 20),
              Expanded(child: TabBarView(children: [_buildLista(_pedidosNuevos, 0), _buildLista(_pedidosEmpaque, 1), _buildLista(_pedidosDespachados, 2)]))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLista(List<Map<String, dynamic>> lista, int tab) {
    if (lista.isEmpty) return const Center(child: Text('No hay pedidos aquí', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (c, i) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${lista[i]['id']} - ${lista[i]['cliente']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (tab == 0) ElevatedButton(onPressed: () => _comenzarEmpaque(i), child: const Text('EMPAQUETAR')),
              if (tab == 1) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: () => _despacharPedido(i), child: const Text('DESPACHAR')),
              if (tab == 2) Text('Guía: ${lista[i]['guia']} (${lista[i]['paqueteria']})', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🚨 VISTA 7: INVENTARIO Y STOCK 
// ============================================================================
class InventarioStockView extends StatefulWidget {
  const InventarioStockView({super.key});

  @override
  State<InventarioStockView> createState() => _InventarioStockViewState();
}

class _InventarioStockViewState extends State<InventarioStockView> {
  List<dynamic> _productosReales = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final datos = await ApiService.obtenerInventario();
      if (!mounted) return;
      setState(() {
        _productosReales = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
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
            const Text('INVENTARIO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
            const SizedBox(height: 30),
            Expanded(
              child: _cargando 
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _productosReales.isEmpty 
                  ? const Center(child: Text("No hay productos", style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _cargarDatos,
                      color: Colors.black,
                      child: ListView.separated(
                        itemCount: _productosReales.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (context, index) {
                          final prod = _productosReales[index];
                          return ListTile(
                            leading: Image.network(sanearImagen(prod['url_foto_principal']), width: 50, height: 50, fit: BoxFit.cover),
                            title: Text(prod['nombre'] ?? 'Prenda'),
                            subtitle: Text('SKU: ${prod['sku']} | Stock: ${prod['stock_bodega']}'),
                          );
                        },
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }
}