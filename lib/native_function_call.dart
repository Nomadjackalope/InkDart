part of inky;

class NativeFunctionCall extends InkObject {
  static const String Add = "+";
  static const String Subtract = "-";
  static const String Divide = "/";
  static const String Multiply = "*";
  static const String Mod = "%";
  static const String Negate = "_"; // distinguish from "-" for subtraction
  static const String Equal = "==";
  static const String Greater = ">";
  static const String Less = "<";
  static const String GreaterThanOrEquals = ">=";
  static const String LessThanOrEquals = "<=";
  static const String NotEquals = "!=";
  static const String Not = "!";
  static const String And = "&&";
  static const String Or = "||";
  static const String Min = "MIN";
  static const String Max = "MAX";
  static const String Pow = "POW";
  static const String Floor = "FLOOR";
  static const String Ceiling = "CEILING";
  static const String Int = "INT";
  static const String Float = "FLOAT";
  static const String Has = "?";
  static const String Hasnt = "!?";
  static const String Intersect = "^";
  static const String ListMin = "LIST_MIN";
  static const String ListMax = "LIST_MAX";
  static const String All = "LIST_ALL";
  static const String Count = "LIST_COUNT";
  static const String ValueOfList = "LIST_VALUE";
  static const String Invert = "LIST_INVERT";

  static NativeFunctionCall callWithName(String functionName) {
    return NativeFunctionCall.from(functionName);
  }

  static bool callExistsWithName(String functionName) {
    _generateNativeFunctionsIfNecessary();
    return _nativeFunctions!.containsKey(functionName);
  }

  String? __name;
  String? get name => __name;

  set _name(String? value) {
    __name = value;
    if (!_isPrototype) {
      _prototype = _nativeFunctions![__name]!;
    }
  }

  int __numberOfParameters = 0;
  int get numberOfParameters {
    if (_prototype != null) {
      return _prototype!.numberOfParameters;
    } else {
      return __numberOfParameters;
    }
  }
  set _numberOfParameters(int value) {
    _numberOfParameters = value;
  }


  InkObject? call(List<InkObject> parameters) {
    if (_prototype != null) {
      return _prototype!._call(parameters);
    }

    if (numberOfParameters != parameters.length) {
      throw FormatException("Unexpected number of parameters");
    }

    bool hasList = false;
    for (var p in parameters) {
      if (p is Void) {
        throw StoryException(
            "Attempting to perform operation on a void value. Did you forget to 'return' a value from a function you called here?");
      }
      if (p is ListValue) {
        hasList = true;
      }
    }

    // Binary operations on lists are treated outside of the standard coerscion rules
    if (parameters.length == 2 && hasList) {
      return _callBinaryListOperation(parameters);
    }

    var coercedParams = _coerceValuesToSingleType(parameters);
    int coercedType = coercedParams[0].valueType;

    if (coercedType == ValueType.iInt) {
      return _call<int>(coercedParams);
    } else if (coercedType == ValueType.iFloat) {
      return _call<double>(coercedParams);
    } else if (coercedType == ValueType.iString) {
      return _call<String>(coercedParams);
    } else if (coercedType == ValueType.iDivertTarget) {
      return _call<Path>(coercedParams);
    } else if (coercedType == ValueType.iList) {
      return _call<InkList>(coercedParams);
    }

    return null;
  }

  Value? _call<T>(List<InkObject?> parametersOfSingleType) {
    Value param1 = parametersOfSingleType[0] as Value;
    int valType = param1.valueType;

    var val1 = param1 as GenericValue<T>;

    int paramCount = parametersOfSingleType.length;

    if (paramCount == 2 || paramCount == 1) {
      Object? opForTypeObj = _operationFuncs![valType];
      if (!_operationFuncs!.containsKey(valType)) {
        throw StoryException(
            "Cannot perform operation '$name' on $valType");
      }

      // Binary
      if (paramCount == 2) {
        Value param2 = parametersOfSingleType[1] as Value;

        var val2 = param2 as GenericValue<T>;

        var opForType = opForTypeObj as BinaryOp<T>;

        // Return value unknown until it's evaluated
        Object resultVal = opForType(val1.value, val2.value);

        return Value.create(resultVal);
      }

      // Unary
      else {
        var opForType = opForTypeObj as UnaryOp<T>;

        var resultVal = opForType(val1.value);

        return Value.create(resultVal);
      }
    } else {
      throw FormatException(
          "Unexpected number of parameters to NativeFunctionCall: ${parametersOfSingleType.length}");
    }
  }

