import 'package:web/web.dart' as web;

String? roomFromLocation() {
  final uri = Uri.parse(web.window.location.href);
  if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'r') {
    return uri.pathSegments[1].toUpperCase();
  }
  final room = uri.queryParameters['room'];
  if (room != null && room.isNotEmpty) return room.toUpperCase();
  return null;
}
