# Lisanslar

Üçüncü taraf varlıklar. Hepsi Poly Haven'dan, CC0 (kamu malı; atıf zorunlu değil, yine de belirtilir).

| Ad | Poly Haven kimliği ve sayfa | Yazar | Lisans | İndirme tarihi | Kullanılan dosya | Çözünürlük |
|---|---|---|---|---|---|---|
| Kloppenheim 03 (gökyüzü HDRI) | kloppenheim_03, https://polyhaven.com/a/kloppenheim_03 | Greg Zaal | CC0 | 2026-11-12 | assets/sky/sky_day.hdr (kloppenheim_03_2k.hdr) | 2k (2048x1024) |
| Rocky Terrain 02 (çimen) | rocky_terrain_02, https://polyhaven.com/a/rocky_terrain_02 | Amal Kumar | CC0 | 2026-11-12 | assets/textures/terrain/grass.jpg (rocky_terrain_02_diff_1k.jpg) | 1k (1024x1024), yalnızca renk haritası |
| Dry Ground Rocks (toprak) | dry_ground_rocks, https://polyhaven.com/a/dry_ground_rocks | Rob Tuytel | CC0 | 2026-11-12 | assets/textures/terrain/soil.jpg (dry_ground_rocks_diff_1k.jpg) | 1k (1024x1024), yalnızca renk haritası |
| Rock Ground (kaya) | rock_ground, https://polyhaven.com/a/rock_ground | Rob Tuytel | CC0 | 2026-11-12 | assets/textures/terrain/rock.jpg (rock_ground_diff_1k.jpg) | 1k (1024x1024), yalnızca renk haritası |

Dosyalar değiştirilmeden kopyalanmıştır (yalnızca adları sadeleştirildi).

Arazi dokularının kalite seviyesine bağlı ek dosyaları (Poly Haven, CC0, JPEG, değiştirilmeden; indirme tarihi 2026-11-12, toplam yaklaşık 28,5 MB). Normal haritaları OpenGL (nor_gl) biçimindedir. 1k normal haritası Orta ve Yüksek'te, 2k diffuse ve 2k normal haritası yalnızca Yüksek'te yüklenir.

| Doku | Poly Haven kimliği | Eklenen dosya | Özgün dosya | Çözünürlük |
|---|---|---|---|---|
| Çimen | rocky_terrain_02 | assets/textures/terrain/grass_nor.jpg | rocky_terrain_02_nor_gl_1k.jpg | 1k normal |
| Çimen | rocky_terrain_02 | assets/textures/terrain/grass_2k.jpg, grass_nor_2k.jpg | rocky_terrain_02_diff_2k.jpg, rocky_terrain_02_nor_gl_2k.jpg | 2k diffuse, 2k normal |
| Toprak | dry_ground_rocks | assets/textures/terrain/soil_nor.jpg | dry_ground_rocks_nor_gl_1k.jpg | 1k normal |
| Toprak | dry_ground_rocks | assets/textures/terrain/soil_2k.jpg, soil_nor_2k.jpg | dry_ground_rocks_diff_2k.jpg, dry_ground_rocks_nor_gl_2k.jpg | 2k diffuse, 2k normal |
| Kaya | rock_ground | assets/textures/terrain/rock_nor.jpg | rock_ground_nor_gl_1k.jpg | 1k normal |
| Kaya | rock_ground | assets/textures/terrain/rock_2k.jpg, rock_nor_2k.jpg | rock_ground_diff_2k.jpg, rock_ground_nor_gl_2k.jpg | 2k diffuse, 2k normal |

| MPFB insan tabani (eller) | MPFB 2.0.18, https://extensions.blender.org/add-ons/mpfb/ ; taban ag base.obj | MakeHuman topluluğu (Data Collection AB, J. Palmius, J. Hauquier) | Taban ag: CC0 (base.obj başlığı); eklenti kodu GPL-3.0-or-later (oyuna girmez, yalnızca araç) | 2026-11-12 | assets/models/hands.glb (poz verilmiş, kesilmiş el + önkol) | Hedef/modifier dosyalarının ayrı lisansı doğrulanmadı |


