part of inky;

class CallStack {
  List<Element> get elements => _callStack;

  int get depth => elements.length;

  Element get currentElement {
    var thread = _threads[_threads.length - 1];
    var cs = thread.callstack;
    return cs[cs.length - 1];
  }

  int get currentElementIndex => _callStack.length - 1;

  Thread get currentThread => _threads[_threads.length - 1];
  set currentThread(Thread value) {
    assert(_threads.length == 1,
        "Shouldn't be directly setting the current thread when we have a stack of them");
    _threads.clear();
    _threads.add(value);
  }

  bool get canPop => _callStack.length > 1;

  CallStack(Story storyContext) {
    _startOfRoot = Pointer.startOf(storyContext.rootContentContainer);
    reset();
  }

  CallStack.from(CallStack toCopy) {
    _threads = <Thread>[];
    for (var otherThread in toCopy._threads) {
      _threads.add(otherThread.copy());
    }
    _threadCounter = toCopy._threadCounter;
    _startOfRoot = toCopy._startOfRoot;
  }

  void reset() {
    _threads = <Thread>[];
    _threads.add(Thread());

    _threads[0].callstack.add(Element(PushPopType.Tunnel, _startOfRoot));
  }

  // Unfortunately it's not possible to implement jsonToken since
  // the setter needs to take a Story as a context in order to
  // look up objects from paths for currentContainer within elements.
  void setJsonToken(Map<String, Object> jObject, Story storyContext) {
    _threads.clear();

    var jThreads = jObject["threads"] as List<Object>;

    for (Object jThreadTok in jThreads) {
      var jThreadObj = jThreadTok as Map<String, Object>;
      var thread = Thread.from(jThreadObj, storyContext);
      _threads.add(thread);
    }

    _threadCounter = jObject["threadCounter"] as int;
    _startOfRoot = Pointer.startOf(storyContext.rootContentContainer);
  }

  void writeJson(Writer w) {
    w.writeObject((writer) {
      writer.writePropertyStart("threads");
      {
        writer.writeArrayStart();

        for (Thread thread in _threads) {
          thread.writeJson(writer);
        }

        writer.writeArrayEnd();
      }
      writer.writePropertyEnd();

      writer.writePropertyStart("threadCounter");
      {
        writer.writeInt(_threadCounter);
      }
      writer.writePropertyEnd();
    });
  }

  void pushThread() {
    var newThread = currentThread.copy();
    _threadCounter++;
    newThread.threadIndex = _threadCounter;
    _threads.add(newThread);
  }

  Thread forkThread() {
    var forkedThread = currentThread.copy();
    _threadCounter++;
    forkedThread.threadIndex = _threadCounter;
    return forkedThread;
  }

  void popThread() {
    if (canPopThread) {
      _threads.remove(currentThread);
    } else {
      throw const FormatException("Can't pop thread");
    }
  }

  bool get canPopThread => _threads.length > 1 && !elementIsEvaluateFromGame;

  bool get elementIsEvaluateFromGame =>
      currentElement.type == PushPopType.FunctionEvaluationFromGame;

  void push(PushPopType type,
      {int externalEvaluationStackHeight = 0,
      int outputStreamLengthWithPushed = 0}) {
    // When pushing to callstack, maintain the current content path, but jump out of expressions by default
    var element = Element(type, currentElement.currentPointer,
        inExpressionEvaluation: false);

    element.evaluationStackHeightWhenPushed = externalEvaluationStackHeight;
    element.functionStartInOuputStream = outputStreamLengthWithPushed;

    _callStack.add(element);
  }

  bool CanPop([PushPopType? type]) {
    if (!canPop) {
      return false;
    }

    if (type == null) {
      return true;
    }

    return currentElement.type == type;
  }

  void pop([PushPopType? type]) {
    if (CanPop(type)) {
      _callStack.removeAt(_callStack.length - 1);
      return;
    } else {
      throw const FormatException("Mismatched push/pop in Callstack");
    }
  }

