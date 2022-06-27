part of inky;

/// <summary>
/// A Story is the core class that represents a complete Ink narrative, and
/// manages the evaluation and state of it.
/// </summary>
class Story extends InkObject {
  /// <summary>
  /// The current version of the ink story file format.
  /// </summary>
  static const int inkVersionCurrent = 20;

  // Version numbers are for engine itself and story file, rather
  // than the story state save format
  //  -- old engine, format: always fail
  //  -- engine, old format: possibly cope, based on this number
  // When incrementing the version number above, the question you
  // should ask yourself is:
  //  -- Will the engine be able to load an old story file from
  //     before I made these changes to the engine?
  //     If possible, you should support it, though it's not as
  //     critical as loading old save games, since it's an
  //     in-development problem only.

  /// <summary>
  /// The minimum legacy version of ink that can be loaded by the current version of the code.
  /// </summary>
  static const int inkVersionMinimumCompatible = 18;

  /// <summary>
  /// The list of Choice objects available at the current point in
  /// the Story. This list will be populated as the Story is stepped
  /// through with the Continue() method. Once canContinue becomes
  /// false, this list will be populated, and is usually
  /// (but not always) on the final Continue() step.
  /// </summary>
  List<Choice> get currentChoices {
    // Don't include invisible choices for external usage.
    var choices = <Choice>[];
    for (var c in _state.currentChoices) {
      if (!c.isInvisibleDefault) {
        c.index = choices.length;
        choices.add(c);
      }
    }
    return choices;
  }

  /// <summary>
  /// The latest line of text to be generated from a Continue() call.
  /// </summary>
  String get currentText {
    _ifAsyncWeCant("call currentText since it's a work in progress");
    return state.currentText;
  }

  /// <summary>
  /// Gets a list of tags as defined with '#' in source that were seen
  /// during the latest Continue() call.
  /// </summary>
  List<String> get currentTags {
    _ifAsyncWeCant("call currentTags since it's a work in progress");
    return state.currentTags;
  }

  /// <summary>
  /// Any errors generated during evaluation of the Story.
  /// </summary>
  List<String>? get currentErrors => state.currentErrors;

  /// <summary>
  /// Any warnings generated during evaluation of the Story.
  /// </summary>
  List<String>? get currentWarnings => state.currentWarnings;

  /// <summary>
  /// The current flow name if using multi-flow funtionality - see SwitchFlow
  /// </summary>
  String? get currentFlowName => state.currentFlowName;

  /// <summary>
  /// Whether the currentErrors list contains any errors.
  /// THIS MAY BE REMOVED - you should be setting an error handler directly
  /// using Story.onError.
  /// </summary>
  bool get hasError => state.hasError;

  /// <summary>
  /// Whether the currentWarnings list contains any warnings.
  /// </summary>
  bool get hasWarning => state.hasWarning;

  /// <summary>
  /// The VariablesState object contains all the global variables in the story.
  /// However, note that there's more to the state of a Story than just the
  /// global variables. This is a convenience accessor to the full state object.
  /// </summary>
  VariablesState get variablesState => state.variablesState;

  ListDefinitionsOrigin? get listDefinitions => _listDefinitions;

  /// <summary>
  /// The entire current state of the story including (but not limited to):
  ///
  ///  * Global variables
  ///  * Temporary variables
  ///  * Read/visit and turn counts
  ///  * The callstack and evaluation stacks
  ///  * The current threads
  ///
  /// </summary>
  StoryState get state => _state;

  /// <summary>
  /// Error handler for all runtime errors in ink - i.e. problems
  /// with the source ink itself that are only discovered when playing
  /// the story.
  /// It's strongly recommended that you assign an error handler to your
  /// story instance to avoid getting exceptions for ink errors.
  /// </summary>
  final Event<ErrorHandlerEventArg> onError = Event<ErrorHandlerEventArg>();

  /// <summary>
  /// Callback for when ContinueInternal is complete
  /// </summary>
  Event onDidContinue = Event();

  /// <summary>
  /// Callback for when a choice is about to be executed
  /// </summary>
  Event<ChoiceEventArg> onMakeChoice = Event();

  /// <summary>
  /// Callback for when a function is about to be evaluated
  /// </summary>
  Event<StringObjectListEventArgs> onEvaluateFunction = Event();

  /// <summary>
  /// Callback for when a function has been evaluated
  /// This is necessary because evaluating a function can cause continuing
  /// </summary>
  Event<StringObjectListStringObjectEventArgs> onCompleteEvaluateFunction =
      Event();

  /// <summary>
  /// Callback for when a path String is chosen
  /// </summary>
  Event<StringObjectListEventArgs> onChoosePathString = Event();

  /// <summary>
  /// Start recording ink profiling information during calls to Continue on Story.
  /// Return a Profiler instance that you can request a report from when you're finished.
  /// </summary>
  Profiler startProfiling() {
    _ifAsyncWeCant("start profiling");
    _profiler = Profiler();
    return _profiler!;
  }

  /// <summary>
  /// Stop recording ink profiling information during calls to Continue on Story.
  /// To generate a report from the profiler, call
  /// </summary>
  void endProfiling() {
    _profiler = null;
  }

  // Warning: When creating a Story using this constructor, you need to
  // call ResetState on it before use. Intended for compiler use only.
  // For normal use, use the constructor that takes a json string.
  Story.fromContainer(Container? contentContainer,
      [List<ListDefinition>? lists]) {
    Initialize(contentContainer, lists);
  }

  void Initialize(Container? contentContainer, [List<ListDefinition>? lists]) {
    _mainContentContainer = contentContainer;

    if (lists != null) {
      _listDefinitions = ListDefinitionsOrigin(lists);
    }

    _externals = <String, ExternalFunctionDef>{};
  }

  /// <summary>
  /// Construct a Story object using a JSON String compiled through inklecate.
  /// </summary>
  Story.fromJson(String jsonString) {
    Initialize(null);

    Map<String, Object> rootObject = SimpleJson.textToDictionary(jsonString);

    Object? versionObj = rootObject["inkVersion"];
    if (versionObj == null) {
      throw const FormatException(
          "ink version number not found. Are you sure it's a valid .ink.json file?");
    }

    int formatFromFile = versionObj as int;
    if (formatFromFile > inkVersionCurrent) {
      throw const FormatException(
          "Version of ink used to build story was newer than the current version of the engine");
    } else if (formatFromFile < inkVersionMinimumCompatible) {
      throw const FormatException(
          "Version of ink used to build story is too old to be loaded by this version of the engine");
    } else if (formatFromFile != inkVersionCurrent) {
      print(
          "WARNING: Version of ink used to build story doesn't match current version of engine. Non-critical, but recommend synchronising.");
    }

    var rootToken = rootObject["root"];
    if (rootToken == null) {
      throw const FormatException(
          "Root node for ink not found. Are you sure it's a valid .ink.json file?");
    }

    if (rootObject.containsKey("listDefs")) {
      Object listDefsObj = rootObject["listDefs"]!;
      _listDefinitions = Json.jTokenToListDefinitions(listDefsObj);
    }

    _mainContentContainer = Json.jTokenToRuntimeObject(rootToken) as Container;

    resetState();
  }

  /// <summary>
  /// The Story itself in JSON representation.
  /// </summary>
  String toJson() {
    //return ToJsonOld();
    var writer = Writer();
    _toJson(writer);
    return writer.toString();
  }

  /// <summary>
  /// The Story itself in JSON representation.
  /// </summary>
  void toJsonFrom(Stream stream) {
    throw UnimplementedError("toJsonFrom Stream not implemented");
    // // var writer = Writer.fromStream(stream);
    // _toJson(writer);
  }

  void _toJson(Writer writer) {
    writer.writeObjectStart();

    writer.writePropertyNameInt("inkVersion", inkVersionCurrent);

    // Main container content
    writer.writeProperty(
        "root", (w) => Json.writeRuntimeContainer(w, _mainContentContainer!));

    // List definitions
    if (_listDefinitions != null) {
      writer.writePropertyStart("listDefs");
      writer.writeObjectStart();

      for (ListDefinition def in _listDefinitions!.lists) {
        writer.writePropertyStart(def.name);
        writer.writeObjectStart();

        for (var itemToVal in def.items.entries) {
          InkListItem item = itemToVal.key;
          int val = itemToVal.value;
          writer.writePropertyNameInt(item.itemName!, val);
        }

        writer.writeObjectEnd();
        writer.writePropertyEnd();
      }

      writer.writeObjectEnd();
      writer.writePropertyEnd();
    }

    writer.writeObjectEnd();
  }

  /// <summary>
  /// Reset the Story back to its initial state as it was when it was
  /// first constructed.
  /// </summary>
  void resetState() {
    // TODO: Could make this possible
    _ifAsyncWeCant("ResetState");

    _state = StoryState(this);
    _state.variablesState.variableChangedEvent
        .subscribe(_variableStateDidChangeEvent);

    _resetGlobals();
  }

  void _resetErrors() {
    _state.resetErrors();
  }

  /// <summary>
  /// Unwinds the callstack. Useful to reset the Story's evaluation
  /// without actually changing any meaningful state, for example if
  /// you want to exit a section of story prematurely and tell it to
  /// go elsewhere with a call to ChoosePathString(...).
  /// Doing so without calling ResetCallstack() could cause unexpected
  /// issues if, for example, the Story was in a tunnel already.
  /// </summary>
  void resetCallstack() {
    _ifAsyncWeCant("ResetCallstack");

    _state.forceEnd();
  }

  void _resetGlobals() {
    if (_mainContentContainer!.namedContent.containsKey("global decl")) {
      var originalPointer = state.currentPointer;

      choosePath(Path.fromString("global decl"), false);

      // Continue, but without validating external bindings,
      // since we may be doing this reset at initialisation time.
      _continueInternal();

      state.currentPointer = originalPointer;
    }

    state.variablesState.snapshotDefaultGlobals();
  }

  void switchFlow(String flowName) {
    _ifAsyncWeCant("switch flow");
    if (_asyncSaving) {
      throw FormatException(
          "Story is already in background saving mode, can't switch flow to $flowName");
    }

    state._switchFlow_Internal(flowName);
  }

  void removeFlow(String flowName) {
    state._removeFlow_Internal(flowName);
  }

  void switchToDefaultFlow() {
    state._switchToDefaultFlow_Internal();
  }

