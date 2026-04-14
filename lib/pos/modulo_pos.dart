import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; 
import 'package:http/http.dart' as http; 
import 'package:http_parser/http_parser.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import '../services/api_service.dart';

// ============================================================================
// 🧠 SANADOR DE IMÁGENES GLOBAL (La misma solución que en la Web)
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
  
  // Reemplaza esto con tu dominio real de producción
  return 'https://api.jpjeansvip.com$cleanPath';
}

// Helper para procesar las tallas complejas de la BD
List<Map<String, dynamic>> parsearTallasBD(dynamic tallasRawData) {
  List<dynamic> tallasRaw = [];
  if (tallasRawData != null) {
    if (tallasRawData is String) {
      try { tallasRaw = jsonDecode(tallasRawData); } catch (e) {}
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined), label: 'CAJA'),
          BottomNavigationBarItem(icon: Icon(Icons.sync_alt_outlined), label: 'CAMBIOS'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'GASTOS'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_outlined), label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'ENVÍOS'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'STOCK'),
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

  final double _valorPromocionActual = 50.00; 

  @override
  void initState() {
    super.initState();
    _cargarCatalogoDesdeCerebro();
    _cargarCarritoMemoria();
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

  // 🚨 ESCÁNER DE CÁMARA
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelado o Error al abrir la cámara'), backgroundColor: Colors.orange));
      }
    }
  }

  // 🚨 FUNCIÓN MÁGICA: INTERPRETA EL CÓDIGO QR Y AGREGA LA TALLA EXACTA
  void _agregarAlCarrito(String codigoOBusqueda) {
    if (codigoOBusqueda.isEmpty) return;
    
    String skuBusqueda = codigoOBusqueda.trim();
    String tallaEncontrada = "ÚNICA";

    // 1. Detectar si el lector escaneó un código QR de la Bóveda (Formato JSON)
    if (skuBusqueda.startsWith('{') && skuBusqueda.endsWith('}')) {
      try {
        final Map<String, dynamic> qrData = jsonDecode(skuBusqueda);
        if (qrData.containsKey('sku')) skuBusqueda = qrData['sku'].toString();
        if (qrData.containsKey('talla')) tallaEncontrada = qrData['talla'].toString();
      } catch (e) {
        debugPrint("No es un JSON válido, buscando como texto normal.");
      }
    }

    // 2. Buscar el producto en el catálogo por SKU o Nombre
    final producto = _catalogoReal.where((p) => 
      p["sku"].toString().toLowerCase() == skuBusqueda.toLowerCase() || 
      p["nombre"].toString().toLowerCase().contains(skuBusqueda.toLowerCase())
    ).toList();

    if (producto.isNotEmpty) {
      var p = producto.first;

      // 3. Buscar si este producto exacto CON ESTA TALLA ya está en el carrito
      int indexEnCarrito = carrito.indexWhere((item) => item['id'] == p['id'] && item['talla'] == tallaEncontrada);
      int cantidadActual = indexEnCarrito != -1 ? carrito[indexEnCarrito]['cantidad'] : 0;

      // 4. Extraer el stock real de ESTA talla en específico
      List<Map<String, dynamic>> tallasBD = parsearTallasBD(p['tallas']);
      int stockDisponible = 0;
      
      for (var t in tallasBD) {
        if (t['talla'] == tallaEncontrada) {
          stockDisponible = t['cantidad'];
          break;
        }
      }

      // Fallback: Si no tiene desglose de tallas, usamos el stock global de la bodega
      if (stockDisponible == 0 && tallasBD.isEmpty) {
         stockDisponible = int.tryParse(p["stock_bodega"]?.toString() ?? '0') ?? 0;
      }

      if (stockDisponible <= cantidadActual) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sin stock suficiente de la talla $tallaEncontrada'), backgroundColor: Colors.orange));
        return;
      }

      // 5. Agregar exitosamente al carrito
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
            "talla": tallaEncontrada, // 🚨 ASIGNA LA TALLA EXACTA DEL QR
            "precio_venta": precioVenta,
            "en_rebaja": enRebaja,
            "precio_rebaja": precioRebaja,
            "precio": enRebaja ? precioRebaja : precioVenta,
            "cantidad": 1,
            "foto_url": sanearImagen(p["url_foto_principal"]) // 🚨 IMAGEN BLINDADA
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
      if (carrito.isEmpty) { _descuentoAplicado = 0.0; _vendedorAsociado = ""; _cuponController.clear(); }
      _recalcularTotal();
      _guardarCarritoMemoria();
    });
  }

  void _aplicarCupon() {
    if (carrito.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega productos antes de usar un código'), backgroundColor: Colors.orange)); return; }
    String codigoIngresado = _cuponController.text.trim().toUpperCase();
    if (codigoIngresado == "MARIA_JP" || codigoIngresado == "CARLOS_JP") {
      setState(() { _vendedorAsociado = codigoIngresado; _descuentoAplicado = _valorPromocionActual; _recalcularTotal(); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Código aplicado: - \$${_valorPromocionActual.toStringAsFixed(2)}'), backgroundColor: Colors.green));
    } else {
      setState(() { _vendedorAsociado = ""; _descuentoAplicado = 0.0; _recalcularTotal(); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código de creador inválido'), backgroundColor: Colors.red));
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

  Future<void> _ejecutarCobroEImprimirTicket() async {
    if (carrito.isEmpty || _procesandoCobro) return;
    double pago = double.tryParse(_pagoController.text) ?? 0.0;
    if (pago < _total) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta dinero para cubrir el total'), backgroundColor: Colors.orange)); return; }
    
    setState(() => _procesandoCobro = true);

    try {
      var res = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/vender'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"carrito": carrito})
      );
      
      var data = jsonDecode(res.body);
      
      if (data['exito'] == true) {
        final List<Map<String, dynamic>> carritoImpresion = List.from(carrito);
        final double totalImpresion = _total;
        final double pagoImpresion = pago;
        final double cambioImpresion = _cambio;
        final String descuentoTxt = _vendedorAsociado.isNotEmpty ? "Desc. ($_vendedorAsociado): -\$${_descuentoAplicado.toStringAsFixed(2)}" : "";

        widget.onVentaExitosa(_total);

        setState(() { carrito.clear(); _pagoController.clear(); _cuponController.clear(); _vendedorAsociado = ""; _descuentoAplicado = 0.0; _recalcularTotal(); });
        _guardarCarritoMemoria(); 
        _cargarCatalogoDesdeCerebro(); 

        final doc = pw.Document();
        pw.MemoryImage? imageLogo;
        try { imageLogo = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List()); } catch (e) { debugPrint("No logo"); }
        
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
                  pw.Divider(borderStyle: pw.BorderStyle.dashed),
                  pw.ListView.builder(
                    itemCount: carritoImpresion.length,
                    itemBuilder: (context, i) {
                      final item = carritoImpresion[i];
                      return pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          // En el ticket también imprimimos la Talla
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
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('EFECTIVO', style: const pw.TextStyle(fontSize: 8)), pw.Text('\$${pagoImpresion.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))]),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('CAMBIO', style: const pw.TextStyle(fontSize: 8)), pw.Text('\$${cambioImpresion.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))]),
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
    try { imageLogo = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List()); } catch (e) { debugPrint("No logo"); }

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
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('EFECTIVO EN CAJA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.Text('\$${totalCaja.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
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
          autofocus: true, // 🚨 ESCÁNER BLUETOOTH ACTIVO AUTOMÁTICAMENTE
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
                                    // 🚨 AHORA MUESTRA LA TALLA VISUALMENTE
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
          TextField(controller: _pagoController, keyboardType: TextInputType.number, onChanged: (val) => _calcularCambio(), decoration: const InputDecoration(labelText: 'Pago del cliente (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money), filled: true, fillColor: Color(0xFFF9F9F9))),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _cambio > 0 ? Colors.green.shade50 : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('CAMBIO', style: TextStyle(fontWeight: FontWeight.bold, color: _cambio > 0 ? Colors.green : Colors.grey)), Text('\$${_cambio.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _cambio > 0 ? Colors.green : Colors.grey))])),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), onPressed: (carrito.isEmpty || _procesandoCobro) ? null : _ejecutarCobroEImprimirTicket, child: _procesandoCobro ? const CircularProgressIndicator(color: Colors.white) : const Text('COBRAR E IMPRIMIR', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold)))),
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
    } catch(e) { debugPrint("Error catalogo: $e"); }
  }

  void _agregarArticulo(String codigo, bool esEntrada) {
    if (codigo.isEmpty) return;
    
    // Si viene en formato JSON
    String skuBuscado = codigo;
    if (skuBuscado.startsWith('{') && skuBuscado.endsWith('}')) {
       try {
         final data = jsonDecode(skuBuscado);
         if (data.containsKey('sku')) skuBuscado = data['sku'].toString();
       } catch(e) {}
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
// 🚨 VISTA 4: BÓVEDA QR (CON INYECCIÓN DE TALLA EN EL QR)
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

  String _qrPreviewData = ''; // Solo para la vista previa
  
  final ImagePicker _picker = ImagePicker();
  XFile? _fotoSeleccionada; 
  Uint8List? _fotoBytes;
  bool _estaCargando = false; 

  int get totalEtiquetas {
    return _listaTallas.fold(0, (sum, item) => sum + (item['cantidad'] as int));
  }

  Future<void> _seleccionarFoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _fotoSeleccionada = image;
          _fotoBytes = bytes;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Foto cargada correctamente'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error al elegir foto: $e");
    }
  }

  void _agregarTalla() {
    String talla = _nuevaTallaController.text.trim().toUpperCase();
    int cantidad = int.tryParse(_nuevaCantidadController.text) ?? 0;

    if (talla.isEmpty || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa una talla válida y su cantidad'), backgroundColor: Colors.orange));
      return;
    }

    setState(() {
      _listaTallas.add({'talla': talla, 'cantidad': cantidad});
      _nuevaTallaController.clear();
      _nuevaCantidadController.clear();
    });
  }

  void _eliminarTalla(int index) {
    setState(() {
      _listaTallas.removeAt(index);
    });
  }

  void _generarVistaPrevia() { 
    if (_corteController.text.isEmpty || _modeloController.text.isEmpty || _precioController.text.isEmpty || totalEtiquetas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faltan datos del modelo, precio o tallas'), backgroundColor: Colors.orange));
      return;
    }
    // Mostramos un QR de prueba
    setState(() { 
      _qrPreviewData = jsonEncode({"sku": _corteController.text, "talla": "MUESTRA"}); 
    }); 
  }

  Future<void> _imprimirEtiquetas() async {
    if (_qrPreviewData.isEmpty || totalEtiquetas == 0 || _estaCargando) return;
    
    setState(() => _estaCargando = true);

    String corteLote = _corteController.text;
    String nombreModelo = _modeloController.text;
    double precioProducto = double.tryParse(_precioController.text) ?? 0.0;
    
    List<Map<String, dynamic>> tallasParaBD = _listaTallas.map((item) {
      return { "talla": item['talla'], "cantidad": item['cantidad'] };
    }).toList();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subiendo foto y registrando mercancía...')));

    try {
      var request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/pos/pre-registro'));
      
      request.fields['sku'] = corteLote;
      request.fields['nombre_interno'] = nombreModelo;
      request.fields['precio'] = precioProducto.toString();
      request.fields['tallas'] = jsonEncode(tallasParaBD);
      request.fields['stock_total'] = totalEtiquetas.toString();

      if (_fotoSeleccionada != null && _fotoBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'foto', 
          _fotoBytes!,
          filename: _fotoSeleccionada!.name,
          contentType: MediaType('image', _fotoSeleccionada!.name.split('.').last),
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Inventario actualizado. Generando PDF...'), backgroundColor: Colors.green));

        List<String> etiquetasAImprimir = [];
        for (var item in _listaTallas) {
          for(int i=0; i<item['cantidad']; i++) { etiquetasAImprimir.add(item['talla']); }
        }

        final doc = pw.Document();
        doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(20), build: (pw.Context context) { 
          return [
            pw.Wrap(
              spacing: 20, runSpacing: 20, 
              children: List.generate(etiquetasAImprimir.length, (index) { 
                
                // 🚨 CADA ETIQUETA TIENE SU PROPIO CÓDIGO QR CON SU TALLA INYECTADA
                String dataQrUnico = jsonEncode({"sku": corteLote, "talla": etiquetasAImprimir[index]});

                return pw.Container(
                  width: 120, height: 150, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)), 
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center, 
                    children: [
                      pw.Text('JP JEANS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), 
                      pw.SizedBox(height: 5), 
                      pw.BarcodeWidget(color: PdfColors.black, barcode: pw.Barcode.qrCode(), data: dataQrUnico, width: 80, height: 80), 
                      pw.SizedBox(height: 5), 
                      pw.Text('$corteLote - Talla: ${etiquetasAImprimir[index]}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))
                    ]
                  )
                ); 
              })
            )
          ]; 
        }));
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'QRs_$corteLote');
        
        setState(() { _listaTallas.clear(); _corteController.clear(); _modeloController.clear(); _precioController.clear(); _qrPreviewData = ''; _fotoSeleccionada = null; _fotoBytes = null;});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error al subir. Revisa tu conexión.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error del sistema: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _estaCargando = false);
      }
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
            onTap: _seleccionarFoto, 
            child: Container(
              width: double.infinity, height: 140, 
              decoration: BoxDecoration(color: _fotoBytes != null ? Colors.transparent : const Color(0xFFF9F9F9), border: Border.all(color: _fotoBytes != null ? Colors.green : Colors.black26, style: BorderStyle.solid), borderRadius: BorderRadius.circular(8)), 
              child: _fotoBytes != null
                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_fotoBytes!, fit: BoxFit.cover)) 
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 40), SizedBox(height: 10), Text('Toma o selecciona foto de muestra', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))])
            )
          ), 
          const SizedBox(height: 24), 
          TextField(controller: _corteController, decoration: const InputDecoration(labelText: 'Lote / Corte (Ej. C-2000)', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9))), 
          const SizedBox(height: 16), 
          TextField(controller: _modeloController, decoration: const InputDecoration(labelText: 'Nombre Interno (Ej. Jeans Baggy Hombre)', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9))), 
          const SizedBox(height: 16),
          TextField(controller: _precioController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio de Venta en Tienda (\$)', border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF9F9F9), prefixIcon: Icon(Icons.attach_money))), 
          const SizedBox(height: 24),
          
          const Text('AGREGAR TALLAS (Ej. 28/5, 30/7, CH)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(flex: 2, child: TextField(controller: _nuevaTallaController, decoration: const InputDecoration(labelText: 'Talla', border: OutlineInputBorder(), isDense: true))), const SizedBox(width: 10),
              Expanded(flex: 1, child: TextField(controller: _nuevaCantidadController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pzs', border: OutlineInputBorder(), isDense: true))), const SizedBox(width: 10),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: _agregarTalla, child: const Icon(Icons.add))
            ],
          ),
          const SizedBox(height: 10),
          
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(4)),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _listaTallas.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  title: Text('Talla: ${_listaTallas[index]['talla']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_listaTallas[index]['cantidad']} pzs', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => _eliminarTalla(index)),
                    ],
                  ),
                );
              }
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL ETIQUETAS:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                Text('$totalEtiquetas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
              ],
            ),
          ),
          const SizedBox(height: 20), 
          SizedBox(width: double.infinity, height: 45, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.black)), onPressed: _generarVistaPrevia, child: const Text('GENERAR VISTA PREVIA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1))))
        ]
      )
    );

    Widget vistaQR = _qrPreviewData.isEmpty 
      ? const Center(child: Text('Genera el lote para visualizar', style: TextStyle(color: Colors.grey))) 
      : Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(8)), child: QrImageView(data: _qrPreviewData, version: QrVersions.auto, size: 180.0, backgroundColor: Colors.white)), 
            const SizedBox(height: 50), 
            SizedBox(
              width: 250, height: 45, 
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), 
                icon: _estaCargando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.print_outlined, size: 18), 
                label: Text(_estaCargando ? 'PROCESANDO...' : 'IMPRIMIR $totalEtiquetas ETIQUETAS', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), 
                onPressed: _estaCargando ? null : _imprimirEtiquetas
              )
            )
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('BÓVEDA QR', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                  IconButton(icon: const Icon(Icons.close, size: 30), onPressed: widget.onCerrar, tooltip: 'Cerrar')
                ],
              ),
              const SizedBox(height: 40),
              if (isMobile) ...[
                formQR,
                const SizedBox(height: 30),
                vistaQR
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: formQR),
                    const SizedBox(width: 32),
                    Expanded(flex: 1, child: vistaQR)
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
// 🚨 VISTA 5: ENVÍOS WEB
// ============================================================================
class EnviosWebView extends StatefulWidget {
  const EnviosWebView({super.key});

