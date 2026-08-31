import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZkPassportOuterProofPublicInputs', () {
    test('extracts outer_count_4 scoped nullifier with semantic count 9', () {
      final inputs = _publicInputs(9)
        ..[6] = _field(4)
        ..[7] = _scopedNullifier
        ..[8] = _oprfPkHash;

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
      final inputs = _publicInputs(10)
        ..[7] = _field(5)
        ..[8] = _scopedNullifier
        ..[9] = _oprfPkHash;

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
      final inputs = _publicInputs(9)
        ..[6] = _field(4)
        ..[7] = _scopedNullifier
        ..[8] = _oprfPkHash;

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

    test(
        'rejects verifier-visible outer_count_4 inputs at the Flutter boundary',
        () {
      final validation = ZkPassportOuterProofValidation.validate(
        publicInputsHex: _publicInputs(
          ZkPassportOuterProofVariant
              .outerCount4.verifierVisiblePublicInputCount,
        ),
        facematchStrict: false,
      );

      expect(validation.isValid, isFalse);
      expect(validation.errorMessage, contains('expected 9'));
    });
  });

  group('ZkPassportSessionResultResponse', () {
    test('parses upgraded bridge result fields', () {
      final result = ZkPassportSessionResultResponse.fromJson({
        'session_id': 'session-1',
        'status': 'result_ok',
        'proof': 'proof-payload',
        'result': {
          'proof_name': ZkPassportOuterProofVariant.outerCount5.proofName,
          'proof_version': ZkPassportOuterProofVariant.outerCount5.proofVersion,
          'proof_vkey_hash':
              ZkPassportOuterProofVariant.outerCount5.proofVkeyHash,
          'nullifier_hex': _scopedNullifier,
          'nullifier_type': 4,
          'unique_identifier_type': 2,
          'oprf_pk_hash': _oprfPkHash,
        },
      });

      expect(result.nullifierHex, _scopedNullifier);
      expect(result.proofName, 'outer_count_5');
      expect(result.proofVersion, '0.20.0');
      expect(
        result.proofVkeyHash,
        ZkPassportOuterProofVariant.outerCount5.proofVkeyHash,
      );
      expect(result.validateOuterProofVariant(facematchStrict: true), isNull);
      expect(result.nullifierType, 4);
      expect(result.uniqueIdentifierType, 2);
      expect(result.oprfPkHash, _oprfPkHash);
    });

    test('rejects a strict proof for a non-strict request', () {
      final result = ZkPassportSessionResultResponse.fromJson({
        'session_id': 'session-1',
        'status': 'result_ok',
        'proof': 'proof-payload',
        'result': {
          'proof_name': ZkPassportOuterProofVariant.outerCount5.proofName,
          'proof_version': ZkPassportOuterProofVariant.outerCount5.proofVersion,
          'proof_vkey_hash':
              ZkPassportOuterProofVariant.outerCount5.proofVkeyHash,
        },
      });

      expect(
        result.validateOuterProofVariant(facematchStrict: false),
        contains('requires outer_count_4@0.20.0'),
      );
    });

    test('rejects missing proof variant metadata', () {
      final result = ZkPassportSessionResultResponse.fromJson({
        'session_id': 'session-1',
        'status': 'result_ok',
        'proof': 'proof-payload',
      });

      expect(
        result.validateOuterProofVariant(facematchStrict: false),
        contains('without complete variant metadata'),
      );
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
