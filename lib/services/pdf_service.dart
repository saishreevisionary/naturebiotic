import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class PdfService {
  static Future<void> generateAndShare({
    required Map<String, dynamic> report,
    required String farmName,
    required String cropName,
    required String farmerName,
  }) async {
    final pdf = pw.Document();

    // Load fonts that support the Rupee symbol (₹)
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    final problemWidget = await _buildProblemSection(report['problem'] ?? '', font, boldFont);
    
    pw.Widget? signatureImage;
    if (report['signature_url'] != null) {
      try {
        final img = await networkImage(report['signature_url']);
        signatureImage = pw.Image(img, height: 40);
      } catch (e) {
        debugPrint('Error loading signature image: $e');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (context) => [
          _buildHeader(dateStr),
          pw.SizedBox(height: 20),
          _buildInfoSection(farmName, cropName, farmerName),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Problem Analysis'),
          problemWidget,
          pw.SizedBox(height: 15),
          _buildSectionTitle('Previous Inputs History'),
          _buildHistoryGrid(report['previous_inputs'] ?? 'No data provided', font, boldFont),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Recommended Products & Treatments'),
          _buildRecommendationsTable(report['recommendations'] ?? ''),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Product Requirements & Estimations'),
          _buildCostTable(report['estimated_cost'] ?? ''),
          pw.Spacer(),
          _buildFooter(signatureImage),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'NatureBiotic_AnalysisReport_${farmName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildHistoryGrid(String history, pw.Font font, pw.Font bold) {
    if (history.isEmpty) return pw.Text('No data provided', style: pw.TextStyle(fontSize: 10));
    
    // Check if it's the new aggregated format
    if (history.contains('\n\nHistorical Records:')) {
      final parts = history.split('\n\nHistorical Records:');
      final currentPart = parts[0];
      final historicalPart = parts[1];
      
      final historyRecords = historicalPart.split('\n--- ').where((p) => p.trim().isNotEmpty).toList();
      
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Current Visit Pre-Visit Observations:', style: pw.TextStyle(fontSize: 10, font: bold)),
          pw.Text(currentPart, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.Text('Historical Entries:', style: pw.TextStyle(fontSize: 10, font: bold)),
          pw.SizedBox(height: 5),
          pw.Wrap(
            spacing: 15,
            runSpacing: 10,
            children: [
              ...historyRecords.map((record) {
                // Format was: "--- $hDate ---\n$hInputs"
                // But my split removed "--- "
                final subParts = record.split(' ---\n');
                if (subParts.length < 2) return pw.Text(record, style: const pw.TextStyle(fontSize: 8));
                
                final dateStr = subParts[0];
                final inputs = subParts[1];
                
                return pw.Container(
                  width: 230,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(dateStr, style: pw.TextStyle(fontSize: 8, font: bold, color: PdfColors.green900)),
                      pw.Divider(color: PdfColors.grey300),
                      pw.Text(inputs, style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      );
    }

    return pw.Text(history, style: const pw.TextStyle(fontSize: 10));
  }

  static pw.Widget _buildHeader(String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('NATURE BIOTIC', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
            pw.Text('Agricultural Analysis & Recommendation Report', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          ],
        ),
        pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildInfoSection(String farm, String crop, String farmer) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _infoItem('Farmer Name', farmer),
          _infoItem('Farm Name', farm),
          _infoItem('Crop Name', crop),
        ],
      ),
    );
  }

  static pw.Widget _infoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(color: PdfColors.green100),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
    );
  }

  static pw.Widget _buildRecommendationsTable(String recommendations) {
    final lines = recommendations.split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return pw.Text('No recommendations provided.');

    return pw.TableHelper.fromTextArray(
      context: null,
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      data: <List<String>>[
        ['Product', 'Application', 'Dose', 'Filler Qty'],
        ...lines.map((line) {
          // Format from app: "Product Name (Application) - Dose: X, Filler: Y"
          final parts = line.split(' - ');
          if (parts.length < 2) return [line, '', '', ''];
          
          final prodPart = parts[0]; // "Name (App)"
          final detailsPart = parts[1]; // "Dose: X, Filler: Y"
          
          final prodName = prodPart.contains('(') ? prodPart.split('(')[0].trim() : prodPart;
          final app = prodPart.contains('(') ? prodPart.split('(')[1].replaceAll(')', '').trim() : '';
          
          final detailParts = detailsPart.split(', ');
          final dose = detailParts[0].replaceAll('Dose: ', '').trim();
          final filler = detailParts.length > 1 ? detailParts[1].replaceAll('Filler: ', '').trim() : '';
          
          return [prodName, app, dose, filler];
        }),
      ],
    );
  }

  static pw.Widget _buildCostTable(String costs) {
    final lines = costs.split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return pw.Text('No estimation provided.');

    final tableData = <List<String>>[
      ['Product Name', 'Pkg Size', 'Qty #', 'MRP', 'Offer Price', 'Total Value'],
    ];

    String grandTotal = '0';
    String nextVisit = 'N/A';

    for (var line in lines) {
      if (line.startsWith('Grand Total:')) {
        grandTotal = line.split(': ')[1];
        continue;
      }
      if (line.startsWith('Next Visit:')) {
        nextVisit = line.split(': ')[1];
        continue;
      }

      // Format from app: "Product Name (Pkg: X) - Qty: Y, MRP: Z, Offer: A, Total: B"
      final parts = line.split(' - ');
      if (parts.length < 2) continue;

      final prodPart = parts[0]; // "Product Name (Pkg: X)"
      final detailsPart = parts[1]; // "Qty: Y, MRP: Z, Offer: A, Total: B"

      final prodName = prodPart.contains('(Pkg:') ? prodPart.split('(Pkg:')[0].trim() : prodPart;
      final pkg = prodPart.contains('(Pkg:') ? prodPart.split('(Pkg:')[1].replaceAll(')', '').trim() : '';

      final detailParts = detailsPart.split(', ');
      final qty = detailParts.length > 0 ? detailParts[0].replaceAll('Qty: ', '').trim() : '';
      final mrp = detailParts.length > 1 ? detailParts[1].replaceAll('MRP: ', '').trim() : '';
      final offer = detailParts.length > 2 ? detailParts[2].replaceAll('Offer: ', '').trim() : '';
      final total = detailParts.length > 3 ? detailParts[3].replaceAll('Total: ', '').trim() : '';

      tableData.add([prodName, pkg, qty, mrp, offer, total]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.TableHelper.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
          cellStyle: const pw.TextStyle(fontSize: 9),
          data: tableData,
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Next Visit Date: $nextVisit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            pw.Text('GRAND TOTAL: $grandTotal', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
          ],
        ),
      ],
    );
  }

  static Future<pw.Widget> _buildProblemSection(String problem, pw.Font font, pw.Font bold) async {
    final parts = problem.split(', ');
    List<pw.Widget> items = [];
    
    for (var part in parts) {
      if (part.contains('{img:')) {
        final problemName = part.split('{img:')[0].trim();
        final imageUrl = part.split('{img:')[1].replaceAll('}', '').trim();
        
        pw.Widget imageWidget;
        try {
          final image = await networkImage(imageUrl);
          imageWidget = pw.Container(
            height: 140,
            width: 230,
            child: pw.Image(image, fit: pw.BoxFit.cover),
          );
        } catch (e) {
          imageWidget = pw.Text('Error loading image', style: pw.TextStyle(fontSize: 8, color: PdfColors.red));
        }

        items.add(
          pw.Container(
            width: 230,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(problemName, style: pw.TextStyle(font: bold, fontSize: 10)),
                pw.SizedBox(height: 5),
                imageWidget,
                pw.SizedBox(height: 10),
              ],
            ),
          ),
        );
      } else {
        items.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(part, style: const pw.TextStyle(fontSize: 10)),
          ),
        );
      }
    }

    return pw.Wrap(
      spacing: 15,
      runSpacing: 15,
      children: items,
    );
  }

  static pw.Widget _buildFooter(pw.Widget? signature) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Nature Biotic Executive Signature', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 5),
                if (signature != null) 
                  pw.Container(
                    height: 30,
                    child: signature,
                  )
                else 
                  pw.SizedBox(height: 30),
                pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)))),
              ],
            ),
            pw.Text('Thank you for choosing Nature Biotic for a sustainable future.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }
}