  @override
  State<EnviosWebView> createState() => _EnviosWebViewState();
}

class _EnviosWebViewState extends State<EnviosWebView> {
  final List<Map<String, dynamic>> _pedidosNuevos = [
    { "id": "WEB-1045", "cliente": "Armando Mendoza", "email": "armando@mail.com", "telefono": "55 1234 5678", "direccion": "Av. Reforma 222, Col. Juárez, CDMX. CP 06600", "total": 2099.00, "items": [ {"nombre": "Jeans Baggy Hombre", "talla": "M", "cant": 1, "sku": "C-2000"}, {"nombre": "Playera Oversize", "talla": "G", "cant": 1, "sku": "P-400"} ] }
  ];

  final List<Map<String, dynamic>> _pedidosEmpaque = [
    { "id": "WEB-1042", "cliente": "Lucía Garza", "email": "lucia@mail.com", "telefono": "81 9876 5432", "direccion": "Calzada San Pedro 100, Monterrey, NL. CP 66220", "total": 899.00, "items": [ {"nombre": "Vestido Midi Seda", "talla": "CH", "cant": 1, "sku": "V-500"} ] }
  ];

  final List<Map<String, dynamic>> _pedidosDespachados = [];

  final TextEditingController _guiaController = TextEditingController();
  final TextEditingController _paqueteriaController = TextEditingController();

