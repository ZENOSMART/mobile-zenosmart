class DeviceTypeModel {
  final String? accountId;
  final String createdAt;
  final DeviceTypeDto? deviceTypeDto;
  final String? name;
  final String orderCode;
  final String id;
  final String classType;
  final String updatedAt;
  final String? parameterGroupCode;

  const DeviceTypeModel({
    this.accountId,
    required this.createdAt,
    this.deviceTypeDto,
    this.name,
    required this.orderCode,
    required this.id,
    required this.classType,
    required this.updatedAt,
    this.parameterGroupCode,
  });

  factory DeviceTypeModel.fromJson(Map<String, dynamic> json) {
    return DeviceTypeModel(
      accountId: json['accountId'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      deviceTypeDto: json['deviceTypeDto'] != null
          ? DeviceTypeDto.fromJson(
              json['deviceTypeDto'] as Map<String, dynamic>,
            )
          : null,
      name: json['name'] as String?,
      orderCode: json['orderCode'] as String? ?? '',
      id: json['id'] as String? ?? '',
      classType: json['classType'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      parameterGroupCode: json['parameterGroupCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountId': accountId,
      'createdAt': createdAt,
      'deviceTypeDto': deviceTypeDto?.toJson(),
      'name': name,
      'orderCode': orderCode,
      'id': id,
      'classType': classType,
      'updatedAt': updatedAt,
      'parameterGroupCode': parameterGroupCode,
    };
  }
}

class DeviceTypeDto {
  final String id;
  final String createdAt;
  final String updatedAt;
  final bool isIot;

  const DeviceTypeDto({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.isIot,
  });

  factory DeviceTypeDto.fromJson(Map<String, dynamic> json) {
    return DeviceTypeDto(
      id: json['id'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      isIot: json['isIot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isIot': isIot,
    };
  }
}
