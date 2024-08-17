import 'package:flutter/material.dart';
import 'package:localhand/models/friends.dart';
import 'package:localhand/pages/home_page.dart';
import 'package:provider/provider.dart';

void main() async {
  // 监听数据源
  runApp(ChangeNotifierProvider(
      create: (context) => Friends(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: "SourceHanSansCN",
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 95, 127, 255)),
        popupMenuTheme: const PopupMenuThemeData(
            color: Color.fromARGB(255, 255, 255, 255) // 修改菜单背景颜色
            ),
      ),
      home: HomePage(),
    );
  }
}
