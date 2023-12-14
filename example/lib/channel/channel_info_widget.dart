import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';

class ChannelInfoWidget extends StatefulWidget {
  final ChannelInfo channelInfo;

  ChannelInfoWidget(this.channelInfo, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ChannelInfoWidgetState();
}

class ChannelInfoWidgetState extends State<ChannelInfoWidget> {
  bool isLoading = true;
  bool isListened = false;

  @override
  void initState() {
    super.initState();
    Imclient.isListenedChannel(widget.channelInfo.channelId).then((value) {
      setState(() {
        isLoading = false;
        isListened = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("频道信息"),),
      body: SafeArea(child:
      isLoading ? const Center(child: CircularProgressIndicator(),) :
      ListView.builder(
        itemCount: 6, //头像，名字，拥有者，描述，清空消息，操作（订阅/取消订阅）
        itemBuilder: (BuildContext context, int index) { return _buildRow(context, index);},)
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    if(index == 0) {
      return Column(children: [
        SizedBox(width: 48, height: 48, child: Image.network(widget.channelInfo.portrait!),),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        )
      ],);
    } else if(index == 1) {
      return Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          const Text("名称:", style: TextStyle(fontSize: 16),),
          Text(widget.channelInfo.name!, style: const TextStyle(fontSize: 16),),
        ],),),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        ),
      ],);
    } else if(index == 2) {
      return Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          const Text("拥有者:", style: TextStyle(fontSize: 16),),
          Text(widget.channelInfo.owner!, style: const TextStyle(fontSize: 16),),
        ],),),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        ),
      ],);
    } else if(index == 3) {
      return Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          const Text("描述:", style: TextStyle(fontSize: 16),),
          Text(widget.channelInfo.desc!, style: const TextStyle(fontSize: 16),),
        ],),),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        ),
      ],);
    } else if(index == 4) {
      return GestureDetector(
        child: Column(children: [
          const SizedBox(
            height: 36,
            child: Center(child: Text("清空历史消息", style: TextStyle(color: Colors.red, fontSize: 16),)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xdbdbdbdb),
          ),
        ],),
        onTap: () {},
      );
    } else if(index == 5) {
      return GestureDetector(
        child: Column(children: [
          SizedBox(
            height: 36,
            child: Center(child: Text(isListened?"取消订阅":"订阅频道", style: const TextStyle(color: Colors.red, fontSize: 16),)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xdbdbdbdb),
          ),
        ],),
        onTap: () {
            Imclient.listenChannel(widget.channelInfo.channelId, !isListened, () {
              setState(() {
                isListened = !isListened;
              });
            }, (errorCode) {
              Fluttertoast.showToast(msg: "网络错误！");
            });
        },
      );
    }
    return Container();
  }
}