  /// <summary>
  /// Continue the story for one line of content, if possible.
  /// If you're not sure if there's more content available, for example if you
  /// want to check whether you're at a choice point or at the end of the story,
  /// you should call <c>canContinue</c> before calling this function.
  /// </summary>
  /// <returns>The line of text content.</returns>
  String Continue() {
    continueAsync(0);
    return currentText;
  }

  /// <summary>
  /// Check whether more content is available if you were to call <c>Continue()</c> - i.e.
  /// are we mid story rather than at a choice point or at the end.
  /// </summary>
  /// <value><c>true</c> if it's possible to call <c>Continue()</c>.</value>
  bool get canContinue => state.canContinue;

  /// <summary>
  /// If ContinueAsync was called (with milliseconds limit > 0) then this property
  /// will return false if the ink evaluation isn't yet finished, and you need to call
  /// it again in order for the Continue to fully complete.
  /// </summary>
  bool get asyncContinueComplete => !_asyncContinueActive;

  /// <summary>
  /// An "asnychronous" version of Continue that only partially evaluates the ink,
  /// with a budget of a certain time limit. It will exit ink evaluation early if
  /// the evaluation isn't complete within the time limit, with the
  /// asyncContinueComplete property being false.
  /// This is useful if ink evaluation takes a long time, and you want to distribute
  /// it over multiple game frames for smoother animation.
  /// If you pass a limit of zero, then it will fully evaluate the ink in the same
  /// way as calling Continue (and in fact, this exactly what Continue does internally).
  /// </summary>
  void continueAsync(double millisecsLimitAsync) {
    if (!_hasValidatedExternals) {
      _validateExternalBindings();
    }

    _continueInternal(millisecsLimitAsync);
  }

  void _continueInternal([double millisecsLimitAsync = 0]) {
    if (_profiler != null) {
      _profiler!.preContinue();
    }

    var isAsyncTimeLimited = millisecsLimitAsync > 0;

    _recursiveContinueCount++;

    // Doing either:
    //  - full run through non-async (so not active and don't want to be)
    //  - Starting async run-through
    if (!_asyncContinueActive) {
      _asyncContinueActive = isAsyncTimeLimited;

      if (!canContinue) {
        throw Exception(
            "Can't continue - should check canContinue before calling Continue");
      }

      _state.didSafeExit = false;
      _state.resetOutput();

      // It's possible for ink to call game to call ink to call game etc
      // In this case, we only want to batch observe variable changes
      // for the outermost call.
      if (_recursiveContinueCount == 1) {
        _state.variablesState.batchObservingVariableChanges = true;
      }
    }

    // Start timing
    var durationStopwatch = Stopwatch();
    durationStopwatch.start();

    bool outputStreamEndsInNewline = false;
    _sawLookaheadUnsafeFunctionAfterNewline = false;
    do {
      try {
        outputStreamEndsInNewline = _continueSingleStep();
      } on StoryException catch (e) {
        _addError(e.msg, useEndLineNumber: e.useEndLineNumber);
        break;
      }

      if (outputStreamEndsInNewline) {
        break;
      }

      // Run out of async time?
      if (_asyncContinueActive &&
          durationStopwatch.elapsedMilliseconds > millisecsLimitAsync) {
        break;
      }
    } while (canContinue);

    durationStopwatch.stop();

    // 4 outcomes:
    //  - got newline (so finished this line of text)
    //  - can't continue (e.g. choices or ending)
    //  - ran out of time during evaluation
    //  - error
    //
    // Successfully finished evaluation in time (or in error)
    if (outputStreamEndsInNewline || !canContinue) {
      // Need to rewind, due to evaluating further than we should?
      if (_stateSnapshotAtLastNewline != null) {
        _restoreStateSnapshot();
      }

      // Finished a section of content / reached a choice point?
      if (!canContinue) {
        if (state.callStack.canPopThread) {
          _addError(
              "Thread available to pop, threads should always be flat by the end of evaluation?");
        }

        if (state.generatedChoices.isEmpty &&
            !state.didSafeExit &&
            _temporaryEvaluationContainer == null) {
          if (state.callStack.CanPop(PushPopType.Tunnel)) {
            _addError(
                "unexpectedly reached end of content. Do you need a '->->' to return from a tunnel?");
          } else if (state.callStack.CanPop(PushPopType.Function)) {
            _addError(
                "unexpectedly reached end of content. Do you need a '~ return'?");
          } else if (!state.callStack.canPop) {
            _addError(
                "ran out of content. Do you need a '-> DONE' or '-> END'?");
          } else {
            _addError(
                "unexpectedly reached end of content for unknown reason. Please debug compiler!");
          }
        }
      }

      state.didSafeExit = false;
      _sawLookaheadUnsafeFunctionAfterNewline = false;

      if (_recursiveContinueCount == 1) {
        _state.variablesState.batchObservingVariableChanges = false;
      }

      _asyncContinueActive = false;
      onDidContinue.broadcast();
    }

    _recursiveContinueCount--;

    if (_profiler != null) {
      _profiler!.postContinue();
    }

    // Report any errors that occured during evaluation.
    // This may either have been StoryExceptions that were thrown
    // and caught during evaluation, or directly added with AddError.
    if (state.hasError || state.hasWarning) {
      if (onError != null) {
        if (state.hasError) {
          for (var err in state.currentErrors!) {
            onError.broadcast(ErrorHandlerEventArg(err, ErrorType.error));
          }
        }
        if (state.hasWarning) {
          for (var err in state.currentWarnings!) {
            onError.broadcast(ErrorHandlerEventArg(err, ErrorType.warning));
          }
        }
        _resetErrors();
      }

      // Throw an exception since there's no error handler
      else {
        var sb = StringBuffer();
        sb.write("Ink had ");
        if (state.hasError) {
          sb.write(state.currentErrors!.length);
          sb.write(state.currentErrors!.length == 1 ? " error" : " errors");
          if (state.hasWarning) sb.write(" and ");
        }
        if (state.hasWarning) {
          sb.write(state.currentWarnings!.length);
          sb.write(
              state.currentWarnings!.length == 1 ? " warning" : " warnings");
        }
        sb.write(
            ". It is strongly suggested that you assign an error handler to story.onError. The first issue was: ");
        sb.write(state.hasError
            ? state.currentErrors![0]
            : state.currentWarnings![0]);

        // If you get this exception, please assign an error handler to your story.
        // If you're using Unity, you can do something like this when you create
        // your story:
        //
        // var story = Ink.Story(jsonTxt);
        // story.onError = (errorMessage, errorType) => {
        //     if( errorType == ErrorType.Warning )
        //         Debug.LogWarning(errorMessage);
        //     else
        //         Debug.LogError(errorMessage);
        // };
        //
        //
        throw StoryException(sb.toString());
      }
    }
  }

  bool _continueSingleStep() {
    if (_profiler != null) {
      _profiler!.preStep();
    }

    // Run main step function (walks through content)
    _step();

    if (_profiler != null) {
      _profiler!.postStep();
    }

    // Run out of content and we have a default invisible choice that we can follow?
    if (!canContinue && !state.callStack.elementIsEvaluateFromGame) {
      _tryFollowDefaultInvisibleChoice();
    }

    if (_profiler != null) {
      _profiler!.preSnapshot();
    }

    // Don't save/rewind during String evaluation, which is e.g. used for choices
    if (!state.inStringEvaluation) {
      // We previously found a newline, but were we just double checking that
      // it wouldn't immediately be removed by glue?
      if (_stateSnapshotAtLastNewline != null) {
        // Has proper text or a tag been added? Then we know that the newline
        // that was previously added is definitely the end of the line.
        var change = _calculateNewlineOutputStateChange(
            _stateSnapshotAtLastNewline!.currentText,
            state.currentText,
            _stateSnapshotAtLastNewline!.currentTags.length,
            state.currentTags.length);

        // The last time we saw a newline, it was definitely the end of the line, so we
        // want to rewind to that point.
        if (change == OutputStateChange.ExtendedBeyondNewline ||
            _sawLookaheadUnsafeFunctionAfterNewline) {
          _restoreStateSnapshot();

          // Hit a newline for sure, we're done
          return true;
        }

        // Newline that previously existed is no longer valid - e.g.
        // glue was encounted that caused it to be removed.
        else if (change == OutputStateChange.NewlineRemoved) {
          _discardSnapshot();
        }
      }

      // Current content ends in a newline - approaching end of our evaluation
      if (state.outputStreamEndsInNewline) {
        // If we can continue evaluation for a bit:
        // Create a snapshot in case we need to rewind.
        // We're going to continue stepping in case we see glue or some
        // non-text content such as choices.
        if (canContinue) {
          // Don't bother to record the state beyond the current newline.
          // e.g.:
          // Hello world\n            // record state at the end of here
          // ~ complexCalculation()   // don't actually need this unless it generates text
          if (_stateSnapshotAtLastNewline == null) {
            _stateSnapshot();
          }
        }

        // Can't continue, so we're about to exit - make sure we
        // don't have an old state hanging around.
        else {
          _discardSnapshot();
        }
      }
    }

    if (_profiler != null) {
      _profiler!.postSnapshot();
    }

    // outputStreamEndsInNewline = false
    return false;
  }

  // Assumption: prevText is the snapshot where we saw a newline, and we're checking whether we're really done
  //             with that line. Therefore prevText will definitely end in a newline.
  //
  // We take tags into account too, so that a tag following a content line:
  //   Content
  //   # tag
  // ... doesn't cause the tag to be wrongly associated with the content above.

  OutputStateChange _calculateNewlineOutputStateChange(
      String prevText, String currText, int prevTagCount, int currTagCount) {
    // Simple case: nothing's changed, and we still have a newline
    // at the end of the current content
    var newlineStillExists = currText.length >= prevText.length &&
        currText[prevText.length - 1] == '\n';
    if (prevTagCount == currTagCount &&
        prevText.length == currText.length &&
        newlineStillExists) {
      return OutputStateChange.NoChange;
    }

    // Old newline has been removed, it wasn't the end of the line after all
    if (!newlineStillExists) {
      return OutputStateChange.NewlineRemoved;
    }

    // Tag added - definitely the start of a line
    if (currTagCount > prevTagCount) {
      return OutputStateChange.ExtendedBeyondNewline;
    }

    // There must be content - check whether it's just whitespace
    for (int i = prevText.length; i < currText.length; i++) {
      var c = currText[i].codeUnitAt(0);
      if (c != ' '.codeUnitAt(0) && c != '\t'.codeUnitAt(0)) {
        return OutputStateChange.ExtendedBeyondNewline;
      }
    }

    // There's text but it's just spaces and tabs, so there's still the potential
    // for glue to kill the newline.
    return OutputStateChange.NoChange;
  }

