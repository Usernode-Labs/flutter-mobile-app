/// Serializes WebKit gesture changes and discards superseded page requests.
/// The caller revalidates the trusted document immediately before each write.
class NativeBackNavigation {
  NativeBackNavigation(this._apply);

  final Future<void> Function(bool enabled) _apply;
  Future<void> _pending = Future<void>.value();
  int _revision = 0;

  Future<bool> setEnabled(
    bool enabled, {
    Future<bool> Function()? canApply,
  }) {
    final revision = ++_revision;
    final operation = _pending.then((_) async {
      if (revision != _revision) return false;
      if (canApply != null && !await canApply()) return false;
      if (revision != _revision) return false;
      await _apply(enabled);
      return true;
    });
    // A failed platform call must not poison subsequent disable requests.
    _pending =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }
}
