import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:localhand/models/friends.dart';

// 定义回调类型的别名
typedef FriendCallback = Function(FriendMsgType type, String message);

InternetAddress _mDnsAddressIPv4 = InternetAddress('224.0.0.251');
const int _port = 65000;

bool _hasMatch(String value, String pattern) {
  // ignore: unnecessary_null_comparison
  return (value == null) ? false : RegExp(pattern).hasMatch(value);
}

/// 抄的getx
extension IpString on String {
  bool get isIPv4 =>
      _hasMatch(this, r'^(?:(?:^|\.)(?:2(?:5[0-5]|[0-4]\d)|1?\d?\d)){4}$');
}

enum StandState {
  nomal, //主页面
  selfWaiting, //请求链接时
  otherWaiting, //对方请求连接
  connecting, //连接中
}

/// 通过组播+广播的方式，让设备能够相互在局域网被发现
class Multicast {
  final int port;
  late RawDatagramSocket _socket;
  late FriendCallback? friendCallback;
  StandState currentState = StandState.nomal;

  // 初始化监听和发送
  Multicast({this.port = _port, this.friendCallback}) {
    _receiveBoardCast();
    instanceSend();
  }

  /// 接收udp广播消息
  Future<void> _receiveBoardCast() async {
    RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
      reusePort: false,
      ttl: 255,
    ).then((RawDatagramSocket socket) {
      // 接收组播消息
      socket.joinMulticast(_mDnsAddressIPv4);
      // 开启广播支持
      socket.broadcastEnabled = true;
      socket.readEventsEnabled = true;
      socket.listen((RawSocketEvent rawSocketEvent) async {
        final Datagram? datagram = socket.receive();
        if (datagram == null) {
          return;
        }
        String message = utf8.decode(datagram.data);
        String address = datagram.address.address;

        bool isSelf = false;
        for (var myhost in await _localAddress()) {
          if (address == myhost) {
            isSelf = true;
            break;
          }
        }
        if (isSelf) return;

        // print(message);
        switch (message) {
          case "Stand":
            foundFromOther(address); //对方在网络搜索
            break;
          case "Connect":
            if (currentState != StandState.nomal) break;
            friendCallback!(FriendMsgType.connect, address); //对方请求连接
            break;
          case "Agree":
            if (currentState != StandState.selfWaiting) break;
            currentState = StandState.connecting;
            friendCallback!(FriendMsgType.agree, address); //对方同意连接
            break;
          case "Refuse":
            if (currentState != StandState.selfWaiting) break;
            currentState = StandState.nomal;
            friendCallback!(FriendMsgType.refuse, address); //对方拒绝连接
            return;
          case "Close":
            if (currentState == StandState.nomal) break;
            // currentState = StandState.nomal;
            // 不应该进入nomal状态，应该手动退出再改变
            friendCallback!(FriendMsgType.close, address); //关闭连接
          default:
            friendCallback!(FriendMsgType.message, message); //设备信息
            break;
        }
      });
    });
  }

  Future<String> loadLocalHost() async {
    // 获取本地主机地址
    String host = "";
    // 查询本地主机名对应的IP地址
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (var interface in interfaces) {
      for (var address in interface.addresses) {
        if (Platform.isWindows) {
          if (address.address.startsWith("192")) {
            host = address.address;
            break;
          }
        } else {
          host = address.address;
          break;
        }
      }
    }
    return host;
  }

  // 对方在搜索
  void foundFromOther(String address) async {
    // 获取设备名和设备信息
    String deviceName = "未知";
    String deviceType = "未知";
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceType = "Android";
      deviceName = androidInfo.model;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceType = "iOS";
      deviceName = iosInfo.name;
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsDeviceInfo = await deviceInfo.windowsInfo;
      deviceType = "Windows";
      deviceName = windowsDeviceInfo.computerName;
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxDeviceInfo = await deviceInfo.linuxInfo;
      deviceType = "Linux";
      deviceName = linuxDeviceInfo.name;
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macOsDeviceInfo = await deviceInfo.macOsInfo;
      deviceType = "MacOS";
      deviceName = macOsDeviceInfo.computerName;
    }

    var myaddress = await loadLocalHost();
    send(
        '{"address":"$myaddress","deviceType":"$deviceType","deviceName":"$deviceName"}',
        address);
    // print("$deviceType:$deviceName:${myaddress}");
  }

  // 发送器
  void instanceSend() async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      ttl: 255,
    );
    _socket.broadcastEnabled = true;
    _socket.readEventsEnabled = true;
  }

  // 请求连接
  void connect(String address) {
    currentState = StandState.selfWaiting;
    send("Connect", address);
  }

  // 拒绝连接
  void connectRefuse(String address) {
    currentState = StandState.nomal;
    send("Refuse", address);
  }

  // 同意连接
  void connectAgree(String address) {
    currentState = StandState.connecting;
    send("Agree", address);
  }

  // 断开连接
  void connectClose(String address) {
    currentState = StandState.nomal;
    send("Close", address);
  }

  // 单独给一个人发
  void send(String msg, String address) {
    List<int> dataList = utf8.encode(msg);
    _socket.send(dataList, InternetAddress(address), port);
  }

  // 广播
  Future<void> boardcast(String msg) async {
    List<int> dataList = utf8.encode(msg);
    _socket.send(dataList, _mDnsAddressIPv4, port);
    final List<String> address = await _localAddress();
    for (final String addr in address) {
      final tmp = addr.split('.');
      tmp.removeLast();
      final String addrPrfix = tmp.join('.');
      final InternetAddress address = InternetAddress(
        // ignore: unnecessary_string_escapes
        '$addrPrfix\.255',
      );
      // print(address.address);
      _socket.send(
        dataList,
        address,
        port,
      );
    }
  }

  Future<List<String>> _localAddress() async {
    List<String> address = [];
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final NetworkInterface netInterface in interfaces) {
      // 遍历网卡
      for (final InternetAddress netAddress in netInterface.addresses) {
        // 遍历网卡的IP地址
        if (netAddress.address.isIPv4) {
          address.add(netAddress.address);
        }
      }
    }
    return address;
  }

  // void addListener(MessageCall listener) {
  //   if (!_isStartReceive) {
  //     _receiveBoardCast();
  //     _isStartReceive = true;
  //   }
  //   _callback.add(listener);
  // }

  // void removeListener(MessageCall listener) {
  //   if (_callback.contains(listener)) {
  //     _callback.remove(listener);
  //   }
  // }
}
