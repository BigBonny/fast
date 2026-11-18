/// Runs OS permission prompts one at a time, app-wide.
///
/// Android shows a single permission dialog at a time: a request made while
/// another dialog is open (notifications at sign-in, say) is dropped and
/// resolves as "denied" without the user ever seeing it. Every runtime
/// permission request (notifications, location, ...) goes through [run] so
/// the next prompt only starts once the previous one has been answered.
class PermissionQueue {
  PermissionQueue._();

  static Future<void> _tail = Future<void>.value();

  static Future<T> run<T>(Future<T> Function() request) {
    final result = _tail.then((_) => request());
    // Keep the chain alive whatever this request does.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
