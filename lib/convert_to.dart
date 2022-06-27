part of inky;

class ConvertTo {
//Could be this. Used as var c = Convert<Container>.convert(obj);
//   class Convert<T> {
//   T? convert(c) {
//     try {
//       return c as T?;
//     } on TypeError catch (e) {
//       return null;
//     }
//   }
// }

  static INamedContent? iNamedContent(c) {
    try {
      return c as INamedContent?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static Container? container(c) {
    try {
      return c as Container?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static Divert? divert(c) {
    try {
      return c as Divert?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static ChoicePoint? choicePoint(c) {
    try {
      return c as ChoicePoint?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static VariablePointerValue? variablePointerValue(c) {
    try {
      return c as VariablePointerValue?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static Value? value(c) {
    try {
      return c as Value?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static BoolValue? boolValue(c) {
    try {
      return c as BoolValue?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static IntValue? intValue(c) {
    try {
      return c as IntValue?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static FloatValue? floatValue(c) {
    try {
      return c as FloatValue?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static StringValue? stringValue(c) {
    try {
      return c as StringValue?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static ListValue? listValue(c) {
    try {
      return c as ListValue?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static DivertTargetValue? divertTargetValue(c) {
    try {
      return c as DivertTargetValue?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static ControlCommand? controlCommand(c) {
    try {
      return c as ControlCommand?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static Glue? glue(c) {
    try {
      return c as Glue?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static Tag? tag(c) {
    try {
      return c as Tag?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static InkObject? inkObject(c) {
    try {
      return c as InkObject?;
    } on TypeError catch (e) {
      return null;
    }
  }

  static Component? component(c) {
    try {
      return c as Component?;
    } on TypeError catch (e) {
      return null;
    }
  }
}
