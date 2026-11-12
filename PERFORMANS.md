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
