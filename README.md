# Cavila

Puzle de flechas para Android: **toca cada flecha para que salga del tablero** en la dirección a la
que apunta. Si otra flecha se cruza en su camino, choca y pierdes una luz. Despeja el cielo en el
orden correcto.

Hecho con **Godot 4** (GDScript), vertical, sin conexión y sin anuncios. Estilo visual «Porcelana»:
fondo claro, tarjetas blancas, flechas en tinta azul marino y un color de acento por mundo. El sonido
se sintetiza por código. Textos en **español** y **catalán**.

## Qué tiene

- **Categorías de nivel**: la mayoría normales, con algún respiro y, de vez en cuando, niveles
  **difíciles**, **súper difíciles** (+1 pista) y **extra** (+2 pistas; todos los múltiplos de 50).
- **Niveles ilimitados** con dificultad creciente: el tablero crece nivel a nivel hasta 32×50
  hacia el nivel 150 (con tamaños variados), con flechas de todos los
  tamaños (incluidas "serpientes" largas que se enroscan) y cadenas de dependencias cada vez más largas.
  Ritmo en bloques de 10 (respiro, normales y un reto).
- **Tableros variados** (desde el nivel 6, una forma nueva cada 4 niveles): rectángulo, esquinas recortadas, óvalo, rombo, cruz, anillo, reloj de arena,
  escalones y tableros con **rocas**: obstáculos infranqueables (también el centro del anillo). Se desbloquean poco a poco.
- **Niveles laberinto** (desde el 15; todos los niveles reto desde el 20): flechas larguísimas que
  serpentean y llenan todo el tablero. Se generan cubriendo el tablero con caminos largos (regla de
  Warnsdorff) y fijando la punta de cada uno con una simulación inversa de la partida, lo que
  garantiza la solución.
- **Zoom** pellizcando y desplazamiento arrastrando en los tableros grandes.
- **Puntuación** por nivel (flechas, dificultad, errores, combos y rapidez) con récord personal, y un
  **rival de la máquina** que avanza a su ritmo mientras juegas.
- **Mundos** de 30 niveles, cada uno con su color (Alba, Marea, Ámbar, Bruma, Bosque, Ascua, Glaciar, Nébula).
- **Ligas** relámpago (3 h), diaria y semanal (con divisiones de Bronce a Diamante, ascensos y
  descensos) y premios en pistas. Por ahora los rivales están **simulados** (`game/leagues.gd`):
  antes de publicar hay que sustituirlos por jugadores reales o indicarlo en la interfaz.
- **Estilos de pieza** a elegir: flechas, colores por dirección, cometas y trazos suaves.
- Indicador de **movimientos posibles** (flechas que pueden salir en este momento).
- **Música ambiente** (acordes suaves con una melodía lenta tipo kalimba) y efectos zen (campanitas
  pentatónicas), todo sintetizado por código, con volumen ajustable; vibración
  suave. Todo se puede desactivar en Ajustes, donde también se puede **borrar el progreso**.
- **3 luces** por nivel y **estrellas** según los choques (3/2/1).
- **Pistas**: señalan la flecha libre más útil. Se ganan cada 5 niveles, en niveles súper difíciles y
  extra y con el reto diario; **se pueden guardar 5 como máximo**.
- **Reto diario** igual para todo el mundo y **racha** de días seguidos.
- Inicio con el siguiente nivel en grande (miniatura del tablero y camino de niveles), animaciones,
  sonido sintetizado y vibración.
- Tutorial en los 3 primeros niveles.

## Cómo funciona por dentro

- `game/arrows.gd` — lógica pura. Las flechas se colocan una a una y cada nueva debe tener su
  salida libre respecto a las ya colocadas, así que **quitarlas en orden inverso siempre funciona**:
  todo nivel tiene solución por construcción. Como quitar una flecha nunca empeora el tablero, un
  solucionador voraz decide exactamente si un tablero es resoluble; además mide la profundidad de
  dependencias, que el generador usa para ajustar la dificultad.
- `game/levels.gd` — curva de dificultad (logarítmica, se estabiliza hacia el nivel 2000),
  mundos y semillas. Cada nivel se genera de forma determinista a partir de su número.
- `core/` — progreso (`user://`), partida en curso, reto diario, traducciones y sonido.
- `ui/` — inicio, juego, ajustes y componentes (`ui/widgets`); `ui/style.gd` define colores,
  tipografías, tarjetas y la carga de iconos.

## Créditos y licencias de terceros

Todo se puede usar en una app comercial; las licencias van incluidas en el repositorio y se citan en
la pantalla de Ajustes.

- **Fredoka** y **Nunito** — SIL Open Font License 1.1 (`assets/fonts/OFL-*.txt`).
- **Phosphor Icons** — licencia MIT (`assets/icons/LICENSE-Phosphor.txt`); los SVG usados están en
  `ui/icon_data.gd`.
- **Godot Engine** — licencia MIT.

## Ejecutar

```bash
godot --path .
```

## Tests

```bash
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd            # lógica, generador, progreso
godot --headless --path . res://tests/smoke.tscn                 # partidas completas, choques, pistas, diario
xvfb-run -a godot --path . res://tests/shots.tscn -- /ruta/salida  # capturas de pantalla
```

## APK para Android

Cada push compila un APK de depuración en GitHub Actions (`.github/workflows/android.yml`):
Actions → la ejecución → *Artifacts* → `cavila-debug-apk`.

Para una versión firmada para tienda hace falta un keystore propio (no se incluye en el repositorio).
El preset `Android` está en `export_presets.cfg`.
