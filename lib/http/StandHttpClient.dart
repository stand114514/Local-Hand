// ignore_for_file: file_names
import 'package:dio/dio.dart';
import 'StandHttpServer.dart';

class StandHttpClient {
  final String address;
  Function(String message, StandType type, String path) sendSucess;
  Function(double progress, int index) onUpload;

  late String fileURL, msgURL;
  StandHttpClient(this.address, this.sendSucess, this.onUpload) {
    fileURL = "http://$address:65001/upload";
    msgURL = "http://$address:65001/sendmsg";
  }

  Future<void> uploadFile(String filePath, String filename) async {
    Dio dio = Dio();
    try {
      int index = sendSucess(filename, getFileType(filePath), filePath);
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });

      // ignore: unused_local_variable
      var response = await dio.post(
        fileURL,
        data: formData,
        onSendProgress: (int sent, int total) {
          double progress = (sent / total) ;
          // print('Progress: $progress%');
          onUpload(progress, index); //显示进度
        },
      );

    } catch (e) {
      print('错误: $e');
    }
  }

  void sendMsg(String msg) async {
    // print(msg);
    Dio dio = Dio();

    try {
      // ignore: unused_local_variable
      var res = await dio.post(
        msgURL,
        data: msg,
      );

      sendSucess(msg, StandType.text, " ");
    } catch (e) {
      print('错误: $e');
    }
  }
}
