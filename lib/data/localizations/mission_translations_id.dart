/// Copy for one mission in one language.
///
/// Nullable per field so a partial translation fills the
/// gaps from English rather than leaving a mission card with a blank clue.
///
/// Deliberately not an Equatable value: it is a const table, never compared.
class MissionCopy {
  const MissionCopy({
    this.title,
    this.description,
    this.startPoint,
    this.direction,
    this.hints,
  });

  final String? title;
  final String? description;
  final String? startPoint;
  final String? direction;

  /// Replaces the whole list rather than merging, so a mission cannot end up
  /// mixing Indonesian clues with an English fallback mid-list.
  final List<String>? hints;
}

/// Indonesian copy for the four missions.
///
/// `test/mission_translations_test.dart` checks every field is present, that
/// each still has three escalating clues, and that nothing is left in English.
const Map<int, MissionCopy> missionCopyId = {
  1: MissionCopy(
    title: 'Temukan Planet Bumi',
    description: 'Mulai dari Matahari lalu hitung ke luar sampai di rumah kita yang biru.',
    startPoint: 'Matahari',
    direction: 'Hitung ke luar dari Matahari',
    hints: [
      'Cari dunia berwarna biru dengan lautan yang jernih dan daratan yang tampak.',
      'Hitung ke luar dari Matahari: Merkurius, Venus, lalu Bumi. Bumi planet ketiga.',
      'Itu yang berwarna biru dan hijau berkilau, dan satu-satunya dunia tempat kita tinggal.',
    ],
  ),
  2: MissionCopy(
    title: 'Temukan Mars',
    description: 'Cari planet batu kecil yang warnanya kemerahan.',
    startPoint: 'Matahari',
    direction: 'Hitung ke luar',
    hints: [
      'Cari dunia batu kecil yang warnanya kemerah-merahan.',
      'Hitung ke luar dari Matahari dan planet ini datang tepat setelah Bumi.',
      'Itu planet merah berdebu, dengan ngarai raksasa dan gunung berapi tertinggi yang kami tahu.',
    ],
  ),
  3: MissionCopy(
    title: 'Temukan Saturnus',
    description: 'Temukan planet yang dikelilingi sistem cincin yang terang.',
    startPoint: 'Matahari',
    direction: 'Hitung ke luar',
    hints: [
      'Cari planet dengan sistem cincin yang spektakuler.',
      'Hitung ke luar dari Matahari dan itu planet ke enam, sedikit lewat dari Jupiter.',
      'Itu planet keemasan, dan cincin yang terang membuatnya mudah dilihat dari jauh.',
    ],
  ),
  4: MissionCopy(
    title: 'Kunjungi Jupiter',
    description: 'Temukan planet raksasa dengan badai yang terkenal.',
    startPoint: 'Matahari',
    direction: 'Hitung ke luar',
    hints: [
      'Cari planet terbesar dengan badai raksasa.',
      'Hitung ke luar dari Matahari dan itu planet ke lima, sedikit sebelum Saturnus.',
      'Itu planet terbesar, dan Bercak Merah Besar-nya adalah badai yang lebih lebar dari Bumi.',
    ],
  ),
};
