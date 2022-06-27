part of inky;

class ListDefinition {
  final String _name;
  String get name => _name;

  Map<InkListItem, int>? _items;
  Map<InkListItem, int> get items {
    if (_items == null) {
      _items = <InkListItem, int>{};
      _itemNameToValues.forEach((key, value) {
        var item = InkListItem(name, key);
        _items![item] = value;
      });
    }
    return _items!;
  }

  // The main representation should be simple item names rather than a RawListItem,
  // since we mainly want to access items based on their simple name, since that's
  // how they'll be most commonly requested from ink.
  final Map<String, int> _itemNameToValues;

  int valueForItem(InkListItem item) {
    return _itemNameToValues[item.itemName] ?? 0;
  }

  bool containsItem(InkListItem item) {
    if (item.originName != name) return false;

    return _itemNameToValues.containsKey(item.itemName);
  }

  bool containsItemWithName(String itemName) {
    return _itemNameToValues.containsKey(itemName);
  }

  ValueHolder<InkListItem> tryGetItemWithValue(int val, /* out */ InkListItem item) {
    ValueHolder<InkListItem>? returnable;

    var found = false;

    _itemNameToValues.forEach((key, value) {
      if (value == val && found == false) {
        item = InkListItem(name, key);
        returnable = ValueHolder<InkListItem>(item, true);
        found = true;
      }
    });

    return found ? returnable! : ValueHolder(InkListItem.nullListItem, false);
  }

  ValueHolder tryGetValueForItem(InkListItem item, /*out*/ int intVal) {
    int? newVal = _itemNameToValues[item.itemName];

    if (newVal == null) {
      return ValueHolder(newVal, true);
    }

    return ValueHolder(intVal, false);
  }

  ListDefinition(this._name, this._itemNameToValues);
}
