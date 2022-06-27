part of inky;

class Json {
  static List<T> jArrayToRuntimeObjList<T extends InkObject?>(
      List<Object?> jArray,
      [bool skipLast = false]) //where T extends InkObject
  {
    // int count = jArray.length;
    // if (skipLast) {
    //   count--;
    // }

    var list =
        List<T>.generate(skipLast ? jArray.length - 1 : jArray.length, (index) {
      return jTokenToRuntimeObject(jArray[index]) as T;
    });

    return list;
  }

  // static List<InkObject> jArrayToRuntimeObjList(List<Object> jArray, [bool skipLast=false])
  //       {
  //           return jArrayToRuntimeObjList<InkObject> (jArray, skipLast);
  //       }

  static void writeDictionaryRuntimeObjs(
      Writer writer, Map<String, InkObject> dictionary) {
    writer.writeObjectStart();
    for (var keyVal in dictionary.entries) {
      writer.writePropertyStart(keyVal.key);
      writeRuntimeObject(writer, keyVal.value);
      writer.writePropertyEnd();
    }
    writer.writeObjectEnd();
  }

  static void writeListRuntimeObjs(Writer writer, List<InkObject?> list) {
    writer.writeArrayStart();
    for (var val in list) {
      writeRuntimeObject(writer, val);
    }
    writer.writeArrayEnd();
  }

  static void writeIntDictionary(Writer writer, Map<String, int> dict) {
    writer.writeObjectStart();
    for (var keyVal in dict.entries) {
      writer.writePropertyNameInt(keyVal.key, keyVal.value);
    }
    writer.writeObjectEnd();
  }

  static void writeRuntimeObject(Writer writer, InkObject? obj) {
    var container = obj as Container?;
    if (container != null) {
      writeRuntimeContainer(writer, container);
      return;
    }

    var divert = obj as Divert?;
    if (divert != null) {
      String divTypeKey = "->";
      if (divert.isExternal) {
        divTypeKey = "x()";
      } else if (divert.pushesToStack) {
        if (divert.stackPushType == PushPopType.Function) {
          divTypeKey = "f()";
        } else if (divert.stackPushType == PushPopType.Tunnel) {
          divTypeKey = "->t->";
        }
      }

      String targetStr;
      if (divert.hasVariableTarget) {
        targetStr = divert.variableDivertName!;
      } else {
        targetStr = divert.targetPathString!;
      }

      writer.writeObjectStart();

      writer.writePropertyNameString(divTypeKey, targetStr);

      if (divert.hasVariableTarget) {
        writer.writePropertyNameBool("var", true);
      }

      if (divert.isConditional) {
        writer.writePropertyNameBool("c", true);
      }

      if (divert.externalArgs > 0) {
        writer.writePropertyNameInt("exArgs", divert.externalArgs);
      }

      writer.writeObjectEnd();
      return;
    }

    var choicePoint = obj as ChoicePoint?;
    if (choicePoint != null) {
      writer.writeObjectStart();
      writer.writePropertyNameString("*", choicePoint.pathStringOnChoice);
      writer.writePropertyNameInt("flg", choicePoint.flags);
      writer.writeObjectEnd();
      return;
    }

    var boolVal = obj as BoolValue?;
    if (boolVal != null) {
      writer.writeBool(boolVal.value);
      return;
    }

    var intVal = obj as IntValue?;
    if (intVal != null) {
      writer.writeInt(intVal.value);
      return;
    }

    var floatVal = obj as FloatValue?;
    if (floatVal != null) {
      writer.writeFloat(floatVal.value);
      return;
    }

    var strVal = obj as StringValue?;
    if (strVal != null) {
      if (strVal.isNewline) {
        writer.writeStringEscape("\\n", false);
      } else {
        writer.writeStringStart();
        writer.writeStringInner("^");
        writer.writeStringInner(strVal.value);
        writer.writeStringEnd();
      }
      return;
    }

    var listVal = obj as ListValue?;
    if (listVal != null) {
      _writeInkList(writer, listVal);
      return;
    }

    var divTargetVal = obj as DivertTargetValue?;
    if (divTargetVal != null) {
      writer.writeObjectStart();
      writer.writePropertyNameString(
          "^->", divTargetVal.value.componentsString);
      writer.writeObjectEnd();
      return;
    }

    var varPtrVal = obj as VariablePointerValue?;
    if (varPtrVal != null) {
      writer.writeObjectStart();
      writer.writePropertyNameString("^var", varPtrVal.value);
      writer.writePropertyNameInt("ci", varPtrVal.contextIndex);
      writer.writeObjectEnd();
      return;
    }

    var glue = obj as Glue?;
    if (glue != null) {
      writer.writeStringEscape("<>");
      return;
    }

    var controlCmd = obj as ControlCommand?;
    if (controlCmd != null) {
      writer.writeStringEscape(_controlCommandNames[controlCmd.commandType]);
      return;
    }

    var nativeFunc = obj as NativeFunctionCall?;
    if (nativeFunc != null) {
      var name = nativeFunc.name;

      // Avoid collision with ^ used to indicate a string
      if (name == "^") name = "L^";

      writer.writeStringEscape(name!);
      return;
    }

    // Variable reference
    var varRef = obj as VariableReference?;
    if (varRef != null) {
      writer.writeObjectStart();

      String readCountPath = varRef.pathStringForCount!;
      if (readCountPath != null) {
        writer.writePropertyNameString("CNT?", readCountPath);
      } else {
        writer.writePropertyNameString("VAR?", varRef.name!);
      }

      writer.writeObjectEnd();
      return;
    }

    // Variable assignment
    var varAss = obj as VariableAssignment?;
    if (varAss != null) {
      writer.writeObjectStart();

      String key = varAss.isGlobal ? "VAR=" : "temp=";
      writer.writePropertyNameString(key, varAss.variableName!);

      // Reassignment?
      if (!varAss.isNewDeclaration) {
        writer.writePropertyNameBool("re", true);
      }

      writer.writeObjectEnd();

      return;
    }

    // Void
    var voidObj = obj as Void;
    if (voidObj != null) {
      writer.writeStringEscape("void");
      return;
    }

    // Tag
    var tag = obj as Tag?;
    if (tag != null) {
      writer.writeObjectStart();
      writer.writePropertyNameString("#", tag.text);
      writer.writeObjectEnd();
      return;
    }

    // Used when serialising save state only
    var choice = obj as Choice?;
    if (choice != null) {
      writeChoice(writer, choice);
      return;
    }

    throw FormatException("Failed to write runtime object to JSON: $obj");
  }

