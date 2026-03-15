/// Текущая подписка салона (GET /subscriptions/current).
class Subscription {
  final String id;
  final String salonId;
  final String type; // TRIAL, STARTER
  final String status; // ACTIVE, INACTIVE, CANCELLED, EXPIRED
  final String startDate;
  final String? endDate;
  final String? nextPaymentDate;
  final String? trialEndDate;
  final double? amount;
  final String? stripeCustomerId;

  Subscription({
    required this.id,
    required this.salonId,
    required this.type,
    required this.status,
    required this.startDate,
    this.endDate,
    this.nextPaymentDate,
    this.trialEndDate,
    this.amount,
    this.stripeCustomerId,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => status == 'EXPIRED';
  bool get isCancelled => status == 'CANCELLED';

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'];
    double? amount;
    if (amountRaw != null) {
      amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw.toString());
    }
    return Subscription(
      id: (json['id']?.toString() ?? '').trim(),
      salonId: (json['salonId']?.toString() ?? '').trim(),
      type: (json['type'] as String?) ?? 'BASIC',
      status: (json['status'] as String?) ?? 'INACTIVE',
      startDate: (json['startDate'] as String?) ?? '',
      endDate: json['endDate'] as String?,
      nextPaymentDate: json['nextPaymentDate'] as String?,
      trialEndDate: json['trialEndDate'] as String?,
      amount: amount,
      stripeCustomerId: json['stripeCustomerId'] as String?,
    );
  }
}

/// Счёт из Stripe (GET /subscriptions/invoices).
class SubscriptionInvoice {
  final String id;
  final String? number;
  final String date;
  final double amount;
  final String currency;
  final String status;
  final String? pdfUrl;
  final String? hostedInvoiceUrl;

  SubscriptionInvoice({
    required this.id,
    this.number,
    required this.date,
    required this.amount,
    required this.currency,
    required this.status,
    this.pdfUrl,
    this.hostedInvoiceUrl,
  });

  factory SubscriptionInvoice.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'];
    final amount = amountRaw is num
        ? amountRaw.toDouble()
        : (double.tryParse(amountRaw?.toString() ?? '') ?? 0.0);
    return SubscriptionInvoice(
      id: json['id']?.toString() ?? '',
      number: json['number'] as String?,
      date: json['date']?.toString() ?? '',
      amount: amount,
      currency: json['currency']?.toString() ?? 'VND',
      status: json['status']?.toString() ?? 'unknown',
      pdfUrl: json['pdfUrl'] as String?,
      hostedInvoiceUrl: json['hostedInvoiceUrl'] as String?,
    );
  }
}
