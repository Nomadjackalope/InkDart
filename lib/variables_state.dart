part of inky;

/// <summary>
/// Encompasses all the global variables in an ink Story, and
/// allows binding of a VariableChanged event so that that game
/// code can be notified whenever the global variables change.
/// </summary>
class VariablesState with IterableMixin<String?> //: IEnumerable<String>
{
  final Event<VariableChangedEventArg> variableChangedEvent =
      Event<VariableChangedEventArg>();

  StatePatch? patch;

  bool _batchObservingVariableChanges = false;
  bool get batchObservingVariableChanges => _batchObservingVariableChanges;
  set batchObservingVariableChanges(bool value) {
    _batchObservingVariableChanges = value;
    if (value) {
      _changedVariablesForBatchObs = HashSet<String>();
    }

    // Finished observing variables in a batch - now send
    // notifications for changed variables all in one go.
    else {
      if (_changedVariablesForBatchObs != null) {
        for (var variableName in _changedVariablesForBatchObs!) {
          var currentValue = _globalVariables[variableName];
          variableChangedEvent
              .broadcast(VariableChangedEventArg(variableName, currentValue));
        }
      }

      _changedVariablesForBatchObs = null;
    }
  }

  // Allow StoryState to change the current callstack, e.g. for
  // temporary function evaluation.

  CallStack get callStack => _callStack;

  /// <summary>
  /// Get or set the value of a named global ink variable.
  /// The types available are the standard ink types. Certain
  /// types will be implicitly casted when setting.
  /// For example, doubles to floats, longs to ints, and bools
  /// to ints.
  /// </summary>
  Object? operator [](String variableName) {
    InkObject varContents = InkObject();
    var valueHolder = patch!.tryGetGlobal(variableName, varContents);
    if (valueHolder.exists) {
      return (valueHolder.value as Value).valueObject!;
    }

    // Search main dictionary first.
    // If it's not found, it might be because the story content has changed,
    // and the original default value hasn't be instantiated.
    // Should really warn somehow, but it's difficult to see how...!

    if (_globalVariables[variableName] != null ||
        _defaultGlobalVariables[variableName] != null) {
      varContents = _globalVariables[variableName] ??
          _defaultGlobalVariables[variableName]!;
      return (varContents as Value).valueObject!;
    } else {
      return null;
    }
  }

  void operator []=(String variableName, Object value) {
    if (!_defaultGlobalVariables.containsKey(variableName)) {
      throw StoryException(
          "Cannot assign to a variable ($variableName) that hasn't been declared in the story");
    }

    var val = Value.create(value);
    if (val == null) {
      if (value == null) {
        throw const FormatException("Cannot pass null to VariableState");
      } else {
        throw FormatException(
            "Invalid value passed to VariableState: ${value.toString()}");
      }
    }

    setGlobal(variableName, val);
  }

  // TODO: Ben Gordon I don't know if this is needed
  //  System.Collections.IEnumerable.GetEnumerator()
  // {
  // 	return getEnumerator();
  // }

  /// <summary>
  /// Enumerator to allow iteration over all global variables by name.
  /// </summary>
  Iterator<String?> getEnumerator() {
    return _globalVariables.keys.iterator;
  }

  VariablesState(CallStack callStack, ListDefinitionsOrigin listDefsOrigin) {
    _globalVariables = <String, InkObject>{};
    _callStack = callStack;
    _listDefsOrigin = listDefsOrigin;
  }

  void applyPatch() {
    for (var namedVar in patch!.globals.entries) {
      _globalVariables[namedVar.key] = namedVar.value;
    }

    if (_changedVariablesForBatchObs != null) {
      for (var name in patch!.changedVariables) {
        _changedVariablesForBatchObs!.add(name);
      }
    }

    patch = null;
  }

  void setJsonToken(Map<String, Object> jToken) {
    _globalVariables.clear();

    for (var varVal in _defaultGlobalVariables.entries) {
      if (jToken.containsKey(varVal.key)) {
        Object loadedToken = jToken[varVal.key]!;
        _globalVariables[varVal.key] = Json.jTokenToRuntimeObject(loadedToken)!;
      } else {
        _globalVariables[varVal.key] = varVal.value;
      }
    }
  }

  /// <summary>
  /// When saving out JSON state, we can skip saving global values that
  /// remain equal to the initial values that were declared in ink.
  /// This makes the save file (potentially) much smaller assuming that
  /// at least a portion of the globals haven't changed. However, it
  /// can also take marginally longer to save in the case that the
  /// majority HAVE changed, since it has to compare all globals.
  /// It may also be useful to turn this off for testing worst case
  /// save timing.
  /// </summary>
  static bool dontSaveDefaultValues = true;

