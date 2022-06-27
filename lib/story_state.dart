part of inky;

/// <summary>
/// All story state information is included in the StoryState class,
/// including global variables, read counts, the pointer to the current
/// point in the story, the call stack (for tunnels, functions, etc),
/// and a few other smaller bits and pieces. You can save the current
/// state using the json serialisation functions ToJson and LoadJson.
/// </summary>
class StoryState {
  /// <summary>
  /// The current version of the state save file JSON-based format.
  /// </summary>
  static const int kInkSaveStateVersion =
      9; // new: multi-flows, but backward compatible
  static const int _kMinCompatibleLoadVersion = 8;

  /// <summary>
  /// Callback for when a state is loaded
  /// </summary>
  final Event onDidLoadState = Event();

  /// <summary>
  /// Exports the current state to json format, in order to save the game.
  /// </summary>
  /// <returns>The save state in json format.</returns>
  String toJson() {
    var writer = Writer();
    _writeJson(writer);
    return writer.toString();
  }

  /// <summary>
  /// Exports the current state to json format, in order to save the game.
  /// For this overload you can pass in a custom stream, such as a FileStream.
  /// </summary>
  void toJsonFromStream(Stream stream) {
    throw UnimplementedError("toJsonFromStream not implemented");
    // var writer = Writer.fromStream(stream);
    // _writeJson(writer);
  }

  /// <summary>
  /// Loads a previously saved state in JSON format.
  /// </summary>
  /// <param name="json">The JSON string to load.</param>
  void loadJson(String json) {
    var jObject = SimpleJson.textToDictionary(json);
    _loadJsonObj(jObject);
    onDidLoadState.broadcast();
  }

  /// <summary>
  /// Gets the visit/read count of a particular Container at the given path.
  /// For a knot or stitch, that path string will be in the form:
  ///
  ///     knot
  ///     knot.stitch
  ///
  /// </summary>
  /// <returns>The number of times the specific knot or stitch has
  /// been enountered by the ink engine.</returns>
  /// <param name="pathString">The dot-separated path string of
  /// the specific knot or stitch.</param>
  int visitCountAtPathString(String pathString) {
    int visitCountOut = 0;

    if (_patch != null) {
      var container =
          story.contentAtPath(Path.fromString(pathString)).container;
      if (container == null) {
        throw FormatException("Content at path not found: $pathString");
      }

      var valueHolder = _patch!.tryGetVisitCount(container, visitCountOut);
      if (valueHolder.exists) {
        return valueHolder.value;
      }
    }

    if (_visitCounts.containsKey(pathString)) {
      return _visitCounts[pathString]!;
    }

    return 0;
  }

  int visitCountForContainer(Container container) {
    if (!container.visitsShouldBeCounted) {
      story.error(
          "Read count for target (${container.name} - on ${container.debugMetadata}) unknown.");
      return 0;
    }

    var valueHolder = _patch?.tryGetVisitCount(container, 0);
    if (valueHolder != null && valueHolder.exists) {
      return valueHolder.value;
    }

    int count = 0;
    var containerPathStr = container.path.toString();
    if (_visitCounts.containsKey(containerPathStr)) {
      count = _visitCounts[containerPathStr]!;
    }
    return count;
  }

  void incrementVisitCountForContainer(Container container) {
    if (_patch != null) {
      var currCount = visitCountForContainer(container);
      currCount++;
      _patch!.setVisitCount(container, currCount);
      return;
    }

    int count = 0;
    var containerPathStr = container.path.toString();
    if (_visitCounts.containsKey(containerPathStr)) {
      count = _visitCounts[containerPathStr]!;
    }
    count++;
    _visitCounts[containerPathStr] = count;
  }

  void recordTurnIndexVisitToContainer(Container container) {
    if (_patch != null) {
      _patch!.setTurnIndex(container, currentTurnIndex);
      return;
    }

    var containerPathStr = container.path.toString();
    _turnIndices[containerPathStr] = currentTurnIndex;
  }

  int turnsSinceForContainer(Container container) {
    if (!container.turnIndexShouldBeCounted) {
      story.error(
          "TURNS_SINCE() for target (${container.name} - on ${container.debugMetadata}) unknown.");
    }

    int index = 0;

    var turnIndex = _patch?.tryGetTurnIndex(container, index);
    if (turnIndex != null && turnIndex.exists) {
      index = turnIndex.value;
      return currentTurnIndex - index;
    }

    var containerPathStr = container.path.toString();
    if (_turnIndices.containsKey(containerPathStr)) {
      index = _turnIndices[containerPathStr]!;
      return currentTurnIndex - index;
    } else {
      return -1;
    }
  }

  int get callstackDepth => callStack.depth;

