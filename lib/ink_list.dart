part of inky;

/// <summary>
/// The underlying type for a list item in ink. It stores the original list definition
/// name as well as the item name, but without the value of the item. When the value is
/// stored, it's stored in a KeyValuePair of InkListItem and int.
/// </summary>
/// In original code this was a struct so we make a default
class InkListItem {
  /// <summary>
  /// The name of the list where the item was originally defined.
  /// </summary>
  String? originName;

  /// <summary>
  /// The main name of the item as defined in ink.
  /// </summary>
  final String? itemName;

  /// <summary>
  /// Create an item with the given original list definition name, and the name of this
  /// item.
  /// </summary>
  InkListItem([this.originName, this.itemName]);

  /// <summary>
  /// Create an item from a dot-separted String of the form "listDefinitionName.listItemName".
  /// </summary>
  InkListItem.from(fullName) 
    : originName = fullName.split('.')[0],
    itemName = fullName.split('.')[1];


  static InkListItem get nullListItem => InkListItem(null, null);

  bool get isNull => originName == null && itemName == null;

  /// <summary>
  /// Get the full dot-separated name of the item, in the form "listDefinitionName.itemName".
  /// </summary>
  String get fullName => "${originName ?? "?"}.$itemName";

  /// <summary>
  /// Get the full dot-separated name of the item, in the form "listDefinitionName.itemName".
  /// Calls fullName internally.
  /// </summary>
  @override
  String toString() {
    return fullName;
  }

  /// <summary>
  /// Is this item the same as another item?
  /// </summary>
  @override
  bool operator ==(Object? obj)
  {
    if (obj is InkListItem) {
      var otherItem = obj;
      return otherItem.itemName   == itemName
        && otherItem.originName == originName;
    }

      return false;
  }

  /// <summary>
  /// Get the hashcode for an item.
  /// </summary>
  @override
  int get hashCode
  {
      int originCode = 0;
      int itemCode = itemName!.hashCode;
      if (originName != null) {
        originCode = originName.hashCode;
      }

      return originCode + itemCode;
  }
}

/// <summary>
/// The InkList is the underlying type that's used to store an instance of a
/// list in ink. It's not used for the *definition* of the list, but for a list
/// value that's stored in a variable.
/// Somewhat confusingly, it's backed by a C# Dictionary, and has nothing to
/// do with a C# List!
/// </summary>
class InkList implements Map<InkListItem, int> {
  final Map<InkListItem, int> _map = {};

  /// <summary>
  /// Create a new empty ink list.
  /// </summary>
  InkList();

  /// <summary>
  /// Create a new ink list that contains the same contents as another list.
  /// </summary>
  InkList.from(InkList otherList) {
    _originNames = otherList.originNames;

    origins = List<ListDefinition>.from(otherList.origins);
  }

  /// <summary>
  /// Create a new empty ink list that's intended to hold items from a particular origin
  /// list definition. The origin Story is needed in order to be able to look up that definition.
  /// </summary>
  InkList.fromOrigin(String singleOriginListName, Story originStory) {
    setInitialOriginName(singleOriginListName);

    ListDefinition? def =
        originStory.listDefinitions!.tryListGetDefinition(singleOriginListName);

    if (def != null) {
      origins = <ListDefinition>[def];
    } else {
      throw FormatException(
          "InkList origin could not be found in story when constructing new list: $singleOriginListName");
    }
  }

  InkList.fromItem(KeyValuePair<InkListItem, int> singleElement) {
    addAll({singleElement.key: singleElement.value});
  }

  /// <summary>
  /// Converts a String to an ink list and returns for use in the story.
  /// </summary>
  /// <returns>InkList created from String list item</returns>
  /// <param name="itemKey">Item key.</param>
  /// <param name="originStory">Origin story.</param>
  static InkList fromString(String myListItem, Story originStory) {
    var listValue =
        originStory.listDefinitions!.findSingleItemListWithName(myListItem);
    if (listValue == null) {
      return InkList.from(listValue!.value);
    } else {
      throw FormatException(
          "Could not find the InkListItem from the String '$myListItem' to create an InkList because it doesn't exist in the original list definition in ink.");
    }
  }

