# Denge: hedef, simülatör ve ölçümler

Sayılar `scripts/core/economy_config.gd`, `build_config.gd` ve `canal_pieces.gd` içindedir (formüller ve yapı adları aynı). Denge, `tools/sim/` altındaki simülatörle ölçülür; `tests/sim_tests.gd` sayılar değişince dengeyi korur.

## Hedef

- En iyi oynayan oyuncu oyunu yaklaşık 3 saatte bitirir (kabul 2:50 - 3:15). Hiçbir strateji 2:45'ten önce bitirmez.
- Bitiş: toplam damla >= `GAME_END_DROPS` (9.000.000).
- Tempo: ilk satın alma 60 sn içinde; ilk alet (tas) 3 dk içinde; çekiç 8-12. dk; kanal sistemi 20-30. dk.
- Aşamalar: Çukur 1-2 dk, Havuz 12-18 dk, Göl 60-80 dk, Büyük göl 130-150 dk.
- Alınabilir (anlamlı) hiçbir şeyin olmadığı en uzun bekleme 4 dk'yı geçmez (20-60. dk arasında 3 dk); oyunun son yarım saati "her şey alındı, yalnızca bekle" değildir.
- İlk ~20 dk yavaş ve elle; kanal kilidi 18-24. dk, ilk hat 2-3 dk içinde ve gelir en az 3 kat sıçrar (ölçülen x4,0); "erken kanal" stratejisi en iyinin 1,30-1,40 katı.
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

