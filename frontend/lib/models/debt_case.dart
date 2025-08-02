import 'package:json_annotation/json_annotation.dart';
import 'case_state.dart';
import 'hateoas_response.dart';

part 'debt_case.g.dart';

@JsonSerializable()
class DebtCase {
  final String id; // Changed from int to String for MongoDB ObjectId compatibility
  final String debtorName;
  final double owedAmount;
  final CaseState state;
  final DateTime? createdDate;
  final DateTime? updatedDate;
  final DateTime lastStateDate;
  final DateTime? nextDeadlineDate;
  final String? createdBy;
  final String? lastModifiedBy;
  final DateTime? lastModifiedDate;
  final bool? ongoingNegotiations;
  final bool? hasInstallmentPlan;
  final bool? paid;
  final String? notes;
  final double? totalPaidAmount;
  final double? remainingAmount;
  final List<dynamic>? payments;
  final List<dynamic>? installments;
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
      // Handle date-only format (e.g., "2025-02-19")
      if (value.length == 10 && !value.contains('T')) {
        return DateTime.parse('${value}T00:00:00');
      }
      // Handle full datetime format (e.g., "2025-01-20T11:15:00")
      return DateTime.parse(value);
    }
    throw ArgumentError('Invalid date type: ${value.runtimeType}');
  }

  static String? _dateToJson(DateTime? date) {
    return date?.toIso8601String();
  }

  factory DebtCase.fromJson(Map<String, dynamic> json) => _$DebtCaseFromJson(json);
  Map<String, dynamic> toJson() => _$DebtCaseToJson(this);
}