import 'package:flutter/material.dart';
import 'page_b.dart'; // Import file B

class PageA extends StatelessWidget {
  const PageA({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang A')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Đi đến trang B'),
          onPressed: () async {
            // Gửi dữ liệu và chờ nhận lại phản hồi
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PageB(dataFromA: 'Xin chào từ A'),
              ),
            );

            // Nhận lại dữ liệu từ trang B
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Nhận từ B: $result')),
              );
            }
          },
        ),
      ),
    );
  }
}