  void writeJson(Writer writer) {
    writer.writeObjectStart();
    for (var keyVal in _globalVariables.entries) {
      var name = keyVal.key;
      var val = keyVal.value;

      if (dontSaveDefaultValues) {
        // Don't write out values that are the same as the default global values
        InkObject? defaultVal = _defaultGlobalVariables[name];
        if (defaultVal != null) {
          if (runtimeObjectsEqual(val, defaultVal)) {
            continue;
          }
        }
      }

      writer.writePropertyStart(name);
      Json.writeRuntimeObject(writer, val);
      writer.writePropertyEnd();
    }
    writer.writeObjectEnd();
  }

  bool runtimeObjectsEqual(InkObject? obj1, InkObject obj2) {
    if (obj1.runtimeType != obj2.runtimeType) return false;

    // Perform equality on int/float/bool manually to avoid boxing
    var boolVal = ConvertTo.boolValue(obj1);
    if (boolVal != null) {
      return boolVal.value == (obj2 as BoolValue).value;
    }

    var intVal = ConvertTo.intValue(obj1);
    if (intVal != null) {
      return intVal.value == (obj2 as IntValue).value;
    }

    var floatVal = ConvertTo.floatValue(obj1);
    if (floatVal != null) {
      return floatVal.value == (obj2 as FloatValue).value;
    }

    // Other Value type (using proper Equals: list, string, divert path)
    var val1 = ConvertTo.value(obj1);
    var val2 = obj2 as Value; // could give error
    if (val1 != null) {
      return val1.valueObject == val2.valueObject;
    }

    throw FormatException(
        "FastRoughDefinitelyEquals: Unsupported runtime object type: ${obj1.runtimeType}");
  }

  InkObject? getVariableWithName(String? name) {
    return _getVariableWithName(name, -1);
  }

  InkObject? tryGetDefaultVariableValue(String? name) {
    InkObject? val = _defaultGlobalVariables[name];
    return val;
  }

  bool globalVariableExistsWithName(String? name) {
    return _globalVariables.containsKey(name) ||
        _defaultGlobalVariables != null &&
            _defaultGlobalVariables.containsKey(name);
  }

  InkObject? _getVariableWithName(String? name, int contextIndex) {
    InkObject? varValue = _getRawVariableWithName(name, contextIndex);

    // Get value from pointer?
    var varPointer = ConvertTo.variablePointerValue(varValue);
    if (varPointer != null) {
      varValue = valueAtVariablePointer(varPointer);
    }

    return varValue;
  }

  InkObject? _getRawVariableWithName(String? name, int contextIndex) {
    InkObject? varValue;

    // 0 context = global
    if (contextIndex == 0 || contextIndex == -1) {
      if (patch != null) {
        var valueHolder = patch!.tryGetGlobal(name, varValue);
        if (valueHolder.exists) {
          return valueHolder.value;
        }
      }

      if (_globalVariables.containsKey(name)) {
        return _globalVariables[name]!;
      }

      // Getting variables can actually happen during globals set up since you can do
      //  VAR x = A_LIST_ITEM
      // So _defaultGlobalVariables may be null.
      // We need to do this check though in case a global is added, so we need to
      // revert to the default globals dictionary since an initial value hasn't yet been set.
      if (_defaultGlobalVariables != null &&
          _defaultGlobalVariables.containsKey(name)) {
        return _defaultGlobalVariables[name]!;
      }

      var listItemValue = _listDefsOrigin.findSingleItemListWithName(name);
      if (listItemValue != null) {
        return listItemValue;
      }
    }

    // Temporary
    varValue = _callStack.getTemporaryVariableWithName(name, contextIndex);

    return varValue;
  }

  InkObject? valueAtVariablePointer(VariablePointerValue pointer) {
    return _getVariableWithName(pointer.variableName, pointer.contextIndex);
  }