  // REMEMBER! REMEMBER! REMEMBER!
  // When adding state, update the Copy method, and serialisation.
  // REMEMBER! REMEMBER! REMEMBER!

  List<InkObject?> get outputStream => _currentFlow.outputStream;

  List<Choice> get currentChoices {
    // If we can continue generating text content rather than choices,
    // then we reflect the choice list as being empty, since choices
    // should always come at the end.
    if (canContinue) return <Choice>[];
    return _currentFlow.currentChoices;
  }

  List<Choice> get generatedChoices => _currentFlow.currentChoices;

  // TODO: Consider removing currentErrors / currentWarnings altogether
  // and relying on client error handler code immediately handling StoryExceptions etc
  // Or is there a specific reason we need to collect potentially multiple
  // errors before throwing/exiting?
  List<String>? _currentErrors;
  List<String>? get currentErrors => _currentErrors;

  List<String>? _currentWarnings;
  List<String>? get currentWarnings => _currentWarnings;

  late VariablesState _variablesState;
  VariablesState get variablesState => _variablesState;

  CallStack get callStack => _currentFlow.callStack;

  // set {
  //     _currentFlow.callStack = value;
  // }

  late List<InkObject> _evaluationStack;
  List<InkObject?> get evaluationStack => _evaluationStack;

  // In original code Pointer is a struct so we need to initialize this
  Pointer divertedPointer = Pointer();

  int _currentTurnIndex = 0;
  int get currentTurnIndex => _currentTurnIndex;

  int storySeed = 0;
  int previousRandom = 0;
  bool didSafeExit = false;

  late Story story;

  /// <summary>
  /// String representation of the location where the story currently is.
  /// </summary>
  String? get currentPathString {
    var pointer = currentPointer;
    if (pointer.isNull) {
      return null;
    } else {
      return pointer.path.toString();
    }
  }

  Pointer get currentPointer {
    print("currentPointer: ${callStack.currentElement.currentPointer}");
    return callStack.currentElement.currentPointer;
  }

  set currentPointer(Pointer value) {
    callStack.currentElement.currentPointer = value;
  }

  Pointer get previousPointer => callStack.currentThread.previousPointer;
  set previousPointer(Pointer value) {
    callStack.currentThread.previousPointer = value;
  }

  bool _canContinue = false;
  bool get canContinue {
    _canContinue = !currentPointer.isNull && !hasError;
    return _canContinue;
  }

  bool get hasError {
    print(
        "currentErrors != null or empty: ${currentErrors != null} or ${currentErrors?.isNotEmpty}");
    return currentErrors != null && currentErrors!.isNotEmpty;
  }

  bool get hasWarning => currentWarnings != null && currentWarnings!.isNotEmpty;

  late String _currentText;
  String get currentText {
    if (_outputStreamTextDirty) {
      var sb = StringBuffer();

      for (var outputObj in outputStream) {
        var textContent = ConvertTo.stringValue(outputObj);
        if (textContent != null) {
          sb.write(textContent.value);
        }
      }

      _currentText = _cleanOutputWhitespace(sb.toString());

      _outputStreamTextDirty = false;
    }

    return _currentText;
  }

  // Cleans inline whitespace in the following way:
  //  - Removes all whitespace from the start and end of line (including just before a \n)
  //  - Turns all consecutive space and tab runs into single spaces (HTML style)
  String _cleanOutputWhitespace(String str) {
    var sb = StringBuffer();

    int currentWhitespaceStart = -1;
    int startOfLine = 0;

    for (int i = 0; i < str.length; i++) {
      var c = str[i];

      bool isInlineWhitespace = c == ' ' || c == '\t';

      if (isInlineWhitespace && currentWhitespaceStart == -1) {
        currentWhitespaceStart = i;
      }

      if (!isInlineWhitespace) {
        if (c != '\n' &&
            currentWhitespaceStart > 0 &&
            currentWhitespaceStart != startOfLine) {
          sb.write(' ');
        }
        currentWhitespaceStart = -1;
      }

      if (c == '\n') {
        startOfLine = i + 1;
      }

      if (!isInlineWhitespace) {
        sb.write(c);
      }
    }

    return sb.toString();
  }

  late List<String> _currentTags;
  List<String> get currentTags {
    if (_outputStreamTagsDirty) {
      _currentTags = <String>[];

      for (var outputObj in outputStream) {
        var tag = ConvertTo.tag(outputObj);
        if (tag != null) {
          _currentTags.add(tag.text);
        }
      }

      _outputStreamTagsDirty = false;
    }

    return _currentTags;
  }

  String? get currentFlowName => _currentFlow.name;

  bool get inExpressionEvaluation =>
      callStack.currentElement.inExpressionEvaluation;

  set inExpressionEvaluation(bool value) {
    callStack.currentElement.inExpressionEvaluation = value;
  }