  void _comenzarEmpaque(int index) {
    setState(() { final pedido = _pedidosNuevos.removeAt(index); _pedidosEmpaque.insert(0, pedido); });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido movido a "En Empaque". Prepara la mercancía.'), backgroundColor: Colors.blue));
  }

  void _despacharPedido(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Despachar Pedido ${_pedidosEmpaque[index]['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa los datos de envío.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            TextField(controller: _paqueteriaController, decoration: const InputDecoration(labelText: 'Paquetería (Ej. Estafeta)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _guiaController, decoration: const InputDecoration(labelText: 'Número de Guía', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            onPressed: () {
              if (_guiaController.text.isNotEmpty && _paqueteriaController.text.isNotEmpty) {
                final now = DateTime.now();
                final fechaDespachoStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                
                setState(() {
                  final pedido = _pedidosEmpaque.removeAt(index);
                  pedido['paqueteria'] = _paqueteriaController.text.trim();
                  pedido['guia'] = _guiaController.text.trim();
                  pedido['fecha_despacho'] = fechaDespachoStr;
                  _pedidosDespachados.insert(0, pedido);
                  _guiaController.clear(); _paqueteriaController.clear();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pedido Despachado.'), backgroundColor: Colors.green));
              } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Llena la paquetería y la guía'), backgroundColor: Colors.orange)); }
            },
            child: const Text('CONFIRMAR'),
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
      body: DefaultTabController(
        length: 3,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('LOGÍSTICA Y ENVÍOS WEB', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: 3)), SizedBox(height: 8), Text('Control total de despachos.', style: TextStyle(color: Colors.grey))]),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)), child: Row(children: [const Icon(Icons.notifications_active, color: Colors.red, size: 16), const SizedBox(width: 8), Text('${_pedidosNuevos.length} PEDIDOS NUEVOS', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))]))
                  ],
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Text('ENVÍOS WEB', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300, letterSpacing: 3)),
                const SizedBox(height: 10),
              ],
              const TabBar(labelColor: Colors.black, unselectedLabelColor: Colors.grey, indicatorColor: Colors.black, isScrollable: true, tabs: [Tab(text: 'NUEVOS (POR ACEPTAR)'), Tab(text: 'EN EMPAQUE'), Tab(text: 'DESPACHADOS')]),
              const SizedBox(height: 20),
              Expanded(child: TabBarView(children: [_buildListaPedidos(_pedidosNuevos, 0, isMobile), _buildListaPedidos(_pedidosEmpaque, 1, isMobile), _buildListaPedidos(_pedidosDespachados, 2, isMobile)]))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaPedidos(List<Map<String, dynamic>> lista, int tipoTab, bool isMobile) {
    if (lista.isEmpty) { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(tipoTab == 2 ? Icons.check_circle_outline : Icons.inbox_outlined, size: 60, color: Colors.black12), const SizedBox(height: 16), const Text('No hay pedidos aquí', style: TextStyle(color: Colors.grey, fontSize: 16))])); }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final p = lista[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16), elevation: 0, shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)), child: Text(p['id'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))), const SizedBox(width: 12), Text(tipoTab == 2 ? p['fecha_despacho'] ?? '' : '', style: const TextStyle(color: Colors.grey, fontSize: 12))]), Text('\$${p['total'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
                const Divider(height: 30),
                
                if (isMobile) ...[
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('DATOS DE ENVÍO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)), const SizedBox(height: 8), Text(p['cliente'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(p['email'], style: const TextStyle(color: Colors.blueAccent, fontSize: 12)), Text(p['telefono'], style: const TextStyle(fontSize: 12)), const SizedBox(height: 8), Text(p['direccion'], style: const TextStyle(fontSize: 12, color: Colors.black87)), if (tipoTab == 2) ...[const SizedBox(height: 12), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(4)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Enviado por: ${p['paqueteria']}', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)), Text('Guía: ${p['guia']}', style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1))]))]]),
                  const SizedBox(height: 20),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ARTÍCULOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)), const SizedBox(height: 8), ...List.generate(p['items'].length, (i) { final item = p['items'][i]; return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [Text('${item['cant']}x', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text('SKU: ${item['sku']}', style: const TextStyle(color: Colors.grey, fontSize: 10))])), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)), child: Text(item['talla'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)))])); })])),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('DATOS DE ENVÍO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)), const SizedBox(height: 8), Text(p['cliente'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(p['email'], style: const TextStyle(color: Colors.blueAccent, fontSize: 12)), Text(p['telefono'], style: const TextStyle(fontSize: 12)), const SizedBox(height: 8), Text(p['direccion'], style: const TextStyle(fontSize: 12, color: Colors.black87)), if (tipoTab == 2) ...[const SizedBox(height: 12), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200), borderRadius: BorderRadius.circular(4)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Enviado por: ${p['paqueteria']}', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)), Text('Guía: ${p['guia']}', style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1))]))]])),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ARTÍCULOS A EMPAQUETAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)), const SizedBox(height: 8), ...List.generate(p['items'].length, (i) { final item = p['items'][i]; return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [Text('${item['cant']}x', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text('SKU: ${item['sku']}', style: const TextStyle(color: Colors.grey, fontSize: 10))])), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)), child: Text(item['talla'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)))])); })]))),
                    ],
                  ),
                ],
                
                if (tipoTab != 2) ...[
                  const SizedBox(height: 20), 
                  Align(
                    alignment: Alignment.centerRight, 
                    child: tipoTab == 0 
                      ? ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), icon: const Icon(Icons.inventory_2_outlined, size: 16), label: const Text('COMENZAR EMPAQUE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), onPressed: () => _comenzarEmpaque(index)) 
                      : ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), icon: const Icon(Icons.local_shipping_outlined, size: 16), label: const Text('DESPACHAR Y AVISAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), onPressed: () => _despacharPedido(index))
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 🚨 VISTA 6: INVENTARIO Y STOCK (CON IMÁGENES BLINDADAS)
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar stock: $e')));
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('INVENTARIO', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
                      const SizedBox(height: 4),
                      const Text('Stock de la tienda (Actualizado desde BD).', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                        Text('${_productosReales.length} MODELOS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  )
              ],
            ),
            const SizedBox(height: 30),
            
            Expanded(
              child: _cargando 
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _productosReales.isEmpty 
                  ? const Center(child: Text("No hay productos en inventario", style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _cargarDatos,
                      color: Colors.black,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                        child: ListView.separated(
                          itemCount: _productosReales.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final prod = _productosReales[index];
                            
                            final String nombre = prod['nombre'] ?? 'Sin nombre';
                            final String corte = prod['sku'] ?? 'N/A';
                            final int totalModelo = int.tryParse(prod['stock_bodega']?.toString() ?? '0') ?? 0;
                            
                            List<Map<String, dynamic>> tallasParseadas = parsearTallasBD(prod['tallas']);

                            // 🚨 LÓGICA DE URL BLINDADA PARA EL INVENTARIO
                            String fotoUrl = sanearImagen(prod['url_foto_principal']);

                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: isMobile 
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(fotoUrl, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 50, height: 50, color: Colors.grey.shade200, child: const Icon(Icons.checkroom, color: Colors.grey))),
                                        ),
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
                                        Text('$totalModelo pzs', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8, runSpacing: 8,
                                      children: tallasParseadas.map((e) {
                                        int cantidadEnTalla = e['cantidad'];
                                        bool agotado = cantidadEnTalla == 0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: agotado ? Colors.red.shade50 : Colors.green.shade50, border: Border.all(color: agotado ? Colors.red.shade200 : Colors.green.shade200), borderRadius: BorderRadius.circular(4)),
                                          child: Text('${e['talla']}: $cantidadEnTalla pz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: agotado ? Colors.red : Colors.green)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(fotoUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 60, color: Colors.grey.shade200, child: const Icon(Icons.checkroom, color: Colors.grey))),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text('SKU/Corte: $corte', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Wrap(
                                        spacing: 10, runSpacing: 10,
                                        children: tallasParseadas.map((e) {
                                          int cantidadEnTalla = e['cantidad'];
                                          bool agotado = cantidadEnTalla == 0;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: agotado ? Colors.red.shade50 : Colors.green.shade50, border: Border.all(color: agotado ? Colors.red.shade200 : Colors.green.shade200), borderRadius: BorderRadius.circular(4)),
                                            child: Text('${e['talla']}: $cantidadEnTalla pz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: agotado ? Colors.red : Colors.green)),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('TOTAL', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text('$totalModelo pzs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: totalModelo == 0 ? Colors.red : Colors.black)),
                                      ],
                                    )
                                  ],
                                ),
                            );
                          },
                        ),
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }
}