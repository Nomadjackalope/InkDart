part of inky;

// Order is significant for type coersion.
// If types aren't directly compatible for an operation,
// they're coerced to the same type, downward.
// Higher value types "infect" an operation.
// (This may not be the most sensible thing to do, but it's worked so far!)
class ValueType {
  // Bool is new addition, keep enum values the same, with Int==0, Float==1 etc,
  // but for coersion rules, we want to keep bool with a lower value than Int
  // so that it converts in the right direction
  static const int iBool = -1;
  // Used in coersion
  static const int iInt = 0;
  static const int iFloat = 1;
  static const int iList = 2;
  static const int iString = 3;
  // Not used for coersion described above
  static const int iDivertTarget = 4;
  static const int iVariablePointer = 5;
}

abstract class Value extends InkObject {
  int get valueType;
  bool get isTruthy;
  Value cast(int newType);
  Object? get valueObject;
  static Value? create(Object? val) {
    // Implicitly lose precision from any doubles we get passed in
    if (val is double) {
      double doub = val;
      val = doub;
    }

    if (val is bool) {
      return BoolValue(val);
    } else if (val is int) {
      return IntValue(val);
    } else if (val is double) {
      return FloatValue(val);
    } else if (val is String) {
      return StringValue(val);
    } else if (val is Path) {
      return DivertTargetValue(val);
    } else if (val is InkList) {
      return ListValue.fromList(val);
    }

    return null;
  }

  InkObject? copy() {
    return create(valueObject!);
  }

  StoryException badCastException(ValueType targetType) {
    return StoryException(
        "Can't cast $valueObject from $valueType to $targetType");
  }
}

abstract class GenericValue<T> extends Value {
  T value;

  @override
  Object? get valueObject => value;

  GenericValue(this.value);

  @override
  String toString() => value.toString();
}

class BoolValue extends GenericValue<bool> {
  @override
  int get valueType => ValueType.iBool;

  @override
  bool get isTruthy => value;

  BoolValue(bool val) : super(val);

  //BoolValue() : this(false) {}

  @override
  Value cast(int newType) {
    if (newType == valueType) {
      return this;
    }

    if (newType == ValueType.iInt) {
      return IntValue(value ? 1 : 0);
    }

    if (newType == ValueType.iFloat) {
      return FloatValue(value ? 1 : 0);
    }

    if (newType == ValueType.iString) {
      return StringValue(value ? "true" : "false");
    }

    throw BadCastException(newType);
  }

  @override
  String toString() => value ? "true" : "false";
}

class IntValue extends GenericValue<int> {
  @override
  int get valueType => ValueType.iInt;

  @override
  bool get isTruthy => value != 0;

  IntValue(int val) : super(val);

  // IntValue() : this(0) {}

  @override
  Value cast(int newType) {
    if (newType == valueType) {
      return this;
    }

    if (newType == ValueType.iBool) {
      return BoolValue(value == 0 ? false : true);
    }

    if (newType == ValueType.iFloat) {
      return FloatValue(value.toDouble());
    }

    if (newType == ValueType.iString) {
      return StringValue(value.toString());
    }

    throw BadCastException(newType);
  }
}

class FloatValue extends GenericValue<double> {
  @override
  int get valueType => ValueType.iFloat;

  @override
  bool get isTruthy => value != 0;

  FloatValue(double val) : super(val);

  //FloatValue() : this(0.0f) {}

  @override
  Value cast(int newType) {
    if (newType == valueType) {
      return this;
    }

    if (newType == ValueType.iBool) {
      return BoolValue(value == 0 ? false : true);
    }

    if (newType == ValueType.iInt) {
      return IntValue(value.toInt());
    }

    if (newType == ValueType.iString) {
      return StringValue(value
          .toString()); // System.Globalization.CultureInfo.InvariantCulture
    }

    throw BadCastException(newType);
  }
}

class StringValue extends GenericValue<String> {
  @override
  int get valueType => ValueType.iString;

  @override
  bool get isTruthy => value.isNotEmpty;

  bool _isNewline = false;
  bool get isNewline => _isNewline;

  bool _isInlineWhitespace = false;
  bool get isInlineWhitespace => _isInlineWhitespace;