  StoryState(this.story) {
    _currentFlow = Flow(kDefaultFlowName, story);

    _outputStreamDirty();

    _evaluationStack = <InkObject>[];

    _variablesState = VariablesState(callStack, story.listDefinitions!);

    _visitCounts = <String, int>{};
    _turnIndices = <String, int>{};

    _currentTurnIndex = -1;

    // Seed the shuffle random numbers
    int timeSeed = DateTime.now().millisecond;
    storySeed = (Random(timeSeed)).nextInt(1000000) % 100;
    previousRandom = 0;

    goToStart();
  }

  void goToStart() {
    callStack.currentElement.currentPointer =
        Pointer.startOf(story.mainContentContainer!);
  }

  void _switchFlow_Internal(String flowName) {
    if (flowName == null) {
      throw FormatException("Must pass a non-null string to Story.SwitchFlow");
    }

    if (_namedFlows == null) {
      _namedFlows = <String, Flow>{};
      _namedFlows![kDefaultFlowName] = _currentFlow;
    }

    if (flowName == _currentFlow.name) {
      return;
    }

    Flow flow;
    if (!_namedFlows!.containsKey(flowName)) {
      flow = Flow(flowName, story);
      _namedFlows![flowName] = flow;
    } else {
      flow = _namedFlows![flowName]!;
    }

    _currentFlow = flow;
    variablesState._callStack = _currentFlow.callStack;

    // Cause text to be regenerated from output stream if necessary
    _outputStreamDirty();
  }

  void _switchToDefaultFlow_Internal() {
    if (_namedFlows == null) return;
    _switchFlow_Internal(kDefaultFlowName);
  }

  void _removeFlow_Internal(String flowName) {
    if (flowName == null) {
      throw FormatException("Must pass a non-null string to Story.DestroyFlow");
    }
    if (flowName == kDefaultFlowName) {
      throw FormatException("Cannot destroy default flow");
    }

    // If we're currently in the flow that's being removed, switch back to default
    if (_currentFlow.name == flowName) {
      _switchToDefaultFlow_Internal();
    }

    _namedFlows!.remove(flowName);
  }

  // Warning: Any InkObject content referenced within the StoryState will
  // be re-referenced rather than cloned. This is generally okay though since
  // InkObjects are treated as immutable after they've been set up.
  // (e.g. we don't edit a Runtime.StringValue after it's been created an added.)
  // I wonder if there's a sensible way to enforce that..??
  StoryState copyAndStartPatching() {
    var copy = StoryState(story);

    copy._patch = StatePatch(_patch);

    // Hijack the new default flow to become a copy of our current one
    // If the patch is applied, then this new flow will replace the old one in _namedFlows
    copy._currentFlow.name = _currentFlow.name;
    copy._currentFlow.callStack = CallStack.from(_currentFlow.callStack);
    copy._currentFlow.currentChoices.addAll(_currentFlow.currentChoices);
    copy._currentFlow.outputStream.addAll(_currentFlow.outputStream);
    copy._outputStreamDirty();

    // The copy of the state has its own copy of the named flows dictionary,
    // except with the current flow replaced with the copy above
    // (Assuming we're in multi-flow mode at all. If we're not then
    // the above copy is simply the default flow copy and we're done)
    if (_namedFlows != null) {
      copy._namedFlows = <String?, Flow>{};
      for (var namedFlow in _namedFlows!.entries) {
        copy._namedFlows![namedFlow.key] = namedFlow.value;
      }
      copy._namedFlows![_currentFlow.name] = copy._currentFlow;
    }

    if (hasError) {
      copy._currentErrors = <String>[];
      copy._currentErrors!.addAll(currentErrors!);
    }
    if (hasWarning) {
      copy._currentWarnings = <String>[];
      copy._currentWarnings!.addAll(currentWarnings!);
    }

    // ref copy - exactly the same variables state!
    // we're expecting not to read it only while in patch mode
    // (though the callstack will be modified)
    copy._variablesState = variablesState;
    copy.variablesState._callStack = copy.callStack;
    copy.variablesState.patch = copy._patch;

    copy.evaluationStack.addAll(evaluationStack);

    if (!divertedPointer.isNull) {
      copy.divertedPointer = divertedPointer;
    }

    copy.previousPointer = previousPointer;

    // visit counts and turn indicies will be read only, not modified
    // while in patch mode
    copy._visitCounts = _visitCounts;
    copy._turnIndices = _turnIndices;

    copy._currentTurnIndex = currentTurnIndex;
    copy.storySeed = storySeed;
    copy.previousRandom = previousRandom;

    copy.didSafeExit = didSafeExit;

    return copy;
  }

