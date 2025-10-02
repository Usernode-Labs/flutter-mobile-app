import 'package:hive/hive.dart';

/// Document types supported.
enum DocumentType { passport, idCard, unknown }

/// Stored representation of an NFC ID document.
/// All fields are stored inside an encrypted Hive box.
class NfcDoc extends HiveObject {
  String id;

  String alias;

  DocumentType type;

  String documentNumber;

  String issuer;

  String givenNames;

  String surname;

  String nationality;

  String sex;

  DateTime dateOfBirth;

  DateTime dateOfExpiry;

  DateTime lastScannedAt;

  String mrzFullText;

  /// Optional face image (DG2). Stored as JPEG bytes if available.
  List<int>? faceImageJpeg;

  NfcDoc({
    required this.id,
    required this.alias,
    required this.type,
    required this.documentNumber,
    required this.issuer,
    required this.givenNames,
    required this.surname,
    required this.nationality,
    required this.sex,
    required this.dateOfBirth,
    required this.dateOfExpiry,
    required this.lastScannedAt,
    required this.mrzFullText,
    this.faceImageJpeg,
  });
}

class NfcDocAdapter extends TypeAdapter<NfcDoc> {
  @override
  final int typeId = 41;

  @override
  NfcDoc read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    final idx = (fields[2] as int? ?? -1);
    final type = (idx >= 0 && idx < DocumentType.values.length)
        ? DocumentType.values[idx]
        : DocumentType.unknown;
    return NfcDoc(
      id: fields[0] as String,
      alias: fields[1] as String,
      type: type,
      documentNumber: fields[3] as String,
      issuer: fields[4] as String,
      givenNames: fields[5] as String,
      surname: fields[6] as String,
      nationality: fields[7] as String,
      sex: fields[8] as String,
      dateOfBirth: DateTime.parse(fields[9] as String),
      dateOfExpiry: DateTime.parse(fields[10] as String),
      lastScannedAt: DateTime.parse(fields[11] as String),
      mrzFullText: fields[12] as String,
      faceImageJpeg: (fields[13] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, NfcDoc obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.alias)
      ..writeByte(2)
      ..write(obj.type.index)
      ..writeByte(3)
      ..write(obj.documentNumber)
      ..writeByte(4)
      ..write(obj.issuer)
      ..writeByte(5)
      ..write(obj.givenNames)
      ..writeByte(6)
      ..write(obj.surname)
      ..writeByte(7)
      ..write(obj.nationality)
      ..writeByte(8)
      ..write(obj.sex)
      ..writeByte(9)
      ..write(obj.dateOfBirth.toIso8601String())
      ..writeByte(10)
      ..write(obj.dateOfExpiry.toIso8601String())
      ..writeByte(11)
      ..write(obj.lastScannedAt.toIso8601String())
      ..writeByte(12)
      ..write(obj.mrzFullText)
      ..writeByte(13)
      ..write(obj.faceImageJpeg);
  }
}

class DocumentTypeAdapter extends TypeAdapter<DocumentType> {
  @override
  final typeId = 40;

  @override
  DocumentType read(BinaryReader reader) {
    final i = reader.readByte();
    switch (i) {
      case 0:
        return DocumentType.passport;
      case 1:
        return DocumentType.idCard;
      default:
        return DocumentType.unknown;
    }
  }

  @override
  void write(BinaryWriter writer, DocumentType obj) {
    switch (obj) {
      case DocumentType.passport:
        writer.writeByte(0);
        break;
      case DocumentType.idCard:
        writer.writeByte(1);
        break;
      case DocumentType.unknown:
        writer.writeByte(255);
        break;
    }
  }
}
