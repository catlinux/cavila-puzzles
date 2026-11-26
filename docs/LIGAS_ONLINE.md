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

### Plan gratuito de Supabase (comprobado el 2026-11-26 en supabase.com/pricing)
- 2 proyectos activos, 500 MB de base de datos por proyecto, 50.000 usuarios activos al mes.
- **Se pausa tras 7 días con poca actividad** (mientras está pausado nadie puede jugar las ligas). Los proyectos de pago no se pausan.
- Sin las copias diarias que trae el plan Pro (Pro: 25 USD/mes, 8 GB de disco, 100.000 usuarios activos al mes).
- Hay también límites de transferencia mensual y de funciones: revisar la página oficial antes de decidir.
- Uso estimado nuestro: cada evento de puntos ocupa ~100 bytes y se borrarían los de más de un mes: caben millones de eventos. Plan gratuito para desarrollar y probar; Pro antes de publicar.

**Recomendación (si se usa un servicio gestionado): Supabase** (región Frankfurt). Coste inicial: plan gratuito; con tráfico real, unos
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

## 9. Decisiones tomadas (2026-11-26)
- **Plataforma: solo Android** (sin iOS). Se publica en Google Play; el inicio de sesión opcional será Google Play Games.
- **Reales y simulados mezclados desde el principio**: cada grupo tiene un tope total (30). Los puestos que no ocupen jugadores reales los rellenan rivales simulados (marcados como tales). Los reales ocupan puestos primero; cuando haya masa crítica, los simulados desaparecen.
- **Apodo**: se genera uno automático al instalar (como los de la simulación) y se puede cambiar libremente, con filtro (longitud, palabras ofensivas, sin enlaces ni datos de contacto) y botón de reportar.
- **Edades (propuesta pendiente de confirmar)**: ranking con jugadores reales solo para **mayores de 14** (en España, el RGPD/LOPDGDD exige consentimiento de los padres por debajo de esa edad), con una pantalla de edad neutra al activar las ligas online. Los menores de 14 juegan igual con ligas simuladas y marcadas, sin cuenta online. Sin anuncios ni SDKs de seguimiento, sin nombre ni correo, con botón de borrar cuenta. Google Play: si el público declarado incluye niños aplica la política de Familias (pantalla de edad neutra en apps mixtas, solo SDKs aprobados, sin identificadores de publicidad, aviso de seguridad si hay funciones sociales); nuestras ligas no tienen chat, solo apodo y avatar. No es asesoramiento legal: revisar la política de privacidad y la declaración de edades antes de publicar.
- **Servidor**: pendiente de decidir (recomendado Supabase; el plan gratuito sirve para pruebas, pero se pausa por inactividad).

## 10. ¿Usar un VPS propio como servidor? (consulta del 2026-11-26)
Sí se puede, y para este juego es razonable. Lo que necesita el móvil es poco: crear jugador anónimo,
enviar puntos, pedir clasificación, cambiar apodo, reportar y borrar cuenta (6 llamadas).
- **No conviene autoalojar Supabase completo**: son ~10 contenedores y varios GB de RAM, demasiado para
  lo que necesitamos.
- **Opción recomendada**: una API pequeña propia (Python/FastAPI o Go) + PostgreSQL (o SQLite al principio)
  + Caddy como proxy HTTPS, todo en `docker compose`. Unos 512 MB-1 GB de RAM bastan para miles de jugadores.
- **Obligatorio**: dominio o subdominio con HTTPS (Android bloquea HTTP sin cifrar), copia de seguridad
  diaria fuera del VPS, cortafuegos, actualizaciones automáticas de seguridad y límite de peticiones.
- **Ventajas**: sin pausa por inactividad, sin coste por usuario, datos donde tú decidas (mejor en la UE).
- **Inconvenientes**: lo mantienes tú (seguridad, copias, caídas) y es un único punto de fallo. El juego
  debe seguir funcionando si el servidor cae: se muestra la última clasificación o la simulada (ya previsto).
- **RGPD**: aunque sea tu servidor, tú eres el responsable de los datos: política de privacidad, borrado de
  cuenta y logs sin IPs (o con caducidad corta).
- **Datos que faltan para decidir**: RAM/CPU/disco del VPS, sistema operativo, país del centro de datos,
  si hay dominio disponible y si ya corre otros servicios.