  /// <summary>
  /// Continue the story until the next choice point or until it runs out of content.
  /// This is as opposed to the Continue() method which only evaluates one line of
  /// output at a time.
  /// </summary>
  /// <returns>The resulting text evaluated by the ink engine, concatenated together.</returns>
  String continueMaximally() {
    _ifAsyncWeCant("ContinueMaximally");

    var sb = StringBuffer();

    while (canContinue) {
      sb.write(Continue());
    }

    return sb.toString();
  }

  SearchResult contentAtPath(Path path) {
    return mainContentContainer!.contentAtPath(path);
  }

  Container? knotContainerWithName(String? name) {
    INamedContent? namedContainer = mainContentContainer!.namedContent[name];
    if (mainContentContainer!.namedContent.containsKey(name)) {
      return namedContainer as Container;
    } else {
      return null;
    }
  }

  Pointer pointerAtPath(Path path) {
    if (path.length == 0) {
      return Pointer.nullPointer;
    }

    var p = Pointer();

    int pathLengthToUse = path.length;

    SearchResult result = SearchResult();
    if (path.lastComponent!.isIndex) {
      pathLengthToUse = path.length - 1;
      result = mainContentContainer!
          .contentAtPath(path, partialPathLength: pathLengthToUse);
      p.container = result.container;
      p.index = path.lastComponent!.index;
    } else {
      result = mainContentContainer!.contentAtPath(path);
      p.container = result.container;
      p.index = -1;
    }

    if (result.obj == null ||
        result.obj == mainContentContainer && pathLengthToUse > 0) {
      FormatException(
          "Failed to find content at path '$path', and no approximation of it was possible.");
    } else if (result.approximate) {
      FormatException(
          "Failed to find content at path '$path', so it was approximated to: '${result.obj?.path}'.");
    }

    return p;
  }

  // Maximum snapshot stack:
  //  - stateSnapshotDuringSave -- not retained, but returned to game code
  //  - _stateSnapshotAtLastNewline (has older patch)
  //  - _state (current, being patched)

  void _stateSnapshot() {
    _stateSnapshotAtLastNewline = _state;
    _state = _state.copyAndStartPatching();
  }

  void _restoreStateSnapshot() {
    // Patched state had temporarily hijacked our
    // VariablesState and set its own callstack on it,
    // so we need to restore that.
    // If we're in the middle of saving, we may also
    // need to give the VariablesState the old patch.
    _stateSnapshotAtLastNewline!.restoreAfterPatch();

    _state = _stateSnapshotAtLastNewline!;
    _stateSnapshotAtLastNewline = null;

    // If save completed while the above snapshot was
    // active, we need to apply any changes made since
    // the save was started but before the snapshot was made.
    if (!_asyncSaving) {
      _state.applyAnyPatch();
    }
  }

  void _discardSnapshot() {
    // Normally we want to integrate the patch
    // into the main global/counts dictionaries.
    // However, if we're in the middle of async
    // saving, we simply stay in a "patching" state,
    // albeit with the newer cloned patch.
    if (!_asyncSaving) {
      _state.applyAnyPatch();
    }

    // No longer need the snapshot.
    _stateSnapshotAtLastNewline = null;
  }

  /// <summary>
  /// Advanced usage!
  /// If you have a large story, and saving state to JSON takes too long for your
  /// framerate, you can temporarily freeze a copy of the state for saving on
  /// a separate thread. Internally, the engine maintains a "diff patch".
  /// When you've finished saving your state, call BackgroundSaveComplete()
  /// and that diff patch will be applied, allowing the story to continue
  /// in its usual mode.
  /// </summary>
  /// <returns>The state for background thread save.</returns>
  StoryState copyStateForBackgroundThreadSave() {
    _ifAsyncWeCant("start saving on a background thread");
    if (_asyncSaving) {
      throw const FormatException(
          "Story is already in background saving mode, can't call CopyStateForBackgroundThreadSave again!");
    }
    var stateToSave = _state;
    _state = _state.copyAndStartPatching();
    _asyncSaving = true;
    return stateToSave;
  }

  /// <summary>
  /// See CopyStateForBackgroundThreadSave. This method releases the
  /// "frozen" save state, applying its patch that it was using internally.
  /// </summary>
  void backgroundSaveComplete() {
    // CopyStateForBackgroundThreadSave must be called outside
    // of any async ink evaluation, since otherwise you'd be saving
    // during an intermediate state.
    // However, it's possible to *complete* the save in the middle of
    // a glue-lookahead when there's a state stored in _stateSnapshotAtLastNewline.
    // This state will have its own patch that is newer than the save patch.
    // We hold off on the final apply until the glue-lookahead is finished.
    // In that case, the apply is always done, it's just that it may
    // apply the looked-ahead changes OR it may simply apply the changes
    // made during the save process to the old _stateSnapshotAtLastNewline state.
    if (_stateSnapshotAtLastNewline == null) {
      _state.applyAnyPatch();
    }

    _asyncSaving = false;
  }

  void _step() {
    bool shouldAddToStream = true;

    // Get current content
    var pointer = state.currentPointer;
    if (pointer.isNull) {
      return;
    }

    // Step directly to the first element of content in a container (if necessary)
    Container? containerToEnter = ConvertTo.container(pointer.resolve());
    while (containerToEnter != null) {
      // Mark container as being entered
      _visitContainer(containerToEnter, true);

      // No content? the most we can do is step past it
      if (containerToEnter.content.isEmpty) {
        break;
      }

      pointer = Pointer.startOf(containerToEnter);
      containerToEnter = ConvertTo.container(pointer.resolve());
    }
    state.currentPointer = pointer;

    if (_profiler != null) {
      _profiler!.step(state.callStack);
    }

    // Is the current content object:
    //  - Normal content
    //  - Or a logic/flow statement - if so, do it
    // Stop flow if we hit a stack pop when we're unable to pop (e.g. return/done statement in knot
    // that was diverted to rather than called as a function)
    var currentContentObj = pointer.resolve();
    bool isLogicOrFlowControl = _performLogicAndFlowControl(currentContentObj);

    // Has flow been forced to end by flow control above?
    if (state.currentPointer.isNull) {
      return;
    }

    if (isLogicOrFlowControl) {
      shouldAddToStream = false;
    }

    // Choice with condition?
    var choicePoint = ConvertTo.choicePoint(currentContentObj);
    if (choicePoint != null) {
      var choice = _processChoice(choicePoint);
      if (choice != null) {
        state.generatedChoices.add(choice);
      }

      currentContentObj = null;
      shouldAddToStream = false;
    }

    // If the container has no content, then it will be
    // the "content" itself, but we skip over it.
    if (currentContentObj is Container) {
      shouldAddToStream = false;
    }

    // Content to add to evaluation stack or the output stream
    if (shouldAddToStream) {
      // If we're pushing a variable pointer onto the evaluation stack, ensure that it's specific
      // to our current (possibly temporary) context index. And make a copy of the pointer
      // so that we're not editing the original runtime object.
      var varPointer = ConvertTo.variablePointerValue(currentContentObj);
      if (varPointer != null && varPointer.contextIndex == -1) {
        // Create object so we're not overwriting the story's own data
        var contextIdx =
            state.callStack.contextForVariableNamed(varPointer.variableName);
        currentContentObj =
            VariablePointerValue(varPointer.variableName, contextIdx);
      }

      // Expression evaluation content
      if (state.inExpressionEvaluation) {
        state.pushEvaluationStack(currentContentObj);
      }
      // Output stream content (i.e. not expression evaluation)
      else {
        state.pushToOutputStream(currentContentObj);
      }
    }

    // Increment the content pointer, following diverts if necessary
    _nextContent();

    // Starting a thread should be done after the increment to the content pointer,
    // so that when returning from the thread, it returns to the content after this instruction.
    var controlCmd = ConvertTo.controlCommand(currentContentObj);
    if (controlCmd != null &&
        controlCmd.commandType == CommandType.startThread) {
      state.callStack.pushThread();
    }
  }

  // Mark a container as having been visited
  void _visitContainer(Container container, bool atStart) {
    if (!container.countingAtStartOnly || atStart) {
      if (container.visitsShouldBeCounted) {
        state.incrementVisitCountForContainer(container);
      }

      if (container.turnIndexShouldBeCounted) {
        state.recordTurnIndexVisitToContainer(container);
      }
    }
  }

  final List<Container> _prevContainers = <Container>[];
  void _visitChangedContainersDueToDivert() {
    var previousPointer = state.previousPointer;
    var pointer = state.currentPointer;

    // Unless we're pointing *directly* at a piece of content, we don't do
    // counting here. Otherwise, the main stepping function will do the counting.
    if (pointer.isNull || pointer.index == -1) {
      return;
    }

    // First, find the previously open set of containers
    _prevContainers.clear();
    if (!previousPointer.isNull) {
      Container? prevAncestor =
          ConvertTo.container(previousPointer.resolve()) ??
              ConvertTo.container(previousPointer.container);
      while (prevAncestor != null) {
        _prevContainers.add(prevAncestor);
        prevAncestor = ConvertTo.container(prevAncestor.parent);
      }
    }

    // If the object is a container itself, it will be visited automatically at the next actual
    // content step. However, we need to walk up the ancestry to see if there are more containers
    InkObject? currentChildOfContainer = pointer.resolve();

    // Invalid pointer? May happen if attemptingto
    if (currentChildOfContainer == null) return;

    Container? currentContainerAncestor =
        ConvertTo.container(currentChildOfContainer.parent);

    bool allChildrenEnteredAtStart = true;
    while (currentContainerAncestor != null &&
        (!_prevContainers.contains(currentContainerAncestor) ||
            currentContainerAncestor.countingAtStartOnly)) {
      // Check whether this ancestor container is being entered at the start,
      // by checking whether the child object is the first.
      bool enteringAtStart = currentContainerAncestor.content.isNotEmpty &&
          currentChildOfContainer == currentContainerAncestor.content[0] &&
          allChildrenEnteredAtStart;

      // Don't count it as entering at start if we're entering random somewhere within
      // a container B that happens to be nested at index 0 of container A. It only counts
      // if we're diverting directly to the first leaf node.
      if (!enteringAtStart) {
        allChildrenEnteredAtStart = false;
      }

      // Mark a visit to this container
      _visitContainer(currentContainerAncestor, enteringAtStart);

      currentChildOfContainer = currentContainerAncestor;
      currentContainerAncestor =
          ConvertTo.container(currentContainerAncestor.parent);
    }
  }

