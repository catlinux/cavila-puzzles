# Cavila: estado del proyecto y notas para la próxima sesión

Última actualización: 2026-11-25. Rama de trabajo: `claude/clever-darwin-6rgy2o`.
El remoto no tiene rama base, así que **aún no hay PR** (pendiente de que el usuario decida crear `main`).

## Qué es
Un solo juego: se tocan flechas y salen deslizándose en su dirección. Si otra flecha las bloquea
se pierde una luz (3 vidas). Tiene pistas (máx. 5), estrellas, reto diario, racha, ligas, miles de
niveles con dificultad creciente y estilo "A · Porcelana" (UI clara, flechas azul marino, color de acento por mundo).

## Reglas ya implementadas
- Una flecha que sale del tablero desaparece y no puede volver a entrar ni chocar más allá.
- Las rocas son infranqueables.
- Tableros hasta 32x50 hacia el nivel ~150, con formas variadas, flechas largas tipo serpiente y niveles tipo laberinto.
- Categorías de dificultad (respiro, normal, difícil, súper difícil, extra) intercaladas.
- Zoom y desplazamiento con pellizco; música ambiente con deslizadores; sonidos zen; vibración suave.
- Esquinas de flecha redondeadas (`CORNER_RADIUS` 0.2 en `ui/play.gd`).

## Entrada táctil (ui/play.gd)
Pulsar resalta la flecha candidata y soltar la activa. El radio de toque (~46 px) se adapta a la casilla y
prefiere flechas libres cercanas. Si hay desplazamiento con zoom, se cancela el candidato. No se midió
el porcentaje de aciertos (la simulación se colgaba): validar a mano en el móvil y ajustar
`FINGER_PX` y `FAIR_PX` si siguen las falsas pulsaciones.

## Ligas (game/leagues.gd)
- Relámpago (3 h), diaria (24 h), semanal (7 días, divisiones, suben/bajan 5).
- Rivales **simulados**, deterministas por clave de liga. Hay 36 avatares (`assets/avatars/av_NN.png`) con tipo
  (`AVATAR_KIND`: n animal, f femenino, m masculino) y `AVATAR_KIN` (familia de plantilla): en una liga no hay
  avatares, familias ni nombres repetidos y el nombre encaja con el avatar.
- Imágenes de liga en `assets/league/`; premios en `assets/rewards/` (se muestra uno en la pantalla de victoria).
- Aviso «rivales simulados» ya visible en la pantalla de ligas; si se pasa a rivales reales, quitarlo.

### Pendiente: hacer las ligas más creíbles (propuesta, sin implementar)
1. Curvas de actividad por hora del día (más gente por la tarde y noche).
2. Habilidad con cola larga (pocos muy buenos, muchos casuales).
3. Puntos a saltos, al completar cada nivel, no continuos.
4. Rivales que reaparecen entre ligas, con historia.
5. Avisos en vivo: "X te ha adelantado", "a 300 puntos del puesto 3".
6. Rivales más fuertes en divisiones altas.
7. ~~Marca visible de "simulado".~~ Hecho: nota «Los rivales son simulados» bajo la lista (`SIM_NOTE`, sin probar en Godot).

## Imágenes aportadas sin usar todavía
- `assets/rewards/`: arch (mundo completado), laurel (dificultad súper/extra), rise (ascenso de división), stars, progress.
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
