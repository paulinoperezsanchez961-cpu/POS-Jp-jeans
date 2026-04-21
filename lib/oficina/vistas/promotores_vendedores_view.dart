import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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

  Future<void> _eliminarVendedor(int id) async {
    final sm = ScaffoldMessenger.of(context);
    bool exito = await ApiService.eliminarVendedor(id);
    if (exito) {
        sm.showSnackBar(const SnackBar(content: Text('Vendedor eliminado.'), backgroundColor: Colors.green));
        _cargarVendedores();
    } else {
        sm.showSnackBar(const SnackBar(content: Text('Error al eliminar.'), backgroundColor: Colors.red));
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
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarVendedor(v['id']),
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