Alet ve dükkân modelleri (Poly Haven, CC0; lisans https://polyhaven.com/license ve varlıkların API bilgisinden doğrulandı). Modeller Blender'da düşük çokgene indirildi, yalnızca base color dokusu glb'ye gömüldü; kaynak dosyalar depoda yok.

| Ad | Poly Haven kimliği ve sayfa | Yazar | Lisans | İndirme tarihi | Kullanılan dosya | Çözünürlük |
|---|---|---|---|---|---|---|
| Wooden Bucket 01 (kova) | wooden_bucket_01, https://polyhaven.com/a/wooden_bucket_01 | James Ray Cock | CC0 | 2026-11-12 | assets/models/tools/bucket.glb, double_bucket.glb, yoke.glb, assets/models/shop/shop.glb (wooden_bucket_01_1k.gltf + .bin + diff_1k.jpg) | 1k diffuse, azaltılmış ağ |
| Wooden Bowl 02 (çanak) | wooden_bowl_02, https://polyhaven.com/a/wooden_bowl_02 | Kuutti Siitonen | CC0 | 2026-11-12 | assets/models/tools/cup.glb, assets/models/shop/shop.glb (wooden_bowl_02_1k.gltf + .bin + diff_1k.jpg) | 1k diffuse, azaltılmış ağ |
| Brown Planks 03 (tahta dokusu) | brown_planks_03, https://polyhaven.com/a/brown_planks_03 | Rob Tuytel | CC0 | 2026-11-12 | assets/models/shop/shop.glb (brown_planks_03_diff_1k.jpg) | 1k (1024x1024), yalnızca renk haritası |

Sırık, ip, dükkân yapısı, tente, sandık ve varil Blender'da modellendi (tools/blender/make_shop.py, make_tool_yoke.py); sırığın dokusu kova atlasından alınır.

İnşa sistemi varlıkları (Poly Haven, CC0; lisans https://polyhaven.com/license). İndirme tarihi 2026-11-12; yalnızca base color dokusu ve gerekirse model dosyası alındı (toplam yaklaşık 10 MB). Kanal, ağaç ve kamış parçaları Blender'da modellendi (tools/blender/make_canal.py, make_build.py).

| Ad | Poly Haven kimliği ve sayfa | Yazar | Lisans | İndirme tarihi | Kullanılan dosya | Çözünürlük |
|---|---|---|---|---|---|---|
| Wooden Hammer 01 (çekiç) | wooden_hammer_01, https://polyhaven.com/a/wooden_hammer_01 | James Ray Cock | CC0 | 2026-11-12 | assets/models/tools/hammer.glb (wooden_hammer_01_1k.gltf + .bin + diff_1k.jpg) | 1k diffuse, azaltılmış ağ (1.300 üçgen) |
| Brown Mud 03 (toprak) | brown_mud_03, https://polyhaven.com/a/brown_mud_03 | Poly Haven (yazar bilgisi sayfada) | CC0 | 2026-11-12 | assets/textures/canal/earth.jpg (brown_mud_03_diff_1k.jpg) | 1k (1024x1024), yalnızca renk haritası |
| Brown Planks 03 (tahta) | brown_planks_03, https://polyhaven.com/a/brown_planks_03 | Rob Tuytel | CC0 | 2026-11-12 | assets/textures/canal/wood.jpg (brown_planks_03_diff_1k.jpg); kanal glb'lerine gömülü | 1k (1024x1024), yalnızca renk haritası |
| Old Stone Wall (taş) | old_stone_wall, https://polyhaven.com/a/old_stone_wall | Poly Haven (yazar bilgisi sayfada) | CC0 | 2026-11-12 | assets/textures/canal/stone.jpg (old_stone_wall_diff_1k.jpg); değirmen glb'sine gömülü | 1k (1024x1024), yalnızca renk haritası |
| Bark Willow (kabuk) | bark_willow, https://polyhaven.com/a/bark_willow | Poly Haven (yazar bilgisi sayfada) | CC0 | 2026-11-12 | assets/models/build/tree_shade.glb (bark_willow_diff_1k.jpg) | 1k diffuse |

Yaprak ve kamış dokuları betikle üretildi (kendi işimiz, lisans sorunu yok). Kanal parçaları, değirmen, savak, su kemeri, havuz, gölge ağacı ve kamış Blender'da modellendi.

Kayalar, kaynak kayası ve pasif kaynak modelleri (Poly Haven, CC0; lisans https://polyhaven.com/license ve varlıkların API bilgisinden doğrulandı; ham dosyalar depoda yok). İndirme tarihi 2026-11-13; yalnızca 1k gltf, .bin ve diffuse (base color) dokusu alındı, toplam yaklaşık 17 MB. Modeller Blender'da 800 üçgene indirildi (tools/blender/make_rocks.py); kaynak kayası bu glb'lerden kuruldu (tools/blender/make_spring_rock.py).

| Ad | Poly Haven kimliği ve sayfa | Yazar (API) | Lisans | İndirme tarihi | Kullanılan dosya | Çözünürlük |
|---|---|---|---|---|---|---|
| Namaqualand Boulder 02 | namaqualand_boulder_02, https://polyhaven.com/a/namaqualand_boulder_02 | Rico Cilliers (model), Greg Zaal (fotoğraf) | CC0 | 2026-11-13 | assets/models/rocks/rock_1.glb | 1k diffuse, 800 üçgen |
| Namaqualand Boulder 03 | namaqualand_boulder_03, https://polyhaven.com/a/namaqualand_boulder_03 | Jenelle van Heerden (model), Dario Barresi (fotoğraf) | CC0 | 2026-11-13 | rock_2.glb; spring_rock.glb (arka kaya) | 1k diffuse, 800 üçgen |
| Namaqualand Boulder 04 | namaqualand_boulder_04, https://polyhaven.com/a/namaqualand_boulder_04 | Jenelle van Heerden | CC0 | 2026-11-13 | rock_3.glb; spring_rock.glb (sol kaya) | 1k diffuse, 800 üçgen |
| Namaqualand Boulder 05 | namaqualand_boulder_05, https://polyhaven.com/a/namaqualand_boulder_05 | Jenelle van Heerden (model), Dario Barresi (fotoğraf) | CC0 | 2026-11-13 | rock_4.glb | 1k diffuse, 800 üçgen |
| Namaqualand Boulder 06 | namaqualand_boulder_06, https://polyhaven.com/a/namaqualand_boulder_06 | Jenelle van Heerden (model), Greg Zaal (fotoğraf) | CC0 | 2026-11-13 | rock_5.glb; spring_rock.glb (sağ kaya) | 1k diffuse, 800 üçgen |
| Rock 07 | rock_07, https://polyhaven.com/a/rock_07 | Jenelle van Heerden | CC0 | 2026-11-13 | rock_6.glb; spring_rock.glb (ön taş) | 1k diffuse, 800 üçgen |

Çeşme, çiğ otu, bulut direği, dere ağzı, çatlak ve kova tutan el Blender'da modellendi (tools/blender/make_pasif.py, make_hands_grip.py). Çeşme, dere ağzı ve bulut direği kendi dokularını depodaki assets/textures/canal/stone.jpg (Old Stone Wall) ve wood.jpg (Brown Planks 03) dosyalarından gömer; çiğ otu dokusu betikle üretilir. hands_grip.glb de MPFB taban ağından türetilmiştir (hands.glb ile aynı lisans notu).

Balık ve kuş modelleri (assets/models/life/fish.glb, bird.glb) Blender'da sıfırdan modellendi (tools/blender/make_life.py); dışarıdan varlık ya da doku indirilmedi, yalnızca vertex color kullanılır. Sol el, gömlek kolları ve hands_grip.glb'ye eklenen "GripL" nesnesi make_hands_grip_mirror.py ile üretildi (2026-11-13; kaynak yine MPFB taban ağı, notu yukarıda).

Ses: oyundaki tüm sesler kodla üretilir (scripts/audio/sound_bank.gd); projede üçüncü taraf ses dosyası yoktur, bu nedenle ses için lisans satırı gerekmez (2026-11-13). Kenney ses paketlerinin (CC0) sayfaları otomatik indirmeye doğrudan bağlantı vermediğinden indirilmedi.