  void restoreAfterPatch() {
    // VariablesState was being borrowed by the patched
    // state, so restore it with our own callstack.
    // _patch will be null normally, but if you're in the
    // middle of a save, it may contain a _patch for save purpsoes.
    variablesState._callStack = callStack;
    variablesState.patch = _patch; // usually null
  }

  void applyAnyPatch() {
    if (_patch == null) return;

    variablesState.applyPatch();

    for (var pathToCount in _patch!.visitCounts.entries) {
      _applyCountChanges(pathToCount.key, pathToCount.value, true);
    }

    for (var pathToIndex in _patch!.turnIndices.entries) {
      _applyCountChanges(pathToIndex.key, pathToIndex.value, false);
    }

    _patch = null;
  }

  _applyCountChanges(Container container, int newCount, bool isVisit) {
    var counts = isVisit ? _visitCounts : _turnIndices;
    counts[container.path.toString()] = newCount;
  }

  void _writeJson(Writer writer) {
    writer.writeObjectStart();

    // Flows
    writer.writePropertyStart("flows");
    writer.writeObjectStart();

    // Multi-flow
    if (_namedFlows != null) {
      for (var namedFlow in _namedFlows!.entries) {
        writer.writeProperty(namedFlow.key, namedFlow.value.writeJson);
      }
    }

    // Single flow
    else {
      writer.writeProperty(_currentFlow.name, _currentFlow.writeJson);
    }

    writer.writeObjectEnd();
    writer.writePropertyEnd(); // end of flows

    writer.writePropertyNameString("currentFlowName", _currentFlow.name);

    writer.writeProperty("variablesState", variablesState.writeJson);

    writer.writeProperty(
        "evalStack", (w) => Json.writeListRuntimeObjs(w, evaluationStack));

    if (!divertedPointer.isNull && divertedPointer.path != null) {
      writer.writePropertyNameString(
          "currentDivertTarget", divertedPointer.path!.componentsString);
    }

    writer.writeProperty(
        "visitCounts", (w) => Json.writeIntDictionary(w, _visitCounts));
    writer.writeProperty(
        "turnIndices", (w) => Json.writeIntDictionary(w, _turnIndices));

    writer.writePropertyNameInt("turnIdx", currentTurnIndex);
    writer.writePropertyNameInt("storySeed", storySeed);
    writer.writePropertyNameInt("previousRandom", previousRandom);

    writer.writePropertyNameInt("inkSaveVersion", kInkSaveStateVersion);

    // Not using this right now, but could do in future.
    writer.writePropertyNameInt("inkFormatVersion", Story.inkVersionCurrent);

    writer.writeObjectEnd();
  }

  void _loadJsonObj(Map<String, Object> jObject) {
    // Object jSaveVersion = null;
    if (!jObject.containsKey("inkSaveVersion")) {
      throw const FormatException("ink save format incorrect, can't load.");
    } else if ((jObject["inkSaveVersion"] as int) <
        _kMinCompatibleLoadVersion) {
      var jSaveVersion = jObject["inkSaveVersion"] as int;
      throw FormatException(
          "Ink save format isn't compatible with the current version (saw '$jSaveVersion', but minimum is $_kMinCompatibleLoadVersion), so can't load.");
    }

    // Flows: Always exists in latest format (even if there's just one default)
    // but this dictionary doesn't exist in prev format
    if (jObject.containsKey("flows")) {
      Object flowsObj = jObject["flows"]!;
      var flowsObjDict = flowsObj as Map<String, Object>;

      // Single default flow
      if (flowsObjDict.length == 1) {
        _namedFlows = null;
      } else if (_namedFlows == null) {
        _namedFlows = <String, Flow>{};
      } else {
        _namedFlows!.clear();
      }

      // Load up each flow (there may only be one)
      for (var namedFlowObj in flowsObjDict.entries) {
        var name = namedFlowObj.key;
        var flowObj = namedFlowObj.value as Map<String, Object>;

        // Load up this flow using JSON data
        var flow = Flow(name, story, jObject: flowObj);

        if (flowsObjDict.length == 1) {
          _currentFlow = Flow(name, story, jObject: flowObj);
        } else {
          _namedFlows![name] = flow;
        }
      }

      if (_namedFlows != null && _namedFlows!.length > 1) {
        var currFlowName = jObject["currentFlowName"] as String;
        _currentFlow = _namedFlows![currFlowName]!;
      }
    }

    // Old format: individually load up callstack, output stream, choices in current/default flow
    else {
      _namedFlows = null;
      _currentFlow.name = kDefaultFlowName;
      _currentFlow.callStack.setJsonToken(
          jObject["callstackThreads"] as Map<String, Object>, story);
      _currentFlow.outputStream =
          Json.jArrayToRuntimeObjList(jObject["outputStream"] as List<Object>);
      _currentFlow.currentChoices = Json.jArrayToRuntimeObjList<Choice>(
          jObject["currentChoices"] as List<Object>);

      Object? jChoiceThreadsObj;
      jChoiceThreadsObj = jObject["choiceThreads"];
      _currentFlow.loadFlowChoiceThreads(
          jChoiceThreadsObj as Map<String, Object>, story);
    }

    _outputStreamDirty();

    variablesState
        .setJsonToken(jObject["variablesState"] as Map<String, Object>);
    variablesState._callStack = _currentFlow.callStack;

    _evaluationStack =
        Json.jArrayToRuntimeObjList(jObject["evalStack"] as List<Object>);

    Object currentDivertTargetPath;
    if (jObject.containsKey("currentDivertTarget")) {
      currentDivertTargetPath = jObject["currentDivertTarget"]!;
      var divertPath = Path.fromString(currentDivertTargetPath.toString());
      divertedPointer = story.pointerAtPath(divertPath);
    }

    _visitCounts = Json.jObjectToIntDictionary(
        jObject["visitCounts"] as Map<String, Object>);
    _turnIndices = Json.jObjectToIntDictionary(
        jObject["turnIndices"] as Map<String, Object>);

    _currentTurnIndex = jObject["turnIdx"] as int;
    storySeed = jObject["storySeed"] as int;

    // Not optional, but bug in inkjs means it's actually missing in inkjs saves

    if (jObject.containsKey("previousRandom")) {
      Object previousRandomObj = jObject["previousRandom"]!;
      previousRandom = previousRandomObj as int;
    } else {
      previousRandom = 0;
    }
  }

