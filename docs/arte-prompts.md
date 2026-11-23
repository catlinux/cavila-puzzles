# Cavila: prompts para generar arte con IA

Guía para crear con una IA de imágenes todo lo visual que el juego necesita y que no se puede dibujar
por código. Los prompts están en **inglés** porque los generadores lo entienden mejor; el texto del
juego (nombres, números, rótulos) lo pone el código, así que **nunca pidas texto dentro de la imagen**.

## 1. Prompt maestro (pégalo al principio de TODOS los encargos)

```
STYLE (keep identical for every image):
Clean, modern casual mobile-game illustration. Flat vector look with very subtle soft gradients
and a gentle soft drop shadow underneath. Rounded, friendly, geometric shapes; no sharp spikes;
thick smooth shapes, no fine detail, readable at 64 px. Premium, calm, relaxing puzzle-game mood.
No outlines, or at most a very thin darker shade of the fill colour. Light, airy, high-key lighting.

PALETTE: deep navy ink #1D2842, porcelain white #FFFFFF and #F2F4F9, soft grey #7A859C,
gold #FFB020, and accent gradients: coral #FF6A55 to orange #FF9A3D (main), blue #3B82F6 to teal
#22B8CF, amber #F59E0B to orange #F97316, violet #8B5CF6 to magenta #D946EF, green #10B981 to
lime #65C028, red #EF4444 to orange #F97316, cyan #06B6D4 to blue #3B82F6, purple #A855F7 to
indigo #6366F1.

COMPOSITION: one single centered object/character, front view, generous empty margin around it
(at least 12% each side), perfectly symmetrical when possible. Square 1:1 format.
BACKGROUND: perfectly flat solid pure magenta #FF00FF with no gradient, no shadow on the
background, no texture (it will be removed afterwards). The object's own soft shadow must stay
inside the object's silhouette area, not spread across the background.

STRICTLY AVOID: any text, letters, numbers, logos, watermarks, signatures, real people likeness,
existing brands, existing characters or games, photorealism, 3D renders with heavy glossy
reflections, busy backgrounds, dark/gritty mood.

NOW CREATE: <aquí el encargo concreto de la lista de abajo>
```

## 2. Qué hace falta (por orden de prioridad)

| # | Recurso | Cantidad | Tamaño | Dónde se usa |
|---|---|---|---|---|
| 1 | Icono de la app | 1 (+ versión adaptativa) | 1024×1024 | Pantalla del móvil y Play Store |
| 2 | Avatares de jugadores | 30–40 | 512×512 | Ligas (rivales y tu perfil) |
| 3 | Insignias de división | 5 | 512×512 | Ligas: Bronce, Plata, Oro, Platino, Diamante |
| 4 | Medallas del podio | 3 | 512×512 | Puestos 1.º, 2.º y 3.º |
| 5 | Emblemas de los mundos | 8 | 512×512 | Alba, Marea, Ámbar, Bruma, Bosque, Ascua, Glaciar, Nébula |
| 6 | Emblemas de categoría | 4 | 512×512 | Respiro, Difícil, Súper difícil, Extra |
| 7 | Insignias de logros | 12–16 | 512×512 | Pantalla de logros (por hacer) |
| 8 | Gráfico de cabecera de Play Store | 1 | 1024×500 | Ficha en Google Play |
| 9 | Pantalla de carga | 1 | 1080×1920 | Al abrir el juego |
| 10 | Mascota (opcional) | 1 con 5–6 poses | 1024×1024 | Tutorial, victoria, derrota |

## 3. Encargos concretos (se pegan después del prompt maestro)

### 3.1 Icono de la app
```
App icon for a calm arrow puzzle game. A single thick rounded arrow made of one smooth
continuous line that makes one soft right-angle curve, pointing up and to the right, in a coral
#FF6A55 to orange #FF9A3D gradient, with a small round white dot at its tail. Placed on a
rounded-square porcelain-white #FFFFFF tile with a very soft shadow. Minimal, instantly readable
at 48 px, no text. Square 1:1, 1024x1024. For this one only: instead of the magenta background,
fill the whole canvas with the tile edge-to-edge in the gradient background coral to orange and
make the arrow white.
```
Pídelo también como **primer plano** (solo la flecha, fondo magenta) y como **fondo** (solo el
degradado), para el icono adaptativo de Android.

### 3.2 Avatares de jugadores (haz tandas de 6–8 y varía el sujeto)
```
Friendly avatar portrait of a cute <SUJETO>, head and shoulders only, big simple eyes, tiny
smile, round face shape, a soft pastel accent colour from the palette, circular composition so
it can be cropped into a circle. Same style, same eye shape and same soft shading in every
avatar of the set.
```
Sustituye `<SUJETO>` por: fox, panda, owl, cat, dog, rabbit, bear, penguin, frog, deer, koala,
tiger, hedgehog, otter, raccoon, lion, elephant, turtle, parrot, hamster… Para variedad añade:
`abstract geometric character made of overlapping circles and a smile` (6 distintos) y
`friendly robot` (3 distintos). **Evita personas realistas.**

