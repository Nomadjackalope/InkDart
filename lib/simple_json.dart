part of inky;

/// <summary>
/// Simple custom JSON serialisation implementation that takes JSON-able System.Collections that
/// are produced by the ink engine and converts to and from JSON text.
/// </summary>
class SimpleJson {
  SimpleJson._();

  static Map<String, Object> textToDictionary(String text) {
    return Reader(text).toDictionary();
  }

  static List<Object> textToArray(String text) {
    return Reader(text).toArray();
  }
}

class Reader {
  Reader(this._text) {
    _offset = 0;

    skipWhitespace();

    _rootObject = readObject();
  }

  Map<String, Object> toDictionary() {
    return _rootObject as Map<String, Object>;
  }

  List<Object> toArray() {
    return _rootObject as List<Object>;
  }

  bool isNumberChar(int c) {
    return c >= '0'.codeUnitAt(0) && c <= '9'.codeUnitAt(0) ||
        c == '.'.codeUnitAt(0) ||
        c == '-'.codeUnitAt(0) ||
        c == '+'.codeUnitAt(0) ||
        c == 'E'.codeUnitAt(0) ||
        c == 'e'.codeUnitAt(0);
  }

  bool isFirstNumberChar(int c) {
    return c >= '0'.codeUnitAt(0) && c <= '9'.codeUnitAt(0) ||
        c == '-'.codeUnitAt(0) ||
        c == '+'.codeUnitAt(0);
  }

  Object? readObject() {
    var currentChar = _text[_offset];

    if (currentChar == '{') {
      return readDictionary();
    } else if (currentChar == '[') {
      return readArray();
    } else if (currentChar == '"') {
      return readString();
    } else if (isFirstNumberChar(currentChar.codeUnitAt(0))) {
      return readNumber();
    } else if (tryRead("true")) {
      return true;
    } else if (tryRead("false")) {
      return false;
    } else if (tryRead("null")) {
      return null;
    }

    throw FormatException(
        "Unhandled object type in JSON: ${_text.substring(_offset, _offset + 30)}");
  }

  Map<String, Object> readDictionary() {
    var dict = <String, Object>{};

    expect("{");

    skipWhitespace();

    // Empty dictionary?
    if (tryRead("}")) {
      return dict;
    }

    do {
      skipWhitespace();

      // Key
      var key = readString();
      expectMessage(key != null, "dictionary key");

      skipWhitespace();

      // :
      expect(":");

      skipWhitespace();

      // Value
      var val = readObject();
      expectMessage(val != null, "dictionary value");

      // Add to dictionary
      dict[key] = val!;

      skipWhitespace();
    } while (tryRead(","));

    expect("}");

    return dict;
  }

  List<Object?> readArray() {
    var list = <Object?>[];

    expect("[");

    skipWhitespace();

    // Empty list?
    if (tryRead("]")) {
      return list;
    }

    do {
      skipWhitespace();

      // Value
      var val = readObject();

      // Add to array
      list.add(val);

      skipWhitespace();
    } while (tryRead(","));

    expect("]");

    return list;
  }

  String readString() {
    expect("\"");

    var sb = StringBuffer();

    for (; _offset < _text.length; _offset++) {
      var c = _text[_offset];

      if (c == '\\') {
        // Escaped character
        _offset++;
        if (_offset >= _text.length) {
          throw Exception("Unexpected EOF while reading String");
        }
        c = _text[_offset];
        switch (c) {
          case '"':
          case '\\':
          case '/': // Yes, JSON allows this to be escaped
            sb.write(c);
            break;
          case 'n':
            sb.write('\n');
            break;
          case 't':
            sb.write('\t');
            break;
          case 'r':
          case 'b':
          case 'f':
            // Ignore other control characters
            break;
          case 'u':
            // 4-digit Unicode
            if (_offset + 4 >= _text.length) {
              throw FormatException("Unexpected EOF while reading String");
            }
            var digits = _text.substring(_offset + 1, _offset + 1 + 4);
            int? uchar = int.tryParse(digits);
            if (uchar != null) {
              sb.write(uchar);
              _offset += 4;
            } else {
              throw FormatException(
                  "Invalid Unicode escape character at offset ${_offset - 1}");
            }
            break;
          default:
            // The escaped character is invalid per json spec
            throw FormatException(
                "Invalid Unicode escape character at offset ${_offset - 1}");
        }
      } else if (c == '"') {
        break;
      } else {
        sb.write(c);
      }
    }

    expect("\"");
    return sb.toString();
  }

