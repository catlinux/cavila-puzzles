# Cavila: estado del proyecto y notas para la próxima sesión

Última actualización: 2026-11-25. Rama de trabajo: `claude/clever-darwin-6rgy2o`.
El remoto no tiene rama base, así que **aún no hay PR** (pendiente de que el usuario decida crear `main`).

## Qué es
Un solo juego: se tocan flechas y salen deslizándose en su dirección. Si otra flecha las bloquea
se pierde una luz (3 vidas). Tiene pistas (máx. 5), estrellas, reto diario, racha, ligas, miles de
niveles con dificultad creciente y estilo "A · Porcelana" (UI clara, flechas azul marino, color de acento por mundo).

## Niveles fijos
- Niveles 1-1000 **horneados** en `game/levels_baked.bin` (0,9 MB, zstd): `Game.make_level` los lee de ahí, así que son iguales para todos y no cambian aunque se toque el generador. Formato y codificación en `game/baked.gd`. Incluido en el APK vía `include_filter` de `export_presets.cfg`.
- Al cambiar la regla de huecos se volvieron a hornear los 1000 niveles (por quinta vez) (cambian respecto a versiones anteriores del APK). Del 1001 en adelante se generan por semilla (deterministas: mismo tablero en todos los móviles). `tests/test_baked.gd` guarda la huella de los niveles 1001, 1500 y 3000: si falla, el generador ha cambiado y esos niveles cambiarían para los jugadores (o es intencionado y hay que hornear más antes).
- Regenerar / ampliar: `tools/bake_levels.gd` (`COUNT`). En paralelo: 4 procesos con `-- desde hasta trozo.bin` y luego `-- --merge trozos...` (~1 min en total). **Ojo:** volver a hornear con un generador distinto cambia niveles que la gente ya ha jugado.

## Reglas ya implementadas
- Una flecha sale al llegar al borde de la cuadrícula o al **primer hueco** (el exterior), de frente contra un lado recto; no choca con nada más allá.
- Las rocas son infranqueables.
- Tableros hasta 32x50 hacia el nivel ~150, con formas variadas, flechas largas tipo serpiente y niveles tipo laberinto.
- Categorías de dificultad (respiro, normal, difícil, súper difícil, extra) intercaladas.
- Zoom y desplazamiento con pellizco; música ambiente con deslizadores; sonidos zen; vibración suave.
- Esquinas de flecha redondeadas (`CORNER_RADIUS` 0.2 en `ui/play.gd`).
- Fondo del tablero con margen amplio (0,62 casillas) y esquinas grandes: contorno suave, flechas del borde claramente dentro. Puntos del fondo más marcados (`DOT_COL`).
- **Salida = borde o primer hueco, siempre por un lado plano.** Las formas (`Shapes._chunk`) se engordan en bloques de 3 casillas (2 en tableros pequeños): escalones anchos y planos, sin muescas de 1 casilla ni huecos cerrados (`_drop_enclosed`), probado en `tests/test_arrows.gd`. Margen blanco del tablero 0,7 casillas (`g` en `_draw_shape`). Además el generador nunca apunta una flecha a un hueco por un rincón (`Arrows.flat_exit`: las dos casillas de los lados del hueco deben ser hueco o estar fuera; test sobre cientos de niveles). Así una flecha ni sale por un rincón ni va rozando el borde. Historial: «cualquier hueco = salida» con muescas finas (confundía) → «los huecos se cruzan» (chocaba tras salir, nivel 60) → «exterior visible» (una flecha corría por el filo del borde) → la actual. Sombra del tablero opaca (`SHADOW_FLAT`). Velocidad de salida: `EXIT_V0` 5, `EXIT_ACC` 48, `EXIT_VMAX` 30 en `ui/play.gd`.

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
- **Coherencia entre ligas**: cada rival es una persona única por semana (`Leagues.week_bots`), con una sola agenda de partidas; sus puntos en cualquier liga son lo ganado dentro de su ventana (`bot_points`). Flash y diaria son subgrupos de la semanal (`Leagues.bots`, con preferencia por los que juegan en la ventana). Por eso semanal >= diaria >= flash para la misma persona. La diaria y la flash comparten calibración, división y zona horaria con la semanal del jugador (`Progress.league`).
- Actividad por hora (más tarde y noche), habilidad con cola larga, puntos a saltos por nivel, 14 rivales habituales que reaparecen entre semanas, rivales más fuertes en divisiones altas (+18 % por división), avisos «X te ha adelantado» / «a N puntos del puesto K» (`Leagues.notice`) y nota «Los rivales son simulados». Tests en `tests/test_leagues.gd`.
- **Ligas con usuarios reales**: propuesta en `docs/LIGAS_ONLINE.md` (sin implementar; hay decisiones del usuario al final).

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

## CI: fallo intermitente conocido
En la CI (commit 852f3e5) falló una vez el test de humo «niveles idénticos con y sin precarga solapada (1 de 12)». No se reproduce en local (600 repeticiones con carga). El test ahora prueba un nivel horneado (300) y otro generado (1300) e imprime qué nivel y cuántas flechas difieren; si vuelve a fallar, mirar ese mensaje.
