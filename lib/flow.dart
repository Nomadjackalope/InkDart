part of inky;

class Flow {
  String? name;
  late CallStack callStack;
  late List<InkObject> outputStream;
  late List<Choice> currentChoices;

  // Flow(String name, Story story) {
  //     this.name = name;
  //     this.callStack =CallStack(story);
  //     this.outputStream = <Object>();
  //     this.currentChoices = <Choice>();
  // }

  Flow(String name, Story story, {Map<String, Object>? jObject}) {
    name = name;
    callStack = CallStack(story);

    if (jObject == null) {
      outputStream = <InkObject>[];
      currentChoices = <Choice>[];
    } else {
      callStack.setJsonToken(
          jObject["callstack"] as Map<String, Object>, story);
      outputStream =
          Json.jArrayToRuntimeObjList(jObject["outputStream"] as List<Object>);
      currentChoices = Json.jArrayToRuntimeObjList<Choice>(
          jObject["currentChoices"] as List<Object>);

      // choiceThreads is optional
      Object? jChoiceThreadsObj = jObject["choiceThreads"];
      loadFlowChoiceThreads(jChoiceThreadsObj as Map<String, Object>?, story);
    }
  }

  void writeJson(Writer writer) {
    writer.writeObjectStart();

    writer.writeProperty("callstack", callStack.writeJson);
    writer.writeProperty(
        "outputStream", (w) => Json.writeListRuntimeObjs(w, outputStream));

    // choiceThreads: optional
    // Has to come BEFORE the choices themselves are written out
    // since the originalThreadIndex of each choice needs to be set
    bool hasChoiceThreads = false;
    for (Choice c in currentChoices) {
      c.originalThreadIndex = c.threadAtGeneration!.threadIndex;

      if (callStack.threadWithIndex(c.originalThreadIndex) == null) {
        if (!hasChoiceThreads) {
          hasChoiceThreads = true;
          writer.writePropertyStart("choiceThreads");
          writer.writeObjectStart();
        }

        writer.writePropertyStart(c.originalThreadIndex);
        c.threadAtGeneration!.writeJson(writer);
        writer.writePropertyEnd();
      }
    }

    if (hasChoiceThreads) {
      writer.writeObjectEnd();
      writer.writePropertyEnd();
    }

    writer.writeProperty("currentChoices", (w) {
      w.writeArrayStart();
      for (var c in currentChoices) {
        Json.writeChoice(w, c);
      }
      w.writeArrayEnd();
    });

    writer.writeObjectEnd();
  }

  // Used both to load old format and current
  void loadFlowChoiceThreads(Map<String, Object>? jChoiceThreads, Story story) {
    for (var choice in currentChoices) {
      var foundActiveThread =
          callStack.threadWithIndex(choice.originalThreadIndex);
      if (foundActiveThread != null) {
        choice.threadAtGeneration = foundActiveThread.copy();
      } else {
        var jSavedChoiceThread =
            jChoiceThreads?[choice.originalThreadIndex.toString()]
                as Map<String, Object>;
        choice.threadAtGeneration = Thread.from(jSavedChoiceThread, story);
      }
    }
  }
}