  Choice? _processChoice(ChoicePoint choicePoint) {
    bool showChoice = true;

    // Don't create choice if choice point doesn't pass conditional
    if (choicePoint.hasCondition) {
      var conditionValue = state.popEvaluationStack();
      if (!_isTruthy(conditionValue)) {
        showChoice = false;
      }
    }

    String startText = "";
    String choiceOnlyText = "";

    if (choicePoint.hasChoiceOnlyContent) {
      var choiceOnlyStrVal = state.popEvaluationStack() as StringValue;
      choiceOnlyText = choiceOnlyStrVal.value;
    }

    if (choicePoint.hasStartContent) {
      var startStrVal = state.popEvaluationStack() as StringValue;
      startText = startStrVal.value;
    }

    // Don't create choice if player has already read this content
    if (choicePoint.onceOnly) {
      var visitCount = state.visitCountForContainer(choicePoint.choiceTarget!);
      if (visitCount > 0) {
        showChoice = false;
      }
    }

    // We go through the full process of creating the choice above so
    // that we consume the content for it, since otherwise it'll
    // be shown on the output stream.
    if (!showChoice) {
      return null;
    }

    var choice = Choice();
    choice.targetPath = choicePoint.pathOnChoice;
    choice.sourcePath = choicePoint.path.toString();
    choice.isInvisibleDefault = choicePoint.isInvisibleDefault;

    // We need to capture the state of the callstack at the point where
    // the choice was generated, since after the generation of this choice
    // we may go on to pop out from a tunnel (possible if the choice was
    // wrapped in a conditional), or we may pop out from a thread,
    // at which point that thread is discarded.
    // Fork clones the thread, gives it a ID, but without affecting
    // the thread stack itself.
    choice.threadAtGeneration = state.callStack.forkThread();

    // Set final text for the choice
    choice.text = (startText + choiceOnlyText)
        .trim(); // TODO ben gordon trim used to be this .trim(' ', '\t')

    return choice;
  }

  // Does the expression result represented by this object evaluate to true?
  // e.g. is it a Number that's not equal to 1?
  bool _isTruthy(InkObject? obj) {
    bool truthy = false;
    if (obj is Value) {
      var val = obj;

      if (val is DivertTargetValue) {
        var divTarget = val;
        FormatException(
            "Shouldn't use a divert target (to ${divTarget.targetPath}) as a conditional value. Did you intend a function call 'likeThis()' or a read count check 'likeThis'? (no arrows)");
        return false;
      }

      return val.isTruthy;
    }
    return truthy;
  }

  /// <summary>
  /// Checks whether contentObj is a control or flow object rather than a piece of content,
  /// and performs the required command if necessary.
  /// </summary>
  /// <returns><c>true</c> if object was logic or flow control, <c>false</c> if it's normal content.</returns>
  /// <param name="contentObj">Content object.</param>
  bool _performLogicAndFlowControl(InkObject? contentObj) {
    if (contentObj == null) {
      return false;
    }

    // Divert
    if (contentObj is Divert) {
      Divert? currentDivert = contentObj;

      if (currentDivert.isConditional) {
        var conditionValue = state.popEvaluationStack();

        // False conditional? Cancel divert
        if (!_isTruthy(conditionValue)) {
          return true;
        }
      }

      if (currentDivert.hasVariableTarget) {
        var varName = currentDivert.variableDivertName;

        var varContents = state.variablesState.getVariableWithName(varName);

        if (varContents == null) {
          throw FormatException(
              "Tried to divert using a target from a variable that could not be found ($varName)");
        } else if (varContents is! DivertTargetValue) {
          var intContent = ConvertTo.intValue(varContents);

          String errorMessage =
              "Tried to divert to a target from a variable, but the variable ($varName) didn't contain a divert target, it ";
          if (intContent != null && intContent.value == 0) {
            errorMessage += "was empty/null (the value 0).";
          } else {
            errorMessage += "contained '$varContents'.";
          }

          throw FormatException(errorMessage);
        }

        var target = ConvertTo.divertTargetValue(varContents);
        state.divertedPointer = pointerAtPath(target!.targetPath);
      } else if (currentDivert.isExternal) {
        callExternalFunction(
            currentDivert.targetPathString, currentDivert.externalArgs);
        return true;
      } else {
        state.divertedPointer = currentDivert.targetPointer;
      }

      if (currentDivert.pushesToStack) {
        state.callStack.push(currentDivert.stackPushType!,
            outputStreamLengthWithPushed: state.outputStream.length);
      }

      if (state.divertedPointer.isNull && !currentDivert.isExternal) {
        // Human readable name available - runtime divert is part of a hard-written divert that to missing content
        if (currentDivert != null &&
            currentDivert.debugMetadata != null &&
            currentDivert.debugMetadata!.sourceName != null) {
          FormatException(
              "Divert target doesn't exist:  ${currentDivert.debugMetadata!.sourceName}");
        } else {
          FormatException("Divert resolution failed: $currentDivert");
        }
      }

      return true;
    }

    // Start/end an expression evaluation? Or print out the result?
    else if (contentObj is ControlCommand) {
      var evalCommand = contentObj;

      switch (evalCommand.commandType) {
        case CommandType.evalStart:
          _assert(state.inExpressionEvaluation == false,
              "Already in expression evaluation?");
          state.inExpressionEvaluation = true;
          break;

        case CommandType.evalEnd:
          _assert(state.inExpressionEvaluation == true,
              "Not in expression evaluation mode");
          state.inExpressionEvaluation = false;
          break;

        case CommandType.evalOutput:

          // If the expression turned out to be empty, there may not be anything on the stack
          if (state.evaluationStack.isNotEmpty) {
            var output = state.popEvaluationStack();

            // Functions may evaluate to Void, in which case we skip output
            if (output is! Void) {
              // TODO: Should we really always blanket convert to string?
              // It would be okay to have numbers in the output stream the
              // only problem is when exporting text for viewing, it skips over numbers etc.
              var text = StringValue(output.toString());

              state.pushToOutputStream(text);
            }
          }
          break;

        case CommandType.noOp:
          break;

        case CommandType.duplicate:
          state.pushEvaluationStack(state.peekEvaluationStack());
          break;

        case CommandType.popEvaluatedValue:
          state.popEvaluationStack();
          break;

        case CommandType.popFunction:
        case CommandType.popTunnel:
          var popType = evalCommand.commandType == CommandType.popFunction
              ? PushPopType.Function
              : PushPopType.Tunnel;

          // Tunnel onwards is allowed to specify an optional override
          // divert to go to immediately after returning: ->-> target
          DivertTargetValue? overrideTunnelReturnTarget;
          if (popType == PushPopType.Tunnel) {
            var popped = state.popEvaluationStack();
            overrideTunnelReturnTarget = ConvertTo.divertTargetValue(popped);
            if (overrideTunnelReturnTarget == null) {
              _assert(popped is Void,
                  "Expected void if ->-> doesn't override target");
            }
          }

          if (state.tryExitFunctionEvaluationFromGame()) {
            break;
          } else if (state.callStack.currentElement.type != popType ||
              !state.callStack.canPop) {
            var names = <PushPopType, String?>{};
            names[PushPopType.Function] =
                "function return statement (~ return)";
            names[PushPopType.Tunnel] = "tunnel onwards statement (->->)";

            String? expected = names[state.callStack.currentElement.type];
            if (!state.callStack.canPop) {
              expected = "end of flow (-> END or choice)";
            }

            var errorMsg = "Found ${names[popType]}, when expected $expected";

            FormatException(errorMsg);
          } else {
            state.popCallstack();

            // Does tunnel onwards override by diverting to a ->-> target?
            if (overrideTunnelReturnTarget != null) {
              state.divertedPointer =
                  pointerAtPath(overrideTunnelReturnTarget.targetPath);
            }
          }

          break;

        case CommandType.beginString:
          state.pushToOutputStream(evalCommand);

          _assert(state.inExpressionEvaluation == true,
              "Expected to be in an expression when evaluating a string");
          state.inExpressionEvaluation = false;
          break;

        case CommandType.endString:

          // Since we're iterating backward through the content,
          // build a stack so that when we build the string,
          // it's in the right order
          var contentStackForString = Stack<InkObject>();

          int outputCountConsumed = 0;
          for (int i = state.outputStream.length - 1; i >= 0; --i) {
            var obj = state.outputStream[i];

            outputCountConsumed++;

            var command = ConvertTo.controlCommand(obj);
            if (command != null &&
                command.commandType == CommandType.beginString) {
              break;
            }

            if (obj is StringValue) {
              contentStackForString.push(obj);
            }
          }

          // Consume the content that was produced for this string
          state.popFromOutputStream(outputCountConsumed);

          // Build String out of the content we collected
          var sb = StringBuffer();
          while (contentStackForString.isNotEmpty) {
            sb.write(contentStackForString.pop().toString());
          }

          // Return to expression evaluation (from content mode)
          state.inExpressionEvaluation = true;
          state.pushEvaluationStack(StringValue(sb.toString()));
          break;

        case CommandType.choiceCount:
          var choiceCount = state.generatedChoices.length;
          state.pushEvaluationStack(IntValue(choiceCount));
          break;

        case CommandType.turns:
          state.pushEvaluationStack(IntValue(state.currentTurnIndex + 1));
          break;

        case CommandType.turnsSince:
        case CommandType.readCount:
          var target = state.popEvaluationStack();
          if (target is! DivertTargetValue) {
            String extraNote = "";
            if (target is IntValue) {
              extraNote =
                  ". Did you accidentally pass a read count ('knot_name') instead of a target ('-> knot_name')?";
            }
            FormatException(
                "TURNS_SINCE expected a divert target (knot, stitch, label name), but saw $target $extraNote");
            break;
          }

          var divertTarget = target;
          var container =
              ConvertTo.container(contentAtPath(divertTarget.targetPath).correctObj);

          int eitherCount;
          if (container != null) {
            if (evalCommand.commandType == CommandType.turnsSince) {
              eitherCount = state.turnsSinceForContainer(container);
            } else {
              eitherCount = state.visitCountForContainer(container);
            }
          } else {
            if (evalCommand.commandType == CommandType.turnsSince) {
              eitherCount = -1;
            } else {
              eitherCount = 0;
            } // visit count, assume 0 to default to allowing entry

            FormatException(
                "Failed to find container for $evalCommand lookup at ${divertTarget.targetPath}");
          }

          state.pushEvaluationStack(IntValue(eitherCount));
          break;

        case CommandType.random:
          {
            var maxInt = ConvertTo.intValue(state.popEvaluationStack());
            var minInt = ConvertTo.intValue(state.popEvaluationStack());

            if (minInt == null) {
              throw const FormatException(
                  "Invalid value for minimum parameter of RANDOM(min, max)");
            }

            if (maxInt == null) {
              throw const FormatException(
                  "Invalid value for maximum parameter of RANDOM(min, max)");
            }

            // +1 because it's inclusive of min and max, for e.g. RANDOM(1,6) for a dice roll.
            int randomRange;
            try {
              randomRange = maxInt.value - minInt.value + 1;
            } catch (e) {
              // Overflow exception
              randomRange = 1000000;
              const FormatException(
                  "RANDOM was called with a range that exceeds the size that ink numbers can use.");
            }
            if (randomRange <= 0) {
              throw FormatException(
                  "RANDOM was called with minimum as ${minInt.value} and maximum as ${maxInt.value}. The maximum must be larger");
            }

            var resultSeed = state.storySeed + state.previousRandom;
            var random = Random(resultSeed);

            var nextRandom = random.nextInt(1000000);
            var chosenValue = (nextRandom % randomRange) + minInt.value;
            state.pushEvaluationStack(IntValue(chosenValue));

            // Next random number (rather than keeping the Random object around)
            state.previousRandom = nextRandom;
            break;
          }

        case CommandType.seedRandom:
          var seed = ConvertTo.intValue(state.popEvaluationStack());
          if (seed == null) {
            throw const FormatException("Invalid value passed to SEED_RANDOM");
          }

          // Story seed affects both RANDOM and shuffle behaviour
          state.storySeed = seed.value;
          state.previousRandom = 0;

          // SEED_RANDOM returns nothing.
          state.pushEvaluationStack(Void());
          break;

        case CommandType.visitIndex:
          var count =
              state.visitCountForContainer(state.currentPointer.container!) -
                  1; // index not count
          state.pushEvaluationStack(IntValue(count));
          break;

        case CommandType.sequenceShuffleIndex:
          var shuffleIndex = _nextSequenceShuffleIndex();
          state.pushEvaluationStack(IntValue(shuffleIndex));
          break;

        case CommandType.startThread:
          // Handled in main step function
          break;

        case CommandType.done:

          // We may exist in the context of the initial
          // act of creating the thread, or in the context of
          // evaluating the content.
          if (state.callStack.canPopThread) {
            state.callStack.popThread();
          }

          // In normal flow - allow safe exit without warning
          else {
            state.didSafeExit = true;

            // Stop flow in current thread
            state.currentPointer = Pointer.nullPointer;
          }

          break;

        // Force flow to end completely
        case CommandType.end:
          state.forceEnd();
          break;

        case CommandType.listFromInt:
          var intVal = ConvertTo.intValue(state.popEvaluationStack());
          var listNameVal = state.popEvaluationStack() as StringValue;

          if (intVal == null) {
            throw StoryException(
                "Passed non-integer when creating a list element from a numerical value.");
          }

          ListValue? generatedListValue;

          ListDefinition? foundListDef =
              listDefinitions!.tryListGetDefinition(listNameVal.value);
          if (foundListDef != null) {
            ValueHolder foundItem =
                foundListDef.tryGetItemWithValue(intVal.value, InkListItem());
            if (foundItem.exists) {
              generatedListValue =
                  ListValue.fromItem(foundItem.value!, intVal.value);
            }
          } else {
            throw StoryException(
                "Failed to find LIST called ${listNameVal.value}");
          }

          generatedListValue ??= ListValue();

          state.pushEvaluationStack(generatedListValue);
          break;

        case CommandType.listRange:
          {
            var max = ConvertTo.value(state.popEvaluationStack());
            var min = ConvertTo.value(state.popEvaluationStack());

            var targetList = ConvertTo.listValue(state.popEvaluationStack());

            if (targetList == null || min == null || max == null) {
              throw StoryException(
                  "Expected list, minimum and maximum for LIST_RANGE");
            }

            var result = targetList.value
                .listWithSubRange(min.valueObject!, max.valueObject!);

            state.pushEvaluationStack(ListValue.fromList(result));
            break;
          }

        case CommandType.listRandom:
          {
            var listVal = ConvertTo.listValue(state.popEvaluationStack());
            if (listVal == null) {
              throw StoryException("Expected list for LIST_RANDOM");
            }

            var list = listVal.value;

            InkList? newList;

            // List was empty: return empty list
            if (list.isEmpty) {
              newList = InkList();
            }

            // Non-empty source list
            else {
              // Generate a random index for the element to take
              var resultSeed = state.storySeed + state.previousRandom;
              var random = Random(resultSeed);

              var nextRandom = random.nextInt(1000000);
              var listItemIndex = nextRandom % list.length;

              // Iterate through to get the random element
              var listEnumerator = list.entries.iterator;
              for (int i = 0; i <= listItemIndex; i++) {
                listEnumerator.moveNext();
              }
              var randomItem = listEnumerator.current;

              // Origin list is simply the origin of the one element
              newList = InkList.fromOrigin(randomItem.key.originName!, this);
              newList.add(randomItem.key, randomItem.value);

              state.previousRandom = nextRandom;
            }

            state.pushEvaluationStack(ListValue.fromList(newList));
            break;
          }

        default:
          FormatException("unhandled ControlCommand: $evalCommand");
          break;
      }

      return true;
    }

    // Variable assignment
    else if (contentObj is VariableAssignment) {
      var varAss = contentObj;
      var assignedVal = state.popEvaluationStack();

      // When in temporary evaluation, don't create variables purely within
      // the temporary context, but attempt to create them globally
      //var prioritiseHigherInCallStack = _temporaryEvaluationContainer != null;

      state.variablesState.assign(varAss, assignedVal);

      return true;
    }

    // Variable reference
    else if (contentObj is VariableReference) {
      var varRef = contentObj;
      InkObject? foundValue;

      // Explicit read count value
      if (varRef.pathForCount != null) {
        var container = varRef.containerForCount;
        int count = state.visitCountForContainer(container);
        foundValue = IntValue(count);
      }

      // Normal variable reference
      else {
        foundValue = state.variablesState.getVariableWithName(varRef.name);

        if (foundValue == null) {
          FormatException(
              "Variable not found: '${varRef.name}'. Using default value of 0 (false). This can happen with temporary variables if the declaration hasn't yet been hit. Globals are always given a default value on load if a value doesn't exist in the save state.");
          foundValue = IntValue(0);
        }
      }

      state.pushEvaluationStack(foundValue);

      return true;
    }

    // Native function call
    else if (contentObj is NativeFunctionCall) {
      var func = contentObj;
      var funcParams = state.popEvaluationStackNum(func.numberOfParameters);
      var result = func._call(funcParams);
      state.pushEvaluationStack(result);
      return true;
    }

    // No control content, must be ordinary content
    return false;
  }