  static Map<String, InkObject> jObjectToDictionaryRuntimeObjs(
      Map<String, Object> jObject) {
    var dict = <String, InkObject>{};

    for (var keyVal in jObject.entries) {
      dict[keyVal.key] = jTokenToRuntimeObject(keyVal.value)!;
    }

    return dict;
  }

  static Map<String, int> jObjectToIntDictionary(Map<String, Object> jObject) {
    var dict = <String, int>{};
    for (var keyVal in jObject.entries) {
      dict[keyVal.key] = keyVal.value as int;
    }
    return dict;
  }

  // ----------------------
  // JSON ENCODING SCHEME
  // ----------------------
  //
  // Glue:           "<>", "G<", "G>"
  //
  // ControlCommand: "ev", "out", "/ev", "du" "pop", "->->", "~ret", "str", "/str", "nop",
  //                 "choiceCnt", "turns", "visit", "seq", "thread", "done", "end"
  //
  // NativeFunction: "+", "-", "/", "*", "%" "~", "==", ">", "<", ">=", "<=", "!=", "!"... etc
  //
  // Void:           "void"
  //
  // Value:          "^string value", "^^string value beginning with ^"
  //                 5, 5.2
  //                 {"^->": "path.target"}
  //                 {"^var": "varname", "ci": 0}
  //
  // Container:      [...]
  //                 [...,
  //                     {
  //                         "subContainerName": ...,
  //                         "#f": 5,                    // flags
  //                         "#n": "containerOwnName"    // only if not redundant
  //                     }
  //                 ]
  //
  // Divert:         {"->": "path.target", "c": true }
  //                 {"->": "path.target", "var": true}
  //                 {"f()": "path.func"}
  //                 {"->t->": "path.tunnel"}
  //                 {"x()": "externalFuncName", "exArgs": 5}
  //
  // Var Assign:     {"VAR=": "varName", "re": true}   // reassignment
  //                 {"temp=": "varName"}
  //
  // Var ref:        {"VAR?": "varName"}
  //                 {"CNT?": "stitch name"}
  //
  // ChoicePoint:    {"*": pathString,
  //                  "flg": 18 }
  //
  // Choice:         Nothing too clever, it's only used in the save state,
  //                 there's not likely to be many of them.
  //
  // Tag:            {"#": "the tag text"}
  static InkObject? jTokenToRuntimeObject(Object? token) {
    print("Token type is: ${token.runtimeType}");
    if (token is int || token is double || token is bool) {
      return Value.create(token);
    }

    if (token is String) {
      String str = token;

      // String value
      int firstChar = str[0].codeUnitAt(0);
      if (firstChar == '^'.codeUnitAt(0)) {
        return StringValue(str.substring(1));
      } else if (firstChar == '\n'.codeUnitAt(0) && str.length == 1) {
        return StringValue("\n");
      }

      // Glue
      if (str == "<>") return Glue();

      // Control commands (would looking up in a hash set be faster?)
      for (int i = 0; i < _controlCommandNames.length; ++i) {
        String cmdName = _controlCommandNames[i];
        if (str == cmdName) {
          return ControlCommand(commandType: i);
        }
      }

      // Native functions
      // "^" conflicts with the way to identify strings, so now
      // we know it's not a string, we can convert back to the proper
      // symbol for the operator.
      if (str == "L^") str = "^";
      if (NativeFunctionCall.callExistsWithName(str)) {
        return NativeFunctionCall.callWithName(str);
      }

      // Pop
      if (str == "->->") {
        return ControlCommand.popTunnel();
      } else if (str == "~ret") {
        return ControlCommand.popFunction();
      }

      // Void
      if (str == "void") {
        return Void();
      }
    }

    if (token is Map<String, Object>) {
      var obj = token;
      Object? propValue;

      // Divert target value to path

      if (obj.containsKey("^->")) {
        return DivertTargetValue(Path.fromString(obj["^->"]));
      }

      // VariablePointerValue
      if (obj.containsKey("^var")) {
        var varPtr = VariablePointerValue(obj["^var"] as String);
        if (obj.containsKey("ci")) {
          varPtr.contextIndex = obj["ci"] as int;
        }
        return varPtr;
      }

      // Divert
      bool isDivert = false;
      bool pushesToStack = false;
      PushPopType divPushType = PushPopType.Function;
      bool external = false;
      if (obj.containsKey("->")) {
        propValue = obj["->"]!;
        isDivert = true;
      } else if (obj.containsKey("f()")) {
        propValue = obj["f()"]!;
        isDivert = true;
        pushesToStack = true;
        divPushType = PushPopType.Function;
      } else if (obj.containsKey("->t->")) {
        propValue = obj["->t->"]!;
        isDivert = true;
        pushesToStack = true;
        divPushType = PushPopType.Tunnel;
      } else if (obj.containsKey("x()")) {
        propValue = obj["x()"]!;
        isDivert = true;
        external = true;
        pushesToStack = false;
        divPushType = PushPopType.Function;
      }
      if (isDivert) {
        var divert = Divert();
        divert.pushesToStack = pushesToStack;
        divert.stackPushType = divPushType;
        divert.isExternal = external;

        if (propValue == null) throw const FormatException("propValue not set");

        String target = propValue.toString();

        if (obj.containsKey("var")) {
          divert.variableDivertName = target;
        } else {
          divert.targetPathString = target;
        }

        divert.isConditional = obj.containsKey("c");

        if (external) {
          if (obj.containsKey("exArgs")) {
            divert.externalArgs = obj["exArgs"] as int;
          }
        }

        return divert;
      }

      // Choice
      if (obj.containsKey("*")) {
        var choice = ChoicePoint();
        choice.pathStringOnChoice = obj["*"].toString();

        if (obj.containsKey("flg")) {
          choice.flags = obj["flg"] as int;
        }

        return choice;
      }

      // Variable reference
      if (obj.containsKey("VAR?")) {
        return VariableReference(obj["VAR?"].toString());
      } else if (obj.containsKey("CNT?")) {
        var readCountVarRef = VariableReference();
        readCountVarRef.pathStringForCount = obj["CNT?"].toString();
        return readCountVarRef;
      }

//TODO  fix prop values
      // Variable assignment
      bool isVarAss = false;
      bool isGlobalVar = false;
      if (obj.containsKey("VAR=")) {
        propValue = obj[
            "VAR="]; // TODO should be done even if key isn't found
        isVarAss = true;
        isGlobalVar = true;
      } else if (obj.containsKey("temp=")) {
         propValue = obj["temp="]; // TODO same as above
        isVarAss = true;
        isGlobalVar = false;
      }
      if (isVarAss) {
        var varName = propValue.toString();
        var isNewDecl = !obj.containsKey("re");
        var varAss = VariableAssignment(varName, isNewDecl);
        varAss.isGlobal = isGlobalVar;
        return varAss;
      }

      // Tag
      if (obj.containsKey("#")) {
        return Tag(propValue as String);
      }

      // List value
      if (obj.containsKey("list")) {
        var listContent = propValue as Map<String, Object>;
        var rawList = InkList();
        if (obj.containsKey("origins")) {
          var namesAsObjs = propValue as List<Object>;
          rawList.setInitialOriginNames(namesAsObjs.cast<String>().toList());
        }
        for (var nameToVal in listContent.entries) {
          var item = InkListItem.from(nameToVal.key);
          var val = nameToVal.value as int;
          rawList.add(item, val);
        }
        return ListValue.fromList(rawList);
      }

      // Used when serialising save state only
      if (obj["originalChoicePath"] != null) {
        return _jObjectToChoice(obj);
      }
    }

    // Array is always a Runtime.Container
    if (token is List<Object?>) {
      return _jArrayToContainer(token);
    }

    if (token == null) {
      return null;
    }

    throw FormatException("Failed to convert token to runtime object: $token");
  }

