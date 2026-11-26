# Ligas con jugadores reales: propuesta de diseño

Estado actual: los rivales son **simulados** (`game/leagues.gd`), deterministas por semana, y la pantalla
de ligas avisa de ello. Este documento describe cómo pasar a un ranking de usuarios reales sin rehacer
el juego. Nada de esto está implementado todavía: hay decisiones que son tuyas (al final).

## 1. Principio: el modelo actual ya es el modelo del servidor
Hoy cada rival tiene una agenda de partidas y sus puntos en una liga son **lo ganado dentro de la
ventana de esa liga** (flash 3 h ⊂ diaria 24 h ⊂ semanal 7 días). Con jugadores reales se hace igual:
el servidor guarda **eventos de puntos** (jugador, momento, puntos) y calcula cada clasificación sumando
los eventos de su ventana. Así la semanal siempre ≥ diaria ≥ flash para la misma persona, sin lógica extra.

## 2. Opciones de servidor
| Opción | A favor | En contra |
|---|---|---|
| **Supabase** (Postgres + API REST) | Se usa desde Godot con `HTTPRequest`, sin plugins; SQL para sumar ventanas; región UE; plan gratuito amplio | Hay que escribir las funciones SQL |
| **Firebase** (Auth anónima + Firestore) | Muy conocido, escala solo | Godot 4 no tiene SDK oficial (plugins de la comunidad o REST); consultas de suma por ventana incómodas |
| **Google Play Games** (marcadores) | Sin servidor propio, gratis | Solo Android; sin grupos de 30, divisiones ni ascensos/descensos; la liga flash/diaria encaja mal |
| **Servidor propio** | Control total | Mantenimiento, seguridad, copias, coste fijo |

**Recomendación: Supabase** (región Frankfurt). Coste inicial: plan gratuito; con tráfico real, unos
25 USD/mes. Cada nivel completado envía unos pocos cientos de bytes.

## 3. Datos
- `players`: id (uuid anónimo), apodo, avatar (de los 36 fijos), creado, división, versión de la app.
- `leagues`: tipo, inicio, fin, división, grupo (≈30 jugadores). La diaria y la flash son subgrupos de
  la semanal, como ahora.
- `score_events`: jugador, nivel, puntos, momento, versión. Todo ranking = suma por ventana.
- Cierre de semana (tarea programada): ordena, asigna ascensos y descensos y guarda el resultado; el
  móvil solo lo lee y cobra las pistas (las pistas siguen siendo locales).

## 4. Emparejamiento
Grupos de ≈30 por división. Al principio habrá pocos jugadores: el servidor **completa el grupo con los
rivales simulados actuales** y los marca como tales en la interfaz («simulado»), de modo que el ranking
nunca está vacío y es honesto. Según crezca la base de jugadores, se reduce el relleno hasta cero.

## 5. Cambios en el cliente
1. Una pequeña interfaz `LeagueSource` con dos implementaciones: simulada (la actual) y remota.
   `Progress.league_standings` y `Progress.add_league_points` son los únicos puntos de contacto.
2. Cola de puntos pendientes con reintentos (el juego sigue siendo jugable sin conexión).
3. Refresco de la clasificación cada pocos segundos solo con la pantalla de ligas abierta.
4. Si no hay red, se muestra la última clasificación guardada o se cae a la simulada.

## 6. Trampas
Los niveles son deterministas, así que el servidor puede saber **cuánto vale como máximo** cada nivel.
- Fase 1: comprobar que los puntos no superan el máximo del nivel, que el tiempo mínimo es creíble y
  limitar el ritmo de envíos por jugador.
- Fase 2 (si hace falta): enviar la secuencia de toques con sus tiempos (unos 100 bytes por nivel) y
  repetirla en el servidor con la lógica de `game/arrows.gd`.
Ninguna defensa es perfecta con un juego offline; el objetivo es que hacer trampas no compense.

## 7. Identidad y privacidad (importante antes de publicar)
- Cuenta **anónima** ligada al dispositivo; inicio de sesión opcional (Google Play Games) para recuperarla.
- Sin nombre real ni correo. Apodo con filtro de palabras y botón de **reportar**; avatares solo de los
  36 fijos (sin subir imágenes: así no hay que moderar fotos).
- RGPD: política de privacidad, datos en la UE, botón de **borrar cuenta y datos**.
- Menores: Google Play exige declarar el público; si se orienta a niños, aplican las normas de Familias.

## 8. Fases
0. (hecho) Rivales simulados coherentes y marcados.
1. Interfaz `LeagueSource` y cola de puntos, sin servidor.
2. Servidor mínimo: cuenta anónima, grupos semanales, eventos, clasificaciones.
3. Comprobaciones básicas contra trampas.
4. Moderación (reportes, filtro) y borrado de cuenta.
5. Reducir el relleno simulado a medida que haya jugadores.

## 9. Decisiones tuyas
1. ¿Servidor? (recomiendo Supabase; alternativa: Google Play Games si solo importa Android y se acepta perder grupos y divisiones).
2. ¿Plataformas? Solo Android o también iOS más adelante (afecta al inicio de sesión).
3. ¿Se acepta mezclar reales con simulados marcados al principio, o se espera a tener masa crítica?
4. ¿Apodos libres con filtro, o solo apodos prefabricados?
5. ¿Público objetivo y clasificación por edad?
