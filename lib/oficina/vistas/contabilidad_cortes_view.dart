import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';

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

  Widget _dibujarDesgloseAvanzado(String detallesStr) {
    if (detallesStr.trim().isEmpty || detallesStr == '{}' || detallesStr == 'null') {
        return const Text("Corte ciego (Sin prendas registradas en bitácora).", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
    }
    
    try {
      Map<String, dynamic> json = jsonDecode(detallesStr);
      List items = json['items'] ?? [];
      List apartados = json['apartados'] ?? [];
      List cambios = json['cambios'] ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isNotEmpty) ...[
            const Text('👕 VENTAS DEL TURNO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
            const SizedBox(height: 6),
            ...items.map((i) {
                String nombreRaw = i['nombre']?.toString() ?? '';
                String precioRaw = i['precio']?.toString() ?? '0';

                if (nombreRaw.contains('[SKU:')) {
                    List<String> partesVendedor = nombreRaw.split('| Vendedor:');
                    String itemsVenta = partesVendedor[0];
                    String vendedor = partesVendedor.length > 1 ? partesVendedor[1].trim() : 'Mostrador General';
                    List<String> lineasItems = itemsVenta.split('c/u.');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50, 
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...lineasItems.where((l) => l.trim().isNotEmpty).map((linea) {
                             return Padding(
                               padding: const EdgeInsets.only(bottom: 4.0),
                               child: Text('• ${linea.trim()} c/u', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87)),
                             );
                          }),
                          const Divider(height: 12, color: Colors.black12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 12, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(vendedor, style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text('Total Ticket: \$$precioRaw', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blue)),
                            ],
                          )
                        ],
                      ),
                    );
                } else {
                   bool esAntiguo = i['sku'] == null || i['sku'].toString().isEmpty;
                   if (esAntiguo) {
                       return Text('- $nombreRaw (\$$precioRaw)', style: const TextStyle(fontSize: 11));
                   } else {
                       return Text('- ${i['cantidad']}x [SKU: ${i['sku']}] $nombreRaw (Talla ${i['talla']})', style: const TextStyle(fontSize: 11));
                   }
                }
            }),
            const SizedBox(height: 10),
          ],
          
          if (apartados.isNotEmpty) ...[
            const Text('🛍️ APARTADOS Y ABONOS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
            const SizedBox(height: 6),
            ...apartados.map((a) {
               return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50, 
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade100)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(a['tipo'].toString().replaceAll('_', ' '), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                          Text('+\$${a['monto']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(a['cliente'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
               );
            }),
            const SizedBox(height: 10),
          ],
          
          if (cambios.isNotEmpty) ...[
            const Text('🔄 CAMBIOS FÍSICOS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.purple)),
            const SizedBox(height: 6),
            ...cambios.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text('Entró: ${c['entra']} | Salió: ${c['sale']}\nMotivo: ${c['motivo']}', style: const TextStyle(fontSize: 11)),
            )),
          ],
          
          if (items.isEmpty && apartados.isEmpty && cambios.isEmpty)
             const Text("Corte en \$0 sin movimientos.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
        ],
      );
    } catch(e) {
      return const Text("Formato de datos no compatible", style: TextStyle(color: Colors.grey, fontSize: 10));
    }
  }

  Widget _buildPestanaCortes() {
    return _historialCortes.isEmpty
      ? const Center(child: Text("Aún no se han registrado cortes de caja"))
      : ListView.separated(
          itemCount: _historialCortes.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final c = _historialCortes[index];
            
            // 🚨 AQUÍ EXTRAEMOS LAS DOS BOLSAS DE DINERO SEPARADAS QUE LE PUSIMOS AL SERVER
            final ventasTotales = double.tryParse(c['ventas_totales'].toString()) ?? 0;
            final ventasEfectivo = double.tryParse(c['ventas_efectivo']?.toString() ?? '0') ?? 0;
            final ventasTarjeta = double.tryParse(c['ventas_tarjeta']?.toString() ?? '0') ?? 0;
            final gastos = double.tryParse(c['gastos_totales'].toString()) ?? 0;
            
            // 🚨 MAGIA FINANCIERA: Lo que el cajero debe entregar en mano (Cajón - Gastos)
            final entregaFisicaCajero = ventasEfectivo - gastos;

            return ExpansionTile(
              title: Text(c['fecha_formateada'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Cajero: ${c['cajero']}  |  ENTREGA FÍSICA: \$${entregaFisicaCajero.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              children: [
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ventas Totales:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('\$${ventasTotales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('  💳 Pagado con Tarjeta (Banco):', style: TextStyle(fontSize: 11, color: Colors.blue)),
                          Text('\$${ventasTarjeta.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('  💵 Cobrado en Efectivo (Cajón):', style: TextStyle(fontSize: 11, color: Colors.green)),
                          Text('\$${ventasEfectivo.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('  ➖ Gastos en Efectivo:', style: TextStyle(fontSize: 11, color: Colors.red)),
                          Text('-\$${gastos.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(color: Colors.black26),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('DINERO FÍSICO A ENTREGAR:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                          Text('\$${entregaFisicaCajero.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _dibujarDesgloseAvanzado(c['detalles'] ?? ''),
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
              Expanded(flex: 2, child: TextField(controller: _conceptoGastoCtrl, decoration: const InputDecoration(labelText: 'Concepto (Ej. Renta, Luz)', isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true))),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: TextField(controller: _montoGastoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '\$ Monto Semanal', isDense: true, border: OutlineInputBorder(), fillColor: Colors.white, filled: true))),
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
                      const Text('Historial de cortes de caja y gestión de gastos automatizados semanales.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  OutlinedButton.icon(onPressed: _cargarTodo, icon: const Icon(Icons.refresh, size: 14), label: const Text('ACTUALIZAR'))
                ],
              ),
              const SizedBox(height: 20),
              const TabBar(labelColor: Colors.black, indicatorColor: Colors.black, tabs: [Tab(text: 'HISTORIAL DE CORTES'), Tab(text: 'GASTOS FIJOS SEMANALES')]),
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