  void resetErrors() {
    _currentErrors = null;
    _currentWarnings = null;
  }

  void resetOutput([List<InkObject?>? objs]) {
    outputStream.clear();
    if (objs != null) outputStream.addAll(objs);
    _outputStreamDirty();
  }

  // Push to output stream, but split out newlines in text for consistency
  // in dealing with them later.
  void pushToOutputStream(InkObject? obj) {
    var text = ConvertTo.stringValue(obj);
    if (text != null) {
      var listText = _trySplittingHeadTailWhitespace(text);
      if (listText != null) {
        for (var textObj in listText) {
          _pushToOutputStreamIndividual(textObj);
        }
        _outputStreamDirty();
        return;
      }
    }

    _pushToOutputStreamIndividual(obj);

    _outputStreamDirty();
  }

  void popFromOutputStream(int count) {
    outputStream.removeRange(outputStream.length - count, outputStream.length);
    _outputStreamDirty();
  }

  // At both the start and the end of the string, split out the new lines like so:
  //
  //  "   \n  \n     \n  the string \n is awesome \n     \n     "
  //      ^-----------^                           ^-------^
  //
  // Excess newlines are converted into single newlines, and spaces discarded.
  // Outside spaces are significant and retained. "Interior" newlines within
  // the main string are ignored, since this is for the purpose of gluing only.
  //
  //  - If no splitting is necessary, null is returned.
  //  - A newline on its own is returned in a list for consistency.
  List<StringValue>? _trySplittingHeadTailWhitespace(StringValue single) {
    String str = single.value;

    int headFirstNewlineIdx = -1;
    int headLastNewlineIdx = -1;
    for (int i = 0; i < str.length; i++) {
      int c = str[i].codeUnitAt(0);
      if (c == '\n'.codeUnitAt(0)) {
        if (headFirstNewlineIdx == -1) {
          headFirstNewlineIdx = i;
        }
        headLastNewlineIdx = i;
      } else if (c == ' '.codeUnitAt(0) || c == '\t'.codeUnitAt(0)) {
        continue;
      } else {
        break;
      }
    }

    int tailLastNewlineIdx = -1;
    int tailFirstNewlineIdx = -1;
    for (int i = str.length - 1; i >= 0; i--) {
      int c = str[i].codeUnitAt(0);
      if (c == '\n'.codeUnitAt(0)) {
        if (tailLastNewlineIdx == -1) {
          tailLastNewlineIdx = i;
        }
        tailFirstNewlineIdx = i;
      } else if (c == ' '.codeUnitAt(0) || c == '\t'.codeUnitAt(0)) {
        continue;
      } else {
        break;
      }
    }

    // No splitting to be done?
    if (headFirstNewlineIdx == -1 && tailLastNewlineIdx == -1) {
      return null;
    }

    var listTexts = <StringValue>[];
    int innerStrStart = 0;
    int innerStrEnd = str.length;

    if (headFirstNewlineIdx != -1) {
      if (headFirstNewlineIdx > 0) {
        var leadingSpaces = StringValue(str.substring(0, headFirstNewlineIdx));
        listTexts.add(leadingSpaces);
      }
      listTexts.add(StringValue("\n"));
      innerStrStart = headLastNewlineIdx + 1;
    }

    if (tailLastNewlineIdx != -1) {
      innerStrEnd = tailFirstNewlineIdx;
    }

    if (innerStrEnd > innerStrStart) {
      var innerStrText = str.substring(innerStrStart, innerStrEnd);
      listTexts.add(StringValue(innerStrText));
    }

    if (tailLastNewlineIdx != -1 && tailFirstNewlineIdx > headLastNewlineIdx) {
      listTexts.add(StringValue("\n"));
      if (tailLastNewlineIdx < str.length - 1) {
        int numSpaces = (str.length - tailLastNewlineIdx) - 1;
        var trailingSpaces = StringValue(str.substring(
            tailLastNewlineIdx + 1, tailLastNewlineIdx + 1 + numSpaces));
        listTexts.add(trailingSpaces);
      }
    }

    return listTexts;
  }

