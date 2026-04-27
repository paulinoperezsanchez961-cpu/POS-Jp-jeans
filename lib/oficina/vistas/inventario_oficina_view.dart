import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class InventarioOficinaView extends StatefulWidget {
  const InventarioOficinaView({super.key});

  @override
  State<InventarioOficinaView> createState() => _InventarioOficinaViewState();
}

class _InventarioOficinaViewState extends State<InventarioOficinaView> {
  List<dynamic> _stockReal = [];
  List<dynamic> _productosFiltrados = [];
  final TextEditingController _buscadorController = TextEditingController();
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    
    final datos = await ApiService.obtenerInventario();
    
    if (!mounted) return;
    setState(() { 
      _stockReal = datos; 
      _filtrarProductos(_buscadorController.text);
      if (!silencioso) _cargando = false; 
    });
  }

  // 🚨 NUEVA BARRA DE BÚSQUEDA INSTANTÁNEA
  void _filtrarProductos(String query) {
    if (query.isEmpty) {
      setState(() => _productosFiltrados = List.from(_stockReal));
      return;
    }
    
    final q = query.toLowerCase();
    setState(() {
      _productosFiltrados = _stockReal.where((p) {
        final sku = (p['sku'] ?? '').toString().toLowerCase();
        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
        return sku.contains(q) || nombre.contains(q);
      }).toList();
    });
  }

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

                  final nav = Navigator.of(contextDialog);
                  final sm = ScaffoldMessenger.of(context);
                  bool exito = await ApiService.cargaMasivaProductos(productosAEnviar);
                  nav.pop(); 
                  
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

  // 🚨 MUTACIÓN LOCAL: RESURTIDO (NO SE TRABA)
  void _abrirGestorResurtido(Map<String, dynamic> prod) {
    List<Map<String, dynamic>> tallasEnEdicion = _parsearTallasOficina(prod['tallas']);
    TextEditingController nuevaTallaCtrl = TextEditingController();
    TextEditingController nuevaCantCtrl = TextEditingController();
    bool guardando = false;

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
                  onPressed: guardando ? null : () async {
                    setStateDialog(() => guardando = true);
                    final nav = Navigator.of(contextDialog);
                    final sm = ScaffoldMessenger.of(context);
                    
                    bool exito = await ApiService.resurtirProducto(prod['id'], tallasEnEdicion, stockTotalCalculado);
                    
                    if (!mounted) return;

                    if (exito) {
                      // 🚨 MUTACIÓN LOCAL: No recargamos toda la lista, actualizamos el producto en memoria
                      setState(() {
                         prod['tallas'] = jsonEncode(tallasEnEdicion);
                         prod['stock_bodega'] = stockTotalCalculado;
                      });
                      nav.pop(); 
                      sm.showSnackBar(const SnackBar(content: Text('Resurtido exitoso. Stock actualizado.'), backgroundColor: Colors.green));
                    } else {
                      setStateDialog(() => guardando = false);
                      sm.showSnackBar(const SnackBar(content: Text('Error al resurtir producto.'), backgroundColor: Colors.red));
                    }
                  },
                  child: guardando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('GUARDAR NUEVO STOCK')
                )
              ]
            );
          }
        );
      }
    );
  }

  // 🚨 MUTACIÓN LOCAL: ELIMINACIÓN (SIN REINICIAR SCROLL)
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
        if (!mounted) return; 

        if (res) {
          // 🚨 MUTACIÓN LOCAL: Lo borra visualmente al instante
          setState(() {
             _stockReal.removeWhere((element) => element['id'] == idProducto);
             _filtrarProductos(_buscadorController.text);
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado exitosamente'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (!mounted) return; 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar'), backgroundColor: Colors.red));
      }
    }
  }

  // 🚨 MUTACIÓN LOCAL: OFERTAS FLUIDAS (NO SE TRABA EL PROGRAMA)
  void _abrirGestorOferta(Map<String, dynamic> prod) {
    bool enRebaja = prod['en_rebaja'] == 1 || prod['en_rebaja'] == true;
    TextEditingController precioOfertaController = TextEditingController(text: prod['precio_rebaja']?.toString() ?? '');
    bool guardando = false;

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
                  onPressed: guardando ? null : () async {
                    double precioNuevo = double.tryParse(precioOfertaController.text) ?? 0;
                    final nav = Navigator.of(contextDialog);
                    final sm = ScaffoldMessenger.of(context);

                    if (enRebaja && precioNuevo <= 0) {
                      sm.showSnackBar(const SnackBar(content: Text('Ingresa un precio válido'), backgroundColor: Colors.orange));
                      return;
                    }
                    
                    setStateDialog(() => guardando = true);
                    bool exito = await ApiService.actualizarOferta(prod['id'], enRebaja, precioNuevo);
                    
                    if (!mounted) return;

                    if(exito) {
                       // 🚨 MUTACIÓN LOCAL: Cambia el precio y el color de la tarjeta instantáneamente sin recargar la lista
                       setState(() {
                         prod['en_rebaja'] = enRebaja ? 1 : 0;
                         prod['precio_rebaja'] = precioNuevo;
                       });
                       nav.pop(); 
                       sm.showSnackBar(const SnackBar(content: Text('Oferta actualizada y guardada'), backgroundColor: Colors.green));
                    } else {
                       setStateDialog(() => guardando = false);
                       sm.showSnackBar(const SnackBar(content: Text('Error al actualizar en servidor'), backgroundColor: Colors.red));
                    }
                  },
                  child: guardando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('GUARDAR OFERTA'),
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
            const SizedBox(height: 20),
            
            // 🚨 BARRA DE BÚSQUEDA FLUIDA
            TextField(
              controller: _buscadorController,
              onChanged: _filtrarProductos,
              decoration: InputDecoration(
                labelText: 'Buscar por SKU o Nombre del pantalón...',
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
                  ? const Center(child: Text("No hay productos en inventario", style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: () => _cargarDatos(silencioso: false),
                      color: Colors.black,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
                        child: ListView.separated(
                          // 🚨 USAMOS LOS PRODUCTOS FILTRADOS
                          itemCount: _productosFiltrados.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final prod = _productosFiltrados[index];
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