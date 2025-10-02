import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import '../../constants/nfc_constants.dart';
import '../../models/nfc_doc.dart';

class DocumentStorageService {
  DocumentStorageService._();
  static final instance = DocumentStorageService._();

  Box<NfcDoc>? _box;

  Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(40)) {
      Hive.registerAdapter(DocumentTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(41)) {
      Hive.registerAdapter(NfcDocAdapter());
    }
    final cipher = await _loadOrCreateCipher();
    _box = await Hive.openBox<NfcDoc>(
      NfcConstants.hiveBoxDocs,
      encryptionCipher: cipher,
    );
  }

  Future<HiveAesCipher> _loadOrCreateCipher() async {
    const storage = FlutterSecureStorage();
    final existing = await storage.read(key: NfcConstants.secureStorageHiveKey);
    List<int> keyBytes;
    if (existing == null) {
      final rand = Random.secure();
      keyBytes = List<int>.generate(32, (_) => rand.nextInt(256));
      await storage.write(
        key: NfcConstants.secureStorageHiveKey,
        value: keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      );
    } else {
      keyBytes = [
        for (int i = 0; i < existing.length; i += 2)
          int.parse(existing.substring(i, i + 2), radix: 16)
      ];
    }
    return HiveAesCipher(keyBytes);
  }

  List<NfcDoc> getAll() {
    final b = _box;
    if (b == null) return [];
    return b.values.toList()
      ..sort((a, b) => b.lastScannedAt.compareTo(a.lastScannedAt));
  }

  Future<void> saveOrUpdate(NfcDoc doc) async {
    final b = _box!;
    // Overwrite by unique key: type + document number
    final key = _keyFor(doc.type, doc.documentNumber);
    await b.put(key, doc);
  }

  Future<void> rename(String typeAndNoKey, String alias) async {
    final b = _box!;
    final doc = b.get(typeAndNoKey);
    if (doc != null) {
      doc.alias = alias;
      await b.put(typeAndNoKey, doc);
    }
  }

  Future<void> delete(String typeAndNoKey) async {
    await _box?.delete(typeAndNoKey);
  }

  static String keyFor(DocumentType type, String documentNumber) =>
      _keyFor(type, documentNumber);

  static String _keyFor(DocumentType type, String documentNumber) =>
      '${type.name}:${documentNumber.toUpperCase()}';
}
