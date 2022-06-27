part of inky;

class ListDefinitionsOrigin {

  late Map<String, ListDefinition> _lists;
  List<ListDefinition> get lists {
    var listOfLists = <ListDefinition>[];
    
    _lists.forEach((key, value) {
      listOfLists.add(value);
    });

    return listOfLists;
  }

  late Map<String?, ListValue> _allUnambiguousListValueCache;

  ListDefinitionsOrigin(List<ListDefinition> lists) {
    _lists = <String, ListDefinition>{};
    _allUnambiguousListValueCache = <String, ListValue>{};

    for (var list in lists) {
      _lists[list.name] = list;

      list.items.forEach((item, val) {
        var listValue = ListValue.fromItem(item, val);

        // May be ambiguous, but compiler should've caught that,
        // so we may be doing some replacement here, but that's okay.
        _allUnambiguousListValueCache[item.itemName.toString()] = listValue;
        _allUnambiguousListValueCache[item.fullName] = listValue;
      });
    }
  }

  ListDefinition? tryListGetDefinition(String name) {
    return _lists[name];
  }

  ListValue? findSingleItemListWithName(String? name) {
    return _allUnambiguousListValueCache[name];
  }
}
