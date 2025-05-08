import 'package:flutter/material.dart';

class PageB extends StatelessWidget {
  final String dataFromA;

  const PageB({super.key, required this.dataFromA});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang B')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Nhận từ A: $dataFromA'),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Gửi lại dữ liệu về A'),
              onPressed: () {
                Navigator.pop(context, 'Xin chào lại từ B');
              },
            )
          ],
        ),
      ),
    );
  }
}
