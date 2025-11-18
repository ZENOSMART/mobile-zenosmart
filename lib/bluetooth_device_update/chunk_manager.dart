import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'update_models.dart';

/// Chunk transfer yönetim sınıfı
class ChunkManager {
  final int _totalFileSize;
  int _currentChunkSize = 0;
  int _currentPartNum = 0;
  int _initialChunkSize = 0; // İlk chunkSize'ı sabitle
  int _initialTotalChunks = 0; // İlk toplam chunk sayısını sabitle

  ChunkManager(this._totalFileSize);

  /// STM32'den gelen chunk isteğini parse et
  /// Örnek: {"ChunkSize":512, "PartNum":45}
  /// İlk chunkSize'ı sabitler, sonraki değişiklikleri dikkate almaz
  ChunkProgress? parseChunkRequest(String data) {
    try {
      // Regex ile ChunkSize ve PartNum değerlerini çıkar
      final match = RegExp(
        r'"ChunkSize"\s*:\s*(\d+),\s*"PartNum"\s*:\s*(\d+)',
      ).firstMatch(data);

      if (match == null) return null;

      final chunkSize = int.parse(match.group(1)!);
      final partNum = int.parse(match.group(2)!);

      // İlk chunk request'te chunkSize'ı sabitle
      if (_initialChunkSize == 0) {
        _initialChunkSize = chunkSize;
        _initialTotalChunks = (_totalFileSize / _initialChunkSize).ceil();
        debugPrint('[ChunkManager] 🔒 İlk chunkSize sabitlendi: $_initialChunkSize, toplam: $_initialTotalChunks');
      }

      // PartNum maksimum değeri aşıyorsa, gönderme
      if (partNum >= _initialTotalChunks) {
        debugPrint('[ChunkManager] ⚠️ PartNum ($partNum) maksimum değeri ($_initialTotalChunks) aşıyor, gönderme!');
        return null;
      }

      _currentChunkSize = chunkSize;
      _currentPartNum = partNum;

      // Progress hesaplamasında ilk sabitlenen chunkSize'ı kullan
      final progress = ChunkProgress(
        chunkSize: _initialChunkSize,
        partNum: _currentPartNum,
        totalChunks: _initialTotalChunks,
      );

      debugPrint('[ChunkManager] 📊 $progress');
      return progress;
    } catch (e) {
      debugPrint('[ChunkManager] ❌ Parse error: $e');
      return null;
    }
  }

  /// Chunk isteğini sunucuya gönderilecek formata çevir
  Uint8List createChunkRequestPacket(int chunkSize, int partNum) {
    final json = '{"ChunkSize":$chunkSize, "PartNum":$partNum}\n';
    return Uint8List.fromList(json.codeUnits);
  }

  /// İlerleme yüzdesi
  double get progress {
    if (_initialChunkSize == 0 || _totalFileSize == 0) return 0.0;
    if (_initialTotalChunks == 0) return 0.0;
    return (_currentPartNum + 1) / _initialTotalChunks;
  }

  /// Tamamlandı mı?
  /// Son chunk gönderildiğinde (partNum + 1 >= totalChunks) tamamlanmış sayılır
  /// NOT: Bu kontrol paket gönderildikten SONRA yapılmalı
  bool get isComplete {
    if (_initialTotalChunks == 0) return false;
    // Son paket gönderildi mi? (partNum 0-indexed, totalChunks 1-indexed)
    // Örnek: partNum=1042, totalChunks=1043 -> 1042+1=1043 >= 1043 -> true
    return _currentPartNum + 1 >= _initialTotalChunks;
  }
  
  /// Son paket mi? (henüz gönderilmedi, sadece request geldi)
  /// Bu kontrol paket gönderilmeden ÖNCE yapılmalı
  bool get isLastChunk {
    if (_initialTotalChunks == 0) return false;
    return _currentPartNum + 1 >= _initialTotalChunks;
  }

  /// Toplam chunk sayısı (ilk sabitlenen değer)
  int get totalChunks {
    return _initialTotalChunks;
  }

  /// Mevcut chunk numarası
  int get currentPartNum => _currentPartNum;

  /// Mevcut chunk boyutu
  int get currentChunkSize => _currentChunkSize;

  /// Reset
  void reset() {
    _currentChunkSize = 0;
    _currentPartNum = 0;
    _initialChunkSize = 0;
    _initialTotalChunks = 0;
  }
}