### 3.3 Insignias de división (5)
```
League rank badge: a rounded shield shape with a soft raised border and a big simple star in the
centre, made of <MATERIAL>. Subtle shine, no text. Same shield shape and same star in all five
badges; only the material and colour change.
```
`<MATERIAL>`: warm polished bronze (#B07040) · cool brushed silver (#A8B4C6) · rich gold
(#F5C442) · teal platinum (#2DD4BF) · sparkling blue diamond (#3B82F6 to #67E8F9, with a few
small facets).

### 3.4 Medallas del podio (3)
```
Round podium medal on a short ribbon, <N> engraved as a simple large star-less relief (no
numbers), <MATERIAL>, soft shine, friendly rounded look.
```
Oro, plata y bronce, con el mismo diseño.

### 3.5 Emblemas de los mundos (8)
```
Round emblem representing the game world "<MUNDO>": <ESCENA>, drawn as a simple badge inside a
circle with a soft inner shadow, using the gradient <GRADIENTE> as its main colours.
```
| Mundo | Escena | Gradiente |
|---|---|---|
| Alba | a calm sunrise over a hill | coral → orange |
| Marea | gentle waves with a small moon | blue → teal |
| Ámbar | a glowing amber crystal | amber → orange |
| Bruma | soft layered fog and a tiny star | violet → magenta |
| Bosque | a round tree with leaves | green → lime |
| Ascua | a small calm ember flame | red → orange |
| Glaciar | a faceted ice crystal | cyan → blue |
| Nébula | a soft swirl galaxy with stars | purple → indigo |

### 3.6 Emblemas de categoría (4)
`Respiro`: a green leaf with a tiny cloud · `Difícil`: an orange flame · `Súper difícil`: a red
double flame with a spark · `Extra`: a purple crown with sparkles. Mismo estilo de insignia redonda.

### 3.7 Insignias de logros (12–16)
```
Achievement badge: a round soft medal containing <SÍMBOLO>, with a small ribbon, accent colour
<COLOR>.
```
Ideas de símbolo: first level done (a small flag), 10 levels (a number-less star), 100 levels
(a mountain), 7-day streak (a flame), 30-day streak (a double flame), win a league (a trophy),
gold division (a crown), first maze (a winding line), no mistakes (a heart), 5 hints saved (a
lightbulb), a night owl (an owl and moon), marathon (a clock).

### 3.8 Gráfico de cabecera de Google Play (1024×500)
```
Wide banner for a relaxing arrow puzzle game. On the left a big clean maze of thick rounded
coral and navy arrows flowing out of a rounded board, on the right a large empty soft porcelain
area (the logo text will be added later). Light airy gradient background from #FFFFFF to
#F2F4F9 with a faint coral glow. 1024x500, no text.
```
Las **capturas** de Play Store no las hace la IA: se sacan del propio juego.

### 3.9 Pantalla de carga
`Vertical 1080x1920 splash: very soft white-to-porcelain gradient background with faint coral and
blue glows, plenty of empty space in the centre (the logo will be placed there), no text.`

### 3.10 Mascota (opcional)
```
Cute mascot "Chispa": a small round firefly-like creature with a glowing coral tail, big simple
eyes, tiny antennae, soft rounded body, friendly. Show it in a neutral pose first.
```
Después, en la misma conversación: contenta, celebrando, pensando, triste, durmiendo.

## 4. Cómo trabajar para que todo case

1. **Una sola sesión** (o la misma herramienta con la función de *referencia de estilo*): sube
   2–3 capturas del juego y una primera imagen aprobada como referencia para el resto.
2. Genera 4 variantes por encargo y elige. Si una no sale, repite con el mismo prompt, no cambies el estilo.
3. **Fondo magenta plano**: luego se recorta con un quitafondos o con una clave de color. Si me pasas los
   archivos con fondo magenta, **yo los recorto** y los integro en el juego.
4. Pide siempre **sin texto**. Los generadores escriben mal; el texto lo pone el juego.
5. Exporta a 1024 como mínimo y deja los originales sin comprimir.

## 5. Licencias y monetización

- Cada herramienta tiene sus propios términos, y **los de los planes gratuitos suelen ser más
  restrictivos que los de pago**. Antes de usar nada comercialmente, lee los términos del plan
  concreto con el que generas y guarda una captura de esos términos con la fecha.
- No metas en los prompts nombres de artistas vivos, marcas, juegos ni personajes existentes.
- En muchos países el material generado íntegramente por IA **no tiene derecho de autor**
  protegible: otros podrían copiarlo. Para el icono y el logo, que son tu marca, conviene que un
  diseñador los retoque o los rehaga cuando el juego despegue.
- Conserva los prompts y las fechas: sirven como prueba de origen.
