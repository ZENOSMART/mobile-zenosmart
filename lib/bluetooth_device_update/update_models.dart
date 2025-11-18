import 'dart:typed_data';

/// Firmware güncelleme bilgilerini tutan model
class UpdateInfo {
  final String? version;
  final int fileSize;
  final int fileState;
  final Uint8List rawEncryptedResponse;

  const UpdateInfo({
    required this.version,
    required this.fileSize,
    required this.fileState,
    required this.rawEncryptedResponse,
  });

  bool get isUpdateAvailable => fileState == 1;

  @override
  String toString() {
    return 'UpdateInfo(version: $version, fileSize: $fileSize, state: $fileState)';
  }
}

/// Cihazdan alınan versiyon bilgileri
class DeviceVersionInfo {
  final String? swVersion;
  final String? hwVersion;
  final String? project;

  const DeviceVersionInfo({
    this.swVersion,
    this.hwVersion,
    this.project,
  });

  @override
  String toString() {
    return 'DeviceVersion(SW: $swVersion, HW: $hwVersion, Project: $project)';
  }
}

/// Chunk transfer durumu
class ChunkProgress {
  final int chunkSize;
  final int partNum;
  final int totalChunks;
  final double progress;

  ChunkProgress({
    required this.chunkSize,
    required this.partNum,
    required this.totalChunks,
  }) : progress = totalChunks > 0 ? (partNum + 1) / totalChunks : 0.0;

  bool get isComplete => progress >= 1.0;

  @override
  String toString() {
    return 'ChunkProgress(part: $partNum/$totalChunks, ${(progress * 100).toStringAsFixed(1)}%)';
  }
}

/// Güncelleme durumu enum
enum UpdateState {
  idle,
  connecting,
  fetchingInfo,
  ready,
  updating,
  completed,
  waitingForRestart,
  failed,
}

/// Güncelleme olayları
abstract class UpdateEvent {}

class UpdateStateChanged extends UpdateEvent {
  final UpdateState state;
  UpdateStateChanged(this.state);
}

class UpdateProgressChanged extends UpdateEvent {
  final ChunkProgress progress;
  UpdateProgressChanged(this.progress);
}

class UpdateError extends UpdateEvent {
  final String message;
  UpdateError(this.message);
}

class UpdateCompleted extends UpdateEvent {
  final String message;
  UpdateCompleted(this.message);
}
