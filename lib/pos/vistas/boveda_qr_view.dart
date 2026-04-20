import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../services/api_service.dart';

// ============================================================================
// 🚨 VISTA 5: BÓVEDA QR (CON ETIQUETAS A RESGUARDO Y NOMBRE/PRECIO INCLUIDO)
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
  String _tallaPreviewMostrada = 'MUESTRA'; 
  
  final ImagePicker _picker = ImagePicker();
  XFile? _fotoSeleccionada; 
  Uint8List? _fotoBytes;
  bool _estaCargando = false; 

  int get totalEtiquetas {
    return _listaTallas.fold(0, (sum, item) => sum + (item['cantidad'] as int));
  }

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
    if (_corteController.text.isEmpty || _precioController.text.isEmpty || totalEtiquetas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faltan datos o tallas'), backgroundColor: Colors.orange));
      return;
    }
    
    String tallaReal = _listaTallas.isNotEmpty ? _listaTallas.first['talla'].toString() : "MUESTRA";

    setState(() {
      _tallaPreviewMostrada = tallaReal;
      _qrPreviewData = "${_corteController.text} TALLA $tallaReal";
    }); 
  }

  Future<void> _imprimirEtiquetas() async {
    if (_qrPreviewData.isEmpty || totalEtiquetas == 0 || _estaCargando) return;
    setState(() => _estaCargando = true);

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
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final doc = pw.Document();
        final formatNuevo = const PdfPageFormat(51.5 * PdfPageFormat.mm, 25.4 * PdfPageFormat.mm, marginAll: 0);

        for (var item in _listaTallas) {
          for(int i=0; i<item['cantidad']; i++) { 
            String dataQrUnico = "$corteLote TALLA ${item['talla']}";
            
            doc.addPage(pw.Page(
              pageFormat: formatNuevo,
              build: (pw.Context context) {
                return pw.Container(
                  width: 51.5 * PdfPageFormat.mm,
                  height: 25.4 * PdfPageFormat.mm,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3 * PdfPageFormat.mm, vertical: 2 * PdfPageFormat.mm), 
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(color: PdfColors.black, barcode: pw.Barcode.qrCode(), data: dataQrUnico, width: 18 * PdfPageFormat.mm, height: 18 * PdfPageFormat.mm), 
                      pw.SizedBox(width: 3 * PdfPageFormat.mm),
                      pw.Expanded(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
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

        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Etiquetas_$corteLote');
        if (!mounted) return;
        
        setState(() { _listaTallas.clear(); _corteController.clear(); _modeloController.clear(); _precioController.clear(); _qrPreviewData = ''; _fotoSeleccionada = null; _fotoBytes = null;});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lote registrado e impresión enviada'), backgroundColor: Colors.green));
      }
    } catch (e) { 
      debugPrint('Aviso Etiquetas: $e'); 
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión o impresión'), backgroundColor: Colors.red));
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
            onTap: _mostrarOpcionesDeFoto, 
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
            Container(width: 200, height: 100, padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(4)), child: Row(children: [QrImageView(data: _qrPreviewData, version: QrVersions.auto, size: 80.0), const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('JP JEANS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)), Text(_corteController.text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), Text('Talla: $_tallaPreviewMostrada', style: const TextStyle(fontSize: 10))]))])), 
            const SizedBox(height: 20), 
            SizedBox(width: 250, height: 45, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white), icon: _estaCargando ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.print), label: Text(_estaCargando ? 'PROCESANDO...' : 'IMPRIMIR $totalEtiquetas (5.1 x 2.5 cm)'), onPressed: _estaCargando ? null : _imprimirEtiquetas))
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