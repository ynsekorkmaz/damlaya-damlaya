# Kanal sistemi: yönlü parçalar modeli

Saf mantık dosyaları: `scripts/core/canal_pieces.gd` (katalog ve tüm sayılar), `canal_network.gd` (ızgara durumu, düzenleme, kayıt), `canal_network_flow.gd` (akış hesabı). Testler: `tests/canal_network_tests.gd`. Oyun (`game.gd`) artık yalnızca bu ağı kullanır; eski `canal_grid.gd`, `canal_flow.gd`, `canal_config.gd` ve `tests/canal_tests.gd` değişmedi, oyundan çağrılmaz.

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
| mill | Değirmen | E, W | 600 (ayrı artış) | 2.500 |
| aqueduct | Su kemeri | E-W ve N-S, birbirine bağlı değil | 150 | 3.000 |
| reservoir | Biriktirme havuzu | N, E, S, W (hepsi bağlı) | 400 | 6.000 |

Y kanalda gövde iki kola bağlıdır, ama bir koldan gövdeye girildiyse diğer kola geçilemez (koldan kola geçiş yok). Yardımcı: `elbow_rotation(heading, turn_right)` su `heading` yönünde giderken sağa/sola dönen dirsek dönüşünü verir (E ve sağ için 0, E ve sol için 1).

## Malzeme ve yükseltmeler

| Malzeme | Sızıntı (hücre başına) | Fiyat çarpanı | Açma |
|---|---|---|---|
| earth (Toprak) | 0,05 | 1 | 0 |
| wood (Ahşap) | 0,03 | 2,5 | 2.500 |
| stone (Taş) | 0,012 | 6 | 30.000 |

Taş kaplama seviyesi 0..3 sızıntıyı [1,0; 0,7; 0,4; 0,16] ile çarpar (toprakta 0,05 / 0,035 / 0,02 / 0,008). Y kanal ayrıca yarı sızıntıdır. Genişlik seviyesi 0..4: çıkış başına kapasite `80 * 2^seviye`. Genişlik maliyeti `floor(12000*4^seviye)`, kaplama maliyeti `floor(15000*4^seviye)`.

## Akış

Her açık pınar için giriş düğümünden en yakın çıkışa en az parça geçen yol bulunur. Yol uzunluğu L yoldaki parça sayısıdır (Y içinde gövde ve kol tek parça sayılır). Varış, akış ile yoldaki parçaların (1 - sızıntı) çarpımıdır. Yol yoksa akış `wasted` olur.

Bileşen (bağlı düğüm kümesi) başına: kapasite = çıkış sayısı x çıkış kapasitesi + havuz eki; havuz eki = en çok 2 havuz x `40 * 2^genişlik`. Taban = min(varış toplamı, kapasite); fazlası `overflow`; `delivered += taban * (1 + 0,08 * min(değirmen, 3))`. Yalnızca en az bir pınar yolunun geçtiği bileşenler akıyor sayılır.

Çıktı: `input, delivered, leaked, overflow, wasted, flowing, flow_dir, per_spring`. `flow_dir` su kemerinde, o hücreden geçen toplam pınar akışı en yüksek olan hattın yönüdür.

## Maliyet

`cost = floor(taban * malzeme çarpanı * 1,04^(mevcut parça sayısı))`. Değirmen: `floor(600 * 1,5^(mevcut değirmen sayısı)) * malzeme çarpanı`. İade: parça söküldükten sonraki sayılara göre aynı parçanın fiyatının yarısı, aşağı yuvarlanır. Para kesme başka katmandadır.

## Varsayılan düzen

14 sütun x 10 satır, göl doğuda. Pınarlar batıda: A satır 4 (akış 80, açma 6.000), B satır 1 (240, 50.000), C satır 8 (800, 150.000). Eski 8x5 düzeni (A 2, B 0, C 4; akışlar 60, 180, 480; açma 4.000, 30.000, 200.000) `Pieces.LEGACY_*` ile kurulur ve altı test senaryosu aynen onunla geçer; denge ayarı yalnızca oyun varsayılanlarına (`DEFAULT_*`) dokunur.

## Oyuna bağlanış

`game.gd` varsayılan 14x10 ağı tutar ve dünya katmanına şu arayüzü sunar: `can_place_canal(col,row,piece_id,rotation,material)` (`{ok, reason_tr, cost}`), `place_canal(...)`, `remove_canal(col,row)` (iadeyi paraya ekler), `rotate_canal(col,row)`, `toggle_gate(col,row)`, `canal_result()` (önbellekli akış sonucu), `canal_piece_cost(piece_id, material)`; değişimde `structures_changed` yayılır. Yerleştirme için çekiç, açık kanal sistemi, açık parça türü ve malzeme gerekir; red nedenleri sırayla: çekiç yok, kanal kilitli, parça ya da malzeme kilitli, sınır dışı, hücre dolu, para yetmiyor.

