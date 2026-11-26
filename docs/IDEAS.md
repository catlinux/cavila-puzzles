# Ideas para hacer Cavila más atractivo

Investigación del 2026-11-26 (búsquedas web + conocimiento general). Ojo: las fuentes son descripciones de
tiendas, artículos del sector y un informe de Mistplay; **no hay cifras de retención de juegos concretos**.
Son hipótesis razonables, no resultados garantizados.

## Qué hacen otros juegos de flechas («Arrows», «Arrow Puzzle», «Arrow Flow», «Tap Away»…)
- **Reto diario** como gancho principal, a veces con **retos mensuales y trofeos** coleccionables.
- **Pistas** que resaltan una flecha que puede salir; se compran o se ganan con monedas.
- **Vidas por nivel** (un error cuesta una vida), modos con **temporizador** o con **puntuación máxima**.
- **Niveles creados por usuarios** (en algún título).
- Quejas habituales en las reseñas: **anuncios obligatorios** y muros de pago. Cavila ya se diferencia:
  sin anuncios, sin conexión, niveles fijos, ligas y modo zen.

## Qué funciona en puzles casuales (resumen del sector)
- **Rachas y bonos de constancia**: el 69 % de los jugadores de puzles los citan como razón para seguir
  (informe de Mistplay). Las **misiones diarias** enganchan más que un simple regalo por entrar.
- **Competir con algo que ya haces** (puntuación del puzle) y **coleccionar** (completar una serie
  desbloquea una skin o un capítulo extra) son objetivos a largo plazo sin sistemas complicados.
- Advertencia: acumular sistemas no ayuda; cada uno debe ser ligero y estar ligado al juego principal.

## Propuestas para Cavila (impacto / esfuerzo)
| # | Idea | Por qué encaja | Esfuerzo |
|---|---|---|---|
| 1 | **Misiones diarias** (3 pequeñas: «supera 3 niveles», «un nivel sin perder luz», «un combo x3») con pista de premio | Ya hay combos, rachas, pistas y estrellas; casi todo el código existe | Bajo |
| 2 | **Compartir resultado** del reto diario al estilo Wordle (texto con estrellas, tiempo y puesto en el portapapeles) | Gratis, viral, sin servidor ni anuncios | Bajo |
| 3 | **«Reta a un amigo»**: compartir un nivel y tu tiempo; el otro juega el mismo (los niveles son fijos) | Social sin servidor | Bajo-medio |
| 4 | **Calendario del reto diario con trofeo mensual** | Lo hacen otros juegos de flechas; refuerza la racha | Medio |
| 5 | **Coleccionables**: estilos de pieza y temas de tablero que se desbloquean al completar mundos o logros, insignias de liga y avatares (ya hay guía de arte en `docs/arte-prompts.md`) | Meta a largo plazo; el arte ya está planificado | Medio |
| 6 | **Escudo de racha** que se gana jugando (perdonar un día) | Evita la frustración de perder una racha larga | Bajo |
| 7 | **Modos extra**: contrarreloj (estrellas por tiempo) y «sin pistas» con puntuación máxima | Variedad sin contenido nuevo | Medio |
| 8 | **Eventos semanales temáticos** (semana de laberintos, tableros gigantes) usando el sistema de eventos que ya existe | Motivo para volver | Medio |
| 9 | **Logros** (12-16) con insignias; en Google Play, Play Games | Se alinean con el arte previsto | Medio |
| 10 | **Ligas con jugadores reales** (ver `docs/LIGAS_ONLINE.md`) | Competir con personas | Alto |

## Qué evitar
Anuncios obligatorios, vidas que se recargan por horas, muros de pago y notificaciones insistentes: son las
quejas más repetidas y chocan con lo que hoy diferencia a Cavila. Si algún día se monetiza: pistas opcionales
con anuncio voluntario o una compra única para quitar límites, sin vender ventaja en las ligas.

## Estado de las ideas (2026-11-26)
- **Aprobadas en principio, por detallar**: misiones diarias (1) con premios como vidas ilimitadas temporales. Racha de días
  jugados (6, variante): **hecha** (chip de llama en portada); premios por hitos pendientes.
- **Vidas y pistas**: propuesta en `docs/VIDAS_Y_PISTAS.md`, por discutir.
- **Aparcadas para discutir más adelante**: compartir resultado (2), reta a un amigo (3), calendario mensual (4),
  coleccionables (5), modos extra (7), eventos semanales (8), logros (9) y ligas con usuarios reales (10).

## Fuentes
- [Listados de juegos de flechas en tiendas](https://play.google.com/store/apps/details?id=com.arrow.arrows)
- [Daily Missions in Puzzles (Deconstructor of Fun)](https://www.deconstructoroffun.com/blog/2024/9/23/daily-missions-in-puzzles-why-should-we-see-them-more-often)
- [Puzzle game trends (Mistplay)](https://business.mistplay.com/resources/puzzle-game-trends)
- [Appointment mechanics (GameAnalytics)](https://www.gameanalytics.com/blog/appointment-mechanics-how-to-keep-your-players-in-game)
- [Retention tactics (Pocketgamer.biz / App Annie)](https://www.pocketgamer.biz/app-annie-reveals-the-top-10-retention-tactics-which-turn-first-time-users-into-repeat-players)
