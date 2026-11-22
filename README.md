# Cavila

Colección de puzles de lógica para Android, para entrenar la mente y la concentración.
Hecha con **Godot 4** (GDScript), en vertical, pensada para móvil y sin conexión.
Todo el arte se dibuja por código (`_draw`); no hay imágenes externas. Textos en **español** y **catalán**.

## Puzles de la fase 1

| Puzle | Idea |
|---|---|
| **Circuito** | Una chispa recorre una cuadrícula de nodos con puertas de un solo sentido (diodos). Los interruptores invierten las puertas de su color. Traza el camino de la entrada a la salida. |
| **Sendero** | Traza un camino continuo entre dos puntos. Los números del borde dicen cuántas casillas de cada fila y columna usa el camino; hay casillas bloqueadas. Solución única verificada. |
| **Piezas** | Rellena una silueta con piezas tipo poliominó que se arrastran y giran. La silueta nace de piezas ya colocadas, así que siempre tiene solución. |

Cada puzle tiene 3 dificultades (fácil, medio, difícil) y **niveles ilimitados** generados por semilla
(`hash(puzle, dificultad, nº de nivel)`), idénticos en cualquier dispositivo. Además hay un **puzle diario**
que depende solo de la fecha. Vidas y pistas (3 de cada por nivel) en Circuito y Sendero; en Piezas solo hay pistas.

## Cómo ejecutarlo

Requisitos: [Godot 4.3+](https://godotengine.org/download) (probado con 4.3).

```bash
godot --path .              # abre y ejecuta el juego
godot --editor --path .     # abre el editor
```

Con el ratón se juega igual que con el dedo (en pantalla táctil, Godot emula el ratón a partir del toque).

### Tests

La lógica de los puzles son clases puras (`RefCounted`, sin nodos), así que se prueban en modo headless:

```bash
godot --headless --path . --script tests/run_tests.gd            # generadores, solucionadores y núcleo
godot --headless --path . --script tests/run_tests.gd -- --quick # versión rápida
godot --headless --path . res://tests/smoke.tscn                 # humo de la UI: escenas, arrastre, pistas
```

Ambos devuelven código de salida distinto de 0 si algo falla. Si faltan los recursos importados,
ejecuta antes una vez `godot --headless --path . --import`.

Capturas de las pantallas (necesita render, por ejemplo con Xvfb):
`xvfb-run -a godot --path . res://tests/shots.tscn -- /ruta/salida`.

### Exportar a Android

El preset `Android` ya está en `export_presets.cfg` (arm64, `com.cavila.puzzles`, vertical).
Necesitas el SDK de Android, JDK 17 y las plantillas de exportación de Godot configurados en
*Editor → Ajustes del editor → Export → Android*, y un keystore propio (no se incluye en el repositorio;
`*.keystore` está en `.gitignore`). Después: *Proyecto → Exportar… → Android*, o por línea de comandos:

```bash
godot --headless --path . --export-debug "Android" build/cavila.apk
```

## Estructura

```
core/      Rng (semillas), Daily (puzle diario), Progress (guardado en user://), Game (nivel, vidas,
           pistas, navegación), I18n (es/ca), Registry (lista de puzles), PuzzleLogic (contrato),
           PuzzleBase (escena base: cabecera, vidas, pista, resultado)
puzzles/<nombre>/   <nombre>_logic.gd (generador + solucionador, puro)  ·  <nombre>_view.gd + .tscn (UI)
ui/        menú principal, selector de nivel, pantalla de resultado, paleta, iconos dibujados por código
tests/     tests de lógica (headless), humo de UI y generador de capturas
```

### Añadir un puzle nuevo

(Preparados en el menú, aún sin lógica: binario 0/1, desigualdades, mosaico/nonograma, enlaces sin cruzar,
apagón y secuencia.)

1. `puzzles/<nombre>/<nombre>_logic.gd` extendiendo `core/puzzle_logic.gd`: `generate(seed, dificultad)`,
   `solve(...)`, `validate(...)`. Sin tocar nodos, para poder probarlo en headless.
2. `puzzles/<nombre>/<nombre>.tscn` con un script que extienda `core/puzzle_base.gd` y sobrescriba
   `_setup()` y `_give_hint()`; llama a `mistake()` y `solved()`.
3. Una entrada en `core/registry.gd` (pasa de `UPCOMING` a `PUZZLES`), sus textos en `core/i18n.gd`
   y un icono en `ui/puzzle_icons.gd` (ya hay uno para cada puzle previsto).
4. Un `tests/test_<nombre>.gd` y añadirlo a `tests/run_tests.gd`.

## Originalidad

Las mecánicas son géneros conocidos de puzles de lógica; los nombres, textos, interfaz, arte, paleta
(fondo oscuro con acentos turquesa y coral) y niveles son propios y se generan proceduralmente.

## Notas técnicas

- `Sendero` difícil (8×8) tarda de media ~0,3 s en generarse en escritorio (peor caso ~1,5 s); la pantalla
  muestra «Generando…». En móviles de gama baja puede tardar más.
- El generador de Sendero parte de un camino aleatorio, siembra casillas bloqueadas y añade bloqueos
  (fuera del camino plantado) hasta que el solucionador cuenta una única solución.
