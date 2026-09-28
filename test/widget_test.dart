import 'package:flutter_test/flutter_test.dart';
import 'package:chat_niu/main.dart';
import 'package:chat_niu/services/chat_settings.dart';

void main() {
  testWidgets('shows the chat welcome screen', (tester) async {
    await tester.pumpWidget(const ChatNiuApp(settings: ChatSettings()));

    expect(find.text('Chat Niu'), findsOneWidget);
    expect(find.text('今天有什么可以帮你？'), findsOneWidget);
    expect(find.text('输入消息，或点麦克风开始语音输入'), findsOneWidget);
  });
}
