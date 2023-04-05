class Tools {

  static List<String> convertDynamicList(List<dynamic>? datas) {
    if (datas == null || datas.isEmpty) {
      return [];
    }
    List<String> list = [];
    for (var element in datas) {
      list.add(element);
    }
    return list;
  }
}