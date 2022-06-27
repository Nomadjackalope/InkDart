part of inky;

class Tag extends InkObject {
  final String _text;
  String get text => _text;

  Tag(this._text);

  @override
  String toString() => "# $text";
}