  Value? _callBinaryListOperation(List<InkObject> parameters) {
    // List-Int addition/subtraction returns a List (e.g. "alpha" + 1 = "beta")
    if ((name == "+" || name == "-") &&
        parameters[0] is ListValue &&
        parameters[1] is IntValue) {
      return _callListIncrementOperation(parameters);
    }

    var v1 = parameters[0] as Value;
    var v2 = parameters[1] as Value;

    // And/or with any other type requires coerscion to bool (int)
    if ((name == "&&" || name == "||") &&
        (v1.valueType != ValueType.iList || v2.valueType != ValueType.iList)) {
      var op = _operationFuncs![ValueType.iInt] as BinaryOp<int>;
      var result = op(v1.isTruthy ? 1 : 0, v2.isTruthy ? 1 : 0) as bool;
      return BoolValue(result);
    }

    // Normal (list • list) operation
    if (v1.valueType == ValueType.iList && v2.valueType == ValueType.iList) {
      return _call<InkList>(<Value>[v1, v2]);
    }

    throw StoryException(
        "Can not call use '$name' operation on ${v1.valueType} and ${v2.valueType}");
  }

  Value _callListIncrementOperation(List<InkObject> listIntParams) {
    var listVal = listIntParams[0] as ListValue;
    var intVal = listIntParams[1] as IntValue;

    var resultRawList = InkList();

    for (var listItemWithValue in listVal.value.entries) {
      //TODO ben gordon test if .entries is the right place to get those
      var listItem = listItemWithValue.key;
      var listItemValue = listItemWithValue.value;

      // Find + or - operation
      var intOp = _operationFuncs![ValueType.iInt] as BinaryOp<int>;

      // Return value unknown until it's evaluated
      int targetInt = intOp(listItemValue, intVal.value) as int;

      // Find this item's origin (linear search should be ok, should be short haha)
      ListDefinition? itemOrigin = null;
      for (var origin in listVal.value.origins) {
        if (origin!.name == listItem.originName) {
          itemOrigin = origin;
          break;
        }
      }
      if (itemOrigin != null) {
        ValueHolder<InkListItem> incrementedItem =
            itemOrigin.tryGetItemWithValue(targetInt, InkListItem());
        if (incrementedItem.exists) {
          resultRawList.add(incrementedItem.value, targetInt);
        }
      }
    }

    return ListValue.fromList(resultRawList);
  }

  List<Value> _coerceValuesToSingleType(List<InkObject> parametersIn) {
    int valType = ValueType.iInt;

    ListValue? specialCaseList = null;

    // Find out what the output type is
    // "higher level" types infect both so that binary operations
    // use the same type on both sides. e.g. binary operation of
    // int and float causes the int to be casted to a float.
    for (var obj in parametersIn) {
      var val = obj as Value;
      if (val.valueType > valType) {
        valType = val.valueType;
      }

      if (val.valueType == ValueType.iList) {
        specialCaseList = val as ListValue;
      }
    }

    // Coerce to this chosen type
    var parametersOut = <Value>[];

    // Special case: Coercing to Ints to Lists
    // We have to do it early when we have both parameters
    // to hand - so that we can make use of the List's origin
    if (valType == ValueType.iList) {
      for (InkObject val in parametersIn) {
        val = val as Value;
        if (val.valueType == ValueType.iList) {
          parametersOut.add(val);
        } else if (val.valueType == ValueType.iInt) {
          int intVal = val.valueObject as int;
          var list = specialCaseList!.value.originOfMaxItem;

          ValueHolder item = list!.tryGetItemWithValue(intVal, InkListItem());
          if (item.exists) {
            var castedValue = ListValue.fromItem(item.value!, intVal);
            parametersOut.add(castedValue);
          } else {
            throw StoryException(
                "Could not find List item with the value $intVal in ${list.name}");
          }
        } else {
          throw StoryException(
              "Cannot mix Lists and ${val.valueType} values in this operation");
        }
      }
    }

    // Normal Coercing (with standard casting)
    else {
      for (InkObject val in parametersIn) {
        val = val as Value;
        var castedValue = val.cast(valType);
        parametersOut.add(castedValue);
      }
    }

    return parametersOut;
  }

  NativeFunctionCall.from(String name) {
    _generateNativeFunctionsIfNecessary();

    this.__name = name;
  }

