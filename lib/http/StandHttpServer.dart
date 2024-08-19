// ignore_for_file: file_names
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

enum StandType { image, audio, document, video, program, other, text }

class StandFile {
  String filename;
  String filePath;
  StandType fileType;

  StandFile(this.filename, this.filePath, this.fileType);
}

class StandHttpServer {
  HttpServer? _server;
  final Function(StandFile standFile) receiveFileCallback; // 收到文件
  final Function(int index) receiveFileEndCallback; // 收到文件
  final Function(String message) receiveMsgCallback; // 收到消息
  Function(double progress, int index) onUpload;

  StandHttpServer(this.receiveFileCallback, this.receiveFileEndCallback,
      this.receiveMsgCallback, this.onUpload) {
    startServer();
  }

  void startServer() {
    // print("Start Http");
    HttpServer.bind(InternetAddress("0.0.0.0"), 65001, shared: true)
        .then((server) {
      _server = server;
      server.listen((HttpRequest request) async {
        if (request.method == 'POST') {
          // 处理文件上传
          if (request.uri.path == '/upload') {
            await handleFileUpload(request);
          } else if (request.uri.path == '/sendmsg') {
            handleMessage(request);
          }
        } else {
          request.response.write("Hello!");
        }
        await request.response.close();
      });
    });
  }

  /// 关闭HTTP服务器
  void closeServer() {
    _server?.close();
  }

  // 收到消息
  void handleMessage(HttpRequest request) async {
    try {
      // 读取请求体数据
      final content = await utf8.decoder.bind(request).join();
      receiveMsgCallback(content);

      // 回应客户端
      // request.response
      //     ..statusCode = HttpStatus.ok
      //     ..write('successfully!');
    } catch (e) {
      print('Error: $e');
    }
    await request.response.close();
  }

  Future<void> handleFileUpload(HttpRequest request) async {
    if (!request.headers.contentType!.mimeType
        .startsWith('multipart/form-data')) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Unsupported content type');
      await request.response.close();
      return;
    }

    // 解析多部分请求
    final boundary = request.headers.contentType!.parameters['boundary']!;
    final transformer = MimeMultipartTransformer(boundary);
    final bodyStream = request.cast<List<int>>().transform(transformer);

    int totalBytes = request.contentLength;
    int receivedBytes = 0;
    int index = 0;
    bool isStart = false;

    await for (final part in bodyStream) {
      final contentDisposition = part.headers['content-disposition'];

      if (contentDisposition != null &&
          contentDisposition.contains('filename=')) {
        String filename = "";
        filename = RegExp(r'filename="([^"]+)"')
            .firstMatch(contentDisposition)!
            .group(1)!;

        // final directory = Directory.current;
        final Directory? downloadsDir = await getDownloadsDirectory();
        // final getfilesDir = Directory('${downloadsDir?.path}/loaclhand');
        // print(getfilesDir.path);

        String filePath = '${downloadsDir?.path}/$filename';
        if (Platform.isAndroid) {
          filePath = await _getFilePath(filename);
        }

        if (!isStart) {
          index = receiveFileCallback(
              StandFile(filename, filePath, getFileType(filename)));
          isStart = true;
        }

        final file = File(filePath);
        final sink = file.openWrite();

        await for (var data in part) {
          sink.add(data);
          receivedBytes += data.length;
          double progress = (receivedBytes / totalBytes);
          onUpload(progress, index); //更新进度
          // print('Progress: $progress%');
        }

        await sink.close();

        receiveFileEndCallback(index); //进度条完

        request.response
          ..statusCode = HttpStatus.ok
          ..write('File "$filename" uploaded successfully!');
        await request.response.close();

        return;
      }
    }

    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('No file uploaded');
    await request.response.close();
  }
}

// 根据文件扩展名判断文件类型
StandType getFileType(String filename) {
  final extension = filename.split('.').last.toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'bmp':
      return StandType.image;
    case 'mp3':
    case 'wav':
    case 'aac':
    case 'flac':
      return StandType.audio;
    case 'txt':
    case 'pdf':
    case 'doc':
    case 'docx':
    case 'xls':
    case 'xlsx':
    case 'ppt':
    case 'pptx':
      return StandType.document;
    case 'mp4':
    case 'avi':
    case 'mkv':
    case 'mov':
      return StandType.video;
    case 'exe':
    case 'dll':
    case 'so':
    case 'jar':
      return StandType.program;
    default:
      return StandType.other;
  }
}

Future<String> _getFilePath(String fileName) async {
  var dir = Directory('/storage/emulated/0/Download/LocalHand');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  print("File Name: ${dir.path}/$fileName");
  return "${dir.path}/$fileName";
}
