# Denge: hedef, simülatör ve ölçümler

Sayılar `scripts/core/economy_config.gd`, `build_config.gd` ve `canal_pieces.gd` içindedir (formüller ve yapı adları aynı). Denge, `tools/sim/` altındaki simülatörle ölçülür; `tests/sim_tests.gd` sayılar değişince dengeyi korur.

## Hedef

- En iyi oynayan oyuncu oyunu yaklaşık 3 saatte bitirir (kabul 2:50 - 3:15). Hiçbir strateji 2:45'ten önce bitirmez.
- Bitiş: toplam damla >= `GAME_END_DROPS` (9.000.000).
- Tempo: ilk satın alma 60 sn içinde; ilk alet (tas) 3 dk içinde; çekiç 8-12. dk; kanal sistemi 20-30. dk.
- Aşamalar: Çukur 1-2 dk, Havuz 12-18 dk, Göl 60-80 dk, Büyük göl 130-150 dk.
- Alınabilir (anlamlı) hiçbir şeyin olmadığı en uzun bekleme 4 dk'yı geçmez; oyunun son yarım saati "her şey alındı, yalnızca bekle" değildir.
- Ağırlık pasif ve kanala kayar: son saatte gelirin büyük kısmı kanal; elle taşıma hiç sıfırlanmaz.

## Simülatör

Çalıştırma (başsız, tam çalıştırma yaklaşık 20 sn; yalnızca varyantlar yaklaşık 50 sn):

```
"<godot>" --headless --path "<proje>" -s res://tools/sim/balance_sim.gd -- [--strategy=all|greedy|variants|extra|hand|rush|random] [--seed=N] [--verbose] [--events]
```

`tools/sim/run.sh` aynı komutun kısayoludur. Çıktının sonunda makine okur `SIM_JSON {...}` satırı vardır. Dosyalar: `tools/sim/sim_core.gd` (çekirdek), `balance_sim.gd` (komut satırı).

### Gerçek mantık

Simülatör `game.gd` düğümünü gerçek oyun gibi kurar (`setup(false)`) ve satın almaları onun sarmalayıcılarıyla yapar (`unlock_tool`, `buy_tool`, `upgrade_tool`, `buy_rate`, `unlock_hammer`, `buy_hammer`, `unlock_source`, `place_structure`, `open_spring`, `place_canal`, `remove_canal`, `upgrade_canal_width` ...). Pasif üretim ve kanal teslimatı her adımda `Economy.tick`, akış `CanalNetworkFlow` ile hesaplanır; doldurma ve dökme `Economy.fill/pour`, aşamalar `Economy.stage_index`, çanak yarıçapı `BasinShape.radius`. Hiçbir formül kopyalanmaz. Aday değerlendirme için ikinci bir geçici oyun düğümüne durum ve ağ kopyası konur; adayın gelir artışı o kopyada gerçek fonksiyonlarla ölçülür.

### Oyuncu modeli ve varsayımlar

| Konu | Varsayım |
|---|---|
| Zaman adımı | 0,5 sn; eylemler kalan süre devrederek ilerler |
| Taşıma turu | kaynakta `FILL_SECONDS` (1,5 sn) doldur, çanağın dökme menziline koşarak yürü, dök, geri dön; her tura 0,6 sn nişan/dönme payı |
| Yürüme mesafesi | kaynak-çanak merkezi arası (27,5 m) - o anki çanak yarıçapı - `POUR_MARGIN` - (`SPRING_RADIUS` + `FILL_REACH`); koşu hızı `SPRINT_SPEED` (6,8 m/sn), sürekli koşu, dolaşma yok |
| Tab ekranı | işlem başına 2 sn |
| Dükkân | çanak kıyısından tezgâha gidiş-dönüş yürüme + işlem başına 2 sn |
| Serbest yapı | 3 sn yer seçme/dönme + yapı başına 1,5 sn |
| Kanal kurma | alana gidiş-dönüş ve alan içi dolaşma (20 m) + parça başına 1,5 sn + 2 sn |
| Karar noktası | dökmeden hemen sonra (her satın alma) ve kaynağa dönünce (yalnızca Tab satın almaları); en geç 120 sn'de bir yeniden planlanır |
| Pasif/kanal | oyuncu yürürken, Tab'dayken, dükkândayken de akar |
| Yer kuralları | yapıların konum kuralları (kıyı, mesafe) modellenmez; yer her zaman bulunur |

