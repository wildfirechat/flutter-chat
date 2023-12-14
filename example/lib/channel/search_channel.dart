import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/user_info_widget.dart';

import '../config.dart';
import '../channel/channel_info_widget.dart';

class SearchChannelDelegate extends SearchDelegate<String> {
  SearchChannelDelegate() : super(searchFieldLabel: "请输入频道名称");

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(onPressed: (){
        query = "";
        showSuggestions(context);
      }, icon: const Icon(Icons.clear)),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
          icon: AnimatedIcons.menu_arrow, progress: transitionAnimation),
      onPressed: () {
        if (query.isEmpty) {
          close(context, "");
        } else {
          query = "";
          showSuggestions(context);
        }
      },
    );
  }

  Future<List<ChannelInfo>> searchChannelsInServer() async {
    if(query.isEmpty) {
      return [];
    }

    List<ChannelInfo> us = [];
    bool finish = false;

    Imclient.searchChannel(query, (channelInfos) {
      us = channelInfos;
      finish = true;
    }, (errorCode) {
      finish = true;
    });

    while(!finish) {
      await Future.delayed(const Duration(microseconds: 100));
    }
    return us;
  }

  late List<ChannelInfo> searchedChannels;


  Widget _buildRow(BuildContext context, int index) {
    ChannelInfo channelInfo = searchedChannels[index];
    return GestureDetector(
      child: Column(children: [
        Row(
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 4), child: SizedBox(width: 40, height: 40, child: (channelInfo.portrait == null || channelInfo.portrait!.isEmpty)?Image.asset(Config.defaultChannelPortrait, width: 40.0, height: 40.0):Image.network(channelInfo.portrait!, width: 40, height: 40,),),),
            Expanded(child: Text(channelInfo.name!)),
          ],
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 4.0),
          height: 1,
          color: const Color(0xffebebeb),
        ),
      ],),
      onTap: () => _toChannelInfoView(context, channelInfo),
    );
  }

  void _toChannelInfoView(BuildContext context, ChannelInfo channelInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChannelInfoWidget(channelInfo)),
    );
  }
  
  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<ChannelInfo>>(
        future: searchChannelsInServer(),
        builder: (context, snapshot) {
          if(snapshot.connectionState == ConnectionState.done) {
            if(snapshot.data!.isEmpty) {
              return const Center(child: Text("没有找到呀，是不是输入的频道名称不对？"),);
            } else {
              searchedChannels = snapshot.data!;
              return ListView.builder(
                itemCount: searchedChannels.length,
                itemBuilder: (context, index) => _buildRow(context, index),
              );
            }
          }
          return const Center(child: CircularProgressIndicator(),);
        }
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if(query.isNotEmpty) {
      return Container();
    } else {
      return Container(
        margin: const EdgeInsets.all(16),
        child: const Text("搜索频道！"),
      );
    }
  }
}