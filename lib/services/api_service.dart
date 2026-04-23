import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://api.jpjeansvip.com/api";

  // ==========================================================
  // 📦 INVENTARIO Y POS
  // ==========================================================
  static Future<bool> preRegistrarProducto({ required String sku, required String nombreInterno, required double precio, required List<Map<String, dynamic>> tallas, required int totalPiezas }) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/pos/pre-registro'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"sku": sku, "nombre_interno": nombreInterno, "precio": precio, "tallas": tallas, "stock_total": totalPiezas}));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) { return false; }
  }

  static Future<List<dynamic>> obtenerInventario() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bodega/inventario'));
      if (response.statusCode == 200) { final data = jsonDecode(response.body); if (data['exito'] == true) return data['productos']; }
      return [];
    } catch (e) { return []; }
  }

  // ==========================================================
  // 💼 CONTABILIDAD Y CORTES (ACTUALIZADO TRANSFERENCIA)
  // ==========================================================
  static Future<bool> guardarCorteCaja(String cajero, double ventasEfectivo, double ventasTarjeta, double ventasTransferencia, double gastosTotales, {Map<String, dynamic>? detalles}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/pos/corte-caja'), 
        headers: {"Content-Type": "application/json"}, 
        body: jsonEncode({
          "cajero": cajero, 
          "ventas_efectivo": ventasEfectivo, 
          "ventas_tarjeta": ventasTarjeta, 
          "ventas_transferencia": ventasTransferencia,
          "gastos_totales": gastosTotales,
          "detalles": detalles ?? {} 
        })
      );
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<List<dynamic>> obtenerHistorialCortes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/oficina/cortes-caja'));
      if (res.statusCode == 200) { final data = jsonDecode(res.body); if (data['exito']) return data['cortes']; }
      return [];
    } catch (e) { return []; }
  }

  static Future<List<dynamic>> obtenerVentasEnVivo({String? fechaInicio, String? fechaFin}) async {
    try {
      String urlStr = '$baseUrl/oficina/ventas-en-vivo';
      if (fechaInicio != null && fechaFin != null) {
        urlStr += '?fechaInicio=$fechaInicio&fechaFin=$fechaFin';
      }
      final res = await http.get(Uri.parse(urlStr));
      if (res.statusCode == 200) { final data = jsonDecode(res.body); if (data['exito']) return data['ventas']; }
      return [];
    } catch (e) { return []; }
  }

  static Future<bool> procesarCambioFisico(List<Map<String, dynamic>> entran, List<Map<String, dynamic>> salen, String motivo) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/pos/cambio'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"entran": entran, "salen": salen, "motivo": motivo})
      );
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  // ==========================================================
  // 🤖 INTELIGENCIA ARTIFICIAL
  // ==========================================================
  static Future<String> preguntarALaIA(String pregunta) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/oficina/ia/copiloto'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"pregunta": pregunta}));
      if (response.statusCode == 200) { final data = jsonDecode(response.body); return data['respuesta'] ?? "Sin respuesta."; }
      return "Error de conexión.";
    } catch (e) { return "Fallo al contactar servidor."; }
  }

  // ==========================================================
  // 👑 GESTIÓN DE OFICINA Y PRODUCTOS
  // ==========================================================
  static Future<bool> eliminarProducto(int idProducto) async {
    try { final res = await http.delete(Uri.parse('$baseUrl/oficina/productos/$idProducto')); return res.statusCode == 200; } catch (e) { return false; }
  }

  static Future<bool> actualizarOferta(int idProducto, bool enRebaja, double precioRebaja) async {
    try {
      final res = await http.put(Uri.parse('$baseUrl/oficina/productos/$idProducto/oferta'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"en_rebaja": enRebaja ? 1 : 0, "precio_rebaja": precioRebaja}));
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> resurtirProducto(int idProducto, List<Map<String, dynamic>> tallasActualizadas, int nuevoStockTotal) async {
    try {
      final res = await http.put(Uri.parse('$baseUrl/oficina/productos/$idProducto/resurtir'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"tallas": tallasActualizadas, "stock_bodega": nuevoStockTotal}));
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  // ==========================================================
  // 📊 GASTOS AUTOMÁTICOS Y CARGA MASIVA EXCEL
  // ==========================================================
  static Future<List<dynamic>> obtenerGastosFijos() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/oficina/gastos-fijos'));
      if (res.statusCode == 200) { final data = jsonDecode(res.body); if (data['exito']) return data['gastos']; }
      return [];
    } catch (e) { return []; }
  }

  static Future<bool> agregarGastoFijo(String concepto, double monto) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/oficina/gastos-fijos'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"concepto": concepto, "monto": monto}));
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> eliminarGastoFijo(int idGasto) async {
    try { final res = await http.delete(Uri.parse('$baseUrl/oficina/gastos-fijos/$idGasto')); return res.statusCode == 200; } catch (e) { return false; }
  }

  static Future<bool> cargaMasivaProductos(List<Map<String, dynamic>> productos) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/oficina/carga-masiva'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"productos": productos}));
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  // ==========================================================
  // 👥 VENDEDORES Y CUPONES
  // ==========================================================
  static Future<bool> liquidarComisiones(String codigo, int piezas, double ventasTotales) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/oficina/vendedores/pagar'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "codigo_creador": codigo,
          "piezas": piezas,
          "ventas_totales": ventasTotales,
        })
      );
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<List<dynamic>> obtenerVendedores() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/oficina/vendedores'));
      if (res.statusCode == 200) { final data = jsonDecode(res.body); if (data['exito']) return data['vendedores']; }
      return [];
    } catch (e) { return []; }
  }

  static Future<bool> registrarVendedor(String nombre, String codigo, double comision, double descuento) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/oficina/vendedores'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"nombre": nombre, "codigo_creador": codigo, "comision_porcentaje": comision, "descuento_cliente": descuento})
      );
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<bool> eliminarVendedor(int idVendedor) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/oficina/vendedores/$idVendedor'));
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>> validarCupon(String codigo) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/cupones/validar/$codigo'));
      if (res.statusCode == 200) { return jsonDecode(res.body); }
      return {'valido': false};
    } catch (e) { return {'valido': false}; }
  }

  // ==========================================================
  // 🔐 SEGURIDAD
  // ==========================================================
  static Future<bool> verificarClaveAdmin(String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/oficina/verificar-admin'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"password": password})
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> cambiarClaves(String clavePos, String claveOficina) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/oficina/cambiar-claves'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"clavePos": clavePos, "claveOficina": claveOficina})
      );
      return res.statusCode == 200;
    } catch (e) { return false; }
  }
}