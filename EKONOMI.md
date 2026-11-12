# Ekonomi tasarımı

Tüm sayılar `scripts/core/economy_config.gd` içinde; mantık `economy.gd`, durum `game_state.gd`, kayıt `save_codec.gd`.

## Döngü

- Kaynaktan su doldur (kapasite 1,5 sn'de dolar), çukura dök.
- Göle ulaşan her damla (elle, pasif kaynak, kanal) o anki oranla paraya çevrilir: `para += damla / damlaBaşınaPara`.
- Satın alma iki yerde: Tab ile açılan Geliştirmeler ekranında kilitler, yükseltmeler ve pasif kaynaklar; dükkân tezgâhında (E) yalnızca elle tutulan aletler. Göl aşama aşama büyür.
- Oyun sonu: toplam damla >= 2.000.000.

## Taşıma aletleri (sırayla)

Önce Geliştirmeler'den kilit açılır (sırayla), sonra dükkândan satın alınır. Kilitsiz alet dükkânda alınamaz. Avuç açık başlar.

| Alet | Kapasite | Kilit | Dükkân | Yükseltme (taban) |
|---|---|---|---|---|
| Avuç | 5 | açık | bedava | 5 |
| Tas | 15 | 8 | 12 | 10 |
| Kova | 50 | 60 | 90 | 70 |
| Çift kova | 140 | 450 | 700 | 500 |
| Sırık ve dört kova | 400 | 4.000 | 6.000 | 4.500 |

- Kapasite yükseltmesi: her alet için ayrı, en fazla 5 seviye; her seviye taban kapasitenin %20'sini ekler (5 seviyede 2 kat). Maliyet: `floor(taban * 1,8^seviye)`. Yalnızca sahip olunan alet yükseltilir.
- Doldurma süresi aynı kalır: kapasite 1,5 sn'de dolar.

## Dönüşüm oranı

| Seviye | Damla / 1 para | Maliyet |
|---|---|---|
| 0 | 5 | bedava |
| 1 | 4 | 60 |
| 2 | 3 | 600 |
| 3 | 2 | 8.000 |
| 4 | 1 | 120.000 |

## Pasif kaynaklar

Adet alımı Geliştirmeler'den; dükkânda yok. Önce kilit açılır: `floor(ilkMaliyet * 0,5)` (çatlak 7, çiğ 50, bulut 550, kaynak 6.000, dere ağzı 75.000). Adet maliyeti: `floor(ilkMaliyet * 1,15^adet)`

| Kaynak | Damla/sn | İlk maliyet |
|---|---|---|
| Çatlak | 0,5 | 15 |
| Çiğ | 3 | 100 |
| Yağmur bulutu | 20 | 1.100 |
| Kaynak | 120 | 12.000 |
| Dere ağzı | 700 | 150.000 |

## Kayıp

- Pasif üretimin %30'u sızar; elle dökülen ve kanaldan gelen suya uygulanmaz.
- Net üretim: `brüt * (1 - kayıp)`.

| Yükseltme | Maliyet | Puan |
|---|---|---|
| Kaya yatağı | 200 | 8 |
| Kamış kenarı | 2.500 | 7 |
| Gölge ağaçları | 30.000 | 7 |
| Kil taban | 400.000 | 5 |

Hepsi alınınca kayıp %3.

## Kanal

Kanal izgarasının fiyatları `canal_config.gd`'de, mantığı `canal_grid.gd`'de; ödeme ekonomi parasından yapılır.

- Kanal sistemi kilidi: 300 para; kilit açılana kadar bölüm yalnızca toplam damla >= 2.000 olunca görünür.
- Kilit açılınca: pınar açma (A 4.000, B 30.000, C 200.000), geniş kanal (4 seviye), taş kaplama (3 seviye).
- Kanal döşeme oyunu henüz bağlı değil; kanal parçaları ileride dükkânda satılacak.

## Aşamalar

| Aşama | Eşik (toplam damla) | Balık | Kuş | Kamış |
|---|---|---|---|---|
| Damla | 0 | 0 | 0 | yok |
| Çukur | 50 | 0 | 0 | yok |
| Havuz | 1.000 | 2 | 0 | var |
| Göl | 25.000 | 5 | 3 | var |
| Büyük göl | 400.000 | 9 | 6 | var |

- `stage_progress`: aşama içinde `ln(1+toplam)` ile doğrusal 0..1 (son aşama oyun sonuna doğru).
- `lake_fill`: `ln(1+toplam) / ln(1+400.000)`, 0..1, süreklidir; son eşikte 1 olur ve orada kalır.

## Görünürlük

- Öğe, toplam kazanılan para (`total_money_earned`) maliyetin yarısına ulaşınca görünür (kilit maliyeti, yükseltme maliyeti ya da dükkân maliyeti).
- Kilidi açılmış öğenin alt satırları (kapasite yükseltmesi, adet alımı) kilit açılınca görünür.

## Çevrimdışı

- Geçen süre < 30 sn: 0. Saat geri alınmışsa: 0.
- Aksi halde en fazla 900 sn pasif üretim + kanal teslimatı eklenir.

## Kayıt

- `SAVE_VERSION = 2`; her alan doğrulanır, bozuk alan varsayılana döner, bilinmeyen id atılır.
- Yeni alanlar: `tool_unlocked`, `tool_upgrades`, `unlocked_sources`, `canal_unlocked`.
- Sürüm 1 (ya da sürümsüz) kayıt silinmez: `tool_level`e kadar aletler ve sahip olunan kaynaklar kilidi açık sayılır.
