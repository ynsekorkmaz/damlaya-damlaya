# Kanal sistemi: yönlü parçalar modeli

Saf mantık dosyaları: `scripts/core/canal_pieces.gd` (katalog ve tüm sayılar), `canal_network.gd` (ızgara durumu, düzenleme, kayıt), `canal_network_flow.gd` (akış hesabı). Testler: `tests/canal_network_tests.gd`. Eski `canal_grid.gd`, `canal_flow.gd`, `canal_config.gd` değişmedi.

## Model

Yönler saat yönünde N, E, S, W (0..3). Satır aşağı arttığı için S aşağıdır. Her parçanın 0 derecedeki ağız kümesi vardır; dönüş 0..3, 90 derece adımla saat yönünde. İki komşu parça ancak karşılıklı bakan ağızları varsa bağlıdır.

Akış grafiğinin düğümü, parça içindeki bağlı ağız grubudur. Çoğu parçada tek düğüm vardır; su kemerinde iki, Y kanalda üç (gövde, kuzey kolu, güney kolu).

Pınar suyu, pınar satırındaki ilk sütun parçasının batı ağzı varsa girer; yoksa boşa gider. Son sütunda doğu ağzı olan düğüm göl çıkışıdır. Kapalı savak grafikte hiç yer almaz.

## Parçalar

| id | Ad | Ağızlar (0 derece) | Taban fiyat | Açma |
|---|---|---|---|---|
| straight | Düz kanal | E, W | 30 | 0 |
| elbow | Dirsek | W, S | 32 | 50 |
| tee | T kanal | W, E, S (hepsi bağlı) | 45 | 150 |
| wye | Y kanal | gövde W; kollar N, S | 60 | 400 |
| cross | Artı kanal | N, E, S, W (hepsi bağlı) | 60 | 600 |
| gate | Savak | E, W; kapalıyken bağlantı yok | 90 | 900 |
| mill | Değirmen | E, W | 600 (ayrı artış) | 1.200 |
| aqueduct | Su kemeri | E-W ve N-S, birbirine bağlı değil | 150 | 3.000 |
| reservoir | Biriktirme havuzu | N, E, S, W (hepsi bağlı) | 400 | 6.000 |

Y kanalda gövde iki kola bağlıdır, ama bir koldan gövdeye girildiyse diğer kola geçilemez (koldan kola geçiş yok). Yardımcı: `elbow_rotation(heading, turn_right)` su `heading` yönünde giderken sağa/sola dönen dirsek dönüşünü verir (E ve sağ için 0, E ve sol için 1).

## Malzeme ve yükseltmeler

| Malzeme | Sızıntı (hücre başına) | Fiyat çarpanı | Açma |
|---|---|---|---|
| earth (Toprak) | 0,05 | 1 | 0 |
| wood (Ahşap) | 0,03 | 2,5 | 800 |
| stone (Taş) | 0,012 | 6 | 8.000 |

Taş kaplama seviyesi 0..3 sızıntıyı [1,0; 0,7; 0,4; 0,16] ile çarpar (toprakta 0,05 / 0,035 / 0,02 / 0,008). Y kanal ayrıca yarı sızıntıdır. Genişlik seviyesi 0..4: çıkış başına kapasite `80 * 2^seviye`. Genişlik maliyeti `floor(3000*4^seviye)`, kaplama maliyeti `floor(5000*4^seviye)`.

## Akış

Her açık pınar için giriş düğümünden en yakın çıkışa en az parça geçen yol bulunur. Yol uzunluğu L yoldaki parça sayısıdır (Y içinde gövde ve kol tek parça sayılır). Varış, akış ile yoldaki parçaların (1 - sızıntı) çarpımıdır. Yol yoksa akış `wasted` olur.

Bileşen (bağlı düğüm kümesi) başına: kapasite = çıkış sayısı x çıkış kapasitesi + havuz eki; havuz eki = en çok 2 havuz x `40 * 2^genişlik`. Taban = min(varış toplamı, kapasite); fazlası `overflow`; `delivered += taban * (1 + 0,08 * min(değirmen, 3))`. Yalnızca en az bir pınar yolunun geçtiği bileşenler akıyor sayılır.

Çıktı: `input, delivered, leaked, overflow, wasted, flowing, flow_dir, per_spring`. `flow_dir` su kemerinde, o hücreden geçen toplam pınar akışı en yüksek olan hattın yönüdür.

## Maliyet

`cost = floor(taban * malzeme çarpanı * 1,04^(mevcut parça sayısı))`. Değirmen: `floor(600 * 1,5^(mevcut değirmen sayısı)) * malzeme çarpanı`. İade: parça söküldükten sonraki sayılara göre aynı parçanın fiyatının yarısı, aşağı yuvarlanır. Para kesme başka katmandadır.

## Varsayılan düzen

14 sütun x 10 satır, göl doğuda. Pınarlar batıda: A satır 4 (akış 60, açma 4.000), B satır 1 (180, 30.000), C satır 8 (480, 200.000). Eski 8x5 düzeni (A 2, B 0, C 4) `Pieces.LEGACY_*` ile kurulur.
