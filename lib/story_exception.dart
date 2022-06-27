part of inky;

/// <summary>
/// Exception that represents an error when running a Story at runtime.
/// An exception being thrown of this type is typically when there's
/// a bug in your ink, rather than in the ink engine itself!
/// </summary>
class StoryException implements Exception {
  final String msg;
  bool useEndLineNumber = true;

  /// <summary>
  /// Constructs a default instance of a StoryException without a message.
  /// </summary>
  StoryException(this.msg);

  /// <summary>
  /// Constructs an instance of a StoryException with a message.
  /// </summary>
  /// <param name="message">The error message.</param>
  // StoryException.withMsg(this.msg);

  @override
  String toString() => 'StoryException: $msg';
}