### Adaylar

Her aday, gerekli ön koşulları (kilit, çekiç, kanal kilidi, parça, malzeme, pınar) içeren bir paket olarak kurulur; paket, gerçek fonksiyonlarla geçici oyunda uygulanıp toplam maliyeti ve gelir artışı (para/sn: el + pasif + kanal) ölçülür. El geliri `kapasite / (dolum + 2 x yürüme + 0,6)` olarak sayılır.

- El: sıradaki alet (kilit + dükkân), mevcut aletin kapasite seviyesi, dönüşüm oranı.
- Pasif: her kaynaktan bir adet (çekiç, kilit dahil), kamış, gölge ağacı, kaya yatağı, kil taban.
- Kanal: pınar hattı (pınar satırında 14 düz parça, malzeme toprak/ahşap/taş; ek çıkış sayısı 0-6 ile), mevcut hatta malzeme yükseltmesi (sök, yenisini kur), ek çıkış (hat sonunda T + dirsek + düz parçadan dikey yığın), değirmen (en çok 3), geniş kanal, taş kaplama. Hat dışındaki parçalar (Y, artı, savak, su kemeri, biriktirme havuzu) kurulmaz.

### Stratejiler

| Strateji | Kural |
|---|---|
| açgözlü | ölçüt = `w x bekleme + geri ödeme süresi` (bekleme: ilk parti parasına kalan süre / mevcut gelir; geri ödeme: toplam maliyet / gelir artışı); en küçük seçilir, para yetince alır. Varyantlar: w = 0,1 - 4, kanal ağırlığı 0,7 / 1 / 1,5, "ufuk" (bekleme sınırı) 60 ve 600 sn |
| yalnız elle | yalnızca alet, kapasite ve oran; çekiç, pasif ve kanal yok |
| erken kanal | kova alınınca en ucuz pınar hattına yönelir, sonra kanal ağırlıklı açgözlü |
| rastgele makul | metriği en iyinin 2 katından küçük adaylardan tohumlu rastgele seçer; 5 tohum |
| kanalsız, oran yok, yalnız pasif | tek bir yolu kapatan açgözlü varyantlar (`--strategy=extra`) |

Kuru dönem ölçüsü: o an alınabilecek "anlamlı" aday yoksa kuru sayılır. Anlamlı: gelir artışı mevcut gelirin en az %0,5'i ve geri ödeme süresi en çok 2 saat. Kuru süre, parası en ucuz anlamlı adayın ilk parti maliyetinin altında geçen en uzun kesintisiz süredir. "Alım arası" ayrıca bildirilir ama sınır değildir (oyuncu büyük bir şey için biriktirirken ucuz ama değersiz şeyler alabilir).

## Sonuçlar (ayardan önce ve sonra)

Ayardan önce: eski sayılar aynı simülatörle (kopya klasörde) ölçüldü.

| Strateji | Önce | Sonra |
|---|---|---|
| açgözlü (w=0,5) | 0:57 | 2:58 |
| açgözlü varyantları (19 adet, ufuk 60 hariç; en kısa - en uzun) | ölçülmedi | 2:54 - 3:10 |
| erken kanal | 1:39 | 4:43 |
| rastgele makul (5 tohum) | 1:02 - 1:06 | 3:12 - 3:50 |
| yalnız elle | 2:44 | 15:49 (10 saatte bitmedi, mevcut hızla tahmin) |
| kanalsız | - | 4:40 |
| oran yok | - | 3:53 |
| yalnız pasif | - | 6:26 |

En iyi süre (tüm varyantlar): 2:54. Hedef aralığın (2:50 - 3:15) içindedir ama alt uca yakındır; gerçek oyuncu için bkz. "Bilinen sınırlar".

### Kilometre taşları (açgözlü, w = 0,5)

| Olay | Önce (dk) | Sonra (dk) |
|---|---|---|
| ilk satın alma | 1,0 | 0,8 |
| tas | 2,6 | 2,1 |
| kova | 8,2 | 7,0 |
| çekiç (alım) | 11,3 | 11,7 |
| kanal kilidi | 31,0 | 22,4 |
| pınar A | 31,9 | 43,5 |
| çift kova | 20,0 | 27,8 |
| pınar B | 47,8 | 75,0 |
| dönüşüm oranı 1 / 2 / 3 / 4 | 8,9 / 17,2 / 30,0 / 46,2 | 9,6 / 50,2 / 86,6 / 123,7 |
| pınar C | alınmadı | 106,4 |
| sırık ve dört kova | 39,3 | 127,1 |
| ilk çeşme (pasif kilidi) | 34,5 | 128,7 |
| dere ağzı (pasif kilidi) | 50,4 | 149,0 |
| Çukur / Havuz / Göl / Büyük göl | 1,3 / 8,4 / 24,1 / 43,3 | 1,3 / 16,0 / 67,2 / 141,5 |
| bitiş | 56,9 | 178 |

