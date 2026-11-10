// lib/screens/qr_screen.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/fast_parts.dart';
import '../l10n/tr.dart';

/// Shown as a full-screen modal: client shows QR to staff for verification.
class QRVerificationScreen extends StatefulWidget {
  final Order order;
  const QRVerificationScreen({super.key, required this.order});

  @override
  State<QRVerificationScreen> createState() => _QRVerificationScreenState();
}

class _QRVerificationScreenState extends State<QRVerificationScreen> {
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final qrData = order.pickupToken ?? order.id;

    return Scaffold(
      backgroundColor: context.fast.bg,
      appBar: AppBar(
        backgroundColor: context.fast.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.fast.t2),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          tr(context, 'staff_check'),
          style: TextStyle(
            color: context.fast.t1,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.fast.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.fast.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(context, 'qr_present'),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.fast.t2,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 28),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.fast.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.fast.line),
              ),
              // A still QR: the scan-line loop was decoration and kept
              // the screen repainting while the customer held it up.
              child: SizedBox(
                width: 220,
                height: 220,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: FASTBrand.onAmber,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: FASTBrand.onAmber,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              tr(context, 'valid_at').replaceAll('{n}', order.restaurantName),
              textAlign: TextAlign.center,
              style: FASTText.body.copyWith(
                color: context.fast.t2,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            // The order id stays for support, but quiet — the pickup code
            // below is the thing to read out.
            Text(
              order.id.toUpperCase(),
              style: FASTText.caption.copyWith(
                color: context.fast.t3,
                letterSpacing: 1.2,
              ),
            ),
            if (order.pickupToken != null) ...[
              SizedBox(height: 24),
              FastPickupCode(
                code: pickupCodeFromToken(order.pickupToken!),
                label: tr(context, 'pickup_code_lbl'),
                hint: tr(context, 'pickup_code_hint'),
              ),
            ],
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.fast.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.fast.line),
              ),
              child: Column(
                children: [
                  _summaryRow(
                    tr(context, 'restaurant_lbl'),
                    order.restaurantName,
                  ),
                  const SizedBox(height: 8),
                  _summaryRow(
                    tr(context, 'articles'),
                    tr(
                      context,
                      'articles_count',
                    ).replaceAll('{n}', '${order.items.length}'),
                  ),
                  const SizedBox(height: 8),
                  _summaryRow(
                    tr(context, 'total'),
                    '${order.total.toStringAsFixed(2)} €',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildStatusSection(order.status),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: context.fast.t3)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: context.fast.t1,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(OrderStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case OrderStatus.placed:
        color = Colors.blue;
        label = tr(context, 'qs_ordered');
        icon = Icons.receipt_long;
        break;
      case OrderStatus.preparing:
        color = Color(0xFFF59E0B);
        label = tr(context, 'qs_preparing');
        icon = Icons.restaurant_menu;
        break;
      case OrderStatus.readyForPickup:
        color = Color(0xFF10B981);
        label = tr(context, 'qs_ready');
        icon = Icons.check_circle;
        break;
      case OrderStatus.completed:
        color = context.fast.t3;
        label = tr(context, 'qs_done');
        icon = Icons.handshake;
        break;
      case OrderStatus.cancelled:
        color = const Color(0xFFEF4444);
        label = tr(context, 'ost_cancelled');
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
