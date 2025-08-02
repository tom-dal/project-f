import 'package:json_annotation/json_annotation.dart';

enum PaymentStatus {
  @JsonValue('UNPAID')
  unpaid,
  @JsonValue('PARTIAL_PAYMENT')
  partialPayment,
  @JsonValue('PAID')
  paid,
}
