// ignore_for_file: file_names
// 消息块
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import '../http/StandHttpServer.dart';

class MessageWidget extends StatelessWidget {
  final String message;
  final String path;
  final StandType type;
  final double progress;

  const MessageWidget(
      {super.key,
      required this.message,
      required this.path,
      required this.type,
      required this.progress});

  void upProgress(double progress) {}

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    IconData icon = Icons.file_copy;
    switch (type) {
      case StandType.audio:
        icon = Icons.music_note;
        break;
      case StandType.image:
        icon = Icons.photo;
        break;
      case StandType.video:
        icon = Icons.videocam;
        break;
      case StandType.document:
        icon = Icons.insert_drive_file;
        break;
      case StandType.program:
        icon = Icons.build;
        break;
      case StandType.other:
      default:
        icon = Icons.file_copy;
        break;
    }

    Widget messageWidget = Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300), // 应用 maxWidth 约束
        child: Text(
          message,
          // overflow: TextOverflow.clip,
          maxLines: null,
        ),
      ),
    );

    if (type != StandType.text) {
      messageWidget = GestureDetector(
          onTap: openFile // 打开文件
          ,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180), // 应用 maxWidth 约束
            child: Text(
              message,
              // overflow: TextOverflow.clip,
              maxLines: null,
              style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: colorScheme.primary),
            ),
          ));
    }

    return Container(
      padding: const EdgeInsets.all(8),
      constraints:
          const BoxConstraints(minWidth: 30, maxWidth: 240, minHeight: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: GestureDetector(
        onLongPressStart: (details) => onLongPress(context, details), //长按复制
        child: Column(
          children: [
            if (type != StandType.text)
              LinearProgressIndicator(
                value: progress, // 设置进度值
                backgroundColor: Colors.grey[300], // 设置背景颜色
                valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary), // 设置进度条的颜色
              ),
            if (type != StandType.text)
              const SizedBox(
                height: 8,
              ),
            if (type == StandType.image && progress == 1)
              Image.file(
                File(path),
                fit: BoxFit.cover,
              ),
            Row(
              children: [
                if (type != StandType.text)
                  Icon(icon, size: 20), // 显示图标，除非类型为text
                if (type != StandType.text) const SizedBox(width: 8),
                messageWidget,
              ],
            ),
          ],
        ),
      ),
    );
  }

  void openFile() async {
    await OpenFile.open(path);
  }

  // 长按菜单
  void onLongPress(BuildContext context, LongPressStartDetails details) async {
    List<PopupMenuEntry<String>> items = [
      const PopupMenuItem<String>(
        value: 'copyMsg',
        child: Text('复制消息文字'),
      ),
    ];

    if (path != "" && path != " ") {
      items.add(
        const PopupMenuItem<String>(
          value: 'copyPath',
          child: Text('复制完整路径'),
        ),
      );

      // 安卓用不了不知道为啥
      if (Platform.isWindows) {
        items.add(
          const PopupMenuItem<String>(
            value: 'openFolder',
            child: Text('打开文件位置'),
          ),
        );
      }
    }

    final result = await showMenu<String>(
      // ignore: use_build_context_synchronously
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: items,
    );

    if (result == 'copyMsg') {
      Clipboard.setData(ClipboardData(text: message));
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文字已复制到剪贴板')),
      );
    } else if (result == 'copyPath') {
      Clipboard.setData(ClipboardData(text: path));
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('路径已复制到剪贴板')),
      );
    } else if (result == 'openFolder') {
      // 查找最后一个斜杠的位置
      // print(path);
      int lastSlashIndex = path.lastIndexOf('/');
      if (lastSlashIndex == -1) {
        lastSlashIndex = path.lastIndexOf('\\');
      }
      var folderPath = path.substring(0, lastSlashIndex);
      await OpenFile.open(folderPath);
    }
  }
}
