import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:localhand/http/StandHttpClient.dart';
import 'package:localhand/http/StandHttpServer.dart'; // 掌管时间的包

import '../components/MessageWidget.dart';

enum MessageCenter { left, right }

class StandMessage {
  String time;
  String message;
  String path;
  StandType type;
  MessageCenter center;
  double progress;

  StandMessage(this.time, this.message, this.path, this.type, this.center,
      this.progress);
}

class HandPage extends StatefulWidget {
  final ValueNotifier<bool> isClose;
  final String title, address;
  final Function myDispose;

  const HandPage(
      {super.key,
      required this.isClose,
      required this.title,
      required this.address,
      required this.myDispose});

  @override
  State<HandPage> createState() => _HandPageState();
}

class _HandPageState extends State<HandPage> {
  final ScrollController _scrollController = ScrollController();
  final List<StandMessage> _messages = [];
  late StandHttpServer _standHttpServer;
  late StandHttpClient _standHttpClient;

  // 获取当前时间
  String getCurrentTime() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    return formatter.format(now);
  }

  @override
  void initState() {
    _standHttpServer = StandHttpServer(
        receiveFile, receiveFileEnd, receiveMsg, onUpload); //页面打开时启动http
    _standHttpClient = StandHttpClient(widget.address, sendSucess, onUpload);
    super.initState();
  }

  @override
  void dispose() {
    _standHttpServer.closeServer(); //页面退出时关闭http
    widget.myDispose();
    _scrollController.dispose();
    super.dispose();
  }

  int sendSucess(String message, StandType type, String path) {
    setState(() {
      _messages.add(StandMessage(
          getCurrentTime(), message, path, type, MessageCenter.right, 0));
    });
    scrollToBottom();
    return _messages.length - 1;
  }

  void onUpload(double progress, int index) {
    setState(() {
      _messages[index].progress = progress;
    });
    // print(progress);
  }

  // 收到文件
  int receiveFile(StandFile standFile) {
    setState(() {
      _messages.add(StandMessage(getCurrentTime(), standFile.filename,
          standFile.filePath, standFile.fileType, MessageCenter.left, 0));
    });
    scrollToBottom();
    return _messages.length - 1;
  }

  // 文件完成
  receiveFileEnd(int index) {
    setState(() {
      _messages[index].progress = 1;
    });
    scrollToBottom();
  }

  // 收到消息
  receiveMsg(String message) {
    setState(() {
      _messages.add(StandMessage(getCurrentTime(), message, "", StandType.text,
          MessageCenter.left, 0));
    });
    scrollToBottom();
  }

  // 滚动到底部
  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextEditingController textEditingController = TextEditingController();
    bool canClose = false;

    // 发送文件
    void sendFile() async {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null || result!.files.isNotEmpty) {
          String? path = result.files[0].path;
          _standHttpClient.uploadFile(path!, result.files[0].name);
        }
      } catch (e) {
        // ignore: avoid_print
        print(e);
      }
    }

    // 发送消息
    void sendMsg() {
      if (textEditingController.text == "") return;
      // print(textEditingController.text);
      _standHttpClient.sendMsg(textEditingController.text);
      textEditingController.clear();
    }

    return Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              const Text(
                '传输',
                style: TextStyle(fontSize: 18),
              ),
              Text(
                widget.title,
                style: const TextStyle(fontSize: 12),
              )
            ],
          ),
          centerTitle: true,
          backgroundColor: colorScheme.primary, // 设置背景颜色
          foregroundColor: colorScheme.onPrimary, // 设置文字颜色
        ),
        body: PopScope(
          //拦截弹窗
          canPop: canClose,
          onPopInvokedWithResult: (bool canPop, dynamic) async {
            if (canPop) return;
            final shouldPop = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("提示"),
                content: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.orange[300],
                    ),
                    const Text('是否退出界面并断开连接?'),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      '确认',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                ],
              ),
            );

            if (shouldPop == true) {
              canClose = true;
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
            }
          },
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey[200],
                  child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Align(
                          alignment:
                              _messages[index].center == MessageCenter.left
                                  ? Alignment.topLeft
                                  : Alignment.topRight,
                          child: Column(
                            crossAxisAlignment:
                                _messages[index].center == MessageCenter.left
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                            children: [
                              Text(
                                _messages[index].time,
                                style: const TextStyle(fontSize: 12),
                              ), //时间
                              const SizedBox(height: 3),
                              IntrinsicWidth(
                                child: MessageWidget(
                                    message: _messages[index].message,
                                    path: _messages[index].path,
                                    type: _messages[index].type,
                                    progress: _messages[index].progress),
                              ),
                              const SizedBox(height: 10)
                            ],
                          ),
                        );
                      }),
                ),
              ),
              // 断开连接
              ValueListenableBuilder<bool>(
                  valueListenable: widget.isClose,
                  builder: (context, value, child) {
                    if (value) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.not_interested, color: Colors.red),
                            Text(
                              "对方已关闭连接",
                              style: TextStyle(
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return const SizedBox();
                    }
                  }),
              Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: TextField(
                            controller: textEditingController,
                            decoration: const InputDecoration.collapsed(
                              hintText: '发送消息...',
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: sendFile,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: colorScheme.primary,
                      ),
                      onPressed: sendMsg,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