  // Require default constructor for serialisation
  NativeFunctionCall() {
    _generateNativeFunctionsIfNecessary();
  }

  // Only called internally to generate prototypes
  NativeFunctionCall._(this.__name, this.__numberOfParameters) {
    _isPrototype = true;
  }

  // For defining operations that do nothing to the specific type
  // (but are still supported), such as floor/ceil on int and float
  // cast on float.
  static Object _identity<T>(T t) {
    return t as Object;
  }

  static void _generateNativeFunctionsIfNecessary() {
    if (_nativeFunctions == null) {
      _nativeFunctions = <String, NativeFunctionCall>{};

      // Why no bool operations?
      // Before evaluation, all bools are coerced to ints in
      // CoerceValuesToSingleType (see default value for valType at top).
      // So, no operations are ever directly done in bools themselves.
      // This also means that 1 == true works, since true is always converted
      // to 1 first.
      // However, many operations return a "native" bool (equals, etc).

      // Int operations
      _addIntBinaryOp(Add, (x, y) => x + y);
      _addIntBinaryOp(Subtract, (x, y) => x - y);
      _addIntBinaryOp(Multiply, (x, y) => x * y);
      _addIntBinaryOp(Divide, (x, y) => x / y);
      _addIntBinaryOp(Mod, (x, y) => x % y);
      _addIntUnaryOp(Negate, (x) => -x);

      _addIntBinaryOp(Equal, (x, y) => x == y);
      _addIntBinaryOp(Greater, (x, y) => x > y);
      _addIntBinaryOp(Less, (x, y) => x < y);
      _addIntBinaryOp(GreaterThanOrEquals, (x, y) => x >= y);
      _addIntBinaryOp(LessThanOrEquals, (x, y) => x <= y);
      _addIntBinaryOp(NotEquals, (x, y) => x != y);
      _addIntUnaryOp(Not, (x) => x == 0);

      _addIntBinaryOp(And, (x, y) => x != 0 && y != 0);
      _addIntBinaryOp(Or, (x, y) => x != 0 || y != 0);

      _addIntBinaryOp(Max, (x, y) => max(x, y));
      _addIntBinaryOp(Min, (x, y) => min(x, y));

      // Have to cast to float since you could do POW(2, -1)
      _addIntBinaryOp(Pow, (x, y) => pow(x, y));
      _addIntUnaryOp(Floor, _identity);
      _addIntUnaryOp(Ceiling, _identity);
      _addIntUnaryOp(Int, _identity);
      _addIntUnaryOp(Float, (x) => x);

      // Float operations
      _addFloatBinaryOp(Add, (x, y) => x + y);
      _addFloatBinaryOp(Subtract, (x, y) => x - y);
      _addFloatBinaryOp(Multiply, (x, y) => x * y);
      _addFloatBinaryOp(Divide, (x, y) => x / y);
      _addFloatBinaryOp(Mod,
          (x, y) => x % y); // TODO: Is this the operation we want for floats?
      _addFloatUnaryOp(Negate, (x) => -x);

      _addFloatBinaryOp(Equal, (x, y) => x == y);
      _addFloatBinaryOp(Greater, (x, y) => x > y);
      _addFloatBinaryOp(Less, (x, y) => x < y);
      _addFloatBinaryOp(GreaterThanOrEquals, (x, y) => x >= y);
      _addFloatBinaryOp(LessThanOrEquals, (x, y) => x <= y);
      _addFloatBinaryOp(NotEquals, (x, y) => x != y);
      _addFloatUnaryOp(Not, (x) => (x == 0));

      _addFloatBinaryOp(And, (x, y) => x != 0 && y != 0);
      _addFloatBinaryOp(Or, (x, y) => x != 0 || y != 0);

      _addFloatBinaryOp(Max, (x, y) => max(x, y));
      _addFloatBinaryOp(Min, (x, y) => min(x, y));

      _addFloatBinaryOp(Pow, (x, y) => pow(x, y));
      _addFloatUnaryOp(Floor, (x) => (x).floor());
      _addFloatUnaryOp(Ceiling, (x) => (x).ceil());
      _addFloatUnaryOp(Int, (x) => x as int);
      _addFloatUnaryOp(Float, _identity);

      // String operations
      _addStringBinaryOp(Add, (x, y) => x + y); // concat
      _addStringBinaryOp(Equal, (x, y) => x == y);
      _addStringBinaryOp(NotEquals, (x, y) => x != y);
      _addStringBinaryOp(Has, (x, y) => x.contains(y));
      _addStringBinaryOp(Hasnt, (x, y) => !x.contains(y));

      // List operations
      _addListBinaryOp(Add, (x, y) => x.union(y));
      _addListBinaryOp(Subtract, (x, y) => x.without(y));
      _addListBinaryOp(Has, (x, y) => x.contains(y));
      _addListBinaryOp(Hasnt, (x, y) => !x.contains(y));
      _addListBinaryOp(Intersect, (x, y) => x.intersect(y));

      _addListBinaryOp(Equal, (x, y) => x == y);
      _addListBinaryOp(Greater, (x, y) => x.greaterThan(y));
      _addListBinaryOp(Less, (x, y) => x.lessThan(y));
      _addListBinaryOp(GreaterThanOrEquals, (x, y) => x.greaterThanOrEquals(y));
      _addListBinaryOp(LessThanOrEquals, (x, y) => x.lessThanOrEquals(y));
      _addListBinaryOp(NotEquals, (x, y) => x != y);

      _addListBinaryOp(And, (x, y) => x.isNotEmpty && y.isNotEmpty);
      _addListBinaryOp(Or, (x, y) => x.isNotEmpty || y.isNotEmpty);

      _addListUnaryOp(Not, (x) => x.isEmpty ? 1 : 0);

      // Placeholders to ensure that these special case functions can exist,
      // since these function is never actually run, and is special cased in Call
      _addListUnaryOp(Invert, (x) => x.inverse);
      _addListUnaryOp(All, (x) => x.all);
      _addListUnaryOp(ListMin, (x) => x.minAsList());
      _addListUnaryOp(ListMax, (x) => x.maxAsList());
      _addListUnaryOp(Count, (x) => x.length);
      _addListUnaryOp(ValueOfList, (x) => x.maxItem.value);

      // Special case: The only operations you can do on divert target values
      BinaryOp<Path> divertTargetsEqual = (Path d1, Path d2) {
        return d1 == d2;
      };
      BinaryOp<Path> divertTargetsNotEqual = (Path d1, Path d2) {
        return d1 != d2;
      };
      _addOpToNativeFunc(Equal, 2, ValueType.iDivertTarget, divertTargetsEqual);
      _addOpToNativeFunc(
          NotEquals, 2, ValueType.iDivertTarget, divertTargetsNotEqual);
    }
  }