  static void writeRuntimeContainer(Writer writer, Container container,
      [bool withoutName = false]) {
    writer.writeArrayStart();

    for (var c in container.content) {
      writeRuntimeObject(writer, c);
    }

    // Container is always an array [...]
    // But the final element is always either:
    //  - a dictionary containing the named content, as well as possibly
    //    the key "#" with the count flags
    //  - null, if neither of the above
    var namedOnlyContent = container.namedOnlyContent;
    var countFlags = container.countFlags;
    var hasNameProperty = container.name != null && !withoutName;

    bool hasTerminator =
        namedOnlyContent != null || countFlags > 0 || hasNameProperty;

    if (hasTerminator) {
      writer.writeObjectStart();
    }

    if (namedOnlyContent != null) {
      for (var namedContent in namedOnlyContent.entries) {
        var name = namedContent.key;
        var namedContainer = namedContent.value as Container;
        writer.writePropertyStart(name);
        writeRuntimeContainer(writer, namedContainer, true);
        writer.writePropertyEnd();
      }
    }

    if (countFlags > 0) {
      writer.writePropertyNameInt("#f", countFlags);
    }

    if (hasNameProperty) {
      writer.writePropertyNameString("#n", container.name!);
    }

    if (hasTerminator) {
      writer.writeObjectEnd();
    } else {
      writer.writeNull();
    }

    writer.writeArrayEnd();
  }