Ayardan önce: ilk sürümün eski sayıları aynı simülatörle (kopya klasörde) ölçüldü. Sonra: bu tur (ilk ~20 dk yavaş ve elle, 22. dk'da kanal ve hemen ilk hat, ortası ve sonu uzun).

| Strateji | Önce | Sonra |
|---|---|---|
| açgözlü (w=0,5) | 0:57 | 3:04 |
| açgözlü varyantları (19 adet, ufuk 60 hariç; en kısa - en uzun) | ölçülmedi | 3:03 - 3:20 |
| erken kanal (kovadan sonra yalnız kanal; pasif ve kapasite yükseltmesi pınarlar bitene kadar yok) | 1:39 | 4:08 (en iyinin 1,36 katı) |
| rastgele makul (5 tohum) | 1:02 - 1:06 | 3:15 - 3:48 |
| yalnız elle | 2:44 | 16:11 (10 saatte bitmedi, mevcut hızla tahmin) |

En iyi süre (tüm varyantlar): 3:03. Hiçbir strateji 2:45'in altında değil.

### İlk hat ve gelir sıçraması

- Kanal bölümü Tab'da 5.000 toplam damlada görünür (yaklaşık 15. dk). Kilit 300, A pınarı 200 para (akış 80), 14 düz toprak parça yaklaşık 540 para: toplam yaklaşık 1.050 para. Oyuncu bunu biriktirip kilidi açar, pınarı açar, hattı kurar; sim'de kilit 21,9. dk, hat 22,5. dk (kilitten sonra 1 dk'dan kısa).
- İlk hat devreye girince gelir: önceki 2 dk ortalamasının 4,0 katı. Sıçrama, A pınarının ucuz olmasından gelir (kilit + pınar + hat ucuz) ve değirmen, ahşap, B, C gibi sonraki adımlar pahalı bırakılarak orta oyun uzatılmıştır.

### İlk 30 dakika, 2 dakikalık dilimlerde gelir (açgözlü, para/dk)

| Dilim (dk) | Gelir | Not |
|---|---|---|
| 0-2 | 8 | avuç, ilk kilit (tas) |
| 2-4 | 21 | tas |
| 4-6 | 29 | |
| 6-8 | 34 | kova 7,0 |
| 8-10 | 64 | ilk oran 9,6 |
| 10-12 | 80 | çekiç 11,7 |
| 12-14 | 92 | çiğ otu, çatlak |
| 14-16 | 138 | |
| 16-18 | 199 | |
| 18-20 | 241 | |
| 20-22 | 236 | kanal parası biriktiriliyor, kilit 21,9 |
| 22-24 | 689 | ilk hat 22,5: SIÇRAMA |
| 24-26 | 948 | |
| 26-28 | 1.152 | |
| 28-30 | 1.232 | |

İlk 20 dk yavaştır ve eldir (elle %100'den %56'ya), 22. dk'dan sonra gelir birkaç kat artar.

### Kilometre taşları (açgözlü, w = 0,5)

| Olay | Önce (dk) | Sonra (dk) |
|---|---|---|
| ilk satın alma | 1,0 | 0,8 |
| tas | 2,6 | 2,1 |
| kova | 8,2 | 7,0 |
| ilk oran yükseltmesi | 8,9 | 9,6 |
| çekiç (alım) | 11,3 | 11,7 |
| kanal kilidi / pınar A / ilk hat | 31,0 / 31,9 / - | 21,9 / 21,9 / 22,5 |
| çift kova | 20,0 | 25,9 |
| oran 2 | 17,2 | 30,9 |
| pınar B | 47,8 | 69,9 |
| oran 3 | 30,0 | 84,2 |
| pınar C | alınmadı | 112,3 |
| geniş kanal / taş kaplama | - | 113,6 / 115,5 |
| oran 4 | 46,2 | 136,8 |
| sırık ve dört kova | 39,3 | 138,3 |
| Çukur / Havuz / Göl / Büyük göl | 1,3 / 8,4 / 24,1 / 43,3 | 1,3 / 16,0 / 68,8 / 143,2 |
| bitiş | 56,9 | 183,9 |

### Gelir ve kaynağı (açgözlü, 10 dakikalık dilimler)

| Dilim sonu (dk) | Para/dk | Elle | Pasif | Kanal | Toplam damla |
|---|---|---|---|---|---|
| 10 | 31 | %100 | %0 | %0 | 1.526 |
| 20 | 150 | %56 | %44 | %0 | 7.535 |
| 30 | 851 | %22 | %27 | %52 | 41.589 |
| 40 | 1.796 | %25 | %27 | %48 | 96.564 |
| 50 | 2.653 | %24 | %37 | %39 | 176.158 |
| 60 | 3.069 | %23 | %43 | %34 | 268.238 |
| 70 | 3.082 | %23 | %43 | %34 | 360.702 |
| 80 | 6.262 | %10 | %21 | %69 | 548.572 |
| 90 | 9.538 | %11 | %23 | %67 | 768.562 |
| 100 | 12.145 | %11 | %26 | %63 | 1.011.461 |
| 110 | 12.557 | %12 | %25 | %63 | 1.262.596 |
| 120 | 24.907 | %4 | %13 | %83 | 1.760.739 |
| 130 | 36.353 | %5 | %9 | %86 | 2.487.808 |
| 140 | 49.612 | %6 | %9 | %85 | 3.230.748 |
| 150 | 96.379 | %8 | %23 | %69 | 4.194.535 |
| 160 | 120.863 | %9 | %37 | %55 | 5.403.167 |
| 170 | 135.429 | %9 | %42 | %49 | 6.757.455 |
| 180 | 156.391 | %9 | %49 | %42 | 8.321.361 |

Son saatte gelirin yarısından fazlası kanaldan gelir (test: kanal >= %50 ve kanal > pasif); son yarım saatte pasif öne geçer, çünkü kanal üç pınarla doyar.

Kuru dönem (alınabilir anlamlı şey yok): tüm oyunda en uzun 1,1 dk; 20-60. dk arasında en uzun 1,1 dk (sınır 3 dk). Oyun sonunda alınmamış kalan öğeler: avuç kapasitesi (0/5), tas (2/5), kova (3/5), geniş kanal 2/4. Kullanılmayan kilitler (modellenmeyen): savak, Y, artı, su kemeri, biriktirme havuzu.

## Eski → yeni sayılar

| Kalem | Eski | Yeni |
|---|---|---|
| Tas (kapasite / dükkân / kilit / yükseltme) | 15 / 12 / 8 / 10 | 12 / 10 / 6 / 8 |
| Kova | 50 / 90 / 60 / 70 | 30 / 60 / 40 / 40 |
| Çift kova | 140 / 700 / 450 / 500 | 120 / 1.200 / 700 / 600 |
| Sırık ve dört kova | 400 / 6.000 / 4.000 / 4.500 | 300 / 15.000 / 8.000 / 8.000 |
| Oran maliyetleri (4:1, 3:1, 2:1, 1:1) | 60, 600, 8.000, 120.000 | 100, 5.000, 80.000, 700.000 |
| Pasif maliyet çarpanı | 1,15 | 1,3 |
| Bulut direği (damla/sn, ilk maliyet) | 20, 1.100 | 20, 7.000 |
| Çeşme | 120, 12.000 | 100, 110.000 |
| Dere ağzı | 700, 150.000 | 240, 700.000 |
| Kil taban | 400.000 | 40.000 |
| Kanal bölümü görünme eşiği (damla) | 2.000 | 5.000 |
| Pınar A (akış, açma) | 60, 4.000 | 80, 200 |
| Pınar B | 180, 30.000 | 240, 70.000 |
| Pınar C | 480, 200.000 | 800, 250.000 |
| Değirmen kilidi | 1.200 | 2.500 |
| Ahşap / taş kilidi | 800 / 8.000 | 4.000 / 50.000 |
| Geniş kanal taban | 3.000 | 12.000 |
| Taş kaplama taban | 5.000 | 15.000 |
| Aşama eşikleri (Havuz, Göl, Büyük göl) | 1.000, 25.000, 400.000 | 4.000, 350.000, 3.500.000 |
| `GAME_END_DROPS` | 2.000.000 | 9.000.000 |

Aynı kaldı: çekiç (40 / 60), kanal kilidi 300, çatlak ve çiğ otu, kamış ve gölge ağacı, kaya yatağı, kapasite yükseltme oranı ve katsayısı, parça tabanları, tüm `LEGACY_*` sabitleri (altı kanal senaryosu aynen geçer).

## Tasarım notları

- Dönüşüm oranı basamakları büyük sıçramalar yapar (2:1 -> 1:1 geliri ikiye katlar). Oran olmadan da oyun biter ama uzar; tek zorunlu yol değildir.
- Kanal yokken oyun çok uzar (sim: 4:40 civarı), "erken kanal" ise cezalandırılmaz ama en iyiden 1,36 kat yavaştır: yalnız kanala koşmak, pasif ve kapasiteyi ihmal etmek maliyetlidir.
- Cömert el aletleri orta oyunda elin payını yüksek tutar (%22-25, 30-70. dk), sonra kanala devreder.
- Ek çıkış (T + dirsek + düz parça) kapasiteyi çok ucuza artırır; geniş kanal yükseltmesi bu yüzden çoğu strateji için gereksizdir (2/4 kalır).
- Simülatör kanal bölümünü `Economy.canal_section_visible` ile, yani gerçek görünme eşiğiyle modeller; kilit açılmadan oyuncu hat parasını biriktirir.

## Bilinen sınırlar (süreyi hangi yöne iter)

- Gerçek oyuncunun dolaşması, durup bakınması, hata yapması, Tab/kitapçık açıp araştırması: süreyi UZATIR (en iyi oyuncu 3:03 bile olsa sıradan oyuncu 3:30 - 4:30 bulabilir).
- Mükemmel koşu ve aralıksız tasıma varsayımı (yalnızca 0,6 sn tur payı): süreyi uzatır; el payı küçük olduğundan etkisi ilk saatte belirgindir (oyun başında el %100 gelir).
- Kanal tasarım hataları: simülatör tek ve doğru bir düzen kurar (düz hat + yığın çıkış), gerçek oyuncu dirsek, sızıntı ya da bağlanmayan uçlarla para ve süre kaybeder: UZATIR. Daha akıllı düzenler (Y, artı, su kemeri, havuz, savak) ise bulunursa KISALTIR.
- Yer kuralları (kıyı, aralık, kayaya bakma) modellenmez; çekiç menzili ve yerleştirme süresi kabaca hesaplanır: UZATIR.
- Çevrimdışı kazanç: tek seferde en çok 900 sn pasif + kanal; oyuncu aralıklı oynarsa 15 dakikaya kadar bedava üretim ekler: KISALTIR (aralıklı oyunda belirgin).
- Tek tek yapılar için yer, görüş ve kamera sorunları, oyuncu motivasyonu, kayıt/yükleme: modellenmez.
- Simülatör açgözlü ve deneyimli bir oyuncuyu temsil eder; oyunun sırlarını bilen (örneğin ek çıkış yığınını hemen kuran) oyuncu için yakın; bilmeyen için uzak. İnsan stratejisi simüle edilenlerin en iyisinden iyi olabilir (örneğin planlı hat sırası): KISALTIR, ama bu sınırın altına (2:45) inmemesi test edilir (tüm varyantlar denendi).
- Zaman adımı 0,5 sn ve karar noktaları dökme sonrası: satın almalar birkaç sn gecikir (ihmal edilebilir).
- Kuru dönem ve "anlamlı aday" tanımı bir ölçüdür (gelir artışı >= %0,5, geri ödeme <= 2 saat); başka tanımlarla (örneğin her adet kamış) süre değişmez, yalnız bildirilen kuru süre değişir.
