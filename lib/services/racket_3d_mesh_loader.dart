import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

/// A single geometric part of the 3D pickleball racket mesh.
class RacketMeshPart {
  final String name;
  final int vertexCount;
  final int indexCount;
  final Float32List vertices; // [x, y, z, nx, ny, nz, ...]
  final Uint16List indices;

  RacketMeshPart({
    required this.name,
    required this.vertexCount,
    required this.indexCount,
    required this.vertices,
    required this.indices,
  });
}

/// In-memory representation of the complete 3D pickleball racket.
class Racket3DMesh {
  final List<RacketMeshPart> parts;

  Racket3DMesh({required this.parts});

  RacketMeshPart get blade => parts[0];
  RacketMeshPart get grip => parts[1];
  RacketMeshPart get rim => parts[2];
}

/// Global cache and loader for the 3D racket mesh.
class Racket3DMeshLoader {
  static Racket3DMesh? _cachedMesh;

  static Future<Racket3DMesh> load() async {
    if (_cachedMesh != null) return _cachedMesh!;

    final data = await rootBundle.load('assets/models/racket_mesh.bin');
    final bytes = data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes);

    int offset = 0;
    // Magic check: 'RACK' (0x5241434B)
    final magic = bytes.getUint32(offset, Endian.little);
    offset += 4;
    if (magic != 0x4B434152 && magic != 0x5241434B) {
      throw FormatException('Invalid racket mesh magic: 0x${magic.toRadixString(16)}');
    }

    final partCount = bytes.getUint32(offset, Endian.little);
    offset += 4;

    final names = ['blade', 'grip', 'rim'];
    final List<RacketMeshPart> parts = [];

    for (int p = 0; p < partCount; p++) {
      final vertexCount = bytes.getUint32(offset, Endian.little);
      offset += 4;
      final indexCount = bytes.getUint32(offset, Endian.little);
      offset += 4;

      final vertFloats = vertexCount * 6;
      final vertBytes = vertFloats * 4;
      final vertices = Float32List.sublistView(
        data,
        offset,
        offset + vertBytes,
      );
      offset += vertBytes;

      final idxBytes = indexCount * 2;
      final indices = Uint16List.sublistView(
        data,
        offset,
        offset + idxBytes,
      );
      offset += idxBytes;

      parts.add(
        RacketMeshPart(
          name: p < names.length ? names[p] : 'part_$p',
          vertexCount: vertexCount,
          indexCount: indexCount,
          vertices: vertices,
          indices: indices,
        ),
      );
    }

    _cachedMesh = Racket3DMesh(parts: parts);
    return _cachedMesh!;
  }
}