  void assign(VariableAssignment varAss, InkObject? value) {
    var name = varAss.variableName;
    int contextIndex = -1;

    // Are we assigning to a global variable?
    bool isSetGlobal = false;
    if (varAss.isNewDeclaration) {
      isSetGlobal = varAss.isGlobal;
    } else {
      isSetGlobal = globalVariableExistsWithName(name);
    }

    // Constructing variable pointer reference
    if (varAss.isNewDeclaration) {
      var varPointer = ConvertTo.variablePointerValue(value);
      if (varPointer != null) {
        var fullyResolvedVariablePointer = _resolveVariablePointer(varPointer);
        value = fullyResolvedVariablePointer;
      }
    }

    // Assign to existing variable pointer?
    // Then assign to the variable that the pointer is pointing to by name.
    else {
      // De-reference variable reference to point to
      VariablePointerValue? existingPointer;
      do {
        existingPointer = _getRawVariableWithName(name, contextIndex)
            as VariablePointerValue?;
        if (existingPointer != null) {
          name = existingPointer.variableName;
          contextIndex = existingPointer.contextIndex;
          isSetGlobal = (contextIndex == 0);
        }
      } while (existingPointer != null);
    }

    if (isSetGlobal) {
      setGlobal(name, value);
    } else {
      _callStack.setTemporaryVariable(
          name, value, varAss.isNewDeclaration, contextIndex);
    }
  }

  void snapshotDefaultGlobals() {
    _defaultGlobalVariables = {..._globalVariables};
  }

  void _retainListOriginsForAssignment(InkObject oldValue, InkObject newValue) {
    var oldList = ConvertTo.listValue(oldValue);
    var newList = ConvertTo.listValue(newValue);
    if (oldList != null && newList != null && newList.value.isEmpty) {
      newList.value.setInitialOriginNames(oldList.value.originNames);
    }
  }

  void setGlobal(String? variableName, InkObject? value) {
    InkObject? oldValue;
    if (patch != null) {
      var patchGlobal = patch!.tryGetGlobal(variableName, value);
      if (!patchGlobal.exists) {
        oldValue = _globalVariables[variableName];
      } else {
        oldValue = patchGlobal.value;
      }
    } else {
      oldValue = _globalVariables[variableName];
    }

    ListValue.retainListOriginsForAssignment(oldValue, value);

    if (patch != null) {
      patch!.setGlobal(variableName, value);
    } else {
      _globalVariables[variableName] = value;
    }

    if (variableChangedEvent != null && value != oldValue) {
      if (batchObservingVariableChanges) {
        if (patch != null) {
          patch!.addChangedVariable(variableName);
        } else if (_changedVariablesForBatchObs != null) {
          _changedVariablesForBatchObs!.add(variableName);
        }
      } else {
        variableChangedEvent
            .broadcast(VariableChangedEventArg(variableName, value));
      }
    }
  }

  // Given a variable pointer with just the name of the target known, resolve to a variable
  // pointer that more specifically points to the exact instance: whether it's global,
  // or the exact position of a temporary on the callstack.
  VariablePointerValue _resolveVariablePointer(
      VariablePointerValue varPointer) {
    int contextIndex = varPointer.contextIndex;

    if (contextIndex == -1) {
      contextIndex = _getContextIndexOfVariableNamed(varPointer.variableName);
    }

    var valueOfVariablePointedTo =
        _getRawVariableWithName(varPointer.variableName, contextIndex);

    // Extra layer of indirection:
    // When accessing a pointer to a pointer (e.g. when calling nested or
    // recursive functions that take a variable references, ensure we don't create
    // a chain of indirection by just returning the final target.
    var doubleRedirectionPointer =
        valueOfVariablePointedTo as VariablePointerValue;
    if (doubleRedirectionPointer != null) {
      return doubleRedirectionPointer;
    }

    // Make copy of the variable pointer so we're not using the value direct from
    // the runtime. Temporary must be local to the current scope.
    else {
      return VariablePointerValue(varPointer.variableName, contextIndex);
    }
  }

  // 0  if named variable is global
  // 1+ if named variable is a temporary in a particular call stack element
  int _getContextIndexOfVariableNamed(String varName) {
    if (globalVariableExistsWithName(varName)) {
      return 0;
    }

    return _callStack.currentElementIndex;
  }

  late Map<String?, InkObject?> _globalVariables;

  late Map<String?, InkObject?> _defaultGlobalVariables;

  // Used for accessing temporary variables
  late CallStack _callStack;
  HashSet<String?>? _changedVariablesForBatchObs;
  late ListDefinitionsOrigin _listDefsOrigin;

  @override
  // TODO: implement iterator
  Iterator<String?> get iterator => _globalVariables.keys.iterator;
}

class VariableChangedEventArg extends EventArgs {
  String? variableName;
  InkObject? newValue;

  VariableChangedEventArg(this.variableName, this.newValue);
}
