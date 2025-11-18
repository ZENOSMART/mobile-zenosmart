class ProductApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final String status;

  const ProductApiResponse({
    required this.success,
    this.data,
    required this.message,
    required this.status,
  });

  factory ProductApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? dataParser,
  ) {
    return ProductApiResponse(
      success: json['success'] as bool? ?? false,
      data: dataParser != null && json['data'] != null
          ? dataParser(json['data'])
          : null,
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class PageableData<T> {
  final List<T> content;
  final Pageable pageable;
  final int totalElements;
  final int totalPages;
  final bool last;
  final int size;
  final int number;
  final Sort sort;
  final int numberOfElements;
  final bool first;
  final bool empty;

  const PageableData({
    required this.content,
    required this.pageable,
    required this.totalElements,
    required this.totalPages,
    required this.last,
    required this.size,
    required this.number,
    required this.sort,
    required this.numberOfElements,
    required this.first,
    required this.empty,
  });

  factory PageableData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) contentParser,
  ) {
    final contentList = json['content'] as List<dynamic>? ?? [];
    return PageableData(
      content: contentList
          .map((e) => contentParser(e as Map<String, dynamic>))
          .toList(),
      pageable: Pageable.fromJson(
        json['pageable'] as Map<String, dynamic>? ?? {},
      ),
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      last: json['last'] as bool? ?? false,
      size: json['size'] as int? ?? 0,
      number: json['number'] as int? ?? 0,
      sort: Sort.fromJson(json['sort'] as Map<String, dynamic>? ?? {}),
      numberOfElements: json['numberOfElements'] as int? ?? 0,
      first: json['first'] as bool? ?? false,
      empty: json['empty'] as bool? ?? true,
    );
  }
}

class Pageable {
  final int pageNumber;
  final int pageSize;
  final Sort sort;
  final int offset;
  final bool paged;
  final bool unpaged;

  const Pageable({
    required this.pageNumber,
    required this.pageSize,
    required this.sort,
    required this.offset,
    required this.paged,
    required this.unpaged,
  });

  factory Pageable.fromJson(Map<String, dynamic> json) {
    return Pageable(
      pageNumber: json['pageNumber'] as int? ?? 0,
      pageSize: json['pageSize'] as int? ?? 0,
      sort: Sort.fromJson(json['sort'] as Map<String, dynamic>? ?? {}),
      offset: json['offset'] as int? ?? 0,
      paged: json['paged'] as bool? ?? false,
      unpaged: json['unpaged'] as bool? ?? false,
    );
  }
}

class Sort {
  final bool sorted;
  final bool empty;
  final bool unsorted;

  const Sort({
    required this.sorted,
    required this.empty,
    required this.unsorted,
  });

  factory Sort.fromJson(Map<String, dynamic> json) {
    return Sort(
      sorted: json['sorted'] as bool? ?? false,
      empty: json['empty'] as bool? ?? true,
      unsorted: json['unsorted'] as bool? ?? true,
    );
  }
}
