import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZkPassportOuterProofPublicInputs', () {
    test('extracts outer_count_4 scoped nullifier with semantic count 9', () {
      final inputs = _publicInputs(12)
        ..[6] = _field(4)
        ..[7] = _scopedNullifier
        ..[8] = _oprfPkHash
        ..[11] = _recursiveVerifierInput;

      final parsed = ZkPassportOuterProofPublicInputs.fromPublicInputsHex(
        inputs,
        facematchStrict: false,
      );

      expect(parsed, isNotNull);
      expect(
        parsed!.semanticInputCount,
        ZkPassportOuterProofPublicInputs.outerCount4SemanticPublicInputCount,
      );
      expect(parsed.nullifierTypeHex, _field(4));
      expect(parsed.scopedNullifierHex, _scopedNullifier);
      expect(parsed.oprfPkHashHex, _oprfPkHash);
    });

    test('extracts outer_count_5 scoped nullifier with semantic count 10', () {
      final inputs = _publicInputs(13)
        ..[7] = _field(5)
        ..[8] = _scopedNullifier
        ..[9] = _oprfPkHash
        ..[12] = _recursiveVerifierInput;

      final parsed = ZkPassportOuterProofPublicInputs.fromPublicInputsHex(
        inputs,
        facematchStrict: true,
      );

      expect(parsed, isNotNull);
      expect(
        parsed!.semanticInputCount,
        ZkPassportOuterProofPublicInputs.outerCount5SemanticPublicInputCount,
      );
      expect(parsed.nullifierTypeHex, _field(5));
      expect(parsed.scopedNullifierHex, _scopedNullifier);
      expect(parsed.oprfPkHashHex, _oprfPkHash);
    });

    test('does not mistake oprf_pk_hash for scoped_nullifier', () {
      final inputs = _publicInputs(10)
        ..[6] = _field(4)
        ..[7] = _scopedNullifier
        ..[8] = _oprfPkHash
        ..[9] = _recursiveVerifierInput;

      final parsed = ZkPassportOuterProofPublicInputs.fromPublicInputsHex(
        inputs,
        facematchStrict: false,
      );

      expect(parsed, isNotNull);
      expect(parsed!.scopedNullifierHex, isNot(parsed.oprfPkHashHex));
      expect(parsed.scopedNullifierHex, _scopedNullifier);
      expect(parsed.oprfPkHashHex, _oprfPkHash);
    });

    test('fails when bridge nullifier_hex differs from scoped_nullifier', () {
      final inputs = _publicInputs(9)
        ..[6] = _field(4)
        ..[7] = _scopedNullifier
        ..[8] = _oprfPkHash;

      final validation = ZkPassportOuterProofValidation.validate(
        publicInputsHex: inputs,
        facematchStrict: false,
        bridgeNullifierHex: _oprfPkHash,
      );

      expect(validation.isValid, isFalse);
      expect(validation.publicInputs, isNull);
      expect(validation.errorMessage, contains('nullifier_hex'));
    });

    test('fails when scoped_nullifier is missing', () {
      final inputs = _publicInputs(9)
        ..[6] = _field(4)
        ..[7] = ''
        ..[8] = _oprfPkHash;

      final validation = ZkPassportOuterProofValidation.validate(
        publicInputsHex: inputs,
        facematchStrict: false,
      );

      expect(validation.isValid, isFalse);
      expect(validation.publicInputs, isNull);
      expect(validation.errorMessage, contains('scoped_nullifier'));
    });

    test('fails when oprf_pk_hash is missing', () {
      final inputs = _publicInputs(9)
        ..[6] = _field(4)
        ..[7] = _scopedNullifier
        ..[8] = '';

      final validation = ZkPassportOuterProofValidation.validate(
        publicInputsHex: inputs,
        facematchStrict: false,
      );

      expect(validation.isValid, isFalse);
      expect(validation.publicInputs, isNull);
      expect(validation.errorMessage, contains('oprf_pk_hash'));
    });
  });

  group('ZkPassportSessionResultResponse', () {
    test('parses upgraded bridge result fields', () {
      final result = ZkPassportSessionResultResponse.fromJson({
        'session_id': 'session-1',
        'status': 'result_ok',
        'proof': 'proof-payload',
        'result': {
          'nullifier_hex': _scopedNullifier,
          'nullifier_type': 4,
          'unique_identifier_type': 2,
          'oprf_pk_hash': _oprfPkHash,
        },
      });

      expect(result.nullifierHex, _scopedNullifier);
      expect(result.nullifierType, 4);
      expect(result.uniqueIdentifierType, 2);
      expect(result.oprfPkHash, _oprfPkHash);
    });
  });
}

List<String> _publicInputs(int count) {
  return List<String>.generate(count, (index) => _field(index + 1));
}

String _field(int value) {
  return '0x${value.toRadixString(16).padLeft(64, '0')}';
}

final _scopedNullifier = _field(0xabc);
final _oprfPkHash = _field(0xdef);
final _recursiveVerifierInput = _field(0x999);
