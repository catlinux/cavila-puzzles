# Cavila

Puzle de flechas para Android: **toca cada flecha para que salga del tablero** en la dirección a la
que apunta. Si otra flecha se cruza en su camino, choca y pierdes una luz. Despeja el cielo en el
orden correcto.

Hecho con **Godot 4** (GDScript), vertical, sin conexión y sin anuncios. Estilo visual «Porcelana»:
fondo claro, tarjetas blancas, flechas en tinta azul marino y un color de acento por mundo. El sonido
se sintetiza por código. Textos en **español** y **catalán**.

## Qué tiene

- **Niveles ilimitados** con dificultad creciente: tableros de 4×6 a 16×24, más flechas, más largas
  y con cadenas de dependencias más profundas. Ritmo en bloques de 10 (respiro, normales y un reto).
- **Mundos** de 30 niveles, cada uno con su color (Alba, Marea, Ámbar, Bruma, Bosque, Ascua, Glaciar, Nébula).
- **Evento semanal**: completa 20 niveles en la semana y gana 3 pistas.
- **3 luces** por nivel y **estrellas** según los choques (3/2/1).
- **Pistas**: señalan la flecha libre más útil. Se ganan cada 5 niveles y con el reto diario.
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
