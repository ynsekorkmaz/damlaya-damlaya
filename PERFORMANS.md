# Performans

Hedef bilgisayar: 8 GB RAM, ekran kartı yok (tümleşik grafik).

## Bütçe

| Kaynak | Sınır |
|---|---|
| Çizim yöntemi | gl_compatibility |
| Üçgen (sahne toplamı) | 60.000 altı |
| Çizim çağrısı | 150 altı |
| Gerçek zamanlı gölge | kapalı |
| Son işlem (glow, SSAO, SSR, DOF, volumetrik sis) | yok |
| Doku dosyası | yok (düz renk, vertex color) |
| Tekrar eden nesneler | MultiMesh |
| Dış model, doku, eklenti | yok, her şey koddan |

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
