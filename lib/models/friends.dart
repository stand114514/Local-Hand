import 'package:flutter/cupertino.dart';

class Friend {
  String address;
  String deviceName;
  String deviceType;

  Friend(this.address, this.deviceName, this.deviceType);
}

class Friends extends ChangeNotifier {
  // 将列表转换为字典
  Map<String, Friend> friendsMap = {};

  List<Friend> get friends {
    return friendsMap.values.toList();
  }

  void addFriend(String address, String deviceName, String deviceType) {
    var newFriend = Friend(address, deviceName, deviceType);
    if(!friendsMap.containsKey(address)) friendsMap[address] = newFriend;
    notifyListeners(); // 通知监听器
  }

  Friend? getFriendByAddress(String address) => friendsMap[address];
}

enum FriendMsgType {
  // ignore: constant_identifier_names
  agree,
  refuse,
  message,
  connect,
  close
}
