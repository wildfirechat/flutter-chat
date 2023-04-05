class Tools {

  static List<String>? convertDynamicList(List<dynamic>? datas) {
    if (datas == null || datas.isEmpty) {
      return [];
    }
    List<String> list = [];
    datas.forEach((element) {
      list.add(element);
    });
    return list;
  }
}