Başlangıç (ilk 12 dk) önce de benzerdi; asıl düzeltilen, oyunun ortasının ve sonunun 3 kat hızlı akması ve kanalın erken bitirilebilir tek yol olması idi. Çekici 8-12. dk aralığına oturtmak için ek bir ucuzlatma gerekmedi: açgözlü, çekici kova ve ilk oran yükseltmesinden sonra alıyor.

### Gelir ve kaynağı (açgözlü, 10 dakikalık dilimler)

| Dilim sonu (dk) | Para/dk | Elle | Pasif | Kanal | Toplam damla |
|---|---|---|---|---|---|
| 10 | 31 | %100 | %0 | %0 | 1.526 |
| 20 | 153 | %54 | %46 | %0 | 7.647 |
| 30 | 390 | %38 | %62 | %0 | 23.236 |
| 40 | 635 | %56 | %44 | %0 | 48.624 |
| 50 | 897 | %36 | %32 | %32 | 84.520 |
| 60 | 2.182 | %28 | %24 | %48 | 150.273 |
| 70 | 2.309 | %31 | %24 | %45 | 219.535 |
| 80 | 3.371 | %17 | %16 | %67 | 320.672 |
| 90 | 7.343 | %12 | %9 | %79 | 508.683 |
| 100 | 10.550 | %10 | %16 | %74 | 719.688 |
| 110 | 14.303 | %7 | %14 | %79 | 1.005.751 |
| 120 | 31.598 | %5 | %6 | %89 | 1.637.713 |
| 130 | 58.377 | %5 | %9 | %86 | 2.338.549 |
| 140 | 99.815 | %7 | %26 | %66 | 3.336.699 |
| 150 | 121.970 | %8 | %38 | %54 | 4.556.400 |
| 160 | 136.257 | %9 | %43 | %48 | 5.918.969 |
| 170 | 158.696 | %8 | %50 | %42 | 7.505.929 |

Son saatte (118-178. dk) gelirin yaklaşık %55'i kanal, %35'i pasif, %8'i el (test: kanal >= %50 ve kanal > pasif). Son yarım saatte pasif öne geçer: kanal üç pınarla doyar, sonraki büyüme çeşme ve dere ağzı yığınlarından gelir.

Oyun sonunda alınmamış kalan öğeler (açgözlü): palm kapasitesi (0/5), tas kapasitesi (2/5), kova kapasitesi (3/5), geniş kanal 2/4. Kullanılmayan kilitler (modellenmeyen): savak, Y, artı, su kemeri, biriktirme havuzu. Son 30 dk başında hâlâ alınmamış kalıcı öğe sayısı 6, son 30 dk'daki satın alma sayısı 11.

## Eski → yeni sayılar

| Kalem | Eski | Yeni |
|---|---|---|
| Tas (kapasite / dükkân / kilit / yükseltme) | 15 / 12 / 8 / 10 | 12 / 10 / 6 / 8 |
| Kova | 50 / 90 / 60 / 70 | 30 / 60 / 40 / 40 |
| Çift kova | 140 / 700 / 450 / 500 | 120 / 1.200 / 700 / 600 |
| Sırık ve dört kova | 400 / 6.000 / 4.000 / 4.500 | 300 / 15.000 / 8.000 / 8.000 |
| Oran maliyetleri (4:1, 3:1, 2:1, 1:1) | 60, 600, 8.000, 120.000 | 100, 5.000, 50.000, 450.000 |
| Pasif maliyet çarpanı | 1,15 | 1,3 |
| Bulut direği (damla/sn, ilk maliyet) | 20, 1.100 | 20, 7.000 |
| Çeşme | 120, 12.000 | 100, 110.000 |
| Dere ağzı | 700, 150.000 | 240, 700.000 |
| Kil taban | 400.000 | 40.000 |
| Pınar A (akış, açma) | 60, 4.000 | 80, 6.000 |
| Pınar B | 180, 30.000 | 240, 50.000 |
| Pınar C | 480, 200.000 | 800, 150.000 |
| Değirmen kilidi | 1.200 | 2.500 |
| Ahşap / taş kilidi | 800 / 8.000 | 2.500 / 30.000 |
| Geniş kanal taban | 3.000 | 12.000 |
| Taş kaplama taban | 5.000 | 15.000 |
| Aşama eşikleri (Havuz, Göl, Büyük göl) | 1.000, 25.000, 400.000 | 4.000, 200.000, 3.500.000 |
| `GAME_END_DROPS` | 2.000.000 | 9.000.000 |

