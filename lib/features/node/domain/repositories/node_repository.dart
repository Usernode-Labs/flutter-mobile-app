import '../entities/node_status.dart';
import 'package:crypto_mobile_app/core/result.dart';

abstract class NodeRepository {
  Future<void> init();
  Future<bool> startForActiveAccount();
  Future<Result<NodeStatus?>> getStatus();
}