  static Container _jArrayToContainer(List<Object?> jArray) {
    var container = Container();
    container.content = jArrayToRuntimeObjList(jArray, true);

    // Final object in the array is always a combination of
    //  - named content
    //  - a "#f" key with the countFlags
    // (if either exists at all, otherwise null)
    var terminatingObj = jArray[jArray.length - 1] as Map<String, Object>?;
    if (terminatingObj != null) {
      var namedOnlyContent = <String, InkObject>{}; // (terminatingObj.length);

      for (var keyVal in terminatingObj.entries) {
        if (keyVal.key == "#f") {
          container.countFlags = keyVal.value as int;
        } else if (keyVal.key == "#n") {
          container.name = keyVal.value.toString();
        } else {
          var namedContentItem = jTokenToRuntimeObject(keyVal.value);
          var namedSubContainer = namedContentItem as Container?;
          if (namedSubContainer != null) {
            namedSubContainer.name = keyVal.key;
          }
          namedOnlyContent[keyVal.key] = namedContentItem!;
        }
      }

      container.namedOnlyContent = namedOnlyContent;
    }

    return container;
  }

  static Choice _jObjectToChoice(Map<String, Object> jObj) {
    var choice = Choice();
    choice.text = jObj["text"].toString();
    choice.index = jObj["index"] as int;
    choice.sourcePath = jObj["originalChoicePath"].toString();
    choice.originalThreadIndex = jObj["originalThreadIndex"] as int;
    choice.pathStringOnChoice = jObj["targetPath"].toString();
    return choice;
  }