  /// <summary>
  /// Change the current position of the story to the given path. From here you can
  /// call Continue() to evaluate the next line.
  ///
  /// The path String is a dot-separated path as used internally by the engine.
  /// These examples should work:
  ///
  ///    myKnot
  ///    myKnot.myStitch
  ///
  /// Note however that this won't necessarily work:
  ///
  ///    myKnot.myStitch.myLabelledChoice
  ///
  /// ...because of the way that content is nested within a weave structure.
  ///
  /// By default this will reset the callstack beforehand, which means that any
  /// tunnels, threads or functions you were in at the time of calling will be
  /// discarded. This is different from the behaviour of ChooseChoiceIndex, which
  /// will always keep the callstack, since the choices are known to come from the
  /// correct state, and known their source thread.
  ///
  /// You have the option of passing false to the resetCallstack parameter if you
  /// don't want this behaviour, and will leave any active threads, tunnels or
  /// function calls in-tact.
  ///
  /// This is potentially dangerous! If you're in the middle of a tunnel,
  /// it'll redirect only the inner-most tunnel, meaning that when you tunnel-return
  /// using '->->', it'll return to where you were before. This may be what you
  /// want though. However, if you're in the middle of a function, ChoosePathString
  /// will throw an exception.
  ///
  /// </summary>
  /// <param name="path">A dot-separted path string, as specified above.</param>
  /// <param name="resetCallstack">Whether to reset the callstack first (see summary description).</param>
  /// <param name="arguments">Optional set of arguments to pass, if path is to a knot that takes them.</param>
  void choosePathString(String path,
      [bool shouldResetCallstack = true, List<Object> arguments = const []]) {
    _ifAsyncWeCant("call ChoosePathString right now");
    onChoosePathString.broadcast(StringObjectListEventArgs(path, arguments));
    if (shouldResetCallstack) {
      resetCallstack();
    } else {
      // ChoosePathString is potentially dangerous since you can call it when the stack is
      // pretty much in any state. Let's catch one of the worst offenders.
      if (state.callStack.currentElement.type == PushPopType.Function) {
        String funcDetail = "";
        var container = state.callStack.currentElement.currentPointer.container;
        if (container != null) {
          funcDetail = "(${container.path}) ";
        }
        throw FormatException(
            "Story was running a function ${funcDetail}when you called ChoosePathString($path) - this is almost certainly not not what you want! Full stack trace: \n${state.callStack.callStackTrace}");
      }
    }

    state.passArgumentsToEvaluationStack(arguments);
    choosePath(Path.fromString(path));
  }

  void _ifAsyncWeCant(String activityStr) {
    if (_asyncContinueActive) {
      throw FormatException(
          "Can't $activityStr. Story is in the middle of a ContinueAsync(). Make more ContinueAsync() calls or a single Continue() call beforehand.");
    }
  }

  void choosePath(Path p, [bool incrementingTurnIndex = true]) {
    state.setChosenPath(p, incrementingTurnIndex);

    // Take a note of newly visited containers for read counts etc
    _visitChangedContainersDueToDivert();
  }

