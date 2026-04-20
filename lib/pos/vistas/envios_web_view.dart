import 'package:flutter/material.dart';
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