  static void writeChoice(Writer writer, Choice choice) {
    writer.writeObjectStart();
    writer.writePropertyNameString("text", choice.text!);
    writer.writePropertyNameInt("index", choice.index);
    writer.writePropertyNameString("originalChoicePath", choice.sourcePath!);
    writer.writePropertyNameInt(
        "originalThreadIndex", choice.originalThreadIndex);
    writer.writePropertyNameString("targetPath", choice.pathStringOnChoice!);
    writer.writeObjectEnd();
  }

  static void _writeInkList(Writer writer, ListValue listVal) {
    var rawList = listVal.value;

    writer.writeObjectStart();

    writer.writePropertyStart("list");

    writer.writeObjectStart();

    for (var itemAndValue in rawList.entries) {
      var item = itemAndValue.key;
      int itemVal = itemAndValue.value;

      writer.writePropertyNameStart();
      writer.writePropertyNameInner(item.originName ?? "?");
      writer.writePropertyNameInner(".");
      writer.writePropertyNameInner(item.itemName!);
      writer.writePropertyNameEnd();

      writer.writeInt(itemVal);

      writer.writePropertyEnd();
    }

    writer.writeObjectEnd();

    writer.writePropertyEnd();

    if (rawList.length == 0 &&
        rawList.originNames != null &&
        rawList.originNames!.length > 0) {
      writer.writePropertyStart("origins");
      writer.writeArrayStart();
      for (var name in rawList.originNames!) {
        writer.writeStringEscape(name);
      }
      writer.writeArrayEnd();
      writer.writePropertyEnd();
    }

    writer.writeObjectEnd();
  }

  static ListDefinitionsOrigin jTokenToListDefinitions(Object obj) {
    var defsObj = obj as Map<String, Object>;

    var allDefs = <ListDefinition>[];

    for (var kv in defsObj.entries) {
      var name = kv.key;
      var listDefJson = kv.value as Map<String, Object>;

      // Cast (string, object) to (string, int) for items
      var items = <String, int>{};
      for (var nameValue in listDefJson.entries) {
        items.putIfAbsent(nameValue.key, () => nameValue.value as int);
      }

      var def = ListDefinition(name, items);
      allDefs.add(def);
    }

    return ListDefinitionsOrigin(allDefs);
  }

  /// Used to be static Json()
  static _initializeControlCommandNames() {
    if (__controlCommandNames.isEmpty) {
      __controlCommandNames = List<String>.filled(CommandType.TOTAL_VALUES, "");

      __controlCommandNames[CommandType.evalStart] = "ev";
      __controlCommandNames[CommandType.evalOutput] = "out";
      __controlCommandNames[CommandType.evalEnd] = "/ev";
      __controlCommandNames[CommandType.duplicate] = "du";
      __controlCommandNames[CommandType.popEvaluatedValue] = "pop";
      __controlCommandNames[CommandType.popFunction] = "~ret";
      __controlCommandNames[CommandType.popTunnel] = "->->";
      __controlCommandNames[CommandType.beginString] = "str";
      __controlCommandNames[CommandType.endString] = "/str";
      __controlCommandNames[CommandType.noOp] = "nop";
      __controlCommandNames[CommandType.choiceCount] = "choiceCnt";
      __controlCommandNames[CommandType.turns] = "turn";
      __controlCommandNames[CommandType.turnsSince] = "turns";
      __controlCommandNames[CommandType.readCount] = "readc";
      __controlCommandNames[CommandType.random] = "rnd";
      __controlCommandNames[CommandType.seedRandom] = "srnd";
      __controlCommandNames[CommandType.visitIndex] = "visit";
      __controlCommandNames[CommandType.sequenceShuffleIndex] = "seq";
      __controlCommandNames[CommandType.startThread] = "thread";
      __controlCommandNames[CommandType.done] = "done";
      __controlCommandNames[CommandType.end] = "end";
      __controlCommandNames[CommandType.listFromInt] = "listInt";
      __controlCommandNames[CommandType.listRange] = "range";
      __controlCommandNames[CommandType.listRandom] = "lrnd";

      for (int i = 0; i < CommandType.TOTAL_VALUES; ++i) {
        if (_controlCommandNames[i] == null) {
          throw FormatException(
              "Control command not accounted for in serialisation");
        }
      }
    }
  }

  static List<String> __controlCommandNames = [];
  static List<String> get _controlCommandNames {
    if (__controlCommandNames.isEmpty) {
      _initializeControlCommandNames();
    }
    return __controlCommandNames;
  }
}