  void _pushToOutputStreamIndividual(InkObject? obj) {
    var glue = ConvertTo.glue(obj);
    var text = ConvertTo.stringValue(obj);

    bool includeInOutput = true;

    // New glue, so chomp away any whitespace from the end of the stream
    if (glue != null) {
      _trimNewlinesFromOutputStream();
      includeInOutput = true;
    }

    // New text: do we really want to append it, if it's whitespace?
    // Two different reasons for whitespace to be thrown away:
    //   - Function start/end trimming
    //   - User defined glue: <>
    // We also need to know when to stop trimming, when there's non-whitespace.
    else if (text != null) {
      // Where does the current function call begin?
      var functionTrimIndex = -1;
      var currEl = callStack.currentElement;
      if (currEl.type == PushPopType.Function) {
        functionTrimIndex = currEl.functionStartInOuputStream;
      }

      // Do 2 things:
      //  - Find latest glue
      //  - Check whether we're in the middle of string evaluation
      // If we're in string eval within the current function, we
      // don't want to trim back further than the length of the current string.
      int glueTrimIndex = -1;
      for (int i = outputStream.length - 1; i >= 0; i--) {
        var o = outputStream[i];
        var c = ConvertTo.controlCommand(o);
        var g = ConvertTo.glue(o);

        // Find latest glue
        if (g != null) {
          glueTrimIndex = i;
          break;
        }

        // Don't function-trim past the start of a string evaluation section
        else if (c != null && c.commandType == CommandType.beginString) {
          if (i >= functionTrimIndex) {
            functionTrimIndex = -1;
          }
          break;
        }
      }

      // Where is the most agressive (earliest) trim point?
      var trimIndex = -1;
      if (glueTrimIndex != -1 && functionTrimIndex != -1) {
        trimIndex = min(functionTrimIndex, glueTrimIndex);
      } else if (glueTrimIndex != -1) {
        trimIndex = glueTrimIndex;
      } else {
        trimIndex = functionTrimIndex;
      }

      // So, are we trimming then?
      if (trimIndex != -1) {
        // While trimming, we want to throw all newlines away,
        // whether due to glue or the start of a function
        if (text.isNewline) {
          includeInOutput = false;
        }

        // Able to completely reset when normal text is pushed
        else if (text.isNonWhitespace) {
          if (glueTrimIndex > -1) {
            _removeExistingGlue();
          }

          // Tell all functions in callstack that we have seen proper text,
          // so trimming whitespace at the start is done.
          if (functionTrimIndex > -1) {
            var callstackElements = callStack.elements;
            for (int i = callstackElements.length - 1; i >= 0; i--) {
              var el = callstackElements[i];
              if (el.type == PushPopType.Function) {
                el.functionStartInOuputStream = -1;
              } else {
                break;
              }
            }
          }
        }
      }

      // De-duplicate newlines, and don't ever lead with a newline
      else if (text.isNewline) {
        if (outputStreamEndsInNewline || !outputStreamContainsContent) {
          includeInOutput = false;
        }
      }
    }

    if (includeInOutput) {
      outputStream.add(obj);
      _outputStreamDirty();
    }
  }

  void _trimNewlinesFromOutputStream() {
    int removeWhitespaceFrom = -1;

    // Work back from the end, and try to find the point where
    // we need to start removing content.
    //  - Simply work backwards to find the first newline in a string of whitespace
    // e.g. This is the content   \n   \n\n
    //                            ^---------^ whitespace to remove
    //                        ^--- first while loop stops here
    int i = outputStream.length - 1;
    while (i >= 0) {
      var obj = outputStream[i];
      var cmd = ConvertTo.controlCommand(obj);
      var txt = ConvertTo.stringValue(obj);

      if (cmd != null || (txt != null && txt.isNonWhitespace)) {
        break;
      } else if (txt != null && txt.isNewline) {
        removeWhitespaceFrom = i;
      }
      i--;
    }

    // Remove the whitespace
    if (removeWhitespaceFrom >= 0) {
      i = removeWhitespaceFrom;
      while (i < outputStream.length) {
        var text = ConvertTo.stringValue(outputStream[i]);
        if (text != null) {
          outputStream.removeAt(i);
        } else {
          i++;
        }
      }
    }

    _outputStreamDirty();
  }

