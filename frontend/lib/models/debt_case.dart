import 'package:json_annotation/json_annotation.dart';
import 'case_state.dart';
import 'hateoas_response.dart';
import 'installment.dart';

part 'debt_case.g.dart';

@JsonSerializable()
class DebtCase {
  final String id; // Changed from int to String for MongoDB ObjectId compatibility
  final String debtorName;
  final double owedAmount;
  final CaseState state;
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime? createdDate;
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime? updatedDate;
  @JsonKey(fromJson: _dateFromJsonRequired, toJson: _dateToJson)
  final DateTime lastStateDate;
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime? nextDeadlineDate;
  final String? createdBy;
  final String? lastModifiedBy;
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime? lastModifiedDate;
  final bool? ongoingNegotiations;
  final bool? hasInstallmentPlan;
  final bool? paid;
  final String? notes;
  final double? totalPaidAmount;
  final double? remainingAmount;
  final List<dynamic>? payments;
  final List<Installment>? installments;
  // HATEOAS links
  @JsonKey(name: '_links')
  final HateoasLinks? links;

  DebtCase({
    required this.id,
    required this.debtorName,
    required this.owedAmount,
    required this.state,
    this.createdDate,
    this.updatedDate,
    required this.lastStateDate,
    this.nextDeadlineDate,
    this.createdBy,
    this.lastModifiedBy,
    this.lastModifiedDate,
    this.ongoingNegotiations,
    this.hasInstallmentPlan,
    this.paid,
    this.notes,
    this.totalPaidAmount,
    this.remainingAmount,
    this.payments,
    this.installments,
    this.links,
  });

  static DateTime? _dateFromJson(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.length == 10 && !value.contains('T')) {
        return DateTime.parse(value);
      }
      return DateTime.parse(value);
    }
    return null;
  }

  // CUSTOM IMPLEMENTATION: ensure non-null for required DateTime field
  static DateTime _dateFromJsonRequired(dynamic value) {
    final dt = _dateFromJson(value);
    if (dt == null) {
      throw const FormatException('lastStateDate is required but was null or invalid');
    }
    return dt;
  }

  static String? _dateToJson(DateTime? value) {
    if (value == null) return null;
    // Send only date part (yyyy-MM-dd)
    return value.toIso8601String().split('T').first;
  }

  factory DebtCase.fromJson(Map<String, dynamic> json) => _$DebtCaseFromJson(json);
  Map<String, dynamic> toJson() => _$DebtCaseToJson(this);
}