  num readNumber() {
    var startOffset = _offset;

    bool isDouble = false;
    for (; _offset < _text.length; _offset++) {
      int c = _text[_offset].codeUnitAt(0);
      if (c == '.'.codeUnitAt(0) ||
          c == 'e'.codeUnitAt(0) ||
          c == 'E'.codeUnitAt(0)) isDouble = true;
      if (isNumberChar(c)) {
        continue;
      } else {
        break;
      }
    }

    String numStr = _text.substring(startOffset, _offset);

    if (isDouble) {
      var d = double.tryParse(numStr);
      if (d != null) return d;
    } else {
      var i = int.tryParse(numStr);
      if (i != null) return i;
    }

    throw FormatException("Failed to parse number value: $numStr");
  }

  bool tryRead(String textToRead) {
    if (_offset + textToRead.length > _text.length) {
      return false;
    }

    for (int i = 0; i < textToRead.length; i++) {
      if (textToRead[i] != _text[_offset + i]) {
        return false;
      }
    }

    _offset += textToRead.length;

    return true;
  }

  void expect(String expectedStr) {
    if (!tryRead(expectedStr)) {
      expectMessage(false, expectedStr);
    }
  }

  void expectMessage(bool condition, [String? message]) {
    if (!condition) {
      if (message == null) {
        message = "Unexpected token";
      } else {
        message = "Expected $message";
      }
      message += " at offset $_offset";

      throw FormatException(message);
    }
  }

  void skipWhitespace() {
    while (_offset < _text.length) {
      var c = _text[_offset];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        _offset++;
      } else {
        break;
      }
    }
  }

  String _text;
  int _offset = 0;

  Object? _rootObject;
}

class Writer {
  Writer() : _writer = StringBuffer();

  // The original code has no references to this
  // Writer.fromStream(Stream stream)
  // {
  //     Stream<List<int>> _writer = File('someFile.txt').openRead();
  //     List<String> lines = await _writer
  //       .transform(utf8.decoder)
  //       .toList();

  // }

  // Stream<List<int>> getWriter() async {
  //   File('someFile.txt').op
  // }

  void writeObject(Function(Writer) inner) {
    writeObjectStart();
    inner(this);
    writeObjectEnd();
  }

  void writeObjectStart() {
    startNewObject(true);
    _stateStack.push(StateElement(type: State.object));
    _writer.write("{");
  }

  void writeObjectEnd() {
    Assert(state == State.object);
    _writer.write("}");
    _stateStack.pop();
  }

  void writePropertyNameAction(String name, Function(Writer) inner) {
    writeProperty<String>(name, inner);
  }

  void writePropertyIdAction(int id, Function(Writer) inner) {
    writeProperty<int>(id, inner);
  }

  void writePropertyNameString(String name, String? content) {
    writePropertyStartName(name);
    writeStringEscape(content);
    writePropertyEnd();
  }

  void writePropertyNameInt(String name, int content) {
    writePropertyStartName(name);
    writeInt(content);
    writePropertyEnd();
  }

  void writePropertyNameBool(String name, bool content) {
    writePropertyStartName(name);
    writeBool(content);
    writePropertyEnd();
  }

  void writePropertyStartName(String name) {
    writePropertyStart<String>(name);
  }

  void writePropertyStartInt(int id) {
    writePropertyStart<int>(id);
  }

  void writePropertyEnd() {
    Assert(state == State.property);
    Assert(childCount == 1);
    _stateStack.pop();
  }

  void writePropertyNameStart() {
    Assert(state == State.object);

    if (childCount > 0) {
      _writer.write(",");
    }

    _writer.write("\"");

    incrementChildCount();

    _stateStack.push(StateElement(type: State.property));
    _stateStack.push(StateElement(type: State.propertyName));
  }

  void writePropertyNameEnd() {
    Assert(state == State.propertyName);

    _writer.write("\":");

    // pop PropertyName, leaving Property state
    _stateStack.pop();
  }

  void writePropertyNameInner(String str) {
    Assert(state == State.propertyName);
    _writer.write(str);
  }

  void writePropertyStart<T>(T name) {
    Assert(state == State.object);

    if (childCount > 0) {
      _writer.write(",");
    }

    _writer.write("\"");
    _writer.write(name);
    _writer.write("\":");

    incrementChildCount();

    _stateStack.push(StateElement(type: State.property));
  }

  // allow name to be String or int
  void writeProperty<T>(T name, Function(Writer) inner) {
    writePropertyStart(name);

    inner(this);

    writePropertyEnd();
  }

