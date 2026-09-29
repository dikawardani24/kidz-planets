/// Fields whose Indonesian value is correctly identical to the English one.
///
/// Indonesian astronomy keeps the Latin spelling of planet and moon names, so
/// "Mars" is Mars and "Io" is Io. The genuine exceptions are the three whose
/// everyday Indonesian word differs: the Sun is Matahari, the Earth is Bumi,
/// and the Moon is Bulan.
///
/// Listed rather than inferred because a general "is it still English?" check
/// would otherwise flag all of these. Kept in a helper so both translation
/// test files can consult one list, and self-checked by
/// `translation_integrity_test.dart` so an entry cannot outlive the row it was
/// written for.
const allowedIdenticalNames = {
  'venus', 'mars', 'jupiter', 'uranus', // planets, Latin spelling
  'deimos', 'io', 'europa', 'ganymede', 'titan', 'enceladus', 'mimas',
  'tethys', 'iapetus', 'miranda', 'ariel', 'umbriel', 'titania', 'oberon',
  'triton', // moons, Latin spelling
  // Phobos is Fobos and Callisto is Kallisto in Indonesian, so they are
  // translated and deliberately absent here.
};

/// Same, for hotspot titles that are official place names.
const allowedIdenticalHotspotTitles = {'mars/olympus_mons'};
