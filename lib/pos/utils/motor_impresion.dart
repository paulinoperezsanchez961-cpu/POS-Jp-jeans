import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MotorImpresion {
  static Future<Directory?> _obtenerDirectorioBase() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  // =========================================================================
  // 🖨️ DISEÑO Y GENERACIÓN DEL TICKET DE VENTA (80MM ESTÉTICO)
  // =========================================================================
  static Future<void> imprimirTicketVenta({
    required List<Map<String, dynamic>> carritoAEnviar,
    required String metodoDB,
    required double totalImpresion,
    required double pagoEf,
    required double pagoTr,
    required double cambioImpresion,
    required String descuentoTxt,
    required String vipTxt,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? imageLogo;

    try {
      imageLogo = pw.MemoryImage(
        (await rootBundle.load('assets/logo.png')).buffer.asUint8List(),
      );
    } catch (e) {
      debugPrint('Aviso Logo: $e');
    }

    final now = DateTime.now();
    final fechaHora =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll:
              5 *
              PdfPageFormat.mm, // 🚨 MARGEN AMPLIADO (Evita cortes a los lados)
        ),
        build: (pw.Context pdfCtx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // 🚨 LOGO MÁS GRANDE COMO PROTAGONISTA
              if (imageLogo != null) pw.Image(imageLogo, width: 75, height: 75),
              pw.SizedBox(height: 8),

              // 🚨 TEXTOS MÁS PEQUEÑOS Y ESTILIZADOS
              pw.Text(
                'JP JEANS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('TLAXCALA', style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Text(
                'Central de autobuses, Tlax',
                style: pw.TextStyle(fontSize: 7),
              ),

              pw.SizedBox(height: 6),
              pw.Text(fechaHora, style: pw.TextStyle(fontSize: 8)),
              pw.Text(
                'Método: ${metodoDB == "MIXTO" ? "PAGO MIXTO" : metodoDB}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // RESUMEN DE COMPRA
              ...carritoAEnviar.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item['cantidad']}x ${item['nombre']} [Talla: ${item['talla']}]',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        '\$${(item['precio'] * item['cantidad']).toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 2),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              if (descuentoTxt.isNotEmpty) ...[
                pw.Text(descuentoTxt, style: pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 5),
              ],
              if (vipTxt.isNotEmpty) ...[
                pw.Text(
                  vipTxt,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
              ],

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '\$${totalImpresion.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              if (metodoDB == "Efectivo") ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('EFECTIVO', style: pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      '\$${pagoEf.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CAMBIO', style: pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      '\$${cambioImpresion.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ] else if (metodoDB.startsWith("MIXTO")) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TRANSFERENCIA', style: pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      '\$${pagoTr.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'EFECTIVO RECIBIDO',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      '\$${pagoEf.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'CAMBIO EN EFECTIVO',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '\$${cambioImpresion.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ] else if (metodoDB == "Transferencia") ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PAGO APROBADO', style: pw.TextStyle(fontSize: 8)),
                    pw.Text('TRANSFERENCIA', style: pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ] else ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PAGO APROBADO', style: pw.TextStyle(fontSize: 8)),
                    pw.Text('TARJETA', style: pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 10),

              pw.Text(
                '¡GRACIAS POR SU COMPRA!',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Text(
                'Muchas gracias por consumir producto nacional, así apoyas a la economía local y al crecimiento del estado. Nuestra meta como empresa es poder proporcionar productos de la más alta calidad a un precio justo y llevar la moda al estado del cual nacimos. Somos una empresa 100% Tlaxcalteca y es un honor estar presentes ya en el estado. Gracias por confiar en nosotros, un saludo de parte de Paulino Pérez y bonito día.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize:
                      6, // 🚨 Letra más pequeña para que encaje como bloque
                  color: PdfColors.black,
                  lineSpacing: 1.5,
                ),
              ),

              pw.SizedBox(
                height: 15 * PdfPageFormat.mm,
              ), // Salto para la guillotina automática
            ],
          );
        },
      ),
    );

    try {
      final Uint8List bytesPdf = await doc.save();
      final Directory? baseDir = await _obtenerDirectorioBase();
      if (baseDir != null) {
        final directorioTickets = Directory(
          '${baseDir.path}/Tickets_Guardados',
        );
        if (!await directorioTickets.exists()) {
          await directorioTickets.create(recursive: true);
        }
        final String nombreArchivo =
            'Ticket_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}.pdf';
        final File archivo = File('${directorioTickets.path}/$nombreArchivo');
        await archivo.writeAsBytes(bytesPdf);
      }
    } catch (e) {
      debugPrint('Aviso al guardar PDF local: $e');
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  // =========================================================================
  // 🖨️ DISEÑO Y GENERACIÓN DEL CORTE DE CAJA (80MM OPTIMIZADO)
  // =========================================================================
  static Future<void> imprimirCorteCaja({
    required int totalPiezas,
    required List<dynamic> detalles,
    required List<dynamic> apartados,
    required List<dynamic> cambios,
    required List<dynamic> gastosLista,
    required double calcVentasTotales,
    required double calcTarjeta,
    required double calcTransferencia,
    required double calcEfectivo,
    required double gastosTotales,
    required double totalFisicoCaja,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? imageLogo;

    try {
      imageLogo = pw.MemoryImage(
        (await rootBundle.load('assets/logo.png')).buffer.asUint8List(),
      );
    } catch (e) {
      debugPrint('Aviso Logo: $e');
    }

    final now = DateTime.now();
    final fechaHora =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 5 * PdfPageFormat.mm, // 🚨 MARGEN AMPLIADO
        ),
        build: (pw.Context pdfCtx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (imageLogo != null) pw.Image(imageLogo, width: 55, height: 55),
              pw.SizedBox(height: 5),
              pw.Text(
                'CORTE DE CAJA',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('JP JEANS TLAXCALA', style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 5),
              pw.Text(fechaHora, style: pw.TextStyle(fontSize: 8)),
              pw.Divider(),

              if (detalles.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  'VENTAS DEL DÍA ($totalPiezas PZS)',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                ...detalles.map((item) {
                  String line = item['nombre'].toString();
                  String itemsVendidos = line.split('| Vendedor:')[0];
                  String vendedor = line.split('| Vendedor:').length > 1
                      ? line.split('| Vendedor:')[1]
                      : '';

                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        itemsVendidos.replaceAll('c/u.', 'c/u\n'),
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${item['metodo'] ?? 'Efectivo'}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            vendedor != '' ? 'Vend: $vendedor' : '',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            '\$${(item['precio'] as num).toDouble().toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  );
                }),
                pw.Divider(),
              ],

              if (apartados.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  'APARTADOS Y ABONOS',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                ...apartados.map(
                  (item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item['tipo']} - ${item['cliente']}',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        '\$${(item['monto'] as num).toDouble().toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
                pw.Divider(),
              ],

              if (cambios.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  'CAMBIOS REALIZADOS',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                ...cambios.map(
                  (item) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Entró: ${item['entra']}',
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'Salió: ${item['sale']}',
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'Motivo: ${item['motivo']}',
                        style: pw.TextStyle(fontSize: 7),
                      ),
                      pw.SizedBox(height: 3),
                    ],
                  ),
                ),
                pw.Divider(),
              ],

              if (gastosLista.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text(
                  'DETALLE DE GASTOS',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                ...gastosLista.map(
                  (item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${item['concepto']} (${item['hora'] ?? ''})',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        '-\$${(item['monto'] as num).toDouble().toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Text(
                'RESUMEN DE CAJA',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('PIEZAS VENDIDAS', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    '$totalPiezas PZS',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL EN TARJETA', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    '\$${calcTarjeta.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL TRANSFERENCIA',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    '\$${calcTransferencia.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL EN EFECTIVO',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    '\$${calcEfectivo.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('- GASTOS DEL DÍA', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    '-\$${gastosTotales.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Divider(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'EFECTIVO A ENTREGAR',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '\$${totalFisicoCaja.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL DE DINERO',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '\$${calcVentasTotales.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 15 * PdfPageFormat.mm),
            ],
          );
        },
      ),
    );

    try {
      final Uint8List bytesPdfCorte = await doc.save();
      final Directory? baseDir = await _obtenerDirectorioBase();
      if (baseDir != null) {
        final directorioCortes = Directory(
          '${baseDir.path}/Cortes_Caja_Guardados',
        );
        if (!await directorioCortes.exists()) {
          await directorioCortes.create(recursive: true);
        }
        final String nombreArchivo =
            'Corte_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.pdf';
        final File archivo = File('${directorioCortes.path}/$nombreArchivo');
        await archivo.writeAsBytes(bytesPdfCorte);
      }
    } catch (e) {
      debugPrint('Aviso al guardar PDF corte local: $e');
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Corte_Caja_JPJeans',
    );
  }
}