  // Get variable value, dereferencing a variable pointer if necessary
  InkObject? getTemporaryVariableWithName(String? name,
      [int contextIndex = -1]) {
    if (contextIndex == -1) {
      contextIndex = currentElementIndex + 1;
    }

    var contextElement = _callStack[contextIndex - 1];

    if (contextElement.temporaryVariables.containsKey(name)) {
      return contextElement.temporaryVariables[name];
    } else {
      return null;
    }
  }

  void setTemporaryVariable(String? name, InkObject? value, bool declareNew,
      [int contextIndex = -1]) {
    if (contextIndex == -1) {
      contextIndex = currentElementIndex + 1;
    }

    var contextElement = _callStack[contextIndex - 1];

    if (!declareNew && !contextElement.temporaryVariables.containsKey(name)) {
      throw FormatException("Could not find temporary variable to set: $name");
    }

    if (contextElement.temporaryVariables.containsKey(name)) {
      InkObject oldValue = contextElement.temporaryVariables[name]!;
      ListValue.retainListOriginsForAssignment(oldValue, value);
    }

    contextElement.temporaryVariables[name] = value;
  }

  // Find the most appropriate context for this variable.
  // Are we referencing a temporary or global variable?
  // Note that the compiler will have warned us about possible conflicts,
  // so anything that happens here should be safe!
  int contextForVariableNamed(String name) {
    // Current temporary context?
    // (Shouldn't attempt to access contexts higher in the callstack.)
    if (currentElement.temporaryVariables.containsKey(name)) {
      return currentElementIndex + 1;
    }

    // Global
    else {
      return 0;
    }
  }

  Thread threadWithIndex(int index) {
    return _threads.firstWhere((t) => t.threadIndex == index);
  }

  List<Element> get _callStack => currentThread.callstack;

  String get callStackTrace {
    var sb = StringBuffer();

    for (int t = 0; t < _threads.length; t++) {
      var thread = _threads[t];
      var isCurrent = (t == _threads.length - 1);
      sb.write(
          "=== THREAD ${(t + 1)}/${_threads.length} ${(isCurrent ? "(current) " : "")}===\n");

      for (int i = 0; i < thread.callstack.length; i++) {
        if (thread.callstack[i].type == PushPopType.Function) {
          sb.write("  [FUNCTION] ");
        } else {
          sb.write("  [TUNNEL] ");
        }

        var pointer = thread.callstack[i].currentPointer;
        if (!pointer.isNull) {
          sb.write("<SOMEWHERE IN ");
          sb.write(pointer.container!.path.toString());
          sb.writeln(">");
        }
      }
    }

    return sb.toString();
  }

  List<Thread> _threads = <Thread>[];
  int _threadCounter = 0;
  Pointer _startOfRoot = Pointer();
}

class Element {
  Pointer currentPointer = Pointer();

  bool inExpressionEvaluation = false;
  late Map<String?, InkObject?> temporaryVariables;
  late PushPopType type = PushPopType.Tunnel;

  // When this callstack element is actually a function evaluation called from the game,
  // we need to keep track of the size of the evaluation stack when it was called
  // so that we know whether there was any return value.
  int evaluationStackHeightWhenPushed = 0;

  // When functions are called, we trim whitespace from the start and end of what
  // they generate, so we make sure know where the function's start and end are.
  int functionStartInOuputStream = 0;

  Element(PushPopType type, Pointer pointer,
      {bool inExpressionEvaluation = false}) {
    currentPointer = pointer;
    inExpressionEvaluation = inExpressionEvaluation;
    temporaryVariables = <String, InkObject>{};
    type = type;
  }

  Element copy() {
    var copy = Element(type, currentPointer,
        inExpressionEvaluation: inExpressionEvaluation);
    copy.temporaryVariables = <String?, InkObject?>{...temporaryVariables};
    copy.evaluationStackHeightWhenPushed = evaluationStackHeightWhenPushed;
    copy.functionStartInOuputStream = functionStartInOuputStream;
    return copy;
  }
}

