import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; 

class ApiService {
  // 🚨 DOMINIO OFICIAL EN PRODUCCIÓN (Conectado a Hostinger/VPS)
  static const String baseUrl = "https://api.jpjeansvip.com/api";

  // 📥 1. PRE-REGISTRO DE MERCANCÍA (Desde Bóveda QR del POS)
  static Future<bool> preRegistrarProducto({
    required String sku,
    required String nombreInterno,
    required double precio,
    required List<Map<String, dynamic>> tallas,
    required int totalPiezas,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pos/pre-registro'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sku": sku,
          "nombre_interno": nombreInterno,
          "precio": precio,
          "tallas": tallas,
          "stock_total": totalPiezas,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Error ApiService (pre-registro): $e");
      return false;
    }
  }

  // 📤 2. LEER STOCK (Para la pestaña de Inventario)
  static Future<List<dynamic>> obtenerInventario() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bodega/inventario'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exito'] == true) {
          return data['productos'];
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error ApiService (obtener inventario): $e");
      return [];
    }
  }

  // 🤖 3. HABLAR CON LA IA (Para el Copiloto de la Oficina)
  static Future<String> preguntarALaIA(String pregunta) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/oficina/ia/copiloto'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"pregunta": pregunta}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['respuesta'] ?? "No obtuve respuesta de la IA.";
      }
      return "Error de conexión con el cerebro IA.";
    } catch (e) {
      debugPrint("Error ApiService (IA): $e");
      return "Hubo un fallo al contactar al servidor.";
    }
  }

  // 📥 4. GUARDAR CORTE DE CAJA (Desde el POS)
  static Future<bool> guardarCorteCaja(String cajero, double ventas, double gastos) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/pos/corte-caja'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cajero": cajero, "ventas_totales": ventas, "gastos_totales": gastos})
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Error guardando corte: $e");
      return false;
    }
  }

  // 📤 5. LEER HISTORIAL DE CORTES (Para la Oficina)
  static Future<List<dynamic>> obtenerHistorialCortes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/oficina/cortes-caja'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['exito']) return data['cortes'];
      }
      return [];
    } catch (e) {
      debugPrint("Error leyendo cortes: $e");
      return [];
    }
  }
}

