# Performans

Hedef bilgisayar: 8 GB RAM, tümleşik grafik (Intel Iris Xe, Vulkan 1.2).

## Bütçe

Artık tek hedef yok; her kalite seviyesinin kendi FPS hedefi var (tablo: graphics_config.gd `target_fps`). Hedefler bu bilgisayarda (Iris Xe, 1280x720) tutulur.

| Seviye | Hedef FPS | Çizim | Gölge ve efekt |
|---|---|---|---|
| Düşük | 60 | Forward+ | gölge yok, efekt yok, MSAA yok |
| Orta (varsayılan) | 50 (tercihen 60) | Forward+ | 2 kademeli güneş gölgesi, tonemap, hafif sis, MSAA 2x, arazi normal haritası |
| Yüksek | 30 (yavaş olabilir) | Forward+ | 4 kademeli gölge, SSAO, glow, MSAA 4x, 2k arazi dokusu |

Ortak sınırlar: tekrar eden nesneler MultiMesh; Compatibility'ye düşüşte aynı sahne Düşük'te 60 FPS tutmalı. Orta hedefi tutmazsa en pahalı kalemler (MSAA, gölge mesafesi) Yüksek'e taşınır. Üçgen sayısı gölge geçişlerini de içerir (Orta ~110 bin, Yüksek ~165 bin).

## Ölçümler

| Aşama | FPS | Üçgen | Çizim çağrısı | Not |
|---|---|---|---|---|
| İskelet (vadi, gökyüzü, kayalar) | 60 | 7.100 | 5 | Intel Iris Xe, 1280x720, doğuş noktasından bakış, 12.11.2026 |
| Yumuşak gölgeli arazi (100x100 hücre, indeksli, merkezi fark normali) | 60 | 23.788 | 5 | Intel Iris Xe, 1280x720, doğuş noktasından bakış, 12.11.2026 |
| Yeni kayalar (40 kaya, 3 biçim, 6.000 altı üçgen, büyük kayalara küre çarpışması) ve yumuşak tepe yamacı | 60 | 25.708 | 7 | Intel Iris Xe, 1280x720, kayalara bakış (--camera-at), 12.11.2026 |
| Ilk dongu, kuru cukur ve su kaynagi kayasi (doguş noktasi, toplam damla 0) | 60 | 27.558 | 39 | Intel Iris Xe, 1280x720, arayuz dahil, 12.11.2026 |
| Ilk dongu, su kaynagina 4 m'den bakis, elde su | 60 | 27.784 | 41 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ilk dongu, havuz (1.500 damla) ve halka dalga | 60 | 28.356 | 50 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ilk dongu, dolu gol (400.000 damla) | 60 | 28.010 | 44 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Buyuyen canak: dis arazi + merkez yama (kutupsal, ~4.600 ucgen), yeni kaynak kayasi; toplam damla 0, oyuga 4,6 m'den bakis | 60 | 32.473 | 37 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ayni, 60 damla (kucuk cukur, dipte su) | 60 | 33.691 | 47 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ayni, 1.500 damla (havuz) | 60 | 33.899 | 47 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ayni, 400.000 damla (buyuk gol) | 60 | 33.681 | 46 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ayni, kaynak kayasina 5 m'den bakis | 60 | 33.961 | 40 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Dokulu arazi + HDRI gokyuzu: doguş noktasindan genel bakis | 60 | 32.081 | 38 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ayni, yere 30 derece bakis | 58 | 37.081 | 40 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ayni, 1.500 damla, cukura bakis | 60 | 32.019 | 45 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Ayni, tepe yamacina bakis | 59 | 35.593 | 37 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Dukkan (yer tutucu), dukkan paneli acik (500 para, 3.000 damla) | 60 | 36.217 | 109 | Intel Iris Xe, 1280x720, 12.11.2026 |
| Elde alet yer tutucusu: tas / kova / sirik (dukkan gorunur) | 60 | 39.715 / 32.659 / 33.171 | 50 / 49 / 55 | Intel Iris Xe, 1280x720, 12.11.2026 |

### Kalite seviyeleri (Forward+, dikey eşzamanlama kapalı, ortalama FPS = 40. ile 120. kare arası, 12.11.2026)

| Kadraj | Düşük FPS | Orta FPS | Yüksek FPS | Üçgen (D / O / Y) | Çizim çağrısı (D / O / Y) |
|---|---|---|---|---|---|
| Doğuş noktası, 1.500 damla | 385-476 | 146-203 | 64 | 39.825 / 110.427 / 166.525 | 53 / 74 / 80 |
| Dükkâna 6 m (Orta) | - | 226 | - | - / 108.455 / - | - / 70 / - |
| 25.000 damla, kıyıdan suya (Orta / Yüksek) | - | 125-177 | 55-57 | - / 90.493 / 140.968 | - / 54 / 61 |
| Elde kova, 25 su (Orta) | - | 187 | - | - / 110.999 / - | - / 67 / - |
| Aynı su kadrajı, Compatibility'ye düşüş (Yüksek) | - | - | 107 | - / - / 140.968 | - / - / 61 |

Dikey eşzamanlama açıkken Düşük ve Orta ekranın 60 Hz'ine kilitlenir. Yüksek bu bilgisayarda en kötü kadrajda 55 FPS civarı; hedefin (30) üstünde. Ölçümler ardışık çalıştırmalar arasında yaklaşık yüzde 30 oynar (özellikle Düşük/Orta).
