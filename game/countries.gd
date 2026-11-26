extends RefCounted
## Países de los jugadores simulados: los más comunes entre quienes juegan en español y en Europa/América,
## con una probabilidad proporcional a su población (España algo por encima por ser el mercado
## principal; EE. UU. contenido). Cada país tiene su huso horario (los rivales juegan en SUS horas
## normales), nombres acordes y una bandera (dibujada en `ui/flags.gd`).
##
## `w` = peso (suman 100), `off` = husos posibles en horas respecto a UTC (invierno del hemisferio
## norte; no se modela el cambio de hora), `f`/`m` = nombres de pila.

const COUNTRIES := {
	"ES": {"w": 19, "off": [1], "f": ["Lucía", "Carmen", "Marta", "Paula", "Laura", "Sara", "Elena", "Irene", "Cristina", "Alba",
		"Nerea", "Ainhoa", "Aitana", "Rocío", "Mireia", "Laia", "Núria", "Clàudia", "Júlia", "Berta"],
		"m": ["Álvaro", "Javier", "Carlos", "Pablo", "Adrián", "Sergio", "Marc", "Jordi", "Pau", "Arnau", "Iker", "Unai", "Hugo",
		"Daniel", "David", "Raúl", "Oriol", "Xavi", "Miguel", "Rubén"]},
	"MX": {"w": 13, "off": [-6], "f": ["Guadalupe", "Ximena", "Valeria", "Fernanda", "Regina", "Camila", "Renata", "Daniela", "Mariana",
		"Paola", "Citlali", "Jimena", "Yazmín", "Itzel", "Montserrat"],
		"m": ["Santiago", "Mateo", "Diego", "Emiliano", "Sebastián", "Leonardo", "Ángel", "Jesús", "Luis", "Iván", "Alan", "Axel",
		"Rodrigo", "Fernando", "Ulises"]},
	"AR": {"w": 8, "off": [-3], "f": ["Sofía", "Valentina", "Martina", "Camila", "Julieta", "Agustina", "Florencia", "Milagros", "Lucía",
		"Abril", "Candela", "Guadalupe", "Rocío", "Brenda", "Micaela"],
		"m": ["Matías", "Facundo", "Nicolás", "Tomás", "Lautaro", "Joaquín", "Franco", "Santiago", "Bautista", "Thiago", "Maxi",
		"Gonzalo", "Ezequiel", "Ramiro", "Agustín"]},
	"CO": {"w": 8, "off": [-5], "f": ["Valentina", "Sofía", "Isabella", "Mariana", "Juliana", "Daniela", "Laura", "Camila", "Natalia",
		"Alejandra", "Paula", "Manuela", "Luisa", "Carolina", "Catalina"],
		"m": ["Santiago", "Juanpa", "Sebastián", "Mateo", "Andrés", "Camilo", "Felipe", "Samuel", "Nicolás", "Daniel", "Esteban",
		"Julián", "Alejandro", "Cristian", "Johan"]},
	"CL": {"w": 4, "off": [-3], "f": ["Constanza", "Javiera", "Catalina", "Francisca", "Antonia", "Fernanda", "Camila", "Valentina",
		"Macarena", "Isidora", "Trinidad", "Florencia", "Paz", "Josefa", "Colomba"],
		"m": ["Benjamín", "Vicente", "Matías", "Martín", "Joaquín", "Cristóbal", "Sebastián", "Nicolás", "Felipe", "Ignacio",
		"Maximiliano", "Tomás", "Agustín", "Diego", "Rodrigo"]},
	"PE": {"w": 4, "off": [-5], "f": ["Camila", "Valeria", "Luciana", "Mía", "Fernanda", "Rosa", "Milagros", "Alexandra", "Gabriela",
		"Karla", "Dayana", "Jimena", "Andrea", "Lucero", "Xiomara"],
		"m": ["Luis", "Jeanpi", "Diego", "Carlos", "Jorge", "Miguel", "Piero", "Renzo", "Anthony", "César", "Mauricio", "Alonso",
		"Gianluca", "Bryan", "Jhon"]},
	"VE": {"w": 3, "off": [-4], "f": ["Andreína", "Génesis", "Yoselin", "Daniela", "Valeria", "Mariangel", "Gabriela", "Karina", "Oriana",
		"Rosmery", "Sofía", "Alejandra", "Mariana", "Yaritza", "Daniela"],
		"m": ["José", "Luis", "Carlos", "Jesús", "Ángel", "Alejandro", "Gabriel", "Eduardo", "Wilmer", "Argenis", "Daniel", "Rafael",
		"Henry", "Víctor", "Yonathan"]},
	"EC": {"w": 2, "off": [-5], "f": ["Doménica", "Camila", "Mishel", "Valentina", "Daniela", "Génesis", "Dayana", "Ariana", "Michelle",
		"Andrea", "Paola", "Karen", "Cristina", "Anahí", "Nayeli"],
		"m": ["Josué", "Mateo", "Santiago", "Kevin", "Anderson", "Joel", "Bryan", "David", "Jordan", "Steven", "Alex", "Dylan",
		"Cristian", "Luis", "Pablo"]},
	"BR": {"w": 8, "off": [-3], "f": ["Maria", "Ana", "Juliana", "Beatriz", "Larissa", "Gabriela", "Camila", "Fernanda", "Mariana",
		"Letícia", "Isabela", "Amanda", "Bruna", "Rafaela", "Thaís"],
		"m": ["João", "Pedro", "Lucas", "Gabriel", "Matheus", "Rafael", "Gustavo", "Felipe", "Bruno", "Guilherme", "Thiago", "Caio",
		"Vinícius", "Leonardo", "Rodrigo"]},
	"FR": {"w": 6, "off": [1], "f": ["Camille", "Léa", "Chloé", "Manon", "Inès", "Emma", "Jade", "Louise", "Clara", "Océane", "Margaux",
		"Pauline", "Élodie", "Juliette", "Sarah"],
		"m": ["Lucas", "Hugo", "Louis", "Gabriel", "Léo", "Théo", "Maxime", "Antoine", "Thomas", "Nathan", "Mathis", "Julien",
		"Romain", "Clément", "Baptiste"]},
	"DE": {"w": 6, "off": [1], "f": ["Anna", "Lena", "Lea", "Laura", "Julia", "Hannah", "Sophie", "Lisa", "Katharina", "Marie", "Johanna",
		"Nele", "Jana", "Lara", "Franziska"],
		"m": ["Lukas", "Jonas", "Felix", "Leon", "Maximilian", "Tobias", "Niklas", "Jan", "Moritz", "Florian", "Sebastian", "Tim",
		"Paul", "Fabian", "Philipp"]},
	"IT": {"w": 6, "off": [1], "f": ["Giulia", "Sofia", "Martina", "Chiara", "Francesca", "Alessia", "Giorgia", "Elena", "Sara",
		"Valentina", "Federica", "Aurora", "Beatrice", "Elisa", "Silvia"],
		"m": ["Luca", "Marco", "Matteo", "Francesco", "Alessandro", "Andrea", "Lorenzo", "Davide", "Simone", "Federico", "Riccardo",
		"Gabriele", "Giacomo", "Stefano", "Tommaso"]},
	"GB": {"w": 5, "off": [0], "f": ["Olivia", "Amelia", "Emily", "Charlotte", "Sophie", "Hannah", "Lucy", "Grace", "Megan", "Chloe",
		"Holly", "Jessica", "Eleanor", "Poppy", "Rebecca"],
		"m": ["Oliver", "George", "Harry", "Jack", "Charlie", "Thomas", "James", "Oscar", "Callum", "Alfie", "Liam", "Ben", "Ryan",
		"Josh", "Daniel"]},
	"PT": {"w": 3, "off": [0], "f": ["Beatriz", "Matilde", "Inês", "Maria", "Mariana", "Carolina", "Leonor", "Ana", "Rita", "Joana",
		"Sara", "Diana", "Catarina", "Marta", "Filipa"],
		"m": ["João", "Tiago", "Rodrigo", "Miguel", "Diogo", "Gonçalo", "Francisco", "André", "Pedro", "Rui", "Nuno", "Bruno",
		"Ricardo", "Hugo", "Duarte"]},
	"US": {"w": 5, "off": [-5, -5, -6, -8], "f": ["Emma", "Ava", "Madison", "Ashley", "Brittany", "Kayla", "Taylor", "Jessica", "Megan",
		"Lauren", "Olivia", "Hailey", "Savannah", "Mia", "Abby"],
		"m": ["Jake", "Ethan", "Tyler", "Mason", "Logan", "Brandon", "Austin", "Cody", "Hunter", "Noah", "Dylan", "Connor",
		"Jackson", "Chase", "Trevor"]},
}

