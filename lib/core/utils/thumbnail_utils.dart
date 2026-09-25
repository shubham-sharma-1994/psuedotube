/// Safe URL lookup for thumbnail lists coming from YouTube / YT Music.
///
/// Some items (episodes, uploads, cached entries) arrive with an empty
/// thumbnail list; `.first` / `.last` on those throws and takes down the
/// whole screen, so every UI lookup should go through here.
String thumbUrl(Iterable<dynamic>? thumbnails, {bool last = false}) {
  if (thumbnails == null || thumbnails.isEmpty) return '';
  final dynamic thumbnail = last ? thumbnails.last : thumbnails.first;
  final dynamic url = thumbnail?.url;
  return url is String ? url : '';
}
