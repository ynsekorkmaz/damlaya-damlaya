# Ekonomi tasarımı

Tüm sayılar `scripts/core/economy_config.gd` içinde; mantık `economy.gd`, durum `game_state.gd`, kayıt `save_codec.gd`.

## Döngü

- Kaynaktan su doldur (kapasite 1,5 sn'de dolar), çukura dök.
- Göle ulaşan her damla (elle, pasif kaynak, kanal) o anki oranla paraya çevrilir: `para += damla / damlaBaşınaPara`.
- Para ile alet, oran, pasif kaynak ve kayıp yükseltmesi alınır; göl aşama aşama büyür.
- Oyun sonu: toplam damla >= 2.000.000.

## Taşıma aletleri (sırayla alınır)

| Alet | Kapasite | Maliyet |
|---|---|---|
| Avuç | 5 | bedava |
| Tas | 15 | 12 |
| Kova | 50 | 90 |
| Çift kova | 140 | 700 |
| Sırık ve dört kova | 400 | 6.000 |

## Dönüşüm oranı

| Seviye | Damla / 1 para | Maliyet |
|---|---|---|
| 0 | 5 | bedava |
| 1 | 4 | 60 |
| 2 | 3 | 600 |
| 3 | 2 | 8.000 |
| 4 | 1 | 120.000 |

## Pasif kaynaklar

Maliyet: `floor(ilkMaliyet * 1,15^adet)`

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

- Öğe, toplam kazanılan para (`total_money_earned`) maliyetin yarısına ulaşınca görünür.

## Çevrimdışı

- Geçen süre < 30 sn: 0. Saat geri alınmışsa: 0.
- Aksi halde en fazla 900 sn pasif üretim + kanal teslimatı eklenir.

## Kayıt

- `SAVE_VERSION = 1`; her alan doğrulanır, bozuk alan varsayılana döner, bilinmeyen id atılır.