class Thread {
  List<Element> callstack = <Element>[];
  int threadIndex = 0;
  Pointer previousPointer = Pointer();

  Thread();

  Thread.from(Map<String, Object> jThreadObj, Story storyContext) {
    threadIndex = jThreadObj["threadIndex"] as int;

    List<Object> jThreadCallstack = jThreadObj["callstack"] as List<Object>;

    for (Object jElTok in jThreadCallstack) {
      var jElementObj = jElTok as Map<String, Object>;

      PushPopType pushPopType = (jElementObj["type"] as int) as PushPopType;

      Pointer pointer = Pointer.nullPointer;

      String? currentContainerPathStr;
      Object? currentContainerPathStrToken = jElementObj["cPath"];

      if (jElementObj.containsKey("cPath")) {
        currentContainerPathStr = currentContainerPathStrToken.toString();

        var threadPointerResult = storyContext
            .contentAtPath(Path.fromString(currentContainerPathStr));
        pointer.container = threadPointerResult.container;
        pointer.index = jElementObj["idx"] as int;

        if (threadPointerResult.obj == null) {
          throw FormatException(
              "When loading state, internal story location couldn't be found: $currentContainerPathStr. Has the story changed since this save data was created?");
        } else if (threadPointerResult.approximate) {
          storyContext.warning(
              "When loading state, exact internal story location couldn't be found: '$currentContainerPathStr', so it was approximated to '${pointer.container!.path}' to recover. Has the story changed since this save data was created?");
        }
      }

      bool inExpressionEvaluation = jElementObj["exp"] as bool;

      var el = Element(pushPopType, pointer,
          inExpressionEvaluation: inExpressionEvaluation);

      Object? temps = jElementObj["temp"];
      if (jElementObj.containsKey("temp")) {
        el.temporaryVariables =
            Json.jObjectToDictionaryRuntimeObjs(temps as Map<String, Object>);
      } else {
        el.temporaryVariables.clear();
      }

      callstack.add(el);
    }

    Object? prevContentObjPath = jThreadObj["previousContentObject"];
    if (jThreadObj.containsKey("previousContentObject")) {
      var prevPath = Path.fromString(prevContentObjPath as String);
      previousPointer = storyContext.pointerAtPath(prevPath);
    }
  }

  Thread copy() {
    var copy = Thread();
    copy.threadIndex = threadIndex;
    for (var e in callstack) {
      copy.callstack.add(e.copy());
    }
    copy.previousPointer = previousPointer;
    return copy;
  }

  void writeJson(Writer writer) {
    writer.writeObjectStart();

    // callstack
    writer.writePropertyStart("callstack");
    writer.writeArrayStart();
    for (Element el in callstack) {
      writer.writeObjectStart();
      if (!el.currentPointer.isNull) {
        writer.writePropertyNameString(
            "cPath", el.currentPointer.container!.path!.componentsString);
        writer.writePropertyNameInt("idx", el.currentPointer.index);
      }

      writer.writePropertyNameBool("exp", el.inExpressionEvaluation);
      writer.writePropertyNameInt("type", el.type as int);

      if (el.temporaryVariables.isNotEmpty) {
        writer.writePropertyStart("temp");
        Json.writeDictionaryRuntimeObjs(
            writer, el.temporaryVariables.cast<String, InkObject>());
        writer.writePropertyEnd();
      }

      writer.writeObjectEnd();
    }
    writer.writeArrayEnd();
    writer.writePropertyEnd();

    // threadIndex
    writer.writePropertyNameInt("threadIndex", threadIndex);

    if (!previousPointer.isNull) {
      writer.writePropertyNameString(
          "previousContentObject", previousPointer.resolve()!.path.toString());
    }

    writer.writeObjectEnd();
  }
}
