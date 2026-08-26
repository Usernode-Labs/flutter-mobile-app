/// Temporary session-scoped capabilities retained until protocol 2 moves
/// bearer and account-secret handling entirely behind the platform vault.
///
/// TODO(protocol-2): Delete this library and its private transport when no raw
/// bearer or account secret crosses Dart and Rust consumes only a credential
/// reference, generation, and vault-write proof.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

part 'delegation_api_part.dart';
part 'legacy_zk_completion_api_part.dart';
part 'session_api_transport.dart';
part 'wallet_provisioning_api_part.dart';
