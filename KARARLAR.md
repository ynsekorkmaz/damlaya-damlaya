# Kararlar

- Motor Godot 4.7.2, dil GDScript (tür bildirimli).
- Çizim gl_compatibility; gölge ve son işlem efekti yok.
- Doku yok: düz renk ve vertex color, malzeme StandardMaterial3D.
- Birinci şahıs bakış, oyuncu çukura dönük doğar.
- class_name yok; betikler birbirine preload ile erişir (başsız testte sınıf önbelleğine bağımlı olmamak için).
- Sahne kodla kurulur: main.tscn yalnızca kök Node3D ve main.gd.
- Tüm ayar sayıları scripts/core/config.gd içinde; scripts/core saf mantıktır (Node yok).
- Arazi yumuşak gölgeli indeksli ArrayMesh (düz gölgeleme yerine: yüzler tek tek seçilip görüntü köşeli duruyordu; normal height fonksiyonunun merkezi farkından, hücre ~1,7 m), çarpışma trimesh (backface_collision açık).
- Tekrar eden nesneler (kayalar) tek MultiMeshInstance3D.
- Kaya yerleşimi tohumlu ve belirlenimcidir; kayalara şimdilik çarpışma yok.
- Girdi eylemleri project.godot'a yazılmaz, kodla kaydedilir (InputSetup).
- Dışarıdan model, doku, eklenti indirilmez.