  void _addOpFuncForType(int valType, Object op) {
    _operationFuncs ??= <int, Object>{};

    _operationFuncs![valType] = op;
  }

  static void _addOpToNativeFunc(
      String name, int args, int valType, Object op) {
    NativeFunctionCall? nativeFunc = _nativeFunctions![name];
    if (nativeFunc == null) {
      nativeFunc = NativeFunctionCall._(name, args);
      _nativeFunctions![name] = nativeFunc;
    }

    nativeFunc._addOpFuncForType(valType, op);
  }

  static void _addIntBinaryOp(String name, BinaryOp<int> op) {
    _addOpToNativeFunc(name, 2, ValueType.iInt, op);
  }

  static void _addIntUnaryOp(String name, UnaryOp<int> op) {
    _addOpToNativeFunc(name, 1, ValueType.iInt, op);
  }

  static void _addFloatBinaryOp(String name, BinaryOp<double> op) {
    _addOpToNativeFunc(name, 2, ValueType.iFloat, op);
  }

  static void _addStringBinaryOp(String name, BinaryOp<String> op) {
    _addOpToNativeFunc(name, 2, ValueType.iString, op);
  }

  static void _addListBinaryOp(String name, BinaryOp<InkList> op) {
    _addOpToNativeFunc(name, 2, ValueType.iList, op);
  }

  static void _addListUnaryOp(String name, UnaryOp<InkList> op) {
    _addOpToNativeFunc(name, 1, ValueType.iList, op);
  }

  static void _addFloatUnaryOp(String name, UnaryOp<double> op) {
    _addOpToNativeFunc(name, 1, ValueType.iFloat, op);
  }

  String toString() {
    return "Native '$name'";
  }

  NativeFunctionCall? _prototype;
  bool _isPrototype = false;

  // Operations for each data type, for a single operation (e.g. "+")
  Map<int, Object>? _operationFuncs;

  static Map<String, NativeFunctionCall>? _nativeFunctions;
}

typedef Object BinaryOp<T>(T left, T right);
typedef Object UnaryOp<T>(T val);