  void writeArrayStart() {
    startNewObject(true);
    _stateStack.push(StateElement(type: State.array));
    _writer.write("[");
  }

  void writeArrayEnd() {
    Assert(state == State.array);
    _writer.write("]");
    _stateStack.pop();
  }

  void writeInt(int i) {
    startNewObject(false);
    _writer.write(i);
  }

  void writeFloat(double f) {
    startNewObject(false);

    // TODO: Find an heap-allocation-free way to do this please!
    // _writer.write(formatStr, obj (the float)) requires boxing
    // Following implementation seems to work ok but requires creating temporary garbage String.
    String floatStr = f.toString();
    if (floatStr == "Infinity") {
      _writer.write("3.4E+38"); // JSON doesn't support, do our best alternative
    } else if (floatStr == "-Infinity") {
      _writer
          .write("-3.4E+38"); // JSON doesn't support, do our best alternative
    } else if (floatStr == "NaN") {
      _writer.write("0.0"); // JSON doesn't support, not much we can do
    } else {
      _writer.write(floatStr);
      if (!floatStr.contains(".") && !floatStr.contains("E")) {
        _writer.write(".0");
      } // ensure it gets read back in as a floating point value
    }
  }

  void writeStringEscape(String? str, [bool escape = true]) {
    startNewObject(false);

    _writer.write("\"");
    if (escape) {
      writeEscapedString(str);
    } else {
      _writer.write(str);
    }
    _writer.write("\"");
  }

  void writeBool(bool b) {
    startNewObject(false);
    _writer.write(b ? "true" : "false");
  }

  void writeNull() {
    startNewObject(false);
    _writer.write("null");
  }

  void writeStringStart() {
    startNewObject(false);
    _stateStack.push(StateElement(type: State.string));
    _writer.write("\"");
  }

  void writeStringEnd() {
    Assert(state == State.string);
    _writer.write("\"");
    _stateStack.pop();
  }

  void writeStringInner(String str, [bool escape = true]) {
    Assert(state == State.string);
    if (escape) {
      writeEscapedString(str);
    } else {
      _writer.write(str);
    }
  }

  // Case expressions must be constant
  // '\n'
  static const int newLineChar = 10;
  // '\t'
  static const int tabChar = 9;
  // '\\'
  static const int backSlash = 92;
  // '"'
  static const int doubleQuote = 34;

  void writeEscapedString(String? str) {
    if (str == null) return; // TODO ben gordon what should be done with a null string
    for (var c in str.runes) {
      if (c < ' '.codeUnitAt(0)) {
        // Don't write any control characters except \n and \t
        switch (c) {
          case newLineChar:
            _writer.write("\\n");
            break;
          case tabChar:
            _writer.write("\\t");
            break;
        }
      } else {
        switch (c) {
          case backSlash:
          case doubleQuote:
            _writer.write("\\");
            _writer.write(c);
            break;
          default:
            _writer.write(c);
            break;
        }
      }
    }
  }

  void startNewObject(bool container) {
    if (container) {
      Assert(state == State.none ||
          state == State.property ||
          state == State.array);
    } else {
      Assert(state == State.property || state == State.array);
    }

    if (state == State.array && childCount > 0) {
      _writer.write(",");
    }

    if (state == State.property) {
      Assert(childCount == 0);
    }

    if (state == State.array || state == State.property) {
      incrementChildCount();
    }
  }

  State get state {
    if (_stateStack.size() > 0) {
      return _stateStack.top().type;
    } else {
      return State.none;
    }
  }

  int get childCount {
    if (_stateStack.size() > 0) {
      return _stateStack.top().childCount;
    } else {
      return 0;
    }
  }

  void incrementChildCount() {
    Assert(_stateStack.size() > 0);
    var currEl = _stateStack.pop();
    currEl.childCount++;
    _stateStack.push(currEl);
  }

  // Shouldn't hit this assert outside of initial JSON development,
  // so it's save to make it debug-only.
  // [System.Diagnostics.Conditional("DEBUG")]
  void Assert(bool condition) {
    if (!condition) {
      throw FormatException("Assert failed while writing JSON");
    }
  }

  String toString() {
    return _writer.toString();
  }

  final Stack<StateElement> _stateStack = Stack<StateElement>();
  // TextWriter _writer;
  StringBuffer _writer;
}

/// In original code this was a struct so we make a default
class StateElement {
  State type;
  int childCount;

  StateElement({this.type = State.none, this.childCount = 0});
}

enum State { none, object, array, property, propertyName, string }
