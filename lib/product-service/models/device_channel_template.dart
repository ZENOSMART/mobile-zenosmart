class DeviceChannelTemplate {
  final String? accountId;
  final String createdAt;
  final int? channelCode;
  final String? channelType;
  final String? dataType;
  final int? dataLimitMin;
  final int? dataLimitMax;
  final int? dataByteLength;
  final int? mqttPackageOrder;
  final bool? hasSubChannel;
  final Map<String, dynamic>? formula;
  final String? enName;
  final String? trName;
  final String? frName;
  final String? arName;
  final String? esName;
  final String id;
  final String updatedAt;
  final DeviceTypeModelDto? deviceTypeModelDto;

  const DeviceChannelTemplate({
    this.accountId,
    required this.createdAt,
    this.channelCode,
    this.channelType,
    this.dataType,
    this.dataLimitMin,
    this.dataLimitMax,
    this.dataByteLength,
    this.mqttPackageOrder,
    this.hasSubChannel,
    this.formula,
    this.enName,
    this.trName,
    this.frName,
    this.arName,
    this.esName,
    required this.id,
    required this.updatedAt,
    this.deviceTypeModelDto,
  });

  factory DeviceChannelTemplate.fromJson(Map<String, dynamic> json) {
    return DeviceChannelTemplate(
      accountId: json['accountId'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      channelCode: json['channelCode'] as int?,
      channelType: json['channelType'] as String?,
      dataType: json['dataType'] as String?,
      dataLimitMin: json['dataLimitMin'] as int?,
      dataLimitMax: json['dataLimitMax'] as int?,
      dataByteLength: json['dataByteLength'] as int?,
      mqttPackageOrder: json['mqttPackageOrder'] as int?,
      hasSubChannel: json['hasSubChannel'] as bool?,
      formula: json['formula'] != null
          ? Map<String, dynamic>.from(json['formula'] as Map)
          : null,
      enName: json['enName'] as String?,
      trName: json['trName'] as String?,
      frName: json['frName'] as String?,
      arName: json['arName'] as String?,
      esName: json['esName'] as String?,
      id: json['id'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      deviceTypeModelDto: json['deviceTypeModelDto'] != null
          ? DeviceTypeModelDto.fromJson(
              json['deviceTypeModelDto'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountId': accountId,
      'createdAt': createdAt,
      'channelCode': channelCode,
      'channelType': channelType,
      'dataType': dataType,
      'dataLimitMin': dataLimitMin,
      'dataLimitMax': dataLimitMax,
      'dataByteLength': dataByteLength,
      'mqttPackageOrder': mqttPackageOrder,
      'hasSubChannel': hasSubChannel,
      'formula': formula,
      'enName': enName,
      'trName': trName,
      'frName': frName,
      'arName': arName,
      'esName': esName,
      'id': id,
      'updatedAt': updatedAt,
      'deviceTypeModelDto': deviceTypeModelDto?.toJson(),
    };
  }
}

class DeviceTypeModelDto {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String? orderCode;
  final String? classType;
  final String? name;

  const DeviceTypeModelDto({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.orderCode,
    this.classType,
    this.name,
  });

  factory DeviceTypeModelDto.fromJson(Map<String, dynamic> json) {
    return DeviceTypeModelDto(
      id: json['id'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      orderCode: json['orderCode'] as String?,
      classType: json['classType'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'orderCode': orderCode,
      'classType': classType,
      'name': name,
    };
  }
}
