part of inky;

class BadCastException implements Exception {
  final Object msg;

  /// <summary>
  /// Constructs a default instance of a BadCastException
  /// </summary>
  BadCastException(this.msg);


  @override
  String toString() => 'BadCastException: $msg';
}