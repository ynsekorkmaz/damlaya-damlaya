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