## Apodos neutros para quien usa un avatar de animal.
const NICKS := ["LunaFox", "zenpanda", "n0va", "KoalaKid", "Bruma", "pixel_owl", "Tito99", "Mochi", "Cometa",
	"Nube", "TigreRoig", "ElOso", "sloth_mode", "PinguiX", "Kiwi", "Churro", "Pistacho", "Ondas", "Brisa", "Zorro_",
	"Tortuga77", "MarAzul", "Bambú", "Cacao", "Trufa", "Valen", "NoraLuna", "Sombra", "Chispa7", "Menta",
	"Wombat", "Pixel", "Nimbus", "Otter42", "Mango", "Blip", "Fenix", "Coco", "Yeti", "Luciérnaga"]


## País al azar con probabilidad proporcional al peso.
static func pick(rng: RandomNumberGenerator) -> String:
	var total := 0
	for code in COUNTRIES:
		total += int(COUNTRIES[code].w)
	var r := rng.randi() % total
	for code in COUNTRIES:
		r -= int(COUNTRIES[code].w)
		if r < 0:
			return code
	return "ES"


## Huso horario (horas respecto a UTC) de un rival de ese país.
static func offset(rng: RandomNumberGenerator, code: String) -> int:
	var l: Array = COUNTRIES[code].off
	return int(l[rng.randi() % l.size()])


## Nombre con estilo variado: «Camila», «Camila R.», «camila_27», «Camila98» o «camila_mx».
static func make_name(rng: RandomNumberGenerator, code: String, gender: String, taken: Dictionary) -> String:
	for _try in 12:
		var base: String = COUNTRIES[code][gender][rng.randi() % COUNTRIES[code][gender].size()]
		var r := rng.randf()
		var nm := base
		if r >= 0.45 and r < 0.65:
			nm = "%s %s." % [base, char(65 + rng.randi() % 26)]
		elif r >= 0.65 and r < 0.82:
			nm = "%s_%d" % [base.to_lower(), rng.randi_range(1, 99)]
		elif r >= 0.82 and r < 0.92:
			nm = "%s%d" % [base, rng.randi_range(80, 99)]
		elif r >= 0.92:
			nm = "%s_%s" % [base.to_lower(), code.to_lower()]
		if not taken.has(nm):
			return nm
	return "%s%d" % [COUNTRIES[code][gender][0], rng.randi_range(100, 999)]