  /// <summary>
  /// Adds the given item to the ink list. Note that the item must come from a list definition that
  /// is already "known" to this list, so that the item's value can be looked up. By "known", we mean
  /// that it already has items in it from that source, or it did at one point - it can't be a
  /// completely fresh empty list, or a list that only contains items from a different list definition.
  /// </summary>
  void addItem(InkListItem item) {
    // check for item nullness?
    if (item.originName == null) {
      addItemWithName(item.itemName!);
      return;
    }

    for (var origin in origins) {
      if (origin?.name == item.originName) {
        int intVal = 0;
        ValueHolder returnedVal = origin!.tryGetValueForItem(item, intVal);
        if (returnedVal.exists) {
          this[item] = returnedVal.value;
          return;
        } else {
          throw FormatException(
              "Could not add the item $item to this list because it doesn't exist in the original list definition in ink.");
        }
      }
    }

    throw const FormatException(
        "Failed to add item to list because the item was from a new list definition that wasn't previously known to this list. Only items from previously known lists can be used, so that the int value can be found.");
  }

  /// <summary>
  /// Adds the given item to the ink list, attempting to find the origin list definition that it belongs to.
  /// The item must therefore come from a list definition that is already "known" to this list, so that the
  /// item's value can be looked up. By "known", we mean that it already has items in it from that source, or
  /// it did at one point - it can't be a completely fresh empty list, or a list that only contains items from
  /// a different list definition.
  /// </summary>
  void addItemWithName(String itemName) {
    ListDefinition? foundListDef;

    for (var origin in origins) {
      if (origin?.containsItemWithName(itemName) != null) {
        if (foundListDef != null) {
          throw FormatException(
              "Could not add the item $itemName to this list because it could come from either ${origin!.name} or ${foundListDef.name}");
        } else {
          foundListDef = origin;
        }
      }
    }

    if (foundListDef == null) {
      throw FormatException(
          "Could not add the item $itemName to this list because it isn't known to any list definitions previously associated with this list.");
    }

    var item = InkListItem(foundListDef.name, itemName);
    var itemVal = foundListDef.valueForItem(item);
    this[item] = itemVal;
  }

  /// <summary>
  /// Returns true if this ink list contains an item with the given short name
  /// (ignoring the original list where it was defined).
  /// </summary>
  bool containsItemNamed(String itemName) {
    for (var entry in entries) {
      if (entry.key.itemName == itemName) return true;
    }
    return false;
  }

  // Story has to set this so that the value knows its origin,
  // necessary for certain operations (e.g. interacting with ints).
  // Only the story has access to the full set of lists, so that
  // the origin can be resolved from the originListName.
  late List<ListDefinition?> origins;
  ListDefinition? get originOfMaxItem {
    if (origins == null) return null;

    var maxOriginName = maxItem.key.originName;
    for (var origin in origins) {
      if (origin?.name == maxOriginName) {
        return origin;
      }
    }

    return null;
  }

  // Origin name needs to be serialised when content is empty,
  // assuming a name is availble, for list definitions with variable
  // that is currently empty.
  List<String>? get originNames {
    if (isNotEmpty) {
      if (_originNames == null) {
        _originNames = <String>[];
      } else {
        _originNames!.clear();
      }

      for (var itemAndValue in entries) {
        _originNames!.add(
            itemAndValue.key.originName.toString()); // null will become "null"
      }
    }

    return _originNames;
  }

  List<String>? _originNames;

  void setInitialOriginName(String initialOriginName) {
    _originNames = <String>[initialOriginName];
  }