Aynı kaldı: çekiç (40 / 60), kanal kilidi 300, çatlak ve çiğ otu (0,5 / 3 damla/sn; 15 / 100), kamış ve gölge ağacı, kaya yatağı, kapasite yükseltme oranı ve katsayısı, parça tabanları (dirsek 50, T 150, ...), tüm `LEGACY_*` sabitleri (altı kanal senaryosu aynen geçer).

## Tasarım notları

- Dönüşüm oranı basamakları çok büyük sıçramalar yapar (özellikle 2:1 -> 1:1 geliri ikiye katlar). Oran olmadan da oyun bitirilebilir (3:53) ama 1 saat uzar; tek zorunlu yol değildir.
- Kanal yokken oyun 4:40'ta biter, yani kanal "çok güçlü ama zorunlu değil"dir. Kamış, ağaç ve kil taban açgözlü stratejide alınıyor (92. - 133. dk), kayıp yükseltmeleri atlanmıyor.
- Cömert el aletleri (çift kova 120, sırık 300) orta oyunda elin payı büyüktür (%28-56, 30-70. dk), sonra kanala devreder; yalnız elle oyun 10 saatte bitmez.
- Ek çıkış (T + dirsek + düz parça) kapasiteyi çok ucuza artırır; geniş kanal yükseltmesi bu yüzden çoğu strateji için gereksizdir (2/4 kalır). Savak, Y, artı, su kemeri ve havuz simülatörde kullanılmaz.

## Bilinen sınırlar (süreyi hangi yöne iter)

- Gerçek oyuncunun dolaşması, durup bakınması, hata yapması, Tab/kitapçık açıp araştırması: süreyi UZATIR (en iyi oyuncu 2:55 bile olsa sıradan oyuncu 3:30 - 4:30 bulabilir).
- Mükemmel koşu ve aralıksız tasıma varsayımı (yalnızca 0,6 sn tur payı): süreyi uzatır; el payı küçük olduğundan etkisi ilk saatte belirgindir (oyun başında el %100 gelir).
- Kanal tasarım hataları: simülatör tek ve doğru bir düzen kurar (düz hat + yığın çıkış), gerçek oyuncu dirsek, sızıntı ya da bağlanmayan uçlarla para ve süre kaybeder: UZATIR. Daha akıllı düzenler (Y, artı, su kemeri, havuz, savak) ise bulunursa KISALTIR.
- Yer kuralları (kıyı, aralık, kayaya bakma) modellenmez; çekiç menzili ve yerleştirme süresi kabaca hesaplanır: UZATIR.
- Çevrimdışı kazanç: tek seferde en çok 900 sn pasif + kanal; oyuncu aralıklı oynarsa 15 dakikaya kadar bedava üretim ekler: KISALTIR (aralıklı oyunda belirgin).
- Tek tek yapılar için yer, görüş ve kamera sorunları, oyuncu motivasyonu, kayıt/yükleme: modellenmez.
- Simülatör açgözlü ve deneyimli bir oyuncuyu temsil eder; oyunun sırlarını bilen (örneğin ek çıkış yığınını hemen kuran) oyuncu için yakın; bilmeyen için uzak. İnsan stratejisi simüle edilenlerin en iyisinden iyi olabilir (örneğin planlı hat sırası): KISALTIR, ama bu sınırın altına (2:45) inmemesi test edilir (tüm varyantlar denendi).
- Zaman adımı 0,5 sn ve karar noktaları dökme sonrası: satın almalar birkaç sn gecikir (ihmal edilebilir).
- Kuru dönem ve "anlamlı aday" tanımı bir ölçüdür (gelir artışı >= %0,5, geri ödeme <= 2 saat); başka tanımlarla (örneğin her adet kamış) süre değişmez, yalnız bildirilen kuru süre değişir.
