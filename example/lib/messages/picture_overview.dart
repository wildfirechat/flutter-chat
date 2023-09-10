import 'package:flutter/material.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:photo_view/photo_view_gallery.dart';

typedef PageToEnd = void Function(int messageId, bool tail);

class PictureOverview extends StatefulWidget {
  final List<Message> imageItems; //图片列表
  final int defaultIndex; //默认第几张
  final PageToEnd? pageToEnd; //切换图片回调
  final Axis direction; //图片查看方向
  final BoxDecoration? decoration; //背景设计

  const PictureOverview(
      this.imageItems,
      {Key? key,  this.defaultIndex = 1,
        this.pageToEnd,
        this.direction = Axis.horizontal,
        this.decoration})
      : assert(imageItems != null), super(key: key);

  @override
  State<PictureOverview> createState() => PictureOverviewState();
}

class PictureOverviewState extends State<PictureOverview> {
  late int currentIndex;
  @override
  void initState() {
    super.initState();
    // TODO: implement initState
    currentIndex = widget.defaultIndex;
  }

  void onLoadMore(List<Message> moreItems, bool front) {
    setState(() {
      if(front) {
        moreItems.addAll(widget.imageItems);
        widget.imageItems.clear();
      }
      widget.imageItems.addAll(moreItems);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          Container(
              child: PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (BuildContext context, int index) {
                    Message message = widget.imageItems[index];
                    String url = (message.content as ImageMessageContent).remoteUrl!;
                    return PhotoViewGalleryPageOptions(
                      imageProvider: NetworkImage(url),
                    );
                  },
                  scrollDirection: widget.direction,
                  itemCount: widget.imageItems.length,
                  backgroundDecoration:
                  widget.decoration ?? const BoxDecoration(color: Colors.black),
                  pageController:
                  PageController(initialPage: widget.defaultIndex),
                  onPageChanged: (index) => setState(() {
                    currentIndex = index;
                    if (widget.pageToEnd != null) {
                      Message message = widget.imageItems[index];
                      if(index == 0) {
                        widget.pageToEnd!(message.messageId!, false);
                      } else if(index == widget.imageItems.length -1) {
                        widget.pageToEnd!(message.messageId!, true);
                      }
                    }
                  }))),
          Positioned(
            bottom: 20,
            child: Container(
                alignment: Alignment.center,
                width: MediaQuery.of(context).size.width,
                child: Text("${currentIndex + 1}/${widget.imageItems.length}",
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      shadows: [
                        Shadow(color: Colors.black, offset: Offset(1, 1)),
                      ],
                    ))),
          ),
          Positioned(//右上角关闭
            top: 60,
            right: 40,
            child: Container(
              alignment: Alignment.centerLeft,
              width: 20,
              child: GestureDetector(
                onTap: () {
                  //隐藏预览
                  Navigator.pop(context);
                },
                child: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
          Positioned(//数量显示
            right: 20,
            top: 20,
            child: Text(
              '${currentIndex + 1}/${widget.imageItems.length}',
              style: const TextStyle(color: Colors.black),
            ),
          )
        ],
      ),
    );
  }
}
