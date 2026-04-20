import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/api_service.dart';
import '../utils/escaner_utils.dart';

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
  final FocusNode _buscadorFocus = FocusNode(); 
  
  final List<Map<String, dynamic>> carrito = [];
  List<dynamic> _catalogoReal = [];

  double _subtotal = 0.0;
  double _descuentoAplicado = 0.0;
  double _total = 0.0;
  double _cambio = 0.0;
  String _vendedorAsociado = "";
  double _descuentoPorPieza = 0.0; 
  
  bool _procesandoCobro = false; 
  bool _cobroEfectivoModo = false; 
  Timer? _mpPollingTimer;

  @override
  void initState() {
    super.initState();
    _cargarCatalogoDesdeCerebro();
    _cargarCarritoMemoria();
  }

  @override
  void dispose() {
    _mpPollingTimer?.cancel();
    _buscadorFocus.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogoDesdeCerebro() async {
    try {
      var res = await http.get(Uri.parse('${ApiService.baseUrl}/pos/catalogo'));
      if (!mounted) return;
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['exito'] == true) setState(() => _catalogoReal = data['productos']);
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

  Future<void> _registrarVentaEnMemoria(List<Map<String, dynamic>> carritoVendido) async {
    final prefs = await SharedPreferences.getInstance();
    final String? detallesStr = prefs.getString('caja_ventas_detalles');
    List<dynamic> detalles = [];
    if (detallesStr != null) {
      detalles = jsonDecode(detallesStr);
    }
    
    for (var item in carritoVendido) {
      bool found = false;
      for (var d in detalles) {
        if (d['sku'] == item['sku'] && d['talla'] == item['talla']) {
          d['cantidad'] += item['cantidad'];
          found = true;
          break;
        }
      }
      if (!found) {
        detalles.add({
          'sku': item['sku'],
          'nombre': item['nombre'],
          'talla': item['talla'],
          'precio': item['precio'],
          'cantidad': item['cantidad']
        });
      }
    }
    await prefs.setString('caja_ventas_detalles', jsonEncode(detalles));
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

  void _mostrarSelectorDeTallas(Map<String, dynamic> p, List<Map<String, dynamic>> tallasBD) {
    showDialog(
      context: context,
      builder: (BuildContext contextDialog) {
        return AlertDialog(
          title: Text('Selecciona la talla de ${p['sku']}'),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tallasBD.map((t) {
              bool agotado = t['cantidad'] <= 0;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: agotado ? Colors.grey : Colors.black, foregroundColor: Colors.white),
                onPressed: agotado ? null : () {
                  Navigator.pop(contextDialog);
                  _ejecutarAgregarAlCarrito(p, sanitizarAlfanumerico(t['talla'].toString()), tallasBD);
                },
                child: Text('${t['talla']} (${t['cantidad']} pz)'),
              );
            }).toList(),
          ),
        );
      }
    );
  }

  void _agregarAlCarrito(String codigoOBusqueda) {
    if (codigoOBusqueda.isEmpty) return;
    
    final datosEscaneo = decodificarEscaneo(codigoOBusqueda);
    String skuLimpio = datosEscaneo['sku']!;
    String tallaLimpia = datosEscaneo['talla']!;

    final producto = _catalogoReal.where((p) {
      String dbSkuLimpio = sanitizarAlfanumerico(p["sku"].toString());
      String dbNombreLimpio = sanitizarAlfanumerico(p["nombre"].toString());
      return dbSkuLimpio == skuLimpio || dbNombreLimpio.contains(skuLimpio);
    }).toList();

    if (producto.isNotEmpty) {
      var p = producto.first;
      List<Map<String, dynamic>> tallasBD = parsearTallasBD(p['tallas']);
      if (tallaLimpia == 'UNICA' && tallasBD.isNotEmpty && sanitizarAlfanumerico(tallasBD[0]['talla'].toString()) != 'UNICA') {
          _mostrarSelectorDeTallas(p, tallasBD);
          return;
      }
      _ejecutarAgregarAlCarrito(p, tallaLimpia, tallasBD);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prenda no encontrada'), backgroundColor: Colors.red));
      _buscadorController.clear();
      _buscadorFocus.requestFocus();
    }
  }

  void _ejecutarAgregarAlCarrito(Map<String, dynamic> p, String tallaEncontradaLimpia, List<Map<String, dynamic>> tallasBD) {
    String tallaRealVisual = "ÚNICA";
    int stockDisponible = 0;

    for (var t in tallasBD) {
      if (sanitizarAlfanumerico(t['talla'].toString()) == tallaEncontradaLimpia) {
        stockDisponible = t['cantidad'];
        tallaRealVisual = t['talla'].toString();
        break;
      }
    }

    if (stockDisponible == 0 && tallasBD.isEmpty) {
       stockDisponible = int.tryParse(p["stock_bodega"]?.toString() ?? '0') ?? 0;
    }

    int indexEnCarrito = carrito.indexWhere((item) => item['id'] == p['id'] && item['talla'] == tallaRealVisual);
    int cantidadActual = indexEnCarrito != -1 ? carrito[indexEnCarrito]['cantidad'] : 0;

    if (stockDisponible <= cantidadActual) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sin stock suficiente de la talla $tallaRealVisual'), backgroundColor: Colors.orange));
      _buscadorController.clear();
      _buscadorFocus.requestFocus();
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
          "id": p["id"], "sku": p["sku"], "nombre": p["nombre"], "talla": tallaRealVisual, 
          "precio_venta": precioVenta, "en_rebaja": enRebaja, "precio_rebaja": precioRebaja,
          "precio": enRebaja ? precioRebaja : precioVenta, "cantidad": 1, "foto_url": sanearImagen(p["url_foto_principal"]) 
        });
      }
      _recalcularTotal();
      _buscadorController.clear();
      _guardarCarritoMemoria();
      _buscadorFocus.requestFocus(); 
    });
  }

  void _quitarDelCarrito(int index) {
    setState(() {
      carrito.removeAt(index);
      if (carrito.isEmpty) { _descuentoAplicado = 0.0; _vendedorAsociado = ""; _cuponController.clear(); _cobroEfectivoModo = false; _descuentoPorPieza = 0.0; }
      _recalcularTotal();
      _guardarCarritoMemoria();
      _buscadorFocus.requestFocus();
    });
  }

  Future<void> _aplicarCupon() async {
    if (carrito.isEmpty) return;
    String codigoIngresado = _cuponController.text.trim().toUpperCase();
    
    try {
      var res = await http.get(Uri.parse('${ApiService.baseUrl}/cupones/validar/$codigoIngresado'));
      if (!mounted) return;
      var data = jsonDecode(res.body);
      
      if (data['valido'] == true) {
        setState(() { 
          _vendedorAsociado = codigoIngresado; 
          _descuentoPorPieza = double.tryParse(data['descuento'].toString()) ?? 0.0; 
          _recalcularTotal(); 
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código aplicado con éxito'), backgroundColor: Colors.green));
      } else {
        setState(() { _vendedorAsociado = ""; _descuentoPorPieza = 0.0; _recalcularTotal(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código inválido o inactivo'), backgroundColor: Colors.red));
      }
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al conectar con servidor'), backgroundColor: Colors.orange));
    }
  }

  void _recalcularTotal() {
    int piezasTotales = carrito.fold(0, (sum, item) => sum + (item['cantidad'] as int));
    _descuentoAplicado = _descuentoPorPieza * piezasTotales;
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

    final nav = Navigator.of(context, rootNavigator: true);

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
      if (!mounted) return;
      
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
                if (!mounted) return;
                nav.pop(); 
                _ejecutarCobroEImprimirTicket(metodo: "Tarjeta MP");
              } else if (estado == 'CANCELED' || estado == 'ERROR') {
                timer.cancel();
                if (!mounted) return;
                nav.pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pago cancelado o rechazado ($estado)'), backgroundColor: Colors.red));
                setState(() => _procesandoCobro = false);
              }
            }
          } catch(e) {
             timer.cancel();
             if (!mounted) return;
             nav.pop();
             setState(() => _procesandoCobro = false);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al consultar estado de MP'), backgroundColor: Colors.red));
          }
        });

      } else {
        nav.pop();
        setState(() => _procesandoCobro = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'No se pudo conectar a la terminal'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      nav.pop();
      setState(() => _procesandoCobro = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de red: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _ejecutarCobroEImprimirTicket({required String metodo}) async {
    double pago = metodo == "Efectivo" ? (double.tryParse(_pagoController.text) ?? 0.0) : _total;
    if (metodo == "Efectivo" && pago < _total) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta dinero para cubrir el total'), backgroundColor: Colors.orange)); 
      return; 
    }
    
    setState(() => _procesandoCobro = true);

    List<Map<String, dynamic>> carritoAEnviar = carrito.map((item) {
      var mod = Map<String, dynamic>.from(item);
      mod['precio_venta'] = (mod['precio_venta'] - _descuentoPorPieza).clamp(0.0, double.infinity);
      if (mod['en_rebaja']) mod['precio_rebaja'] = (mod['precio_rebaja'] - _descuentoPorPieza).clamp(0.0, double.infinity);
      return mod;
    }).toList();

    try {
      // 🚨 AQUÍ INYECTAMOS EL CÓDIGO DE CREADOR PARA EL SERVIDOR
      var res = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/vender'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "carrito": carritoAEnviar, 
          "metodo_pago": metodo,
          "codigo_creador": _vendedorAsociado
        })
      );
      
      if (!mounted) return;
      
      var data = jsonDecode(res.body);

      if (data['exito'] == true) {
        final List<Map<String, dynamic>> carritoImpresion = List.from(carrito);
        final double totalImpresion = _total;
        final double pagoImpresion = pago;
        final double cambioImpresion = metodo == "Efectivo" ? _cambio : 0.0;
        final String descuentoTxt = _vendedorAsociado.isNotEmpty ? "Desc. ($_vendedorAsociado): -\$${_descuentoAplicado.toStringAsFixed(2)}" : "";

        widget.onVentaExitosa(_total);
        _registrarVentaEnMemoria(carritoImpresion);

        setState(() { carrito.clear(); _pagoController.clear(); _cuponController.clear(); _vendedorAsociado = ""; _descuentoAplicado = 0.0; _descuentoPorPieza = 0.0; _cobroEfectivoModo = false; _recalcularTotal(); });
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error BD: ${data['error']}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error de red: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _procesandoCobro = false);
      _buscadorFocus.requestFocus(); 
    }
  }

  // 🚨 EL CORTE AHORA MANDA LOS DETALLES E IMPRIME EL DESGLOSE COMPLETO
  Future<void> _imprimirCorteCaja() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. LEER VENTAS
    final String? detallesStr = prefs.getString('caja_ventas_detalles');
    List<dynamic> detalles = detallesStr != null ? jsonDecode(detallesStr) : [];
    int totalPiezas = 0;
    for(var d in detalles) { totalPiezas += (d['cantidad'] as int); }
    
    // 2. LEER APARTADOS
    final String? apartadosStr = prefs.getString('caja_apartados_detalles');
    List<dynamic> apartados = apartadosStr != null ? jsonDecode(apartadosStr) : [];

    // 3. LEER CAMBIOS
    final String? cambiosStr = prefs.getString('caja_cambios_detalles');
    List<dynamic> cambios = cambiosStr != null ? jsonDecode(cambiosStr) : [];

    Map<String, dynamic> detallesCorte = {
      "piezas": totalPiezas,
      "items": detalles,
      "apartados": apartados,
      "cambios": cambios
    };

    await ApiService.guardarCorteCaja("Cajero Mostrador", widget.ventasTotales, widget.gastosTotales, detalles: detallesCorte);
    if (!mounted) return;

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
              
              // 🚨 DESGLOSE DE PRODUCTOS VENDIDOS
              if (detalles.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text('PRENDAS VENDIDAS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                ...detalles.map((item) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text('${item['cantidad']}x ${item['nombre']} [Talla: ${item['talla']}]', style: const pw.TextStyle(fontSize: 8))),
                    pw.Text('\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ]
                )),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
              ],

              // 🚨 DESGLOSE DE APARTADOS Y ABONOS
              if (apartados.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text('APARTADOS Y ABONOS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                ...apartados.map((item) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text('${item['tipo']} - ${item['cliente']}', style: const pw.TextStyle(fontSize: 8))),
                    pw.Text('\$${(item['monto'] as num).toDouble().toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ]
                )),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
              ],

              // 🚨 DESGLOSE DE CAMBIOS
              if (cambios.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text('CAMBIOS REALIZADOS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                ...cambios.map((item) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Entró: ${item['entra']}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Salió: ${item['sale']}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Motivo: ${item['motivo']}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                    pw.SizedBox(height: 3),
                  ]
                )),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
              ],
              
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('+ INGRESOS TOTALES', style: const pw.TextStyle(fontSize: 10)), pw.Text('\$${widget.ventasTotales.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))]),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('- GASTOS', style: const pw.TextStyle(fontSize: 10)), pw.Text('\$${widget.gastosTotales.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))]),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL EN CAJA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.Text('\$${totalCaja.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
              pw.SizedBox(height: 10),
            ]
          );
        }
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Corte_Caja_JPJeans');
    
    if (!mounted) return; 

    widget.onCerrarCaja();
    await prefs.remove('caja_ventas_detalles'); 
    await prefs.remove('caja_apartados_detalles'); 
    await prefs.remove('caja_cambios_detalles'); 
    
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
          focusNode: _buscadorFocus, 
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