  /// <summary>
  /// Chooses the Choice from the currentChoices list with the given
  /// index. Internally, this sets the current content path to that
  /// pointed to by the Choice, ready to continue story evaluation.
  /// </summary>
  void chooseChoiceIndex(int choiceIdx) {
    var choices = currentChoices;
    _assert(
        choiceIdx >= 0 && choiceIdx < choices.length, "choice out of range");

    // Replace callstack with the one from the thread at the choosing point,
    // so that we can jump into the right place in the flow.
    // This is important in case the flow was forked by a thread, which
    // can create multiple leading edges for the story, each of
    // which has its own context.
    var choiceToChoose = choices[choiceIdx];
    onMakeChoice.broadcast(ChoiceEventArg(choiceToChoose));
    state.callStack.currentThread = choiceToChoose.threadAtGeneration!;

    choosePath(choiceToChoose.targetPath!);
  }

  /// <summary>
  /// Checks if a function exists.
  /// </summary>
  /// <returns>True if the function exists, else false.</returns>
  /// <param name="functionName">The name of the function as declared in ink.</param>
  bool hasFunction(String functionName) {
    try {
      return knotContainerWithName(functionName) != null;
    } catch (e) {
      return false;
    }
  }

  /// <summary>
  /// Evaluates a function defined in ink.
  /// </summary>
  /// <returns>The return value as returned from the ink function with `~ return myValue`, or null if nothing is returned.</returns>
  /// <param name="functionName">The name of the function as declared in ink.</param>
  /// <param name="arguments">The arguments that the ink function takes, if any. Note that we don't (can't) do any validation on the number of arguments right now, so make sure you get it right!</param>
  Object evaluateFunction(String functionName, List<Object> arguments) {
    return evaluateFunctionWithText(functionName, "", arguments);
  }

  /// <summary>
  /// Evaluates a function defined in ink, and gathers the possibly multi-line text as generated by the function.
  /// This text output is any text written as normal content within the function, as opposed to the return value, as returned with `~ return`.
  /// </summary>
  /// <returns>The return value as returned from the ink function with `~ return myValue`, or null if nothing is returned.</returns>
  /// <param name="functionName">The name of the function as declared in ink.</param>
  /// <param name="textOutput">The text content produced by the function via normal ink, if any.</param>
  /// <param name="arguments">The arguments that the ink function takes, if any. Note that we don't (can't) do any validation on the number of arguments right now, so make sure you get it right!</param>
  Object evaluateFunctionWithText(
      String functionName, String textOutput, List<Object> arguments) {
    onEvaluateFunction
        .broadcast(StringObjectListEventArgs(functionName, arguments));
    _ifAsyncWeCant("evaluate a function");

    if (functionName == null) {
      throw const FormatException("Function is null");
    } else if (functionName == "" || functionName.trim() == "") {
      throw const FormatException("Function is empty or white space.");
    }

    // Get the content that we need to run
    var funcContainer = knotContainerWithName(functionName);
    if (funcContainer == null) {
      throw FormatException("Function doesn't exist: '$functionName'");
    }

    // Snapshot the output stream
    var outputStreamBefore = <InkObject?>[...state.outputStream];
    _state.resetOutput();

    // State will temporarily replace the callstack in order to evaluate
    state.startFunctionEvaluationFromGame(funcContainer, arguments);

    // Evaluate the function, and collect the String output
    var stringOutput = StringBuffer();
    while (canContinue) {
      stringOutput.write(Continue());
    }
    textOutput = stringOutput.toString();

    // Restore the output stream in case this was called
    // during main story evaluation.
    _state.resetOutput(outputStreamBefore);

    // Finish evaluation, and see whether anything was produced
    var result = state.completeFunctionEvaluationFromGame()!;
    onCompleteEvaluateFunction.broadcast(StringObjectListStringObjectEventArgs(
        functionName, arguments, textOutput, result));
    return result;
  }

  // Evaluate a "hot compiled" piece of ink content, as used by the REPL-like
  // CommandLinePlayer.
  InkObject? evaluateExpression(Container exprContainer) {
    int startCallStackHeight = state.callStack.elements.length;

    state.callStack.push(PushPopType.Tunnel);

    _temporaryEvaluationContainer = exprContainer;

    state.goToStart();

    int evalStackHeight = state.evaluationStack.length;

    Continue();

    _temporaryEvaluationContainer = null;

    // Should have fallen off the end of the Container, which should
    // have auto-popped, but just in case we didn't for some reason,
    // manually pop to restore the state (including currentPath).
    if (state.callStack.elements.length > startCallStackHeight) {
      state.popCallstack();
    }

    int endStackHeight = state.evaluationStack.length;
    if (endStackHeight > evalStackHeight) {
      return state.popEvaluationStack();
    } else {
      return null;
    }
  }

  /// <summary>
  /// An ink file can provide a fallback functions for when when an EXTERNAL has been left
  /// unbound by the client, and the fallback function will be called instead. Useful when
  /// testing a story in playmode, when it's not possible to write a client-side C# external
  /// function, but you don't want it to fail to run.
  /// </summary>
  bool allowExternalFunctionFallbacks = false;

  void callExternalFunction(String? funcName, int numberOfArguments) {
    ExternalFunctionDef? funcDef = _externals[funcName];
    Container? fallbackFunctionContainer;

    var foundExternal = _externals.containsKey(funcName);

    // Should this function break glue? Abort run if we've already seen a newline.
    // Set a bool to tell it to restore the snapshot at the end of this instruction.
    if (foundExternal &&
        !funcDef!.lookaheadSafe &&
        _stateSnapshotAtLastNewline != null) {
      _sawLookaheadUnsafeFunctionAfterNewline = true;
      return;
    }

    // Try to use fallback function?
    if (!foundExternal) {
      if (allowExternalFunctionFallbacks) {
        fallbackFunctionContainer = knotContainerWithName(funcName);
        _assert(fallbackFunctionContainer != null,
            "Trying to call EXTERNAL function '$funcName' which has not been bound, and fallback ink function could not be found.");

        // Divert direct into fallback function and we're done
        state.callStack.push(PushPopType.Function,
            outputStreamLengthWithPushed: state.outputStream.length);
        state.divertedPointer = Pointer.startOf(fallbackFunctionContainer!);
        return;
      } else {
        _assert(false,
            "Trying to call EXTERNAL function '$funcName' which has not been bound (and ink fallbacks disabled).");
      }
    }

    // Pop arguments
    var arguments = <Object>[];
    for (int i = 0; i < numberOfArguments; ++i) {
      var poppedObj = state.popEvaluationStack() as Value;
      var valueObj = poppedObj.valueObject;
      arguments.add(valueObj!);
    }

    // Reverse arguments from the order they were popped,
    // so they're the right way round again.
    arguments = arguments.reversed.toList();

    // Run the function!
    Object? funcResult = funcDef!.function!(arguments);

    // Convert return value (if any) to the a type that the ink engine can use
    InkObject? returnObj = null;
    if (funcResult != null) {
      returnObj = Value.create(funcResult);
      _assert(returnObj != null,
          "Could not create ink value from returned object of type ${funcResult.runtimeType}");
    } else {
      returnObj = Void();
    }

    state.pushEvaluationStack(returnObj);
  }

  /// <summary>
  /// General purpose delegate definition for bound EXTERNAL function definitions
  /// from ink. Note that this version isn't necessary if you have a function
  /// with three arguments or less - see the overloads of BindExternalFunction.
  /// </summary>
  // delegate Object ExternalFunction(List<Object> args);

