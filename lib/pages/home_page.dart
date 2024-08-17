import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:localhand/pages/hand_page.dart';
import 'package:flutter/cupertino.dart';

import '../components/ConnectByOtherBottomSheet.dart';
import '../components/ConnectBySelfBottomSheet.dart';
import '../multicast.dart';
import '../models/friends.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  final ValueNotifier<bool> isClose = ValueNotifier(false);
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String myHost = "未连接";
  String message = "none";
  late Multicast multicast;

  @override
  void initState() {
    super.initState();
    multicast = Multicast(friendCallback: (FriendMsgType type, String message) {
      switch (type) {
        case FriendMsgType.message: //设备信息
          final friendsClass = context.read<Friends>();
          var decoded = jsonDecode(message);
          friendsClass.addFriend(
              decoded["address"], decoded["deviceName"], decoded["deviceType"]);
          break;

        case FriendMsgType.connect: //请求连接
          var address = message;
          final friendsClass = context.read<Friends>();
          Friend? theFriend = friendsClass.getFriendByAddress(address);
          if (theFriend != null) {
            message =
                "${theFriend.deviceName} · ${theFriend.deviceType} · ${theFriend.address}";
          } else {
            message = "未知 · 未知 · $address";
          }
          // 弹出是否接受
          showModalBottomSheet(
            isDismissible: false, // 禁止点击背景关闭 BottomSheet
            context: context,
            builder: (context) => ConnectByOtherBottomSheet(
              onRefuse: () {
                Navigator.pop(context);
                multicast.connectRefuse(address);
              },
              onAgree: () {
                multicast.connectAgree(address);
                joinHandPage(address, context);
              },
              message: message,
            ),
          );
          break;
        case FriendMsgType.agree: //对方同意
          var address = message;
          joinHandPage(address, context);
          break;
        case FriendMsgType.refuse: //对方拒绝
          Navigator.pop(context);
          break;
        case FriendMsgType.close: //断开应该提示断开连接
          widget.isClose.value = true;
          break;
        default:
          break;
      }
    });

    showMyIp();
  }

  void joinHandPage(String address, BuildContext context) {
    widget.isClose.value = false;
    Navigator.pop(context);
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => HandPage(
            isClose: widget.isClose,
            title: getTitleByAddress(address),
            address: address,
            myDispose: () => multicast.connectClose(address)),
        // 这里传递了数据
      ),
    );
  }

  String getTitleByAddress(String address) {
    final friendsClass = context.read<Friends>();
    Friend? theFriend = friendsClass.getFriendByAddress(address);
    if (theFriend != null) {
      message =
          "${theFriend.deviceName} · ${theFriend.deviceType} · ${theFriend.address}";
    } else {
      message = "未知 · 未知 · $address";
    }
    return message;
  }

  void showMyIp() async {
    var host = await multicast.loadLocalHost();
    setState(() {
      myHost = host;
    });
  }

  void sendConnect(String address) {
    multicast.connect(address); //进入等待状态
    showModalBottomSheet(
      isDismissible: false, // 禁止点击背景关闭 BottomSheet
      context: context,
      builder: (context) => CountdownBottomSheet(onCountdownEnd: () {
        Navigator.pop(context);
        multicast.connectRefuse(address); //取消状态
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Consumer<Friends>(
        builder: (context, value, child) => Scaffold(
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            appBar: AppBar(
              //不需要返回按钮
              automaticallyImplyLeading: false,
              leading: IconButton(
                  onPressed: () {
                    multicast.boardcast("Stand");
                  },
                  icon: const Icon(Icons.refresh)),
              title: Column(
                children: [
                  const Text("设备列表",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    "本机 $myHost",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              centerTitle: true,
              elevation: 0, // 设置AppBar的阴影高度为0
              backgroundColor: colorScheme.primary, // 设置背景颜色
              foregroundColor: colorScheme.onPrimary, // 设置文字颜色
            ),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 搜索
                // Container(
                //     margin: const EdgeInsets.all(10),
                //     padding: const EdgeInsets.symmetric(horizontal: 20),
                //     decoration: BoxDecoration(
                //       border: Border.all(color: colorScheme.primary, width: 1),
                //       borderRadius: BorderRadius.circular(50),
                //     ),
                //     child: const TextField(
                //       decoration: InputDecoration(
                //         border: InputBorder.none, // 隐藏TextField自带的边框
                //         hintText: '搜索',
                //       ),
                //     )),
                // Container(
                //   height: 10,
                //   color: Colors.grey[200],
                // ),
                value.friends.isEmpty
                    ? Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.track_changes,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const Text(
                              "暂无设备\n请启动其他设备然后刷新",
                              textAlign: TextAlign.center
                            ),
                            IconButton(
                              onPressed: () {
                                multicast.boardcast("Stand");
                              },
                              icon: const Icon(Icons.refresh),
                              color: colorScheme.primary,
                            ),
                          ],
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: value.friends.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      getIconForDeviceType(
                                          value.friends[index].deviceType),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(value.friends[index].deviceName,
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  color: colorScheme.primary)),
                                          Text(
                                              "IP  ${value.friends[index].address}"),
                                        ],
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                      onPressed: () => sendConnect(
                                          value.friends[index].address),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.join_inner),
                                          Text("连接")
                                        ],
                                      ))
                                ],
                              ),
                            );
                          },
                        ),
                      )
              ],
            )));
  }

  Widget getIconForDeviceType(String deviceType) {
    switch (deviceType) {
      case "Android":
        return const Icon(Icons.android, color: Colors.green);
      case "iOS":
      case "MacOS":
        return Icon(Icons.apple, color: Colors.red[300],);
      case "Windows":
        return const Icon(Icons.window, color: Colors.blue);
      case "Linux":
        return const Icon(Icons.computer, color: Colors.purple);
      default:
        return const Icon(Icons.device_unknown, color: Colors.yellow);
    }
  }
}
