library inky;

import 'dart:collection';
// import 'dart:io'; // Used below for manual testing
import 'dart:math';

import 'package:stack/stack.dart';
import 'package:event/event.dart';

part 'bad_cast_exception.dart';
part 'call_stack.dart';
part 'choice.dart';
part 'container.dart';
part 'control_command.dart';
part 'glue.dart';
part 'ink_list.dart';
part 'ink_object.dart';
part 'i_named_content.dart';
part 'key_value_pair.dart';
part 'list_definition.dart';
part 'list_definition_origin.dart';
part 'path.dart';
part 'pointer.dart';
part 'profiler.dart';
part 'push_pop.dart';
part 'search_result.dart';
part 'simple_json.dart';
part 'story.dart';
part 'story_exception.dart';
part 'string_ext.dart';
part 'value.dart';
part 'value_holder.dart';
part 'flow.dart';
part 'json_serialisation.dart';
part 'error.dart'; // TODO move to other package
part 'story_state.dart';
part 'variables_state.dart';
part 'state_patch.dart';
part 'debug_metadata.dart';
part 'variable_assignment.dart';
part 'tag.dart';
part 'void.dart';
part 'choice_point.dart';
part 'divert.dart';
part 'native_function_call.dart';
part 'variable_reference.dart';
part 'convert_to.dart';

// void main() {
//   File('fileName')
//       .readAsString()
//       .then((value) {
//     _story = Story.fromJson(value);
//     tryReadStory(value);
//   });
// }

// Story? _story;
// void tryReadStory(String value) {
//   while (_story!.canContinue) {
//     print(_story!.Continue());
//   }

//   if (_story!.currentChoices.isNotEmpty) {
//     for (var element in _story!.currentChoices) {
//       print("Choice: ${element.text}");
//     }
//     _story!.chooseChoiceIndex(0);
//     tryReadStory(value);
//   }
// }