  /// <summary>
  /// Most general form of function binding that returns an object
  /// and takes an array of object parameters.
  /// The only way to bind a function with more than 3 arguments.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="func">The C# function to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunctionGeneral(String funcName, ExternalFunction func,
      [bool lookaheadSafe = true]) {
    _ifAsyncWeCant("bind an external function");
    _assert(!_externals.containsKey(funcName),
        "Function '$funcName' has already been bound.");
    _externals[funcName] = ExternalFunctionDef(func, lookaheadSafe);
  }

  Object? _tryCoerce<T>(Object value) {
    if (value == null) {
      return null;
    }

    if (value is T) {
      return value;
    }

    if (value is double && T == int) {
      int intVal = value.round();
      return intVal;
    }

    if (value is int && T == double) {
      double floatVal = value as double;
      return floatVal;
    }

    if (value is int && T == bool) {
      int intVal = value;
      return intVal == 0 ? false : true;
    }

    if (value is bool && T == int) {
      bool boolVal = value;
      return boolVal ? 1 : 0;
    }

    if (T == String) {
      return value.toString();
    }

    _assert(false, "Failed to cast ${value.runtimeType} to $T");

    return null;
  }

  // Convenience overloads for standard functions and actions of various arities
  // Is there a better way of doing this?!

  /// <summary>
  /// Bind a C# function to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="func">The C# function to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction(String funcName, Function() func,
      [bool lookaheadSafe = false]) {
    _assert(func != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 0, "External function expected no arguments");
      return func();
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# Action to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="act">The C# action to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunctionA(String funcName, Function() act,
      [bool lookaheadSafe = false]) {
    _assert(act != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.isEmpty, "External function expected no arguments");
      act();
      // return null;
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# function to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="func">The C# function to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction1<T>(String funcName, Object Function(T) func,
      [bool lookaheadSafe = false]) {
    _assert(func != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 1, "External function expected one argument");
      return func((_tryCoerce<T>(args[0]) as T));
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# action to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="act">The C# action to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction1A<T>(String funcName, Function(T) act,
      [bool lookaheadSafe = false]) {
    _assert(act != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 1, "External function expected one argument");
      act(_tryCoerce<T>(args[0]) as T);
      return null;
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# function to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="func">The C# function to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction2<T1, T2>(
      String funcName, Object Function(T1, T2) func,
      [bool lookaheadSafe = false]) {
    _assert(func != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 2, "External function expected two arguments");
      return func(_tryCoerce<T1>(args[0]) as T1, _tryCoerce<T2>(args[1]) as T2);
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# action to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="act">The C# action to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction2A<T1, T2>(String funcName, Function(T1, T2) act,
      [bool lookaheadSafe = false]) {
    _assert(act != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 2, "External function expected two arguments");
      act(_tryCoerce<T1>(args[0]) as T1, _tryCoerce<T2>(args[1]) as T2);
      return null;
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# function to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="func">The C# function to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction3<T1, T2, T3>(
      String funcName, Object Function(T1, T2, T3) func,
      [bool lookaheadSafe = false]) {
    _assert(func != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 3, "External function expected three arguments");
      return func(_tryCoerce<T1>(args[0]) as T1, _tryCoerce<T2>(args[1]) as T2,
          _tryCoerce<T3>(args[2]) as T3);
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# action to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="act">The C# action to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction3A<T1, T2, T3>(
      String funcName, Function(T1, T2, T3) act,
      [bool lookaheadSafe = false]) {
    _assert(act != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 3, "External function expected three arguments");
      act(_tryCoerce<T1>(args[0]) as T1, _tryCoerce<T2>(args[1]) as T2,
          _tryCoerce<T3>(args[2]) as T3);
      return null;
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# function to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="func">The C# function to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction4<T1, T2, T3, T4>(
      String funcName, Object Function(T1, T2, T3, T4) func,
      [bool lookaheadSafe = false]) {
    _assert(func != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 4, "External function expected four arguments");
      return func(_tryCoerce<T1>(args[0]) as T1, _tryCoerce<T2>(args[1]) as T2,
          _tryCoerce<T3>(args[2]) as T3, _tryCoerce<T4>(args[3]) as T4);
    }, lookaheadSafe);
  }

  /// <summary>
  /// Bind a C# action to an ink EXTERNAL function declaration.
  /// </summary>
  /// <param name="funcName">EXTERNAL ink function name to bind to.</param>
  /// <param name="act">The C# action to bind.</param>
  /// <param name="lookaheadSafe">The ink engine often evaluates further
  /// than you might expect beyond the current line just in case it sees
  /// glue that will cause the two lines to become one. In this case it's
  /// possible that a function can appear to be called twice instead of
  /// just once, and earlier than you expect. If it's safe for your
  /// function to be called in this way (since the result and side effect
  /// of the function will not change), then you can pass 'true'.
  /// Usually, you want to pass 'false', especially if you want some action
  /// to be performed in game code when this function is called.</param>
  void bindExternalFunction4A<T1, T2, T3, T4>(
      String funcName, Function(T1, T2, T3, T4) act,
      [bool lookaheadSafe = false]) {
    _assert(act != null, "Can't bind a null function");

    bindExternalFunctionGeneral(funcName, (List<Object> args) {
      _assert(args.length == 4, "External function expected four arguments");
      act(_tryCoerce<T1>(args[0]) as T1, _tryCoerce<T2>(args[1]) as T2,
          _tryCoerce<T3>(args[2]) as T3, _tryCoerce<T4>(args[3]) as T4);
      return null;
    }, lookaheadSafe);
  }

  /// <summary>
  /// Remove a binding for a named EXTERNAL ink function.
  /// </summary>
  void unbindExternalFunction(String funcName) {
    _ifAsyncWeCant("unbind an external a function");
    _assert(_externals.containsKey(funcName),
        "Function '$funcName' has not been bound.");
    _externals.remove(funcName);
  }

  /// <summary>
  /// Check that all EXTERNAL ink functions have a valid bound C# function.
  /// Note that this is automatically called on the first call to Continue().
  /// </summary>
  void _validateExternalBindings() {
    var missingExternals = HashSet<String>();

    _validateExternalBindingsContainerHashSet(
        _mainContentContainer!, missingExternals);
    _hasValidatedExternals = true;

    // No problem! Validation complete
    if (missingExternals.length == 0) {
      _hasValidatedExternals = true;
    }

    // Error for all missing externals
    else {
      var message =
          "ERROR: Missing function binding for external${missingExternals.length > 1 ? "s" : ""}: '${missingExternals.toList().join(
                "', '",
              )}' ${allowExternalFunctionFallbacks ? ", and no fallback ink function found." : " (ink fallbacks disabled)"}";

      FormatException(message);
    }
  }

  void _validateExternalBindingsContainerHashSet(
      Container c, HashSet<String> missingExternals) {
    for (var innerContent in c.content) {
      var container = ConvertTo.container(innerContent);
      if (container == null || !container.hasValidName) {
        _validateExternalBindingsInkObjectHashSet(
            innerContent, missingExternals);
      }
    }
    for (var innerKeyValue in c.namedContent.entries) {
      _validateExternalBindingsInkObjectHashSet(
          innerKeyValue.value as InkObject, missingExternals);
    }
  }

  void _validateExternalBindingsInkObjectHashSet(
      InkObject o, HashSet<String> missingExternals) {
    var container = ConvertTo.container(o);
    if (container != null) {
      _validateExternalBindingsContainerHashSet(container, missingExternals);
      return;
    }

    var divert = ConvertTo.divert(o);
    if (divert != null && divert.isExternal) {
      var name = divert.targetPathString;

      if (!_externals.containsKey(name)) {
        if (allowExternalFunctionFallbacks) {
          bool fallbackFound =
              mainContentContainer!.namedContent.containsKey(name);
          if (!fallbackFound) {
            missingExternals.add(name!);
          }
        } else {
          missingExternals.add(name!);
        }
      }
    }
  }

  /// <summary>
  /// Delegate definition for variable observation - see ObserveVariable.
  /// </summary>
  // delegate void VariableObserver(String variableName, Object newValue);
  // final Event<StringObjectEventArgs> variableObserver = Event<StringObjectEventArgs>();

  /// <summary>
  /// When the named global variable changes it's value, the observer will be
  /// called to notify it of the change. Note that if the value changes multiple
  /// times within the ink, the observer will only be called once, at the end
  /// of the ink's evaluation. If, during the evaluation, it changes and then
  /// changes back again to its original value, it will still be called.
  /// Note that the observer will also be fired if the value of the variable
  /// is changed externally to the ink, by directly setting a value in
  /// story.variablesState.
  /// </summary>
  /// <param name="variableName">The name of the global variable to observe.</param>
  /// <param name="observer">A delegate function to call when the variable changes.</param>
  void observeVariable(String variableName, VariableObserver observer) {
    _ifAsyncWeCant("observe a variable");

    // <String, Function(StringObjectEventArgs)>{};

    if (!state.variablesState.globalVariableExistsWithName(variableName)) {
      throw Exception(
          "Cannot observe variable '$variableName' because it wasn't declared in the ink story.");
    }

    if (!_variableObservers.containsKey(variableName)) {
      _variableObservers[variableName] = Event();
    }

    _variableObservers[variableName]!.subscribe(observer);
  }

  /// <summary>
  /// Convenience function to allow multiple variables to be observed with the same
  /// observer delegate function. See the singular ObserveVariable for details.
  /// The observer will get one call for every variable that has changed.
  /// </summary>
  /// <param name="variableNames">The set of variables to observe.</param>
  /// <param name="observer">The delegate function to call when any of the named variables change.</param>
  void observeVariables(List<String> variableNames, VariableObserver observer) {
    for (var varName in variableNames) {
      observeVariable(varName, observer);
    }
  }

  /// <summary>
  /// Removes the variable observer, to stop getting variable change notifications.
  /// If you pass a specific variable name, it will stop observing that particular one. If you
  /// pass null (or leave it blank, since it's optional), then the observer will be removed
  /// from all variables that it's subscribed to. If you pass in a specific variable name and
  /// null for the the observer, all observers for that variable will be removed.
  /// </summary>
  /// <param name="observer">(Optional) The observer to stop observing.</param>
  /// <param name="specificVariableName">(Optional) Specific variable name to stop observing.</param>
  void removeVariableObserver(
      [VariableObserver? observer, String? specificVariableName]) {
    _ifAsyncWeCant("remove a variable observer");

    if (_variableObservers == null) {
      return;
    }

    // Remove observer for this specific variable
    if (specificVariableName != null) {
      if (_variableObservers.containsKey(specificVariableName)) {
        if (observer != null) {
          _variableObservers[specificVariableName]!.unsubscribe(observer);
          if (_variableObservers[specificVariableName] == null) {
            _variableObservers.remove(specificVariableName);
          }
        } else {
          _variableObservers.remove(specificVariableName);
        }
      }
    }

    // Remove observer for all variables
    else if (observer != null) {
      var keys = <String>[..._variableObservers.keys];
      for (var varName in keys) {
        _variableObservers[varName]!.unsubscribe(observer);
        if (_variableObservers[varName] == null) {
          _variableObservers.remove(varName);
        }
      }
    }
  }

  void _variableStateDidChangeEvent(VariableChangedEventArg? arg) {
    if (_variableObservers == null || arg == null) {
      return;
    }

    Event<StringObjectEventArgs>? observers =
        _variableObservers[arg.variableName];
    if (observers != null) {
      if (arg.newValue is! Value) {
        throw const FormatException(
            "Tried to get the value of a variable that isn't a standard type");
      }
      var val = arg.newValue as Value;

      observers
          .broadcast(StringObjectEventArgs(arg.variableName!, val.valueObject));
    }
  }

  /// <summary>
  /// Get any global tags associated with the story. These are defined as
  /// hash tags defined at the very top of the story.
  /// </summary>
  List<String>? get globalTags => _tagsAtStartOfFlowContainerWithPathString("");

  /// <summary>
  /// Gets any tags associated with a particular knot or knot.stitch.
  /// These are defined as hash tags defined at the very top of a
  /// knot or stitch.
  /// </summary>
  /// <param name="path">The path of the knot or stitch, in the form "knot" or "knot.stitch".</param>
  List<String>? tagsForContentAtPath(String path) {
    return _tagsAtStartOfFlowContainerWithPathString(path);
  }

  List<String>? _tagsAtStartOfFlowContainerWithPathString(String pathString) {
    var path = Path.fromString(pathString);

    // Expected to be global story, knot or stitch
    var flowContainer = contentAtPath(path).container;
    while (true) {
      var firstContent = flowContainer.content[0];
      if (firstContent is Container) {
        flowContainer = firstContent;
      } else {
        break;
      }
    }

    // Any initial tag objects count as the "main tags" associated with that story/knot/stitch
    List<String>? tags;
    for (var c in flowContainer.content) {
      var tag = ConvertTo.tag(c);
      if (tag != null) {
        tags ??= <String>[];
        tags.add(tag.text);
      } else {
        break;
      }
    }

    return tags;
  }

  /// <summary>
  /// Useful when debugging a (very short) story, to visualise the state of the
  /// story. Add this call as a watch and open the extended text. A left-arrow mark
  /// will denote the current point of the story.
  /// It's only recommended that this is used on very short debug stories, since
  /// it can end up generate a large quantity of text otherwise.
  /// </summary>
  /*virtual*/ String buildStringOfHierarchy() {
    var sb = StringBuffer();

    mainContentContainer!
        .buildStringOfHierarchy(sb, 0, state.currentPointer.resolve());

    return sb.toString();
  }

  String _buildStringOfContainer(Container container) {
    var sb = StringBuffer();

    container.buildStringOfHierarchy(sb, 0, state.currentPointer.resolve());

    return sb.toString();
  }

  void _nextContent() {
    // Setting previousContentObject is critical for VisitChangedContainersDueToDivert
    state.previousPointer = state.currentPointer;

    // Divert step?
    if (!state.divertedPointer.isNull) {
      state.currentPointer = state.divertedPointer;
      state.divertedPointer = Pointer.nullPointer;

      // Internally uses state.previousContentObject and state.currentContentObject
      _visitChangedContainersDueToDivert();

      // Diverted location has valid content?
      if (!state.currentPointer.isNull) {
        return;
      }

      // Otherwise, if diverted location doesn't have valid content,
      // drop down and attempt to increment.
      // This can happen if the diverted path is intentionally jumping
      // to the end of a container - e.g. a Conditional that's re-joining
    }

    bool successfulPointerIncrement = _incrementContentPointer();

    // Ran out of content? Try to auto-exit from a function,
    // or finish evaluating the content of a thread
    if (!successfulPointerIncrement) {
      bool didPop = false;

      if (state.callStack.CanPop(PushPopType.Function)) {
        // Pop from the call stack
        state.popCallstack(PushPopType.Function);

        // This pop was due to dropping off the end of a function that didn't return anything,
        // so in this case, we make sure that the evaluator has something to chomp on if it needs it
        if (state.inExpressionEvaluation) {
          state.pushEvaluationStack(Void());
        }

        didPop = true;
      } else if (state.callStack.canPopThread) {
        state.callStack.popThread();

        didPop = true;
      } else {
        state.tryExitFunctionEvaluationFromGame();
      }

      // Step past the point where we last called out
      if (didPop && !state.currentPointer.isNull) {
        _nextContent();
      }
    }
  }

  bool _incrementContentPointer() {
    bool successfulIncrement = true;

    var pointer = state.callStack.currentElement.currentPointer;
    pointer.index++;

    // Each time we step off the end, we fall out to the next container, all the
    // while we're in indexed rather than named content
    while (pointer.index >= pointer.container!.content.length) {
      successfulIncrement = false;

      Container? nextAncestor = pointer.container?.parent as Container?;
      if (nextAncestor == null) {
        break;
      }

      var indexInAncestor = nextAncestor.content.indexOf(pointer.container!);
      if (indexInAncestor == -1) {
        break;
      }

      pointer = Pointer.from(nextAncestor, indexInAncestor);

      // Increment to next content in outer container
      pointer.index++;

      successfulIncrement = true;
    }

    if (!successfulIncrement) pointer = Pointer.nullPointer;

    state.callStack.currentElement.currentPointer = pointer;

    return successfulIncrement;
  }

  bool _tryFollowDefaultInvisibleChoice() {
    var allChoices = _state.currentChoices;

    // Is a default invisible choice the ONLY choice?
    var invisibleChoices =
        allChoices.where((c) => c.isInvisibleDefault).toList();
    if (invisibleChoices.length == 0 ||
        allChoices.length > invisibleChoices.length) {
      return false;
    }

    var choice = invisibleChoices[0];

    // Invisible choice may have been generated on a different thread,
    // in which case we need to restore it before we continue
    state.callStack.currentThread = choice.threadAtGeneration!;

    // If there's a chance that this state will be rolled back to before
    // the invisible choice then make sure that the choice thread is
    // left intact, and it isn't re-entered in an old state.
    if (_stateSnapshotAtLastNewline != null) {
      state.callStack.currentThread = state.callStack.forkThread();
    }

    choosePath(choice.targetPath!, false);

    return true;
  }

  // Note that this is O(n), since it re-evaluates the shuffle indices
  // from a consistent seed each time.
  // TODO: Is this the best algorithm it can be?
  int _nextSequenceShuffleIndex() {
    var numElementsIntVal = state.popEvaluationStack() as IntValue;
    if (numElementsIntVal == null) {
      const FormatException(
          "expected number of elements in sequence for shuffle index");
      return 0;
    }

    var seqContainer = state.currentPointer.container;

    int numElements = numElementsIntVal.value;

    var seqCountVal = state.popEvaluationStack() as IntValue;
    var seqCount = seqCountVal.value;
    var loopIndex = seqCount / numElements;
    var iterationIndex = seqCount % numElements;

    // Generate the same shuffle based on:
    //  - The hash of this container, to make sure it's consistent
    //    each time the runtime returns to the sequence
    //  - How many times the runtime has looped around this full shuffle
    var seqPathStr = seqContainer!.path.toString();
    int sequenceHash = 0;
    for (int c in seqPathStr.runes) {
      sequenceHash += c;
    }
    var randomSeed = sequenceHash + loopIndex + state.storySeed;
    var random = Random(randomSeed.toInt());

    var unpickedIndices = <int>[];
    for (int i = 0; i < numElements; ++i) {
      unpickedIndices.add(i);
    }

    for (int i = 0; i <= iterationIndex; ++i) {
      var chosen = random.nextInt(1000000) % unpickedIndices.length;
      var chosenIndex = unpickedIndices[chosen];
      unpickedIndices.removeAt(chosen);

      if (i == iterationIndex) {
        return chosenIndex;
      }
    }

    throw const FormatException("Should never reach here");
  }

  // Throw an exception that gets caught and causes AddError to be called,
  // then exits the flow.
  void error(String message, [bool useEndLineNumber = false]) {
    var e = StoryException(message);
    e.useEndLineNumber = useEndLineNumber;
    throw e;
  }

  void warning(String message) {
    _addError(message, isWarning: true);
  }

  void _addError(String message,
      {bool isWarning = false, bool useEndLineNumber = false}) {
    var dm = _currentDebugMetadata;

    var errorTypeStr = isWarning ? "WARNING" : "ERROR";

    if (dm != null) {
      int lineNum = useEndLineNumber ? dm.endLineNumber : dm.startLineNumber;
      message =
          "RUNTIME $errorTypeStr: '${dm.fileName}' line $lineNum: $message";
    } else if (!state.currentPointer.isNull) {
      message =
          "RUNTIME $errorTypeStr: (${state.currentPointer.path}): $message";
    } else {
      message = "RUNTIME $errorTypeStr: $message";
    }

    state.addError(message, isWarning);

    // In a broken state don't need to know about any other errors.
    if (!isWarning) {
      state.forceEnd();
    }
  }

  void _assert(bool condition, [String? message, List<Object>? formatParams]) {
    if (condition == false) {
      message ??= "Story assert";
      if (formatParams != null && formatParams.isNotEmpty) {
        message = "$message $formatParams";
      }

      throw FormatException("$message $_currentDebugMetadata");
    }
  }

  DebugMetadata? get _currentDebugMetadata {
    DebugMetadata? dm;

    // Try to get from the current path first
    var pointer = state.currentPointer;
    if (!pointer.isNull) {
      dm = pointer.resolve()!.debugMetadata;
      if (dm != null) {
        return dm;
      }
    }

    // Move up callstack if possible
    for (int i = state.callStack.elements.length - 1; i >= 0; --i) {
      pointer = state.callStack.elements[i].currentPointer;
      if (!pointer.isNull && pointer.resolve() != null) {
        dm = pointer.resolve()!.debugMetadata;
        if (dm != null) {
          return dm;
        }
      }
    }

    // Current/previous path may not be valid if we've just had an error,
    // or if we've simply run out of content.
    // As a last resort, try to grab something from the output stream
    for (int i = state.outputStream.length - 1; i >= 0; --i) {
      var outputObj = state.outputStream[i];
      dm = outputObj!.debugMetadata;
      if (dm != null) {
        return dm;
      }
    }

    return null;
  }

  int get _currentLineNumber {
    var dm = _currentDebugMetadata;
    if (dm != null) {
      return dm.startLineNumber;
    }
    return 0;
  }

  Container? get mainContentContainer {
    if (_temporaryEvaluationContainer != null) {
      return _temporaryEvaluationContainer;
    } else {
      return _mainContentContainer;
    }
  }

  Container? _mainContentContainer;
  ListDefinitionsOrigin? _listDefinitions;

  late Map<String, ExternalFunctionDef> _externals;
  late Map<String, Event<StringObjectEventArgs>> _variableObservers;
  bool _hasValidatedExternals = false;

  Container? _temporaryEvaluationContainer;

  late StoryState _state;

  bool _asyncContinueActive = false;
  StoryState? _stateSnapshotAtLastNewline;
  bool _sawLookaheadUnsafeFunctionAfterNewline = false;

  int _recursiveContinueCount = 0;

  bool _asyncSaving = false;

  Profiler? _profiler;
}

