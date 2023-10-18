import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';

class FavGroupsPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => FavGroupsPageState();
}

class FavGroupsPageState extends State<FavGroupsPage> {
  List<String> favGroupIds = [];

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Fav group count: ${favGroupIds.length}'),);
  }

  @override
  void initState() {
    Imclient.getFavGroups().then((groupIds) {
      if(groupIds != null) {
        setState(() {
          favGroupIds = groupIds;
        });
      }
    });
  }
}