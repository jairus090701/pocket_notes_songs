/// A single song record. Table name: songs
/// Fields besides id: title, artist.
class Song {
  final int? id; // auto-increment, null until inserted
  final String title;
  final String artist;

  const Song({this.id, required this.title, required this.artist});

  /// Object -> row. We leave id out when it is null so SQLite assigns it.
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'artist': artist,
      };

  /// Row -> object.
  factory Song.fromMap(Map<String, Object?> map) => Song(
        id: map['id'] as int,
        title: map['title'] as String,
        artist: map['artist'] as String,
      );
}