/// <summary>
/// General purpose delegate definition for bound EXTERNAL function definitions
/// from ink. Note that this version isn't necessary if you have a function
/// with three arguments or less - see the overloads of BindExternalFunction.
/// </summary>
typedef ExternalFunction = Object? Function(List<Object> args);

/// <summary>
/// Delegate definition for variable observation - see ObserveVariable.
/// </summary>
// typedef VariableObserver = void Function(String variablename, Object newValue);
typedef VariableObserver = void Function(StringObjectEventArgs? args);

/// In original code this was a struct so we make a default
class ExternalFunctionDef {
  ExternalFunction? function;
  bool lookaheadSafe = false;

  ExternalFunctionDef(this.function, this.lookaheadSafe);
}

enum OutputStateChange { NoChange, ExtendedBeyondNewline, NewlineRemoved }

class StringObjectEventArgs extends EventArgs {
  String changedStringValue;
  Object? changedListValue;

  StringObjectEventArgs(this.changedStringValue, this.changedListValue);
}

class StringObjectListEventArgs extends EventArgs {
  String changedStringValue;
  List<Object> changedListValue;

  StringObjectListEventArgs(this.changedStringValue, this.changedListValue);
}

class StringObjectListStringObjectEventArgs extends EventArgs {
  String changedStringValue;
  List<Object> changedListValue;
  String changedStringTwoValue;
  Object changedObjectValue;

  StringObjectListStringObjectEventArgs(
      this.changedStringValue,
      this.changedListValue,
      this.changedStringTwoValue,
      this.changedObjectValue);
}

class ErrorHandlerEventArg extends EventArgs {
  String message;
  ErrorType type;

  ErrorHandlerEventArg(this.message, this.type);
}

class ChoiceEventArg extends EventArgs {
  Choice choice;

  ChoiceEventArg(this.choice);
}
