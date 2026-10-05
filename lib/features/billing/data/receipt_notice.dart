import '../../withdrawals/data/models.dart' show NoticeReach;

/// A quién le llega el recibo y por dónde (lo que de verdad pasa) y, para
/// quien no tiene la app, el mensaje con el link al recibo (vale 30 días) para
/// mandárselo por WhatsApp.
class ReceiptNotice {
  const ReceiptNotice({
    this.reach = const [],
    this.message = '',
    this.receiptUrl,
  });

  static ReceiptNotice? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return ReceiptNotice(
      reach: ((json['reach'] as List?) ?? const [])
          .map((r) => NoticeReach.fromJson(r as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String? ?? '',
      receiptUrl: json['receipt_url'] as String?,
    );
  }

  final List<NoticeReach> reach;
  final String message;
  final String? receiptUrl;

  /// Los que no tienen la app pero sí celular.
  List<NoticeReach> get viaWhatsApp =>
      reach.where((person) => person.canWhatsApp).toList();
}