Kilitler durumda (`unlocked_pieces`, `unlocked_materials`) tutulur; düz kanal ve toprak baştan açıktır, diğerlerinin açma maliyeti Tab'ın Kanal bölümünden ödenir. Kayıtta ağ `network.to_dict()` ile `canal` alanındadır; eski ızgara kaydı okununca boş ağ olur. Teslimat (`delivered`) her karede göle eklenir, kayıp uygulanmaz.

## Dünya düzeni ve arayüz

Kanal alanı gölün batısındadır (`config.gd` `CANAL_FIELD_*`): 14 sütun x 10 satır, hücre 2 m, doğu kenarı x = -20 (en büyük göl yarıçapı 19 m'nin hemen dışı), batı kenarı x = -48, z = -10..+10; satır 0 kuzeyde (z = -10), sütun 0 batıda. Hücre merkezi `(-48 + 2 col + 1, -10 + 2 row + 1)`; dönüşümler `scripts/core/canal_field.gd`'de. Dönüş `rotation * 90` derece saat yönünde, yani Y ekseni dönüşü `-rotation * PI / 2` (Doğu -> Güney); `canal_pieces.rotated_nodes` ile tutarlılık `tests/world_tests.gd`'de gerçek modellerin oluk kutusuyla doğrulanır.

Arazi alanın içinde ve 1 m dışında tam düzdür (`terrain_shape.waves` dalgaları `CANAL_FIELD_HEIGHT`'a doğru söndürür), çevresinde 3 m'de yumuşak geçiş vardır; alan içi yükseklik farkı 2 cm'nin altındadır. Kayalar alandan, payı ve geçişi dahil 3 m uzak durur; dükkân, kaynak kayası ve doğuş noktası alandan en az 10 m dışındadır.

Çizim: `scripts/world/canal_view.gd` hücre başına modeli örnekler (`assets/models/canal/<parça_id>.glb`, yoksa `placeholder_models.gd` yer tutucusu), "Channel" malzemesini toprak/taş için `assets/textures/canal/*.jpg` ile değiştirir (ahşap glb'nin kendi dokusudur), "Water" nesnelerine `assets/shaders/canal_water.gdshader` verir (akmayan hücrede gizli), "Wheel" akan değirmende döner, "Gate" açıkken 0,5 m kalkar. Su deseninin yönü: V parça yerelinde Doğu/Kuzey ucunda 0'dır, Batı/Güney yönünde artar (arti ve havuzda Batı ve Güney); desen çıkış ağzı V'si yüksekse +V yönünde, değilse -V yönünde kayar. Su kemerinde iki hattın ayrı akıp akmadığı bilinmez (sonuç hücre başına tek yön verir); akan kemer hücresinde iki su da görünür, eksene uymayan hat varsayılan yönde kayar.

`canal_field_view.gd`: çekiç eldeyken ve oyuncu alana 24 m'den yakınken zeminde soluk ızgara; batı kenarında satır ortalarında A, B, C pınar çeşmeleri (kapalıyken kuru ve soluk, açılınca fışkırır ve alana su akar; Label3D "A   60/sn"); son sütunda doğu ağzı olan her akan çıkıştan göl kıyısına zemini izleyen dar bir dere şeridi (kıyı değişince kısalır).

Serbest yapılar `structures_view.gd`'de: kamış, gölge ağacı, çiğ otu tür başına MultiMesh; çatlak (kayaya yapışık sızıntı), bulut direği (küçük bulut ve yağmur damlaları), çeşme (fışkırma), dere ağzı (göle şerit) ayrı düğüm. Yer kuralları `scripts/core/build_rules.gd`: alana, dükkâna ve kaynak kayasına konmaz; göl suyuna konmaz (kamış hariç); kamış kıyıdan en çok 3 m (içeride ya da dışarıda), gölge ağacı en büyük yarıçapın dışında ve ağaçtan en az 3 m, çatlak yalnızca bir kayaya bakarken, dere ağzı merkezden 42 m'den uzak, diğerleri başka yapıya en az 1,5 m. `placed: false` yapılara açılışta halka dağılımıyla yer verilir.

Girdi: 1 su aleti, 2 çekiç, fare tekerleği yuvayı, Shift + tekerlek son 5 yapıyı değiştirir. Q yapı kitapçığını açar (çekiç eldeyken). Sol tık kurar (basılı tutup sürükleyince döşer), sağ tık sökmeye yarar (iade "+N para"), R önizlemeyi ya da bakılan parçayı döndürür (serbest yapıda 15 derece), savağa bakarken E açar/kapatır (su aleti eldeyken de).
