import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; // 🚨 IMPORTANTE PARA EL CLONADOR DINÁMICO
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// 🚨 IMPORTACIONES RELATIVAS 
import '../../services/api_service.dart';
import '../utils/escaner_utils.dart';

class InventarioStockView extends StatefulWidget {
  const InventarioStockView({super.key});

  @override
  State<InventarioStockView> createState() => _InventarioStockViewState();
}

class _InventarioStockViewState extends State<InventarioStockView> {
  List<dynamic> _productosReales = [];
  List<dynamic> _productosFiltrados = []; 
  final TextEditingController _buscadorController = TextEditingController(); 
  
  bool _cargando = true;
  final ImagePicker _picker = ImagePicker();

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
        _productosFiltrados = datos; 
        _buscadorController.clear(); 
        _cargando = false; 
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _filtrarProductos(String query) {
    if (query.isEmpty) {
      setState(() => _productosFiltrados = _productosReales);
      return;
    }
    
    final q = query.toLowerCase();
    setState(() {
      _productosFiltrados = _productosReales.where((p) {
        final sku = (p['sku'] ?? '').toString().toLowerCase();
        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
        return sku.contains(q) || nombre.contains(q);
      }).toList();
    });
  }

  Future<void> _actualizarFotoProducto(int idProducto) async {
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
                    _procesarSubidaFoto(idProducto, ImageSource.gallery);
                  }),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tomar Foto con Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _procesarSubidaFoto(idProducto, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _procesarSubidaFoto(int idProducto, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image == null || !mounted) return;

      final sm = ScaffoldMessenger.of(context);
      sm.showSnackBar(const SnackBar(content: Text('Subiendo nueva foto...'), duration: Duration(seconds: 1)));

      final bytes = await image.readAsBytes();
      var request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/pos/actualizar-foto/$idProducto'));
      request.files.add(http.MultipartFile.fromBytes('foto', bytes, filename: image.name, contentType: MediaType('image', image.name.split('.').last)));
      
      var response = await http.Response.fromStream(await request.send());
      if (!mounted) return;

      if (response.statusCode == 200) {
        _cargarDatos();
        sm.showSnackBar(const SnackBar(content: Text('Foto actualizada exitosamente'), backgroundColor: Colors.green));
      } else {
        sm.showSnackBar(const SnackBar(content: Text('Error al guardar en el servidor'), backgroundColor: Colors.red));
      }
    } catch (e) { debugPrint('Aviso foto: $e'); }
  }

  void _solicitarClaveParaResurtir(Map<String, dynamic> prod) {
    TextEditingController claveController = TextEditingController();
    bool verificando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (contextDialog) {
        return StatefulBuilder(
          builder: (contextBuilder, setStateDialog) {
            return AlertDialog(
              title: const Row(children: [Icon(Icons.security, color: Colors.red), SizedBox(width: 10), Text('Autorización Requerida', style: TextStyle(color: Colors.red))]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ingresa la contraseña de Administrador para resurtir mercancía.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: claveController,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Contraseña Maestra', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: verificando ? null : () async {
                    if (claveController.text.trim().isEmpty) return;
                    setStateDialog(() => verificando = true);
                    
                    bool autorizado = await ApiService.verificarClaveAdmin(claveController.text.trim());
                    
                    // 🛡️ GUARDIA DOBLE SEGURA
                    if (!mounted || !contextDialog.mounted) return;
                    
                    setStateDialog(() => verificando = false);

                    if (autorizado) {
                      Navigator.pop(contextDialog); 
                      _abrirGestorResurtido(prod); 
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Contraseña Incorrecta'), backgroundColor: Colors.red));
                    }
                  },
                  child: verificando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('VERIFICAR'),
                )
              ]
            );
          }
        );
      }
    );
  }

  void _abrirGestorResurtido(Map<String, dynamic> prod) {
    // 🚨 CLONADOR DINÁMICO: Extraemos y volvemos a construir la lista para evitar bloqueos de solo lectura
    List<Map<String, dynamic>> tallasEnEdicion = [];
    try {
      var raw = prod['tallas'];
      List<dynamic> dec = (raw is String) ? jsonDecode(raw) : (raw ?? []);
      for (var item in dec) {
        if (item is Map) {
          tallasEnEdicion.add({
            'talla': (item['talla'] ?? item['nombre'] ?? 'ÚNICA').toString().toUpperCase(),
            'cantidad': int.tryParse(item['cantidad']?.toString() ?? item['stock']?.toString() ?? '0') ?? 0
          });
        }
      }
    } catch(e) { debugPrint('Aviso JSON Tallas: $e'); }

    List<Map<String, dynamic>> tallasAgregadasParaImprimir = []; 

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
                                  // 🚨 Buscamos si la talla ya existe
                                  int idx = tallasEnEdicion.indexWhere((element) => element['talla'] == t);
                                  if (idx != -1) { 
                                    tallasEnEdicion[idx]['cantidad'] = (tallasEnEdicion[idx]['cantidad'] as int) + c; 
                                  } else { 
                                    // 🚨 Si NO existe, la inyectamos como nueva
                                    tallasEnEdicion.add({'talla': t, 'cantidad': c}); 
                                  }
                                  
                                  int idxPrint = tallasAgregadasParaImprimir.indexWhere((element) => element['talla'] == t);
                                  if (idxPrint != -1) { 
                                    tallasAgregadasParaImprimir[idxPrint]['cantidad'] = (tallasAgregadasParaImprimir[idxPrint]['cantidad'] as int) + c; 
                                  } else { 
                                    tallasAgregadasParaImprimir.add({'talla': t, 'cantidad': c}); 
                                  }

                                  nuevaTallaCtrl.clear(); nuevaCantCtrl.clear();
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
                        shrinkWrap: true, itemCount: tallasEnEdicion.length,
                        itemBuilder: (c, i) => ListTile(
                          dense: true, contentPadding: EdgeInsets.zero,
                          title: Text('Talla: ${tallasEnEdicion[i]['talla']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => setStateDialog(() { 
                                if (tallasEnEdicion[i]['cantidad'] > 0) tallasEnEdicion[i]['cantidad']--; 
                              })),
                              SizedBox(width: 30, child: Center(child: Text('${tallasEnEdicion[i]['cantidad']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
                              IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => setStateDialog(() { 
                                tallasEnEdicion[i]['cantidad']++; 
                                String t = tallasEnEdicion[i]['talla'];
                                int idxPrint = tallasAgregadasParaImprimir.indexWhere((element) => element['talla'] == t);
                                if (idxPrint != -1) { tallasAgregadasParaImprimir[idxPrint]['cantidad']++; }
                                else { tallasAgregadasParaImprimir.add({'talla': t, 'cantidad': 1}); }
                              })),
                              const SizedBox(width: 10),
                              IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => setStateDialog(() => tallasEnEdicion.removeAt(i))),
                            ],
                          )
                        )
                      ),
                    ),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('NUEVO STOCK TOTAL:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)), Text('$stockTotalCalculado PZS', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 20))]),
                  ]
                )
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(contextDialog), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () async {
                    final nav = Navigator.of(contextDialog);
                    final sm = ScaffoldMessenger.of(context);
                    
                    bool exito = await ApiService.resurtirProducto(prod['id'], tallasEnEdicion, stockTotalCalculado);
                    nav.pop(); 
                    
                    if (exito) {
                      sm.showSnackBar(const SnackBar(content: Text('Stock actualizado.'), backgroundColor: Colors.green));
                      _cargarDatos(); 
                      
                      if (tallasAgregadasParaImprimir.isNotEmpty) {
                        _imprimirEtiquetasNuevas(prod, tallasAgregadasParaImprimir);
                      }
                    } else {
                      sm.showSnackBar(const SnackBar(content: Text('Error al resurtir producto.'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('GUARDAR E IMPRIMIR NUEVAS')
                )
              ]
            );
          }
        );
      }
    );
  }

  Future<void> _imprimirEtiquetasNuevas(Map<String, dynamic> prod, List<Map<String, dynamic>> tallasNuevas) async {
    final sm = ScaffoldMessenger.of(context);
    String corteLote = prod['sku'];
    String nombreModelo = prod['nombre'] ?? '';
    double precioProducto = double.tryParse(prod['precio_venta']?.toString() ?? '0') ?? 0.0;

    int totalEtiquetas = tallasNuevas.fold(0, (sum, item) => sum + (item['cantidad'] as int));
    if (totalEtiquetas == 0) return;

    try {
      sm.showSnackBar(SnackBar(content: Text('Enviando $totalEtiquetas nuevas etiquetas...'), duration: const Duration(seconds: 2)));
      
      final doc = pw.Document();
      final formatNuevo = const PdfPageFormat(51.5 * PdfPageFormat.mm, 25.4 * PdfPageFormat.mm, marginAll: 0);

      for (var item in tallasNuevas) {
        for(int i=0; i<item['cantidad']; i++) { 
          String dataQrUnico = "$corteLote TALLA ${item['talla']}";
          doc.addPage(pw.Page(
            pageFormat: formatNuevo,
            build: (pw.Context context) {
              return pw.Container(
                width: 51.5 * PdfPageFormat.mm, height: 25.4 * PdfPageFormat.mm,
                padding: const pw.EdgeInsets.symmetric(horizontal: 3 * PdfPageFormat.mm, vertical: 2 * PdfPageFormat.mm), 
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start, crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(color: PdfColors.black, barcode: pw.Barcode.qrCode(), data: dataQrUnico, width: 18 * PdfPageFormat.mm, height: 18 * PdfPageFormat.mm), 
                    pw.SizedBox(width: 3 * PdfPageFormat.mm),
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center, crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('JP JEANS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)), 
                          pw.SizedBox(height: 1 * PdfPageFormat.mm),
                          pw.Text(nombreModelo.toUpperCase(), style: pw.TextStyle(fontSize: 6), maxLines: 1),
                          pw.Text(corteLote, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Talla: ${item['talla']}', style: pw.TextStyle(fontSize: 7)), 
                          pw.Text('\$${precioProducto.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)), 
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
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Resurtido_$corteLote');
      if (!mounted) return;
      sm.showSnackBar(const SnackBar(content: Text('Impresión completada'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _reimprimirEtiquetas(Map<String, dynamic> prod) async {
    final sm = ScaffoldMessenger.of(context);
    String corteLote = prod['sku'];
    String nombreModelo = prod['nombre'] ?? '';
    double precioProducto = double.tryParse(prod['precio_venta']?.toString() ?? '0') ?? 0.0;
    List<Map<String, dynamic>> tallasBD = parsearTallasBD(prod['tallas']);

    int totalEtiquetas = tallasBD.fold(0, (sum, item) => sum + (item['cantidad'] as int));
    if (totalEtiquetas == 0) {
       sm.showSnackBar(const SnackBar(content: Text('Este producto tiene 0 piezas en inventario.'), backgroundColor: Colors.orange));
       return;
    }

    try {
      sm.showSnackBar(SnackBar(content: Text('Generando $totalEtiquetas etiquetas...'), duration: const Duration(seconds: 1)));
      final doc = pw.Document();
      final formatNuevo = const PdfPageFormat(51.5 * PdfPageFormat.mm, 25.4 * PdfPageFormat.mm, marginAll: 0);

      for (var item in tallasBD) {
        for(int i=0; i<item['cantidad']; i++) { 
          String dataQrUnico = "$corteLote TALLA ${item['talla']}";
          doc.addPage(pw.Page(
            pageFormat: formatNuevo,
            build: (pw.Context context) {
              return pw.Container(
                width: 51.5 * PdfPageFormat.mm, height: 25.4 * PdfPageFormat.mm,
                padding: const pw.EdgeInsets.symmetric(horizontal: 3 * PdfPageFormat.mm, vertical: 2 * PdfPageFormat.mm), 
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start, crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(color: PdfColors.black, barcode: pw.Barcode.qrCode(), data: dataQrUnico, width: 18 * PdfPageFormat.mm, height: 18 * PdfPageFormat.mm), 
                    pw.SizedBox(width: 3 * PdfPageFormat.mm),
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center, crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('JP JEANS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)), 
                          pw.SizedBox(height: 1 * PdfPageFormat.mm),
                          pw.Text(nombreModelo.toUpperCase(), style: pw.TextStyle(fontSize: 6), maxLines: 1),
                          pw.Text(corteLote, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Talla: ${item['talla']}', style: pw.TextStyle(fontSize: 7)), 
                          pw.Text('\$${precioProducto.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)), 
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
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Reimpresion_$corteLote');
      if (!mounted) return;
      sm.showSnackBar(const SnackBar(content: Text('Impresión enviada'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      sm.showSnackBar(SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red));
    }
  }

  void _verImagen(String url, String modelo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true, minScale: 0.5, maxScale: 4,
              child: Container(width: double.infinity, height: double.infinity, decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(url), fit: BoxFit.contain))),
            ),
            Container(
              margin: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
            ),
            Positioned(
              bottom: 20, left: 20,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)), child: Text(modelo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))
            )
          ],
        ),
      ),
    );
  }

  String _construirStringTallas(dynamic tallasRaw) {
    List<Map<String, dynamic>> tallas = parsearTallasBD(tallasRaw);
    if (tallas.isEmpty) return "Sin desglose";
    return tallas.map((t) => "${t['talla']}: ${t['cantidad']}").join("  |  ");
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
            const Text('INVENTARIO POS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: 3)),
            const SizedBox(height: 20),
            
            TextField(
              controller: _buscadorController,
              onChanged: _filtrarProductos,
              decoration: InputDecoration(
                labelText: 'Buscar por SKU o Nombre...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscadorController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { 
                      _buscadorController.clear(); 
                      _filtrarProductos(''); 
                      FocusScope.of(context).unfocus();
                    }) 
                  : null,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _cargando 
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _productosFiltrados.isEmpty 
                  ? const Center(child: Text("No hay productos", style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _cargarDatos,
                      color: Colors.black,
                      child: ListView.separated(
                        itemCount: _productosFiltrados.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (context, index) {
                          final prod = _productosFiltrados[index]; 
                          String fotoUrl = sanearImagen(prod['url_foto_principal']);
                          String desgloseTallas = _construirStringTallas(prod['tallas']); 
                          
                          return Card(
                            elevation: 0, shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _verImagen(fotoUrl, prod['sku']),
                                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fotoUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 60, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: Colors.grey)))),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(prod['nombre'] ?? 'Prenda', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text('SKU: ${prod['sku']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(desgloseTallas, style: const TextStyle(color: Colors.black87, fontSize: 11, fontStyle: FontStyle.italic)),
                                        const SizedBox(height: 4),
                                        Text('Stock Total: ${prod['stock_bodega']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                                        icon: const Icon(Icons.print, size: 14), label: const Text('REIMPRIMIR', style: TextStyle(fontSize: 10)),
                                        onPressed: () => _reimprimirEtiquetas(prod),
                                      ),
                                      const SizedBox(height: 5),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                                        icon: const Icon(Icons.add_box, size: 14), label: const Text('RESURTIR', style: TextStyle(fontSize: 10)),
                                        onPressed: () => _solicitarClaveParaResurtir(prod),
                                      ),
                                      const SizedBox(height: 5),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
                                        icon: const Icon(Icons.camera_alt, size: 14), label: const Text('CAMBIAR FOTO', style: TextStyle(fontSize: 10)),
                                        onPressed: () => _actualizarFotoProducto(prod['id']),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
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