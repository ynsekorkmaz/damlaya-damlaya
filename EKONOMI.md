# Ekonomi tasarımı

Tüm sayılar `scripts/core/economy_config.gd` ve `build_config.gd` içinde; mantık `economy.gd` ve `build.gd` (serbest yapılar), durum `game_state.gd`, kayıt `save_codec.gd`.

## Döngü

- Kaynaktan su doldur (kapasite 1,5 sn'de dolar), çukura dök.
- Göle ulaşan her damla (elle, pasif kaynak, kanal) o anki oranla paraya çevrilir: `para += damla / damlaBaşınaPara`.
- Satın alma üç yerde: Tab ile açılan Geliştirmeler ekranında kilitler ve yükseltmeler; dükkân tezgâhında (E) elle tutulan aletler ve çekiç; dünyada çekiçle (Q) yapılar (kanal parçaları, kamış, gölge ağacı, pasif kaynaklar). Göl aşama aşama büyür.
- Oyun sonu: toplam damla >= 9.000.000 (en iyi oyuncu için yaklaşık 3 saat; ayar ve ölçüm için DENGE.md).

## Taşıma aletleri (sırayla)

Önce Geliştirmeler'den kilit açılır (sırayla), sonra dükkândan satın alınır. Kilitsiz alet dükkânda alınamaz. Avuç açık başlar.

| Alet | Kapasite | Kilit | Dükkân | Yükseltme (taban) |
|---|---|---|---|---|
| Avuç | 5 | açık | bedava | 5 |
| Tas | 12 | 6 | 10 | 8 |
| Kova | 30 | 40 | 60 | 40 |
| Çift kova | 120 | 700 | 1.200 | 600 |
| Sırık ve dört kova | 300 | 8.000 | 15.000 | 8.000 |

- Kapasite yükseltmesi: her alet için ayrı, en fazla 5 seviye; her seviye taban kapasitenin %20'sini ekler (5 seviyede 2 kat). Maliyet: `floor(taban * 1,8^seviye)`. Yalnızca sahip olunan alet yükseltilir.
- Doldurma süresi aynı kalır: kapasite 1,5 sn'de dolar.

## Dönüşüm oranı

| Seviye | Damla / 1 para | Maliyet |
|---|---|---|
| 0 | 5 | bedava |
| 1 | 4 | 100 |
| 2 | 3 | 5.000 |
| 3 | 2 | 80.000 |
| 4 | 1 | 700.000 |

## Çekiç

Su taşıma aletlerinden bağımsızdır (`TOOLS` dizisinde değil; durumda `hammer_unlocked`, `hammer_owned`). Önce Geliştirmeler'in Aletler bölümünden kilidi açılır (40 para), sonra dükkândan alınır (60 para). Çekiç olmadan hiçbir yapı kurulamaz (kanal parçası, kamış, ağaç, pasif kaynak); sökme ve döndürme de çekiç ister. Görünürlük kuralı diğerleriyle aynı: kilit satırı 20 paraya, dükkân satırı 30 paraya ulaşınca görünür.

## Serbest yapılar

Konumları dünyada olan yapılar `state.structures` listesinde durur; öğe `{kind, x, z, rot, placed}`. `placed=false` eski kayıttan göçen, konumu henüz verilmemiş yapıdır; dünya katmanı bunları bir yere dizer ve `set_structure_position` ile konum verir. Tek doğruluk kaynağı bu liste: `state.counts` (tür başına adet) ondan türetilir, elle değiştirilmez. En fazla 2.000 yapı.

Yerleştirme koşulları sırayla: çekiç, kilit (Geliştirmeler'den), azami adet, para. Kilitli bir yapı çekiçle de kurulamaz ("Önce Geliştirmeler'den (Tab) kilidini aç"). Konum kuralları (kıyıya yakınlık vb.) dünya katmanındadır; mantık yalnızca sayar. Adet maliyeti `floor(ilkMaliyet * çarpan^mevcutAdet)`; sökünce söküldükten sonraki adetle hesaplanan fiyatın yarısı iade edilir.

### Pasif kaynaklar

Önce kilit açılır: `floor(ilkMaliyet * 0,5)` (çatlak 7, çiğ otu 50, bulut direği 3.500, çeşme 55.000, dere ağzı 350.000). Her adet çekiçle kurulan bir yapıdır; Tab'dan adet alınmaz. Adet maliyeti: `floor(ilkMaliyet * 1,3^adet)`.

| Yapı (id) | Damla/sn | İlk maliyet |
|---|---|---|
| Çatlak (crack) | 0,5 | 15 |
| Çiğ otu (dew) | 3 | 100 |
| Bulut direği (rain_cloud) | 20 | 7.000 |
| Çeşme (spring) | 100 | 110.000 |
| Dere ağzı (stream_mouth) | 240 | 700.000 |

### Kamış ve gölge ağacı

Her biri kaybı 1 puan düşürür; en fazla 7 tanesi sayılır. 7'den sonra da kurulabilir ama etkisizdir (`can_place_structure` sonucundaki `note_tr`: "Daha fazlası kaybı azaltmaz"). Maliyet `floor(taban * 1,5^adet)`.

| Yapı (id) | Kilit | İlk maliyet | Etki |
|---|---|---|---|
| Kamış öbeği (reeds) | 300 | 60 | 7 adete kadar -1 puan |
| Gölge ağacı (shade_tree) | 3.000 | 700 | 7 adete kadar -1 puan |

## Kayıp

- Pasif üretimin %30'u sızar; elle dökülen ve kanaldan gelen suya uygulanmaz.
- Net üretim: `brüt * (1 - kayıp)`.
- Tek seferlik yükseltmeler Tab'da kalır; kamış ve ağaç yapılarının etkisi eski "Kamış kenarı" (7) ve "Gölge ağaçları" (7) yükseltmelerinin yerini alır (aynı tavan).

| Kalem | Maliyet | Puan |
|---|---|---|
| Kaya yatağı (yükseltme) | 200 | 8 |
| Kil taban (yükseltme) | 40.000 | 5 |
| Kamış öbekleri (yapı, 7'ye kadar) | 60'tan başlar | 7 |
| Gölge ağaçları (yapı, 7'ye kadar) | 700'den başlar | 7 |

Hepsi olunca kayıp %3.

## Kanal

Kanal ağının mantığı `canal_network.gd` ve `canal_network_flow.gd`'de, fiyatlar ve kilit maliyetleri `canal_pieces.gd`'de (bkz. KANAL.md); ödeme ekonomi parasından yapılır. Oyun artık yalnızca bu ağı kullanır.

- Kanal sistemi kilidi: 300 para; kilit açılana kadar bölüm yalnızca toplam damla >= 5.000 olunca görünür (en iyi oyuncuda yaklaşık 15. dk; kilit yaklaşık 22. dk).
- Kilit açılınca Tab'ın Kanal bölümü dört alt başlıkta: Pınarlar (A 200, B 70.000, C 250.000), Yükseltmeler (geniş kanal 4 seviye, 12.000'den; taş kaplama 3 seviye, 15.000'den), Parçalar (dirsek 50, T 150, Y 400, artı 600, savak 900, değirmen 2.500, su kemeri 3.000, biriktirme havuzu 6.000), Malzemeler (ahşap 4.000, taş 50.000). Düz kanal ve toprak baştan açık.
- Parça ve malzemeler çekiçle yerleştirilir (`can_place_canal` / `place_canal`); kilitli parça ya da malzeme yerleştirilemez.
- Kanal teslimatı her karede göle eklenir (kayıp uygulanmaz).

## Aşamalar

| Aşama | Eşik (toplam damla) | Balık | Kuş | Kamış |
|---|---|---|---|---|
| Damla | 0 | 0 | 0 | yok |
| Çukur | 50 | 0 | 0 | yok |
| Havuz | 4.000 | 2 | 0 | var |
| Göl | 350.000 | 5 | 3 | var |
| Büyük göl | 3.500.000 | 9 | 6 | var |

- `stage_progress`: aşama içinde `ln(1+toplam)` ile doğrusal 0..1 (son aşama oyun sonuna doğru).
- `lake_fill`: `ln(1+toplam) / ln(1+3.500.000)`, 0..1, süreklidir; son eşikte 1 olur ve orada kalır.

## Görünürlük

- Öğe, toplam kazanılan para (`total_money_earned`) maliyetin yarısına ulaşınca görünür (kilit maliyeti, yükseltme maliyeti ya da dükkân maliyeti).
- Kilidi açılmış öğenin alt satırları (kapasite yükseltmesi) kilit açılınca görünür. Çekiç, kanal parçası/malzemesi, kamış ve ağaç kilitleri de aynı kuralı izler (kilit maliyetinin yarısı).

## Çevrimdışı

- Geçen süre < 30 sn: 0. Saat geri alınmışsa: 0.
- Aksi halde en fazla 900 sn pasif üretim + kanal teslimatı eklenir.

## Kayıt

- `SAVE_VERSION = 3`; her alan doğrulanır, bozuk alan varsayılana döner, bilinmeyen id atılır.
- Sürüm 2 alanları: `tool_unlocked`, `tool_upgrades`, `unlocked_sources`, `canal_unlocked`. Sürüm 3 alanları: `hammer_unlocked`, `hammer_owned`, `unlocked_pieces`, `unlocked_materials`, `unlocked_structures`, `structures`. `sources` alanı artık yazılmaz.
- `structures` doğrulaması: bilinmeyen tür atılır, sayı olmayan ya da sonsuz koordinat atılır (bozuk dönüş 0 olur), en fazla 2.000 öğe.
- Sürüm 1 (ya da sürümsüz) kayıt silinmez: `tool_level`e kadar aletler ve sahip olunan kaynaklar kilidi açık sayılır.
- Sürüm 1 ve 2 göçü: eski `sources` adetleri kaybolmaz, konumsuz (`placed=false`) yapılara döner; eski "Kamış kenarı" ya da "Gölge ağaçları" alınmışsa 7'şer konumsuz kamış/ağaç olur (kayıp tavanı aynı kalır). Kanal kaydı `canal` alanında yeni ağ biçimiyle durur; eski ızgara biçimi sessizce boş ağa döner (çökme yok, eski kanal parası geri verilmez).