  void setInitialOriginNames(List<String>? initialOriginNames) {
    if (initialOriginNames == null) {
      _originNames = null;
    } else {
      _originNames = List<String>.from(initialOriginNames);
    }
  }

  /// <summary>
  /// Get the maximum item in the list, equivalent to calling LIST_MAX(list) in ink.
  /// </summary>
  KeyValuePair<InkListItem, int> get maxItem {
    MapEntry<InkListItem, int> max = MapEntry(InkListItem.nullListItem, 0);

    for (var kv in entries) {
      if (max.key.isNull || kv.value > max.value) {
        max = kv;
      }
    }
    return KeyValuePair(max.key, max.value);
  }

  /// <summary>
  /// Get the minimum item in the list, equivalent to calling LIST_MIN(list) in ink.
  /// </summary>
  KeyValuePair<InkListItem, int> get minItem {
    MapEntry<InkListItem, int> min = MapEntry(InkListItem.nullListItem, 0);

    for (var kv in entries) {
      if (min.key.isNull || kv.value < min.value) {
        min = kv;
      }
    }
    return KeyValuePair(min.key, min.value);
  }

  /// <summary>
  /// The inverse of the list, equivalent to calling LIST_INVERSE(list) in ink
  /// </summary>
  InkList get inverse {
    var list = InkList();

    for (var origin in origins) {
      if (origin != null) {
        for (var itemAndValue in origin.items.entries) {
          if (!containsKey(itemAndValue.key)) {
            list[itemAndValue.key] = itemAndValue.value;
          }
        }
      }
    }

    return list;
  }

  /// <summary>
  /// The list of all items from the original list definition, equivalent to calling
  /// LIST_ALL(list) in ink.
  /// </summary>
  InkList get all {
    var list = InkList();

    for (var origin in origins) {
      if (origin != null) {
        for (var itemAndValue in origin.items.entries) {
          list[itemAndValue.key] = itemAndValue.value;
        }
      }
    }
    return list;
  }

  void add(InkListItem key, int value) {
    if (containsKey(key)) {
      throw ArgumentException(key);
    } else {
      this[key] = value;
    }
  }

  /// <summary>
  /// Returns a new list that is the combination of the current list and one that's
  /// passed in. Equivalent to calling (list1 + list2) in ink.
  /// </summary>
  InkList union(InkList otherList) {
    var union = InkList.from(this);
    for (var kv in otherList.entries) {
      union[kv.key] = kv.value;
    }
    return union;
  }

  /// <summary>
  /// Returns a new list that is the intersection of the current list with another
  /// list that's passed in - i.e. a list of the items that are shared between the
  /// two other lists. Equivalent to calling (list1 ^ list2) in ink.
  /// </summary>
  InkList intersect(InkList otherList) {
    var intersection = InkList();
    for (var kv in entries) {
      if (otherList.containsKey(kv.key)) {
        intersection.add(kv.key, kv.value);
      }
    }
    return intersection;
  }

  /// <summary>
  /// Returns a new list that's the same as the current one, except with the given items
  /// removed that are in the passed in list. Equivalent to calling (list1 - list2) in ink.
  /// </summary>
  /// <param name="listToRemove">List to remove.</param>
  InkList without(InkList listToRemove) {
    var result = InkList.from(this);
    for (var kv in listToRemove.entries) {
      result.remove(kv.key);
    }
    return result;
  }

  /// <summary>
  /// Returns true if the current list contains all the items that are in the list that
  /// is passed in. Equivalent to calling (list1 ? list2) in ink.
  /// </summary>
  /// <param name="otherList">Other list.</param>
  bool contains(InkList otherList) {
    for (var kv in otherList.entries) {
      if (!containsKey(kv.key)) return false;
    }
    return true;
  }

  /// <summary>
  /// Returns true if all the item values in the current list are greater than all the
  /// item values in the passed in list. Equivalent to calling (list1 > list2) in ink.
  /// </summary>
  bool greaterThan(InkList otherList) {
    if (isEmpty) return false;
    if (otherList.isEmpty) return true;

    // All greater
    return minItem.value > otherList.maxItem.value;
  }

