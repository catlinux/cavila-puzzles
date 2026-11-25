# Cavila: estado del proyecto y notas para la próxima sesión

Última actualización: 2026-11-25. Rama de trabajo: `claude/clever-darwin-6rgy2o`.
El remoto no tiene rama base, así que **aún no hay PR** (pendiente de que el usuario decida crear `main`).

## Qué es
Un solo juego: se tocan flechas y salen deslizándose en su dirección. Si otra flecha las bloquea
se pierde una luz (3 vidas). Tiene pistas (máx. 5), estrellas, reto diario, racha, ligas, miles de
niveles con dificultad creciente y estilo "A · Porcelana" (UI clara, flechas azul marino, color de acento por mundo).

## Niveles fijos
- Niveles 1-1000 **horneados** en `game/levels_baked.bin` (0,9 MB, zstd): `Game.make_level` los lee de ahí, así que son iguales para todos y no cambian aunque se toque el generador. Formato y codificación en `game/baked.gd`. Incluido en el APK vía `include_filter` de `export_presets.cfg`.
- Del 1001 en adelante se generan por semilla (deterministas: mismo tablero en todos los móviles). `tests/test_baked.gd` guarda la huella de los niveles 1001, 1500 y 3000: si falla, el generador ha cambiado y esos niveles cambiarían para los jugadores (o es intencionado y hay que hornear más antes).
- Regenerar / ampliar: `tools/bake_levels.gd` (`COUNT`). En paralelo: 4 procesos con `-- desde hasta trozo.bin` y luego `-- --merge trozos...` (~1 min en total). **Ojo:** volver a hornear con un generador distinto cambia niveles que la gente ya ha jugado.

## Reglas ya implementadas
- Una flecha que sale del tablero desaparece y no puede volver a entrar ni chocar más allá.
- Las rocas son infranqueables.
- Tableros hasta 32x50 hacia el nivel ~150, con formas variadas, flechas largas tipo serpiente y niveles tipo laberinto.
- Categorías de dificultad (respiro, normal, difícil, súper difícil, extra) intercaladas.
- Zoom y desplazamiento con pellizco; música ambiente con deslizadores; sonidos zen; vibración suave.
- Esquinas de flecha redondeadas (`CORNER_RADIUS` 0.2 en `ui/play.gd`).
- Fondo del tablero con margen amplio (0,62 casillas) y esquinas grandes: contorno suave, flechas del borde claramente dentro. Puntos del fondo más marcados (`DOT_COL`).
- **Huecos = exterior.** Una flecha con un hueco justo delante ya ha salido, aunque más allá haya otra flecha (regla de `Arrows.exit_path`). Para que se vea, cada hueco de salida (hasta 3 casillas) se pinta como un canal gris de una casilla centrado en la línea de la flecha (`_corridor`, en `_draw_shape`). Si tras el hueco vuelve a haber tablero (`_exit_enclosed`) la flecha se desvanece en 1,5 casillas y no sobrevuela lo de detrás. Antes se pintaba de blanco y la pista parecía errónea. La animación de salida es la original.

## Entrada táctil (ui/play.gd)
Pulsar resalta la flecha candidata y soltar la activa. El radio de toque (~46 px) se adapta a la casilla y
prefiere flechas libres cercanas. Si hay desplazamiento con zoom, se cancela el candidato. No se midió
el porcentaje de aciertos (la simulación se colgaba): sigue pendiente; validar a mano en el móvil y ajustar
`FINGER_PX` y `FAIR_PX` si siguen las falsas pulsaciones.

## Ligas (game/leagues.gd)
- Relámpago (3 h), diaria (24 h), semanal (7 días, divisiones, suben/bajan 5).
- Rivales **simulados**, deterministas por clave de liga. Hay 36 avatares (`assets/avatars/av_NN.png`) con tipo
  (`AVATAR_KIND`: n animal, f femenino, m masculino) y `AVATAR_KIN` (familia de plantilla): en una liga no hay
  avatares, familias ni nombres repetidos y el nombre encaja con el avatar.
- Imágenes de liga en `assets/league/`; premios en `assets/rewards/` (se muestra uno en la pantalla de victoria).
- Aviso «rivales simulados» ya visible en la pantalla de ligas; si se pasa a rivales reales, quitarlo.

### Credibilidad de las ligas (hecho)
Actividad por hora (más tarde y noche), habilidad con cola larga, puntos a saltos por nivel completado,
14 rivales habituales que reaparecen entre ligas (`Leagues.regulars()`), rivales más fuertes en divisiones
altas (+18 % por división), avisos «X te ha adelantado» / «a N puntos del puesto K» (`Leagues.notice`,
sticky 30 s en `ui/leagues.gd`) y nota «Los rivales son simulados». Todo con tests en `tests/test_leagues.gd`.

## Imágenes de premios
- `assets/rewards/`: `arch` (último nivel de un mundo), `laurel` (niveles súper/extra), `rise` (ascenso de división) ya se usan.
- Sin usar aún: `stars`, `progress`.
- Descartadas por texto deformado o "$": laurel original, moneda "100%", cofre "$".

## Otros pendientes
- Crear `main` y abrir el PR cuando el usuario lo pida.
- Servidor para ligas reales.
- Arte aún por generar: ver `docs/arte-prompts.md` (icono, insignias de división, mundos, logros...).

## Tests y compilación
- Lógica: `godot --headless --path . --script tests/run_tests.gd`.
- Smoke: `godot --headless --path . res://tests/smoke.tscn`.
- Capturas: `xvfb-run godot --path . --rendering-driver opengl3 res://tests/shots.tscn -- <carpeta>`.
- Si Godot se cuelga sin salida, suele ser un error de parseo de GDScript: se queda esperando al depurador.
- El generador de niveles no es seguro entre hilos: usar siempre `Game.generate_locked`.
- APK: GitHub Actions `android.yml`, publica en el release `latest` (enlace de descarga fijo).
