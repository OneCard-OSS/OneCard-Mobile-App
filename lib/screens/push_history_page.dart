import 'package:flutter/material.dart';
import '../deeplink_page.dart';

class PushHistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final Function(int) onDeleteMessage;
  final VoidCallback onClearAll;

  const PushHistoryPage({
    super.key,
    required this.messages,
    required this.onDeleteMessage,
    required this.onClearAll,
  });

  @override
  State<PushHistoryPage> createState() => _PushHistoryPageState();
}

class _PushHistoryPageState extends State<PushHistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 수신 리스트'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (widget.messages.isNotEmpty)
            IconButton(
              onPressed: () {
                _showClearAllDialog();
              },
              icon: const Icon(Icons.delete_sweep),
              tooltip: '전체 삭제',
            ),
        ],
      ),
      body: widget.messages.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '아직 수신된 알림이 없어요.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: Dismissible(
                    key: Key('message_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await _showDeleteDialog(index);
                    },
                    onDismissed: (direction) {
                      widget.onDeleteMessage(index);
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.black,
                        child: const Icon(
                          Icons.notifications,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        message['title'] ?? '제목 없음',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            message['content'] ?? '내용 없음',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          if (message['service_name'] != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.business, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  '서비스: ${message['service_name']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (message['emp_no'] != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.person, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '사번: ${message['emp_no']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${message['timestamp']?.toString().substring(0, 19) ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          if (message['url'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.link, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Deep Link: ${message['url']}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _showDeleteDialog(index),
                      ),
                      onTap: message['url'] != null
                          ? () => _handleDeepLinkTap(message['url'])
                          : null,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<bool?> _showDeleteDialog(int index) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('메시지 삭제', style: TextStyle(color: Colors.black)),
          content: const Text(
            '이 푸시 알림을 삭제하시겠습니까?',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('전체 삭제', style: TextStyle(color: Colors.black)),
          content: const Text(
            '모든 푸시 알림 내역을 삭제하시겠습니까?',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onClearAll();
                Navigator.of(context).pop(); // 내역 화면도 닫기
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('전체 삭제'),
            ),
          ],
        );
      },
    );
  }

  void _handleDeepLinkTap(String deepLinkUrl) {
    // DeepLink 처리 로직 (main.dart의 로직과 동일)
    try {
      debugPrint('Deep link tapped: $deepLinkUrl');
      
      final uri = Uri.parse(deepLinkUrl);
      if (uri.scheme == 'onecard' && uri.host == 'auth') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DeepLinkPage(
              url: deepLinkUrl,
              params: uri.queryParameters,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('지원하지 않는 링크 형식입니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling deep link tap: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('링크 처리 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
