// ignore_for_file: file_names
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// 定义回调类型的别名
typedef CountdownCallback = Function();

class CountdownBottomSheet extends StatefulWidget {
  final CountdownCallback? onCountdownEnd;
  const CountdownBottomSheet({super.key, this.onCountdownEnd});

  @override
  // ignore: library_private_types_in_public_api
  _CountdownBottomSheetState createState() => _CountdownBottomSheetState();
}

class _CountdownBottomSheetState extends State<CountdownBottomSheet>
    with SingleTickerProviderStateMixin {
  int _counter = 60; // 倒计时
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_counter > 0 && mounted) {
        setState(() {
          _counter--;
        });
      } else {
        timer.cancel();
        widget.onCountdownEnd?.call(); // 触发回调
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height / 2,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("等待接受", style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color.fromARGB(255, 216, 216, 216), width: 10),
              ),
              alignment: Alignment.center,
              child: Stack(
                // 使用 Stack 来组合多个子元素
                children: <Widget>[
                  Center(
                    // 将 CustomPaint 居中显示
                    child: CustomPaint(
                      size: const Size(150, 150), // 设置 CustomPaint 的大小
                      painter: AnimatedCircleSectorPainter(_counter, context),
                    ),
                  ),
                  Center(
                    // 将 Text 居中显示
                    child: Text(
                      _counter.toString(),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                widget.onCountdownEnd?.call();
              }, // 触发回调,
              label: Text(
                "取消",
                style: TextStyle(color: Colors.red[400], fontSize: 16),
              ),
              icon: Icon(
                Icons.cancel,
                color: Colors.red[400],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class AnimatedCircleSectorPainter extends CustomPainter {
  final int timer; // Timer value in seconds
  final BuildContext context;

  AnimatedCircleSectorPainter(this.timer, this.context);

  @override
  void paint(Canvas canvas, Size size) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final Paint sectorPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final double radius =
        (size.width < size.height) ? size.width / 2 : size.height / 2;

    // 计算扇形的角度
    final double angle = timer / 60 * 360;

    // 绘制扇形
    final Rect rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2), radius: radius + 5);
    canvas.drawArc(rect, -pi / 2, angle * pi / 180, false, sectorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is AnimatedCircleSectorPainter) {
      return timer != oldDelegate.timer;
    }
    return true;
  }
}