  // Only called when non-whitespace is appended
  void _removeExistingGlue() {
    for (int i = outputStream.length - 1; i >= 0; i--) {
      var c = outputStream[i];
      if (c is Glue) {
        outputStream.removeAt(i);
      } else if (c is ControlCommand) {
        // e.g. BeginString
        break;
      }
    }

    _outputStreamDirty();
  }

  bool get outputStreamEndsInNewline {
    if (outputStream.isNotEmpty) {
      for (int i = outputStream.length - 1; i >= 0; i--) {
        var obj = outputStream[i];
        if (obj is ControlCommand) {
          break;
        }
        var text = ConvertTo.stringValue(outputStream[i]);
        if (text != null) {
          if (text.isNewline) {
            return true;
          } else if (text.isNonWhitespace) {
            break;
          }
        }
      }
    }

    return false;
  }

  bool get outputStreamContainsContent {
    for (var content in outputStream) {
      if (content is StringValue) {
        return true;
      }
    }
    return false;
  }

  bool get inStringEvaluation {
    for (int i = outputStream.length - 1; i >= 0; i--) {
      var cmd = ConvertTo.controlCommand(outputStream[i]);
      if (cmd != null && cmd.commandType == CommandType.beginString) {
        return true;
      }
    }

    return false;
  }

  void pushEvaluationStack(InkObject? obj) {
    // Include metadata about the origin List for list values when
    // they're used, so that lower level functions can make use
    // of the origin list to get related items, or make comparisons
    // with the integer values etc.
    var listValue = ConvertTo.listValue(obj);
    if (listValue != null) {
      // Update origin when list is has something to indicate the list origin
      var rawList = listValue.value;
      if (rawList.originNames != null) {
        // rawList.origins;
        rawList.origins.clear();

        for (var n in rawList.originNames!) {
          ListDefinition? def = story.listDefinitions!.tryListGetDefinition(n);
          if (!rawList.origins.contains(def)) {
            rawList.origins.add(def);
          }
        }
      }
    }

    evaluationStack.add(obj);
  }

  InkObject? popEvaluationStack() {
    var obj = evaluationStack[evaluationStack.length - 1];
    evaluationStack.removeAt(evaluationStack.length - 1);
    return obj;
  }

  InkObject? peekEvaluationStack() {
    return evaluationStack[evaluationStack.length - 1];
  }

  List<InkObject?> popEvaluationStackNum(int numberOfObjects) {
    if (numberOfObjects > evaluationStack.length) {
      throw FormatException("trying to pop too many objects");
    }

    var popped = evaluationStack.getRange(
        evaluationStack.length - numberOfObjects, evaluationStack.length);
    evaluationStack.removeRange(
        evaluationStack.length - numberOfObjects, evaluationStack.length);
    return popped.toList();
  }

  /// <summary>
  /// Ends the current ink flow, unwrapping the callstack but without
  /// affecting any variables. Useful if the ink is (say) in the middle
  /// a nested tunnel, and you want it to reset so that you can divert
  /// elsewhere using ChoosePathString(). Otherwise, after finishing
  /// the content you diverted to, it would continue where it left off.
  /// Calling this is equivalent to calling -> END in ink.
  /// </summary>
  void forceEnd() {
    callStack.reset();

    _currentFlow.currentChoices.clear();

    currentPointer = Pointer.nullPointer;
    previousPointer = Pointer.nullPointer;

    didSafeExit = true;
  }

  // Add the end of a function call, trim any whitespace from the end.
  // We always trim the start and end of the text that a function produces.
  // The start whitespace is discard as it is generated, and the end
  // whitespace is trimmed in one go here when we pop the function.
  void _trimWhitespaceFromFunctionEnd() {
    assert(callStack.currentElement.type == PushPopType.Function);

    var functionStartPoint =
        callStack.currentElement.functionStartInOuputStream;

    // If the start point has become -1, it means that some non-whitespace
    // text has been pushed, so it's safe to go as far back as we're able.
    if (functionStartPoint == -1) {
      functionStartPoint = 0;
    }

    // Trim whitespace from END of function call
    for (int i = outputStream.length - 1; i >= functionStartPoint; i--) {
      var obj = outputStream[i];
      var txt = obj as StringValue;
      var cmd = obj as ControlCommand;
      if (txt == null) continue;
      if (cmd != null) break;

      if (txt.isNewline || txt.isInlineWhitespace) {
        outputStream.removeAt(i);
        _outputStreamDirty();
      } else {
        break;
      }
    }
  }