  /// <summary>
  /// Returns true if the item values in the current list overlap or are all greater than
  /// the item values in the passed in list. None of the item values in the current list must
  /// fall below the item values in the passed in list. Equivalent to (list1 >= list2) in ink,
  /// or LIST_MIN(list1) >= LIST_MIN(list2) &amp;&amp; LIST_MAX(list1) >= LIST_MAX(list2).
  /// </summary>
  bool greaterThanOrEquals(InkList otherList) {
    if (isEmpty) return false;
    if (otherList.isEmpty) return true;

    return minItem.value >= otherList.minItem.value &&
        maxItem.value >= otherList.maxItem.value;
  }

  /// <summary>
  /// Returns true if all the item values in the current list are less than all the
  /// item values in the passed in list. Equivalent to calling (list1 &lt; list2) in ink.
  /// </summary>
  bool lessThan(InkList otherList) {
    if (otherList.isEmpty) return false;
    if (isEmpty) return true;

    return maxItem.value < otherList.minItem.value;
  }

  /// <summary>
  /// Returns true if the item values in the current list overlap or are all less than
  /// the item values in the passed in list. None of the item values in the current list must
  /// go above the item values in the passed in list. Equivalent to (list1 &lt;= list2) in ink,
  /// or LIST_MAX(list1) &lt;= LIST_MAX(list2) &amp;&amp; LIST_MIN(list1) &lt;= LIST_MIN(list2).
  /// </summary>
  bool lessThanOrEquals(InkList otherList) {
    if (otherList.isEmpty) return false;
    if (isEmpty) return true;

    return maxItem.value <= otherList.maxItem.value &&
        minItem.value <= otherList.minItem.value;
  }

  InkList maxAsList() {
    if (length > 0) {
      return InkList.fromItem(maxItem);
    } else {
      return InkList();
    }
  }

  InkList minAsList() {
    if (length > 0) {
      return InkList.fromItem(minItem);
    } else {
      return InkList();
    }
  }

  /// <summary>
  /// Returns a sublist with the elements given the minimum and maxmimum bounds.
  /// The bounds can either be ints which are indices into the entire (sorted) list,
  /// or they can be InkLists themselves. These are intended to be single-item lists so
  /// you can specify the upper and lower bounds. If you pass in multi-item lists, it'll
  /// use the minimum and maximum items in those lists respectively.
  /// WARNING: Calling this method requires a full sort of all the elements in the list.
  /// </summary>
  InkList listWithSubRange(Object minBound, Object maxBound) {
    if (isEmpty) return InkList();

    var ordered = orderedItems;

    int minValue = 0;
    int maxValue = double.maxFinite as int;

    if (minBound is int) {
      minValue = minBound;
    } else {
      if (minBound is InkList && minBound.isNotEmpty) {
        minValue = (minBound).minItem.value;
      }
    }

    if (maxBound is int) {
      maxValue = maxBound;
    } else {
      if (minBound is InkList && minBound.isNotEmpty) {
        // TODO maybe a bug? should be maxbound
        maxValue = (maxBound as InkList).maxItem.value;
      }
    }

    var subList = InkList();
    subList.setInitialOriginNames(originNames);
    for (var item in ordered) {
      if (item.value >= minValue && item.value <= maxValue) {
        subList.add(item.key, item.value);
      }
    }

    return subList;
  }

  /// <summary>
  /// Returns true if the passed object is also an ink list that contains
  /// the same items as the current list, false otherwise.
  /// </summary>
  // override bool Equals (object other)
  // {
  //     var otherRawList = other as InkList;
  //     if (otherRawList == null) return false;
  //     if (otherRawList.Count != Count) return false;

  //     foreach (var kv in this) {
  //         if (!otherRawList.ContainsKey (kv.Key)) {
  //           return false;
  //         }
  //     }

