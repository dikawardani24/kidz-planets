import 'planet_copy.dart';

/// Indonesian copy for the solar-system catalogue.
///
/// Every body in `PlanetCatalog.planets` and every hotspot needs a row here,
/// and `test/planet_translations_test.dart` fails if one is missing or if a
/// row still holds the English text.
///
/// English stays on the entity itself so a locale with no row yet renders in
/// English rather than blank.
const Map<String, PlanetCopy> planetCopyId = {
  'sun': PlanetCopy(
    name: 'Matahari',
    tag: 'Bintang Berpijar Kita',
    fact:
        'Matahari menyimpan 99,8% dari seluruh massa Tata Surya. Intinya '
        'berpanas pada suhu 15 juta derajat Celsius, menyatukan hidrogen '
        'menjadi helium.',
    narration:
        'Wah! Inilah Matahari. Ini bintang terdekat kita, dan benda '
        'terang di langit kita. Lihat seberapa besar dan menyalanya. Jauh di '
        'dalamnya, Matahari sibuk menyatukan hidrogen, dan proses itu '
        'menghasilkan banyak cahaya dan panas. Panas itulah yang membuat Bumi '
        'cukup hangat untuk kita hidup. Bisa kamu melihat titik-titik kecil di '
        'permukaannya? Itu adalah bintik matahari, dan mereka datang lalu '
        'pergi.',
    hotspots: {
      'nuclear_fusion': HotspotCopy(
        title: 'Fusi Nuklir',
        description: 'Setiap detik Matahari menyatukan 600 juta ton hidrogen.',
        narration:
            'Ini luar biasa. Setiap detik, Matahari menghimpun sekitar '
            'enam ratus juta ton hidrogen dan mengubahnya menjadi helium. '
            'Ilmuwan menyebutnya fusi nuklir. Reaksi inilah yang juga '
            'menggerakkan bintang-bintang. Matahari sudah melakukannya selama '
            'miliaran tahun.',
      ),
      'solar_wind': HotspotCopy(
        title: 'Angin Matahari',
        description:
            'Partikel bermuatan terbang keluar dan melukis aurora di kutub.',
        narration:
            'Matahari tidak hanya bersinar. Matahari meniupkan '
            'partikel kecil bermuatan, jauh melewati Bumi. Kami menyebutnya '
            'angin matahari. Ketika partikel itu bertemu langit kami di '
            'kutub, mereka melukis cahaya berkilau yang kamu lihat di utara. '
            'Namanya aurora.',
      ),
    },
  ),
  'mercury': PlanetCopy(
    name: 'Merkurius',
    tag: 'Pelari Kelabu yang Kilat',
    fact:
        'Merkurius adalah planet terkecil, melayang mengelilingi Matahari '
        'hanya dalam 88 hari.',
    narration:
        'Planet kecil ini adalah Merkurius. Ini planet terkecil di Tata '
        'Surya kita, dan yang paling dekat dengan Matahari. Bisa kamu melihat '
        'betapa berbatu dan kelabu warnanya? Itu karena nyaris tidak ada udara '
        'yang menutupinya. Ini juga planet tercepat, melayang mengelilingi '
        'Matahari hanya dalam delapan puluh delapan hari.',
    hotspots: {
      'speedy_orbit': HotspotCopy(
        title: 'Orbit Tercepat',
        description: 'Satu tahun yang_pendek hanya 88 hari Bumi.',
        narration:
            'Merkurius adalah planet kecil yang paling cepat. Ia '
            'melayang mengelilingi Matahari hanya dalam delapan puluh delapan '
            'hari Bumi. Itu kurang dari tiga bulan. Karena sangat dekat dengan '
            'Matahari, ia bergerak lebih cepat daripada planet mana pun.',
      ),
      'cratered_face': HotspotCopy(
        title: 'Wajah Berlubang',
        description: 'Tanpa udara, setiap benturan meninggalkan bekas.',
        narration:
            'Lihatlah Merkurius dengan saksama dan kamu akan melihat '
            'banyak lubuk. Itu adalah tempat batu dan komet telah menghantam '
            'permukaannya. Di Bumi, sebagian besar lubuk terkikis oleh angin '
            'dan hujan. Merkurius tidak punya angin dan hujan, jadi lubuknya '
            'tetap ada selama miliaran tahun.',
      ),
    },
  ),
  'venus': PlanetCopy(
    name: 'Venus',
    tag: 'Kembaran Keemasan Berawan',
    fact:
        'Venus adalah dunia terpanas karena atmosfernya yang tebal menahan '
        'panas Matahari.',
    narration:
        'Ini Venus. Planet ini paling mendekati ukuran dan bentuk '
        'Bumi. Tapi Venus sangat berbeda. Pakaian awan tebalnya menjadikan '
        'planet ini panas sekali, bahkan lebih panas dari Merkurius yang lebih '
        'dekat dengan Matahari. Awan itu juga menekan kita dari bawah.',
    hotspots: {
      'runaway_heat': HotspotCopy(
        title: 'Panas Berlebihan',
        description: 'Efek rumah kaca membuat Venus 465 derajat Celsius.',
        narration:
            'Venus seperti rumah kaca raksasa. Sinar matahari menembus '
            'awan tipisnya lalu terperangkap di dalam, sehingga planet ini '
            'menjadi sangat panas. Sekitar 465 derajat Celsius. Jauh lebih '
            'panas dari yang kita rasakan',
      ),
      'backward_spin': HotspotCopy(
        title: 'Berputar Mundur',
        description: 'Venus berputar berlawanan dengan semua planet lain.',
        narration:
            'Perhatikan Venus berputar. Planet-planet lain berputar '
            'seperti baling-baling pagar yang berputar ke kanan. Venus berputar '
            'ke arah sebaliknya. Karena itu matahari terbit di barat dan '
            'terbenam di timur di Venus.',
      ),
    },
  ),
  'earth': PlanetCopy(
    name: 'Bumi',
    tag: 'Bola Biru Rumah Kita',
    fact:
        'Bumi adalah satu-satunya dunia dengan lautan, udara segar, dan '
        'kehidupan.',
    narration:
        'Ini rumah kita. Inilah Bumi. Ini satu-satunya dunia yang kami '
        'tahu memiliki lautan, udara segar, dan kehidupan. Lihat seberapa biru '
        'warnanya dari luar angkasa. Semua warna biru itu adalah air. Dan '
        'apakah kamu tahu Bumi sedikit miring? Kemiringan itu memberikan '
        'empat musim. Syukurlah pada Bumi.',
    hotspots: {
      'liquid_oceans': HotspotCopy(
        title: 'Laut Cair',
        description:
            'Laut menutupi 71% permukaan, satu-satunya lautan yang dikenal.',
        narration:
            'Lihatlah air yang melimpah itu. Laut menutupi sebagian '
            'besar planet kita. Kami pernah melihat laut di bulan dan planet '
            'lain, tetapi hanya Bumilah yang punya lautan dengan kehidupan yang '
            'berenang di dalamnya. Menarik, ya?',
      ),
      'protective_shield': HotspotCopy(
        title: 'Perisai Pelindung',
        description: 'Medan magnet dan ozon melindungi semua makhluk hidup.',
        narration:
            'Bumi memakai perisai tak kasat mata. Di jauh dalam, logam '
            'cair yang berputar untuk membuat medan magnet medan magnet, dan medan itu '
            'mengalihkan partikel berbahaya dari Matahari. Lapisan gas yang '
            'dipanggil ozon juga menahan sebagian besar sinar berbahaya '
            'Matahari. Bersama-sama keduanya membuat kita aman.',
      ),
    },
  ),
  'mars': PlanetCopy(
    name: 'Mars',
    tag: 'Gurun Merah Berkarat',
    fact:
        'Mars adalah gurun merah berkarat dengan gunung berapi tertinggi dan '
        'lembah terdalam.',
    narration:
        'Lihatlah Mars. Ini planet merah, dan warnanya berasal dari '
        'besi berkarat di tanahnya. Mars memiliki gunung berapi tertinggi dan '
        'lembah terdalam di Tata Surya kita. Mars dingin dan kering, dan '
        'tampaknya sangat mirip gurun. Bisa kamu melihat semua merah itu?',
    hotspots: {
      'olympus_mons': HotspotCopy(
        title: 'Olympus Mons',
        description: 'Gunung berapi yang hampir 3 kali tinggi Everest.',
        narration:
            'Ini Olympus Mons. Ini gunung berapi raksasa di Mars, dan '
            'hampir tiga kali lebih tinggi dari Gunung Everest. Ia begitu '
            'besar sehingga kamu bisa berdiri di kakinya dan masih tidak melihat '
            'puncaknya. Mungkin ada kawah di puncaknya, seperti topi yang '
            'sangat lebar.',
      ),
      'polar_ice_caps': HotspotCopy(
        title: 'Es Kutub',
        description: 'Air beku dan es kering berkilau di kedua kutub.',
        narration:
            'Perhatikan kutub Mars. Di sana ada tutup es yang sangat '
            'besar. Terlihat mengepung. Es itu membuat Mars terasa seperti '
            'dunia yang beku.',
      ),
    },
  ),
  'jupiter': PlanetCopy(
    name: 'Jupiter',
    tag: 'Raja Badai Bergaris',
    fact:
        'Jupiter adalah planet terbesar, dengan badai yang lebih lebar dari '
        'Bumi.',
    narration:
        'Ini Jupiter, raja planet. Jupiter adalah planet terbesar di '
        'Tata Surya kita, dan bisa muat lebih dari seribu Bumi di dalamnya. '
        'Permukaannya berjalur-jalur cokelat dan putih, seperti awan yang '
        'berputar. Dan itu semua karena Jupiter berputar sangat cepat.',
    hotspots: {
      'great_red_spot': HotspotCopy(
        title: 'Bercak Merah Besar',
        description: 'Badai monster yang lebih lebar dari Bumi.',
        narration:
            'Ini Bercak Merah Besar. Ini badai raksasa di Jupiter yang '
            'sudah berputar selama berabad-abad. Bercak ini lebih lebar dari '
            'seluruh Bumi! Bisakah kamu membayangkan badai sebesar itu di '
            'planet lain?',
      ),
      '79_moons': HotspotCopy(
        title: '79+ Bulan',
        description:
            'Jupiter punya lebih banyak bulan daripada planet mana pun.',
        narration:
            'Lihatlah sekeliling Jupiter. Ada banyak bulan yang '
            'mengelilinginya. Jupiter punya lebih banyak bulan daripada planet '
            'mana pun di Tata Surya. Sebagian bulan itu besar sekali, bahkan '
            'lebih besar dari planet Bumi.',
      ),
    },
  ),
  'saturn': PlanetCopy(
    name: 'Saturnus',
    tag: 'Perhiasan Berlingkung',
    fact:
        'Saturnus adalah planet yang terlihat berlingkung, dan cincinya '
        'tersusun dari batuan es.',
    narration:
        'Dan ini Saturnus! Saturnus punya cincin yang menjulang dan '
        'menarik. Cincin itu tersusun dari batuan es yang sangat banyak dan '
        'berputar mengelilingi planet. Cincin Saturnus begitu tipis hingga '
        'kalau kamu berdiri di Saturnus, cincinya akan tampak seperti jalan '
        'yang datar.',
    hotspots: {
      'icy_rings': HotspotCopy(
        title: 'Cincin Es',
        description: 'Miliaran potongan es mengorbit di sekitar Saturnus.',
        narration:
            'Cincin Saturnus tersusun dari miliaran potongan es, batu, '
            'dan debu. Masing-masing sebesar butiran pasir yang kamu '
            'lihat di pantai. Bersama-sama mereka membentuk cincin yang '
            'mengelilingi planet ini seperti pelindung yang sangat tipis.',
      ),
      'light_as_cork': HotspotCopy(
        title: 'Ringan Seperti Gabus',
        description: 'Saturnus sangat ringan sehingga bisa mengapung di air.',
        narration:
            'Saturnus sangat ringan. Kalau kamu punya kolam yang cukup '
            'besar, Saturnus akan mengapung di air! Ratanya sangat rendah '
            'karena sebagian besar massanya adalah gas dan es. Planet kedua '
            'yang paling ringan di Tata Surya.',
      ),
    },
  ),
  'uranus': PlanetCopy(
    name: 'Uranus',
    tag: 'Raksasa Es yang Menggulung',
    fact: 'Uranus adalah planet es yang berputar miring seperti lieung bola.',
    narration:
        'Inilah Uranus. Uranus berbeda dari planet lain karena berputar '
        'miring, hampir terguling. Seolah-olah planet ini tergelincir '
        'mengitari Matahari. Warnanya biru pucat karena lapisan es dan gas '
        'yang membeku.',
    hotspots: {
      'sideways_roll': HotspotCopy(
        title: 'Bergulir Miring',
        description:
            'Uranus bergulir seperti lieung bola bukan berputar tegak.',
        narration:
            'Lihatlah Uranus. Planet ini berputar miring, hampir '
            'terguling, seperti lieung bola yang sedang jatuh. Uranus tidak '
            'seperti planet lain yang berputar tegak di atas sumbunya. Jari '
            'Uranus mungkin pernah menabrak sesuatu yang besar dan meruntuhkannya '
            'ke posisi sekarang.',
      ),
      'methane_sky': HotspotCopy(
        title: 'Langit Metana',
        description: 'Metana membuat Uranus berubah menjadi biru kehijauan.',
        narration:
            'Lihat langit Uranus. Langitnya berwarna biru pucat dan '
            'hijau muda. Itu karena gas metana di atmosfernya menyerap cahaya '
            'merah dan membuat Uranus terlihat seperti itu.',
      ),
    },
  ),
  'neptune': PlanetCopy(
    name: 'Neptunus',
    tag: 'Dunia Badai Biru Tua',
    fact:
        'Neptunus adalah planet yang paling windy, dengan badai yang lebih '
        'besar dari Bumi.',
    narration:
        'Inilah Neptunus. Neptunus adalah planet paling jauh dari '
        'Matahari, dan sugnu sangat dingin. Neptunus berwarna biru tua dan '
        'mempunyai angin paling ganas di Tata Surya. Angin di sini bisa '
        'mencapai lebih dari 2.000 kilometer per jam!',
    hotspots: {
      'supersonic_winds': HotspotCopy(
        title: 'Angin Superssonik',
        description: 'Angin tercepat di Tata Surya, lebih dari suara.',
        narration:
            'Dengarkan angin di Neptunus. Angin di sini mencapai '
            'lebih dari 2.000 kilometer per jam, dan itu lebih cepat '
            'daripada suara. Tidak ada tempat lain di Tata Surya yang punya '
            'angin sekencang ini.',
      ),
      'white_cirrus_clouds': HotspotCopy(
        title: 'Awan Sirkus Putih',
        description:
            'Awan putih yang bergerak sangat cepat mengelilingi Neptunus.',
        narration:
            'Perhatikan awan-awan putih yang mengambang di Neptunus. '
            'Awan bergerak sangat cepat, bahkan lebih cepat dari angin di '
            'permukaan planet. Para ilmuwan yakin awan-awan ini bergerak '
            'karena badai yang sangat kuat.',
      ),
    },
  ),
  'moon': PlanetCopy(
    name: 'Bulan',
    tag: 'Satelit Alami Bumi',
    fact: 'Bulan membantu menstabilkan Bumi dan merekam sejarah Tata Surya.',
    narration:
        'Mari bertemu Bulan! Ini satu-satunya satellit alami Bumi. '
        'Gravitasinya membantu menciptakan pasang laut, dan permukaannya '
        'menyimpan rekaman tumbukan dari jaman yang sudah lama.',
  ),
  'phobos': PlanetCopy(
    name: 'Fobos',
    tag: 'Bulan Dalam Mars',
    fact:
        'Fobos adalah bulan kecil yang mengorbit sangat dekat dengan '
        'permukaan Mars.',
    narration:
        'Ini Fobos, salah satu dari dua bulan kecil Mars. Bentuknya '
        'kecil, berwarna gelap, dan mengorbit sangat dekat dengan Mars '
        'sehingga ia menyelesaikan satu putaran dalam kurang dari delapan jam.',
  ),
  'deimos': PlanetCopy(
    name: 'Deimos',
    tag: 'Bulan Luar Mars',
    fact:
        'Deimos adalah bulan kecil yang terlihat halus dan mengelilingi '
        'Mars perlahan.',
    narration:
        'Deimos adalah bulan yang lebih kecil dan lebih jauh dari dua '
        'bulan Mars. Ia terlihat seperti dunia kecil seperti kentang yang '
        'melayang mengitari planet merah.',
  ),
  'io': PlanetCopy(
    name: 'Io',
    tag: 'Bulan Gunung Berapi',
    fact: 'Io adalah dunia yang paling aktif secara vulkanik di Tata Surya.',
    narration:
        'Wah! Ini Io, dunia yang paling aktif secara vulkanik di Tata '
        'Surya. Gunung berapi di Io bisa menyemburkan air lava tinggi sekali di '
        'atas permukaannya.',
  ),
  'europa': PlanetCopy(
    name: 'Europa',
    tag: 'Dunia Samudra Es',
    fact: 'Europa punya bukti kuat adanya lautan asin di bawah kerak esnya.',
    narration:
        'Europa terlihat seperti bola es yang retak, tapi sesuatu yang '
        'menakjubkan mungkin tersembunyi di bawahnya. Para ilmuwan punya '
        'bukti kuat adanya lautan asin di bawah kerak esnya yang membeku.',
  ),
  'ganymede': PlanetCopy(
    name: 'Ganymede',
    tag: 'Bulan Terbesar',
    fact:
        'Ganymede adalah bulan terbesar di Tata Surya, bahkan lebih besar '
        'dari Merkurius.',
    narration:
        'Ini Ganymede, bulan terbesar di Tata Surya. Bahkan lebih besar '
        'daripada planet Merkurius, dan ia punya medan magnetnya sendiri.',
  ),
  'callisto': PlanetCopy(
    name: 'Kallisto',
    tag: 'Bulan Kuno Berlubang',
    fact:
        'Kallisto adalah salah satu dunia yang paling penuh lubuk di Tata '
        'Surya.',
    narration:
        'Kallisto dipenuhi lubuk dari tumbukan selama miliaran tahun. '
        'Jauh di bawah permukaan esnya, para ilmuwan menganggap mungkin ada '
        'lautan asin.',
  ),
  'titan': PlanetCopy(
    name: 'Titan',
    tag: 'Bulan dengan Langit Tebal',
    fact:
        'Titan adalah satu-satunya bulan yang diketahui punya atmosfer tebal '
        'serta danau dan lautan di permukaannya.',
    narration:
        'Titan adalah bulan yang sangat khusus. Ia punya atmosfer '
        'tebal, awan, hujan, sungai, danau, dan lautan. Tapi bukan air yang '
        'mengalir di sana, melainkan metana dan etana.',
  ),
  'enceladus': PlanetCopy(
    name: 'Enceladus',
    tag: 'Bulan Pancaran Es',
    fact: 'Enceladus menyjets air es dari lautan di bawah cangkangnya.',
    narration:
        'Lihatlah Enceladus yang mungil! Ia bulan es dengan lautan '
        'tersembunyi. Pancaran air di dekat kutub selatan menyemburkan partikel '
        'air dan es ke luar angkasa.',
  ),
  'mimas': PlanetCopy(
    name: 'Mimas',
    tag: 'Bulan dengan Lubang Raksasa',
    fact:
        'Mimas punya lubang tumbukan raksasa yang membuatnya terlihat mirip '
        'Bintang Kematian.',
    narration:
        'Ini Mimas. Lihat lubang raksasa itu? Lubang itu sangat besar '
        'sehingga membuat Mimas sedikit mirip stasiun luar angkasa terkenal '
        'dari sebuah film.',
  ),
  'tethys': PlanetCopy(
    name: 'Tethys',
    tag: 'Bulan Es Cerah',
    fact:
        'Tethys adalah bulan es Saturnus dengan sistem ngarai raksasa dan '
        'lubang besar.',
    narration:
        'Tethys adalah bulan es yang terang milik Saturnus. Ia punya '
        'lubang raksasa dan sistem ngarai besar yang membentang di sebagian '
        'besar permukaannya.',
  ),
  'iapetus': PlanetCopy(
    name: 'Iapetus',
    tag: 'Bulan Dua Warna',
    fact:
        'Iapetus punya permukaan dua warna yang aneh, dengan satu sisi jauh '
        'lebih gelap.',
    narration:
        'Iapetus adalah salah satu bulan paling aneh milik Saturnus. '
        'Satu sisinya jauh lebih gelap dari yang lain, memberi bulan ini '
        'tampilan dramatis dua warna.',
  ),
  'miranda': PlanetCopy(
    name: 'Miranda',
    tag: 'Bulan Bermotif Tambalan',
    fact:
        'Miranda punya permukaan yang tampak sangat rusak dengan tebing, '
        'alur, dan medan aneh.',
    narration:
        'Miranda mungkin bulan yang paling aneh kelihatan di Tata '
        'Surya. Permukaannya terlihat seperti tambalan raksasa dari tebing, '
        'alur, dan medan yang rusak.',
  ),
  'ariel': PlanetCopy(
    name: 'Ariel',
    tag: 'Bulan Uranus yang Cerah',
    fact:
        'Ariel adalah salah satu bulan utama Uranus, ditandai dataran es '
        'cerah dan lembah yang dalam.',
    narration:
        'Ariel adalah salah satu dari lima bulan utama Uranus. '
        'Permukaan esnya dipotong oleh lembah-lembah panjang dan wilayah '
        'yang terang.',
  ),
  'umbriel': PlanetCopy(
    name: 'Umbriel',
    tag: 'Bulan Uranus yang Gelap',
    fact: 'Umbriel adalah bulan paling gelap dari lima bulan utama Uranus.',
    narration:
        'Umbriel adalah bulan es yang gelap milik Uranus. Dibandingkan '
        'tetangganya yang lebih terang, ia memantulkan sangat sedikit sinar '
        'matahari.',
  ),
  'titania': PlanetCopy(
    name: 'Titania',
    tag: 'Bulan Terbesar Uranus',
    fact:
        'Titania adalah bulan terbesar Uranus, dengan lembah raksasa dan '
        'garis patahan.',
    narration:
        'Titania adalah bulan terbesar Uranus. Permukaan esnya '
        'dipotong oleh lembah raksasa dan garis patahan yang panjang.',
  ),
  'oberon': PlanetCopy(
    name: 'Oberon',
    tag: 'Bulan Uranus Berlubang',
    fact:
        'Oberon adalah bulan paling luar dan terbesar kedua dari lima bulan '
        'utama Uranus.',
    narration:
        'Oberon adalah bulan dingin berlubang yang jauh dari Uranus. '
        'Material terang di sekitar beberapa lubuknya membuat permukaan lamanya '
        'lebih mudah dikenali.',
  ),
  'triton': PlanetCopy(
    name: 'Triton',
    tag: 'Bulan Neptunus yang Berputar Mundur',
    fact:
        'Triton mengorbit Neptunus secara terbalik dan mungkin merupakan '
        'objek Sabuk Kuiper yang tertangkap.',
    narration:
        'Triton adalah bulan terbesar Neptunus, dan ia melakukan '
        'sesuatu yang tidak biasa. Ia mengorbit Neptunus secara terbalik '
        'dibandingkan rotasi planetnya. Mungkin ia pernah tertangkap dari '
        'Sabuk Kuiper yang jauh.',
  ),
};
