class Tools {

  static List<String> convertDynamicList(List<dynamic> datas) {
    if (datas == null || datas.isEmpty) {
      return new List();
    }
    List<String> list = new List();
    datas.forEach((element) {
      list.add(element);
    });
    return list;
  }
}