  void popCallstack([PushPopType? popType]) {
    // Add the end of a function call, trim any whitespace from the end.
    if (callStack.currentElement.type == PushPopType.Function) {
      _trimWhitespaceFromFunctionEnd();
    }

    callStack.pop(popType);
  }

  // Don't make since the method need to be wrapped in Story for visit counting
  void setChosenPath(Path path, bool incrementingTurnIndex) {
    // Changing direction, assume we need to clear current set of choices
    _currentFlow.currentChoices.clear();

    var newPointer = story.pointerAtPath(path);
    if (!newPointer.isNull && newPointer.index == -1) {
      newPointer.index = 0;
    }

    currentPointer = newPointer;

    if (incrementingTurnIndex) {
      _currentTurnIndex++;
    }
  }

  void startFunctionEvaluationFromGame(
      Container funcContainer, List<Object> arguments) {
    callStack.push(PushPopType.FunctionEvaluationFromGame,
        externalEvaluationStackHeight: evaluationStack.length);
    callStack.currentElement.currentPointer = Pointer.startOf(funcContainer);

    passArgumentsToEvaluationStack(arguments);
  }

  void passArgumentsToEvaluationStack(List<Object> arguments) {
    // Pass arguments onto the evaluation stack
    if (arguments != null) {
      for (int i = 0; i < arguments.length; i++) {
        if (!(arguments[i] is int ||
            arguments[i] is double ||
            arguments[i] is String ||
            arguments[i] is InkList)) {
          throw ArgumentException(
              "ink arguments when calling EvaluateFunction / ChoosePathStringWithParameters must be int, double, string or InkList. Argument was ${(arguments[i] == null ? "null" : arguments[i].runtimeType)}");
        }

        pushEvaluationStack(Value.create(arguments[i]));
      }
    }
  }

  bool tryExitFunctionEvaluationFromGame() {
    if (callStack.currentElement.type ==
        PushPopType.FunctionEvaluationFromGame) {
      currentPointer = Pointer.nullPointer;
      didSafeExit = true;
      return true;
    }

    return false;
  }

  Object? completeFunctionEvaluationFromGame() {
    if (callStack.currentElement.type !=
        PushPopType.FunctionEvaluationFromGame) {
      throw FormatException(
          "Expected external function evaluation to be complete. Stack trace: " +
              callStack.callStackTrace);
    }

    int originalEvaluationStackHeight =
        callStack.currentElement.evaluationStackHeightWhenPushed;

    // Do we have a returned value?
    // Potentially pop multiple values off the stack, in case we need
    // to clean up after ourselves (e.g. caller of EvaluateFunction may
    // have passed too many arguments, and we currently have no way to check for that)
    InkObject? returnedObj;
    while (evaluationStack.length > originalEvaluationStackHeight) {
      var poppedObj = popEvaluationStack();
      returnedObj ??= poppedObj;
    }

    // Finally, pop the external function evaluation
    popCallstack(PushPopType.FunctionEvaluationFromGame);

    // What did we get back?
    if (returnedObj != null) {
      if (returnedObj is Void) {
        return null;
      }

      // Some kind of value, if not void
      var returnVal = returnedObj as Value;

      // DivertTargets get returned as the string of components
      // (rather than a Path, which isn't public)
      if (returnVal.valueType == ValueType.iDivertTarget) {
        return returnVal.valueObject.toString();
      }

      // Other types can just have their exact object type:
      // int, float, string. VariablePointers get returned as strings.
      return returnVal.valueObject;
    }

    return null;
  }

  void addError(String message, bool isWarning) {
    if (!isWarning) {
      _currentErrors ??= <String>[];
      _currentErrors!.add(message);
    } else {
      _currentWarnings ??= <String>[];
      _currentWarnings!.add(message);
    }
  }

  void _outputStreamDirty() {
    _outputStreamTextDirty = true;
    _outputStreamTagsDirty = true;
  }

  // REMEMBER! REMEMBER! REMEMBER!
  // When adding state, update the Copy method and serialisation
  // REMEMBER! REMEMBER! REMEMBER!

  late Map<String, int> _visitCounts;
  late Map<String, int> _turnIndices;
  bool _outputStreamTextDirty = true;
  bool _outputStreamTagsDirty = true;

  StatePatch? _patch;

  late Flow _currentFlow;
  Map<String?, Flow>? _namedFlows;
  static const String kDefaultFlowName = "DEFAULT_FLOW";
}
