# 32 Unique Stylized Cartoon Fish pack

Author: remofair, via CGTrader (the `.url` file beside this README links the product page). License and price
are whatever the CGTrader purchase recorded; there is no license file in the pack.

Thirty-two rigged FBX fish, each with a swim animation on `Armature_Fish`, and PBR textures in the sibling
`../Textures/` folder (`Fish_NN_diffuse`, `_normal`, `_Roughness`, most with `_Metalness`). The FBX files
reference the textures by bare file name, so Godot's importer does not find them and the models come in
white. The species used in the game get a wrapper scene under `scenes/fish_models/` that instances the FBX
and puts a `StandardMaterial3D` with the right textures on its mesh; do the same for any other.

The pack is stylised and unnamed, so the species below are what the textures and shapes read as, not what
the artist called them. Bold rows are the ones wired to the game's `Fish` resources.

| File | Reads as | Used for |
| --- | --- | --- |
| `Fish_01` | Red with black spots and orange fins, grouper style | |
| `Fish_02` | Yellow with orange stripes, tang style | |
| `Fish_03` | Pink-red snapper or soldierfish | |
| `Fish_04` | Blue back, red belly, teeth: a piranha | |
| `Fish_05` | Small red fish; its bounds import huge, check the scale before using it | |
| `Fish_06` | Black and yellow bands with white spots: clown triggerfish | |
| `Fish_07` | Blue speckled with a white belly | |
| **`Fish_08`** | **Gold with dark spots and yellow fins: a golden koi or goldfish** | **Koi** |
| **`Fish_09`** | **Dark red, white tail, blue band, with barbel strips painted in the texture: catfish** | **Catfish** |
| **`Fish_10`** | **Brown, heavily scaled: common carp** | **Carp** |
| `Fish_11` | Yellow with fine dots and a dark dorsal edge | |
| `Fish_12` | Blue with red dots | |
| `Fish_13` | Orange with black eyebrow marks, clownfish style | |
| **`Fish_14`** | **Silver with a dark lateral band and black spots: rainbow trout** | **Rainbow Trout** |
| `Fish_15` | Pink with a brown stripe and blue fins | |
| `Fish_16` | Navy with an orange ring | |
| `Fish_17` | Tan with red scales, kohaku koi style (the other koi candidate) | |
| `Fish_18` | Dark red with a gold band and dots | |
| `Fish_19` | Navy with white stripes and teeth: tigerfish | |
| `Fish_20` | Plain gold | |
| `Fish_21` | Pink with pale bands | |
| `Fish_22` | Cream with orange dots and a blue tail | |
| **`Fish_23`** | **Yellow with black dashes, the closest to a yellow perch's bars** | **Perch** |
| `Fish_24` | Blue with black dots and yellow fins | |
| `Fish_25` | Cream with brown diamonds, long body, pike or gar style | |
| `Fish_26` | Silver with orange spots and a yellow head: brown trout (the other trout candidate) | |
| `Fish_27` | Teal with stripes | |
| `Fish_28` | Dark red with white dashes and orange fins | |
| `Fish_29` | Red with a blue head and a white band | |
| `Fish_30` | Gold with crosshatched scales: the other carp candidate | |
| `Fish_31` | Peach with orange markings | |
| `Fish_32` | Orange with red bars and yellow eyes, clownfish style | |

A catch scales the model so its longest axis is the fish's length (`Fish.dress_model`), so the pack's own
size does not matter. The old boot keeps the box placeholder.