  //     return true;
  // }

  /// <summary>
  /// Return the hashcode for this object, used for comparisons and inserting into dictionaries.
  /// </summary>
  // override int GetHashCode ()
  // {
  //     int ownHash = 0;
  //     foreach (var kv in this)
  //         ownHash += kv.Key.GetHashCode ();
  //     return ownHash;
  // }

  List<KeyValuePair<InkListItem, int>> get orderedItems {
    var ordered = <KeyValuePair<InkListItem, int>>[];

    // Add all
    for (var entry in entries) {
      ordered.add(KeyValuePair(entry.key, entry.value));
    }

    ordered.sort((x, y) {
      // Ensure consistent ordering of mixed lists.
      if (x.value == y.value) {
        //TODO make this exactly like c# ordering
        return x.key.originName.toString().toLowerCase().compareTo(y
            .key.originName
            .toString()
            .toLowerCase()); // to avoid nulls // toLowercase helps match c# ordering
      } else {
        return x.value.compareTo(y.value);
      }
    });
    return ordered;
  }

  /// <summary>
  /// Returns a String in the form "a, b, c" with the names of the items in the list, without
  /// the origin list definition names. Equivalent to writing {list} in ink.
  /// </summary>
  @override
  String toString() {
    var ordered = orderedItems;

    var sb = StringBuffer();
    for (int i = 0; i < ordered.length; i++) {
      if (i > 0) {
        sb.write(", ");
      }

      var item = ordered[i].key;
      sb.write(item.itemName);
    }

    return sb.toString();
  }

  @override
  int? operator [](Object? key) {
    return _map[key];
  }

  @override
  void operator []=(InkListItem key, int value) {
    _map[key] = value;
  }

  @override
  void clear() {
    _map.clear();
  }

  @override
  Iterable<InkListItem> get keys => _map.keys;

  @override
  int? remove(Object? key) {
    return _map.remove(key);
  }

  @override
  void addAll(Map<InkListItem, int> other) {
    _map.addAll(other);
  }

  @override
  void addEntries(Iterable<MapEntry<InkListItem, int>> newEntries) {
    _map.addEntries(newEntries);
  }

  @override
  Map<RK, RV> cast<RK, RV>() {
    return _map.cast<RK, RV>();
  }

  @override
  bool containsKey(Object? key) {
    return _map.containsKey(key);
  }

  @override
  bool containsValue(Object? value) {
    return _map.containsValue(value);
  }

  @override
  Iterable<MapEntry<InkListItem, int>> get entries => _map.entries;

  @override
  void forEach(void Function(InkListItem key, int value) action) {
    _map.forEach(action);
  }

  @override
  bool get isEmpty => _map.isEmpty;

  @override
  bool get isNotEmpty => _map.isNotEmpty;

  @override
  int get length => _map.length;

  @override
  Map<K2, V2> map<K2, V2>(
      MapEntry<K2, V2> Function(InkListItem key, int value) convert) {
    return _map.map(convert);
  }

  @override
  int putIfAbsent(InkListItem key, int Function() ifAbsent) {
    return _map.putIfAbsent(key, ifAbsent);
  }

  @override
  void removeWhere(bool Function(InkListItem key, int value) test) {
    _map.removeWhere(test);
  }

  @override
  int update(InkListItem key, int Function(int value) update,
      {int Function()? ifAbsent}) {
    return _map.update(key, update);
  }

  @override
  void updateAll(int Function(InkListItem key, int value) update) {
    _map.updateAll(update);
  }

  @override
  Iterable<int> get values => _map.values;
}

class ArgumentException implements Exception {
  final Object key;

  /// <summary>
  /// Constructs a default instance of an ArgumentException
  /// </summary>
  ArgumentException(this.key);

  @override
  String toString() =>
      'ArgumentException: An element with the same key already exists in the $key';
}
