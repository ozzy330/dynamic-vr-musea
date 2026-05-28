# Museum Garden VR — Project Context

## Stack
- Godot 4.x con OpenXR (Meta Quest target)
- Servidor externo REST (por montar) en HTTP simple
- Assets: Polyhaven (CC0) + Sketchfab free + Spatial Gardener plugin

## Arquitectura general
Cliente VR en Godot consume API REST que devuelve eventos/cuadros.
El servidor es fuente de verdad del contenido — Godot solo renderiza.

## Schema del JSON de mundo (world.json / API)
```json
{
  "halls": [
    {
      "hallId": "nombre_sala",
      "slots": [
        {
          "wall": 0,
          "slot": 0,
          "asset": {
            "imagen": "res://ruta/foto.jpg",
            "video":  "res://ruta/clip.ogv",
            "audio":  "res://ruta/sonido.ogg",
            "video_with_audio": true
          }
        }
      ]
    }
  ]
}
```

### Campos de `asset` (todos opcionales)
| campo | tipo | descripción |
|---|---|---|
| `imagen` | string | ruta `res://` a imagen (jpg/png/webp) |
| `video`  | string | ruta `res://` a video (ogv/mp4/webm) |
| `audio`  | string | ruta `res://` a audio separado (ogg) — solo se usa si `video_with_audio` es `false` |
| `video_with_audio` | bool | `true` (default) = video reproduce su audio embebido; `false` = VideoStreamPlayer muteado, AudioStreamPlayer3D usa campo `audio` |

### Mapeo de índices → nodos Godot
- `wall: 0` → `Wall1`, `wall: 1` → `Wall2`  (**máximo wall: 1** — hall_basic.tscn solo tiene 2 paredes)
- `slot: 0` → `Slot1`, `slot: 1` → `Slot2`, `slot: 2` → `Slot3`  (**máximo slot: 2**)
- Ruta de nodo resuelta: `Wall{wall+1}/Slot{slot+1}/Lienzo`
- Capacidad máxima por hall: **6 slots** (2 walls × 3 slots)

## Mapeo schema → escena Godot
- hallId → room/node a activar (dinámico, se instancia si no existe)
- wallSide → 0-3 (las 4 paredes de cada room)
- positionIndex → 0-2 (3 slots por pared)
- imagePath → textura del MeshInstance3D del slot
- mediaType → photo = ImageTexture | video = VideoStreamPlayer
- ambientAudioPath → AudioStreamPlayer3D de la room
- narrationAudioPath → se activa por proximity trigger al cuadro
- title/dateDisplay/description → UI panel al mirar el cuadro

## Estructura de escena
```
World
├── RoomManager          ← carga API, instancia rooms dinámicamente
├── HubGarden            ← room default si API falla o no responde
│   ├── Wall0
│   │   ├── Slot0        ← MeshInstance3D plano, recibe textura
│   │   ├── Slot1
│   │   └── Slot2
│   ├── Wall1, Wall2, Wall3 (igual)
│   ├── AmbientAudio     ← AudioStreamPlayer3D
│   ├── SpawnZone_Norte  ← Area3D para vegetación
│   ├── SpawnZone_Sur
│   ├── SpawnZone_Este
│   ├── SpawnZone_Oeste
│   └── Portals
│       ├── Portal_A     ← trigger de transición a otra room
│       ├── Portal_B
│       ├── Portal_C
│       └── Portal_D
└── VegetationSpawner    ← script global de scatter
```

## RoomManager — comportamiento esperado
- Al iniciar: GET /events
- Si falla o vacío: activar HubGarden como default
- Por cada evento: ensure_room_exists(hallId) → instancia hall.tscn si no existe
- Rooms son instancias de hall.tscn renombradas con hallId
- Conexiones entre rooms se generan automáticamente hacia el hub

## Vegetación — comportamiento esperado
- seed = hash(hallId) → reproducible por hall, distinto entre halls
- Pool de meshes: cypress, lavender, agave, grass_tussock, fern, shrub
- Cada hall usa subconjunto aleatorio del pool (filtro randf > 0.3)
- Scatter dentro de SpawnZones (Area3D definidas en editor)
- MultiMeshInstance3D para performance
- exclusion_radius = 2.0 alrededor del centro de cada zone

## Convenciones de código
- GDScript, no C#
- Nombres de nodos en PascalCase
- Nombres de variables en snake_case
- Señales para comunicación entre sistemas (no referencias directas)
- Comentarios en inglés

## Fases del proyecto
1. ACTUAL: Blueprint con primitivas CSG en Godot — validar escala VR y layout
2. Servidor REST mínimo — GET /events devuelve JSON hardcodeado
3. Conectar API → cuadros cambian dinámicamente
4. Assets reales (Polyhaven + Sketchfab) reemplazan primitivas
5. Vegetación generativa con seed por hallId (última fase)

## Assets pendientes de conseguir
Todos CC0 de polyhaven.com/models/plants:
- cypress_tree
- lavender_bush  
- agave_plant
- grass_tussock
- fern_plant
- small_shrub (Sketchfab free)

## Lo que YA existe
- Sistema base donde se pueden colocar cuadros (pre-existente)
- Schema de eventos definido

## Contexto de deployment
- Target: Meta Quest (OpenXR)
- Plugin VR: godot-xr-tools
- Locomotion: teleport (por definir) o caminar por portales
```