  bool get isNonWhitespace {
    return !isNewline && !isInlineWhitespace;
  }

  StringValue(String val) : super(val) {
    // Classify whitespace status
    _isNewline = value == "\n";
    _isInlineWhitespace = true;
    for (var rune in value.runes) {
      var c = String.fromCharCode(rune);
      if (c != ' ' && c != '\t') {
        _isInlineWhitespace = false;
        break;
      }
    }
  }

  // StringValue() : this("") {}

  @override
  Value cast(int newType) {
    if (newType == valueType) {
      return this;
    }

    if (newType == ValueType.iInt) {
      return IntValue(int.tryParse(value)!);
    }

    if (newType == ValueType.iFloat) {
      return FloatValue(double.tryParse(value)!);
    }

    throw BadCastException(newType);
  }
}

class DivertTargetValue extends GenericValue<Path> {
  Path get targetPath => value;
  set targetPath(Path value) {
    this.value = value;
  }

  @override
  int get valueType => ValueType.iDivertTarget;

  @override
  bool get isTruthy => throw const FormatException(
      "Shouldn't be checking the truthiness of a divert target");

  DivertTargetValue(Path targetPath) : super(targetPath);

  //DivertTargetValue() : base(null) {}

  @override
  Value cast(int newType) {
    if (newType == valueType) return this;

    throw BadCastException(newType);
  }

  @override
  String toString() {
    return "DivertTargetValue($targetPath)";
  }
}

// TODO: Think: Erm, I get that this contains a string, but should
// we really derive from Value<string>? That seems a bit misleading to me.
class VariablePointerValue extends GenericValue<String> {
  String get variableName => value;
  set variableName(String value) {
    this.value = value;
  }

  @override
  int get valueType => ValueType.iVariablePointer;

  @override
  bool get isTruthy => throw const FormatException(
      "Shouldn't be checking the truthiness of a variable pointer");

  // Where the variable is located
  // -1 = default, unknown, yet to be determined
  // 0  = in global scope
  // 1+ = callstack element index + 1 (so that the first doesn't conflict with special global scope)
  int contextIndex = 0;

  VariablePointerValue(String variableName, [this.contextIndex = -1])
      : super(variableName);

  // VariablePointerValue() : this(null) {}

  @override
  Value cast(int newType) {
    if (newType == valueType) {
      return this;
    }

    throw BadCastException(newType);
  }

  @override
  String toString() {
    return "VariablePointerValue($variableName)";
  }

  @override
  InkObject? copy() {
    return VariablePointerValue(variableName, contextIndex);
  }
}

class ListValue extends GenericValue<InkList> {
  @override
  int get valueType => ValueType.iList;

  // Truthy if it is non-empty
  @override
  bool get isTruthy => value.isNotEmpty;

  @override
  Value cast(int newType) {
    if (newType == ValueType.iInt) {
      var max = value.maxItem;
      if (max.key.isNull) {
        return IntValue(0);
      } else {
        return IntValue(max.value);
      }
    } else if (newType == ValueType.iFloat) {
      var max = value.maxItem;
      if (max.key.isNull) {
        return FloatValue(0);
      } else {
        return FloatValue(max.value as double);
      }
    } else if (newType == ValueType.iString) {
      var max = value.maxItem;
      if (max.key.isNull) {
        return StringValue("");
      } else {
        return StringValue(max.key.toString());
      }
    }

    if (newType == valueType) {
      return this;
    }

    throw BadCastException(newType);
  }

  ListValue() : super(InkList());

  ListValue.fromList(InkList list) : super(InkList.from(list));

  ListValue.fromItem(InkListItem singleItem, int singleValue)
      : super(InkList.fromItem(KeyValuePair(singleItem, singleValue)));

  static void retainListOriginsForAssignment(
      InkObject? oldValue, InkObject? newValue) {
    var oldList = ConvertTo.listValue(oldValue);
    var newList = ConvertTo.listValue(newValue);

    // When assigning the emtpy list, try to retain any initial origin names
    if (oldList != null && newList != null && newList.value.isEmpty) {
      newList.value.setInitialOriginNames(oldList.value.originNames);
    }
  }
}
