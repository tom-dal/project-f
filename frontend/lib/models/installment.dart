import 'package:json_annotation/json_annotation.dart';

part 'installment.g.dart';

@JsonSerializable()
class Installment {
  final String id;
  final String? debtCaseId; // backend may omit
  final int installmentNumber;
  final double amount; // USER PREFERENCE: backend BigDecimal -> double here
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime dueDate;
  final bool? paid;
  @JsonKey(fromJson: _dateFromJson, toJson: _dateTimeToJson)
  final DateTime? paidDate;
  final double? paidAmount;
  @JsonKey(fromJson: _dateFromJson, toJson: _dateTimeToJson)
  final DateTime? createdDate;
  @JsonKey(fromJson: _dateFromJson, toJson: _dateTimeToJson)
  final DateTime? lastModifiedDate;

  Installment({
    required this.id,
    this.debtCaseId,
    required this.installmentNumber,
    required this.amount,
    required this.dueDate,
    this.paid,
    this.paidDate,
    this.paidAmount,
    this.createdDate,
    this.lastModifiedDate,
  });

  factory Installment.fromJson(Map<String, dynamic> json) => _$InstallmentFromJson(json);
  Map<String, dynamic> toJson() => _$InstallmentToJson(this);

  static DateTime _dateFromJson(String v) => DateTime.parse(v);
  static String _dateToJson(DateTime v) => v.toIso8601String();
  static String? _dateTimeToJson(DateTime? v) => v?.toIso8601String();
}

