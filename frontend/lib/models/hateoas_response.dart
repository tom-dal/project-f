import 'package:json_annotation/json_annotation.dart';

part 'hateoas_response.g.dart';

/// Represents pagination information in HATEOAS responses
@JsonSerializable()
class PageInfo {
  final int size;
  final int totalElements;
  final int totalPages;
  final int number;

  PageInfo({
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.number,
  });

  // USER PREFERENCE: Added computed getters for pagination navigation
  /// Returns true if this is the first page
  bool get first => number == 0;

  /// Returns true if this is the last page
  bool get last => number >= (totalPages - 1);

  factory PageInfo.fromJson(Map<String, dynamic> json) => _$PageInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PageInfoToJson(this);
}

/// Represents HATEOAS links
@JsonSerializable()
class HateoasLink {
  final String href;
  final String? templated;

  HateoasLink({
    required this.href,
    this.templated,
  });

  factory HateoasLink.fromJson(Map<String, dynamic> json) => _$HateoasLinkFromJson(json);
  Map<String, dynamic> toJson() => _$HateoasLinkToJson(this);
}

/// Represents the _links section in HATEOAS responses
@JsonSerializable()
class HateoasLinks {
  final HateoasLink? self;
  final HateoasLink? first;
  final HateoasLink? prev;
  final HateoasLink? next;
  final HateoasLink? last;
  // CRUD operation links
  final HateoasLink? update;
  final HateoasLink? delete;
  final HateoasLink? edit;

  HateoasLinks({
    this.self,
    this.first,
    this.prev,
    this.next,
    this.last,
    this.update,
    this.delete,
    this.edit,
  });

  factory HateoasLinks.fromJson(Map<String, dynamic> json) => _$HateoasLinksFromJson(json);
  Map<String, dynamic> toJson() => _$HateoasLinksToJson(this);
}

/// Generic HATEOAS paginated response
@JsonSerializable(genericArgumentFactories: true)
class HateoasPaginatedResponse<T> {
  @JsonKey(name: '_embedded')
  final Map<String, dynamic>? embedded;
  
  final PageInfo page;
  
  @JsonKey(name: '_links')
  final HateoasLinks links;

  HateoasPaginatedResponse({
    this.embedded,
    required this.page,
    required this.links,
  });

  /// Extract the list of items from the embedded section
  List<T> getItems<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    if (embedded == null || !embedded!.containsKey(key)) {
      return [];
    }
    
    final itemsData = embedded![key];
    if (itemsData is! List) {
      return [];
    }
    
    return itemsData
        .cast<Map<String, dynamic>>()
        .map((json) => fromJson(json))
        .toList();
  }

  factory HateoasPaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) => _$HateoasPaginatedResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(
    Object? Function(T value) toJsonT,
  ) => _$HateoasPaginatedResponseToJson(this, toJsonT);
}
