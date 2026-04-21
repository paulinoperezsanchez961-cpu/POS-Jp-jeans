import 'package:flutter/material.dart';

import 'vistas/dashboard_estadisticas_view.dart';
import 'vistas/inventario_oficina_view.dart';
import 'vistas/contabilidad_cortes_view.dart';
import 'vistas/promotores_vendedores_view.dart';
import 'vistas/inteligencia_artificial_view.dart';
import 'vistas/configuracion_oficina_view.dart';
import 'vistas/ventas_en_vivo_view.dart'; // 🚨 NUEVA VISTA IMPORTADA

class ModuloOficina extends StatefulWidget {
  const ModuloOficina({super.key});

  @override
  State<ModuloOficina> createState() => _ModuloOficinaState();
}

class _ModuloOficinaState extends State<ModuloOficina> {
  int _index = 0;

  void _cambiarPestana(int nuevaPestana) {
    setState(() { _index = nuevaPestana; });
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    final List<Widget> vistas = [
      const DashboardEstadisticasView(), 
      const VentasEnVivoView(), // 🚨 NUEVA PESTAÑA EN LA POSICIÓN 1
      const InventarioOficinaView(),     
      const ContabilidadCortesView(),    
      const PromotoresVendedoresView(),  
      const InteligenciaArtificialView(),
      const ConfiguracionOficinaView(),  
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: isMobile ? BottomNavigationBar(
        currentIndex: _index,
        onTap: _cambiarPestana,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9),
        unselectedLabelStyle: const TextStyle(fontSize: 9),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'DASH'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: 'EN VIVO'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'STOCK'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'CORTES'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'VENDEDORES'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'IA'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'AJUSTES'),
        ],
      ) : null,
      body: Row(
        children: [
          if (!isMobile) NavigationRail(
            backgroundColor: const Color(0xFF1E1E1E),
            selectedIndex: _index,
            onDestinationSelected: _cambiarPestana,
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white54),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.analytics_outlined), label: Text('DASHBOARD')),
              NavigationRailDestination(icon: Icon(Icons.monitor_heart_outlined), label: Text('EN VIVO')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('INVENTARIO')),
              NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: Text('CONTABILIDAD')),
              NavigationRailDestination(icon: Icon(Icons.groups_outlined), label: Text('VENDEDORES')),
              NavigationRailDestination(icon: Icon(Icons.auto_awesome), label: Text('CEREBRO IA')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('AJUSTES')),
            ],
          ),
          Expanded(child: IndexedStack(index: _index, children: vistas)),
        ],
      ),
    );
  }
}