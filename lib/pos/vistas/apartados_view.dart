import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../utils/escaner_utils.dart';

// ============================================================================
// 🚨 VISTA 4: MÓDULO DE APARTADOS (ABONOS Y LIQUIDACIÓN INTELIGENTE)
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
  final FocusNode _buscadorFocus = FocusNode(); 

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

  @override
  void dispose() {
    _buscadorFocus.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    try {
      var res = await http.get(Uri.parse('${ApiService.baseUrl}/pos/catalogo'));
      if (!mounted) return;
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['exito'] == true) setState(() => _catalogoReal = data['productos']);
      }
    } catch(e) { debugPrint('Aviso: $e'); }
  }

  Future<void> _cargarApartados() async {
    try {
      var res = await http.get(Uri.parse('${ApiService.baseUrl}/pos/apartados'));
      if (!mounted) return;
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['exito'] == true) setState(() => _apartadosActivos = data['apartados']);
      }
    } catch(e) { debugPrint("Aviso: $e"); }
  }

  Future<void> _registrarMovimientoApartado(String tipo, String clienteConDetalle, double monto) async {
    final prefs = await SharedPreferences.getInstance();
    final String? apartadosStr = prefs.getString('caja_apartados_detalles');
    List<dynamic> apartados = apartadosStr != null ? jsonDecode(apartadosStr) : [];
    
    apartados.add({
      'tipo': tipo,
      'cliente': clienteConDetalle,
      'monto': monto
    });
    
    await prefs.setString('caja_apartados_detalles', jsonEncode(apartados));
  }

  void _mostrarSelectorDeTallasApartado(Map<String, dynamic> p, List<Map<String, dynamic>> tallasBD) {
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
                  _ejecutarAgregarPrenda(p, sanitizarAlfanumerico(t['talla'].toString()), tallasBD);
                },
                child: Text('${t['talla']} (${t['cantidad']} pz)'),
              );
            }).toList(),
          ),
        );
      }
    );
  }

  void _agregarPrenda(String codigo) {
    if (codigo.isEmpty) return;
    
    final datosEscaneo = decodificarEscaneo(codigo);
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
          _mostrarSelectorDeTallasApartado(p, tallasBD);
          return;
      }
      
      _ejecutarAgregarPrenda(p, tallaLimpia, tallasBD);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prenda no encontrada'), backgroundColor: Colors.red));
      _buscadorController.clear();
      _buscadorFocus.requestFocus();
    }
  }

  void _ejecutarAgregarPrenda(Map<String, dynamic> p, String tallaEncontradaLimpia, List<Map<String, dynamic>> tallasBD) {
    String tallaRealVisual = "ÚNICA";
    for (var t in tallasBD) {
      if (sanitizarAlfanumerico(t['talla'].toString()) == tallaEncontradaLimpia) {
        tallaRealVisual = t['talla'].toString();
        break;
      }
    }

    setState(() {
      int index = _carritoApartado.indexWhere((item) => item['id'] == p['id'] && item['talla'] == tallaRealVisual);
      if (index != -1) {
        _carritoApartado[index]['cantidad'] += 1;
      } else {
        double precio = double.tryParse((p["en_rebaja"] == 1 ? p["precio_rebaja"] : p["precio_venta"]).toString()) ?? 0.0;
        _carritoApartado.add({
          "id": p["id"], "sku": p["sku"], "nombre": p["nombre"], "talla": tallaRealVisual, "precio": precio, "cantidad": 1, "foto_url": sanearImagen(p["url_foto_principal"])
        });
      }
      _calcularTotal();
      _buscadorController.clear();
      _buscadorFocus.requestFocus(); 
    });
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

    final sm = ScaffoldMessenger.of(context); 

    setState(() => _procesando = true);

    try {
      var res = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/apartados/nuevo'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cliente": _clienteController.text, "carrito": _carritoApartado, "enganche": enganche, "total": _totalApartado})
      );
      if (!mounted) return;
      
      var data = jsonDecode(res.body);
      if (data['exito'] == true || res.statusCode == 404) {
        
        await _imprimirTicketApartado(
          "TICKET DE APARTADO", 
          _clienteController.text, 
          _carritoApartado, 
          _totalApartado, 
          enganche, 
          _totalApartado - enganche
        );
        if (!mounted) return;

        widget.onVentaExitosa(enganche);
        
        // 🚨 AHORA SÍ: El resumen para el corte de caja incluye el [SKU: ...]
        String resumenPrendas = _carritoApartado.map((item) => "${item['cantidad']}x [SKU: ${item['sku']}] ${item['nombre']}").join(", ");
        await _registrarMovimientoApartado('NUEVO APARTADO', "${_clienteController.text} ($resumenPrendas)", enganche);

        setState(() {
          _carritoApartado.clear();
          _clienteController.clear();
          _engancheController.clear();
          _totalApartado = 0.0;
        });
        
        await _cargarApartados();
        sm.showSnackBar(const SnackBar(content: Text('Apartado creado con éxito'), backgroundColor: Colors.green)); 
      }
    } catch(e) { 
      debugPrint('Aviso al crear apartado: $e'); 
    } finally { 
      if (mounted) setState(() => _procesando = false); 
    }
  }

  void _abrirDialogoLiquidarOAbonar(Map<String, dynamic> apartado) {
    double restaAnterior = double.tryParse(apartado['resta'].toString()) ?? 0.0;
    double totalOriginal = double.tryParse(apartado['total'].toString()) ?? 0.0;
    TextEditingController pagoController = TextEditingController();

    showDialog(
      context: context,
      builder: (contextDialog) => StatefulBuilder(
        builder: (contextBuilder, setStateDialog) {
          double pago = double.tryParse(pagoController.text) ?? 0.0;
          bool esLiquidacion = pago >= restaAnterior;
          double cambio = esLiquidacion ? (pago - restaAnterior) : 0.0;
          double nuevaResta = esLiquidacion ? 0.0 : (restaAnterior - pago);

          return AlertDialog(
            title: Text('Cobrar - ${apartado['cliente']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resta actual: \$${restaAnterior.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: pagoController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setStateDialog(() {}),
                  decoration: const InputDecoration(labelText: 'Dinero que entrega el cliente (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                ),
                const SizedBox(height: 10),
                if (esLiquidacion) ...[
                  Text('LIQUIDA CUENTA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  Text('CAMBIO: \$${cambio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
                ] else if (pago > 0) ...[
                  Text('ABONO PARCIAL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                  Text('Nueva Resta: \$${nuevaResta.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: esLiquidacion ? Colors.black : Colors.orange, foregroundColor: Colors.white),
                onPressed: pago > 0 ? () async {
                  Navigator.pop(contextDialog);
                  if (mounted) setState(() => _procesando = true);
                  
                  final sm = ScaffoldMessenger.of(context); 

                  try {
                    String url = esLiquidacion 
                        ? '${ApiService.baseUrl}/pos/apartados/liquidar/${apartado['id']}' 
                        : '${ApiService.baseUrl}/pos/apartados/abonar/${apartado['id']}'; 
                        
                    double dineroParaCuenta = esLiquidacion ? restaAnterior : pago;

                    await http.post(Uri.parse(url), body: jsonEncode({"pago": dineroParaCuenta}), headers: {"Content-Type": "application/json"});
                    if (!mounted) return;
                    
                    widget.onVentaExitosa(dineroParaCuenta);
                    await _cargarApartados();
                    
                    List<dynamic> itemsRecuperados = jsonDecode(apartado['items'] ?? '[]');
                    List<Map<String, dynamic>> carritoRecuperado = itemsRecuperados.map((e) => Map<String,dynamic>.from(e)).toList();
                    
                    if (esLiquidacion) {
                      // 🚨 AHORA SÍ: El resumen para el corte de caja incluye el [SKU: ...] al liquidar
                      String resumenPrendas = carritoRecuperado.map((item) => "${item['cantidad']}x [SKU: ${item['sku']}] ${item['nombre']}").join(", ");
                      await _registrarMovimientoApartado('LIQUIDACIÓN', "${apartado['cliente']} ($resumenPrendas)", dineroParaCuenta);
                      await _imprimirTicketApartado("LIQUIDACIÓN DE APARTADO", apartado['cliente'], carritoRecuperado, totalOriginal, dineroParaCuenta, 0.0, cambio: cambio, pagoCliente: pago);
                      sm.showSnackBar(const SnackBar(content: Text('Cuenta liquidada. Ticket impreso.'), backgroundColor: Colors.green));
                    } else {
                      await _registrarMovimientoApartado('ABONO', apartado['cliente'].toString(), dineroParaCuenta);
                      await _imprimirTicketApartado("ABONO A CUENTA", apartado['cliente'], carritoRecuperado, totalOriginal, pago, nuevaResta);
                      sm.showSnackBar(const SnackBar(content: Text('Abono registrado. Ticket impreso.'), backgroundColor: Colors.orange));
                    }
                  } catch(e) { debugPrint('Aviso liquidar/abonar: $e'); } finally { if (mounted) setState(() => _procesando = false); }
                } : null,
                child: Text(esLiquidacion ? 'COBRAR Y LIQUIDAR' : 'REGISTRAR ABONO'),
              )
            ],
          );
        }
      )
    );
  }

  Future<void> _imprimirTicketApartado(String titulo, String cliente, List<Map<String, dynamic>> carrito, double total, double pagoActual, double resta, {double cambio = 0.0, double pagoCliente = 0.0}) async {
    final doc = pw.Document();
    pw.MemoryImage? imageLogo;
    try { imageLogo = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List()); } catch (e) { debugPrint('Logo: $e'); }
    
    final now = DateTime.now();
    final fecha = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute}';
    
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
              pw.Text(titulo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('Fecha: $fecha', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Cliente: ${cliente.toUpperCase()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              ...carrito.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('${item['cantidad']}x ${item['sku'] ?? ''} - ${item['nombre']} [${item['talla']}]', style: const pw.TextStyle(fontSize: 8))),
                  pw.Text('\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                ]
              )),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL ORIGINAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('SU PAGO HOY', style: const pw.TextStyle(fontSize: 10)), pw.Text('\$${pagoActual.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('RESTA POR PAGAR', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.Text('\$${resta.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))]),
              if (cambio > 0) ...[
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('EFECTIVO RECIBIDO', style: const pw.TextStyle(fontSize: 8)), pw.Text('\$${pagoCliente.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('CAMBIO', style: const pw.TextStyle(fontSize: 8)), pw.Text('\$${cambio.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8))]),
              ],
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              if (resta > 0) pw.Text('TIENES 20 DÍAS PARA LIQUIDAR.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('NO HAY DEVOLUCIONES.', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
            ]
          );
        }
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Recibo_Apartado');
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
        if (!mounted) return;
        await _cargarApartados();
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
        TextField(controller: _buscadorController, focusNode: _buscadorFocus, decoration: InputDecoration(labelText: 'Escanear Código / QR', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.qr_code_scanner), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _agregarPrenda(_buscadorController.text))), onSubmitted: _agregarPrenda),
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
                  title: Text('${_carritoApartado[i]['sku']} - ${_carritoApartado[i]['nombre']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                          Text(apt['cliente']?.toString() ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(apt['descripcion_prendas']?.toString() ?? 'Prendas varias', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('Resta: \$${apt['resta']}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => _abrirDialogoLiquidarOAbonar(apt), child: const Text('COBRAR')),
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