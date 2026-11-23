extends Node
## Autoload "Sfx": sonido y vibración. Todo se sintetiza por código (sin archivos de audio).
##  - Efectos zen: campanitas en escala pentatónica (suben de nota al encadenar flechas).
##  - Música ambiente: acordes suaves, bajo y una melodía lenta tipo kalimba, en bucle. Se genera en un
##    hilo aparte la primera vez y se guarda en user:// para que las siguientes sea inmediata.

const RATE := 22050
const MUSIC_RATE := 12000
const MUSIC_VERSION := 2
const MUSIC_CACHE := "user://ambient_v%d.pcm"

## Pentatónica de Do (Do5 … Do6): cualquier secuencia de notas suena bien.
const CHIME_NOTES := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.51]

var _streams := {}
var _players: Array = []
var _next := 0
var _music: AudioStreamPlayer
var _thread: Thread


func _ready() -> void:
	for i in CHIME_NOTES.size():
		_streams["chime%d" % i] = _chime(CHIME_NOTES[i], 0.9, 0.26)
	_streams["bump"] = _thud()
	_streams["tap"] = _chime(1046.5, 0.25, 0.10)
	_streams["hint"] = _chime(1318.51, 1.2, 0.16)
	_streams["win"] = _arpeggio([523.25, 659.25, 783.99, 1046.5, 1318.51], 0.13, 0.20)
	_streams["lose"] = _arpeggio([659.25, 523.25, 440.0], 0.22, 0.16)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -11.0
	add_child(_music)
	_start_music()


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func play(name: String, pitch := 1.0) -> void:
	if not Progress.setting("sound") or not _streams.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.play()


## Campanita de la n-ésima flecha encadenada (sube por la escala y vuelve a empezar).
func play_chain(n: int) -> void:
	play("chime%d" % (n % CHIME_NOTES.size()))


## Vibración breve y suave (intensidad reducida).
func vibrate(ms: int, strength := 0.3) -> void:
	if Progress.setting("vibration"):
		Input.vibrate_handheld(ms, strength)


# --- Música ambiente ----------------------------------------------------------------

func set_music(on: bool) -> void:
	Progress.set_setting("music", on)
	if on:
		if _music.stream:
			_music.play()
		else:
			_start_music()
	else:
		_music.stop()


func _start_music() -> void:
	if not Progress.setting("music"):
		return
	var cache := MUSIC_CACHE % MUSIC_VERSION
	if FileAccess.file_exists(cache):
		var f := FileAccess.open(cache, FileAccess.READ)
		if f:
			_set_music_data(f.get_buffer(f.get_length()))
			return
	if _thread and _thread.is_started():
		return
	_thread = Thread.new()
	_thread.start(_generate_music)


func _generate_music() -> void:
	var data := _ambient()
	call_deferred("_music_ready", data)


func _music_ready(data: PackedByteArray) -> void:
	if _thread:
		_thread.wait_to_finish()
	var f := FileAccess.open(MUSIC_CACHE % MUSIC_VERSION, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
	_set_music_data(data)


func _set_music_data(data: PackedByteArray) -> void:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MUSIC_RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = data.size() / 2
	_music.stream = s
	if Progress.setting("music"):
		_music.play()


## Música de 64 s en bucle a 60 pulsos por minuto: 8 acordes de 8 pulsos, un pad muy suave,
## un bajo discreto y una melodía tipo kalimba en pentatónica de La menor. Lo que pasa del
## final se suma al principio, así que el bucle no tiene corte.
func _ambient() -> PackedByteArray:
	var R := MUSIC_RATE
	var beat := 1.0
	var chord_len := 8.0 * beat
	# [voces del pad, notas del acorde para la melodía]
	var chords := [
		[[110.0, 164.81, 220.0, 261.63], [440.0, 523.25, 659.25]],   # La m
		[[87.31, 130.81, 174.61, 220.0], [440.0, 523.25, 698.46]],   # Fa
		[[130.81, 196.0, 261.63, 329.63], [523.25, 659.25, 783.99]], # Do
		[[98.0, 146.83, 196.0, 246.94], [392.0, 587.33, 783.99]],    # Sol
		[[110.0, 164.81, 220.0, 261.63], [440.0, 523.25, 659.25]],   # La m
		[[73.42, 146.83, 174.61, 220.0], [440.0, 587.33, 698.46]],   # Re m
		[[87.31, 130.81, 174.61, 220.0], [440.0, 523.25, 698.46]],   # Fa
		[[98.0, 146.83, 196.0, 246.94], [392.0, 587.33, 783.99]],    # Sol
	]
	var n := int(chord_len * chords.size() * R)
	var buf := PackedFloat32Array()
	buf.resize(n)
	# Pad y bajo: entran despacio y se solapan con el acorde siguiente.
	var voice_len := int((chord_len + 3.0) * R)
	var att := 2.5 * R
	for ci in chords.size():
		var start := int(ci * chord_len * R)
		var freqs: Array = chords[ci][0]
		var phases := []
		phases.resize(freqs.size() + 1)
		phases.fill(0.0)
		var bass: float = freqs[0] / 2.0 if freqs[0] > 90.0 else freqs[0]
		for i in voice_len:
			var env := minf(1.0, i / att) * minf(1.0, (voice_len - i) / att)
			var v := 0.0
			for k in freqs.size():
				phases[k] += TAU * freqs[k] / R
				v += sin(phases[k])
			phases[freqs.size()] += TAU * bass / R
			v = v * 0.026 + sin(phases[freqs.size()]) * 0.045
			buf[(start + i) % n] += v * env
	# Melodía: ritmos con silencios y notas que se mueven por grados conjuntos.
	var scale := [329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]
	var rhythms := [[0.0, 1.0, 2.0, 3.5, 5.0], [0.0, 1.5, 3.0, 4.0, 6.0], [0.0, 2.0, 3.0, 4.5],
		[0.5, 1.0, 2.0, 4.0, 5.5], [0.0, 3.0, 4.0], [0.0, 1.0, 1.5, 2.0, 4.0, 6.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var idx := 3
	var note_len := int(2.4 * R)
	for ci in chords.size():
		var rhythm: Array = rhythms[rng.randi() % rhythms.size()]
		if ci % 4 == 3:
			rhythm = [0.0, 2.0]  # cada cuatro acordes, la frase descansa
		var tones: Array = chords[ci][1]
		for k in rhythm.size():
			if k == 0:
				# Primera nota de cada acorde: la nota del acorde más cercana.
				var best := 0
				for j in scale.size():
					if tones.has(scale[j]) and absi(j - idx) < absi(best - idx):
						best = j
				idx = best
			else:
				idx = clampi(idx + [-2, -1, -1, 1, 1, 2][rng.randi() % 6], 0, scale.size() - 1)
			var f: float = scale[idx]
			var start := int((ci * chord_len + rhythm[k] * beat) * R)
			var ph := 0.0
			var ph2 := 0.0
			var vol := 0.10 if k == 0 else 0.075
			for i in note_len:
				ph += TAU * f / R
				ph2 += TAU * f * 3.0 / R
				var t := float(i) / R
				var env := exp(-t / 0.75) * minf(1.0, i / (R * 0.004))
				var tine := 0.22 * sin(ph2) * exp(-t / 0.08)
				buf[(start + i) % n] += (sin(ph) + tine) * env * vol
	# Eco suave (con vuelta al principio para que el bucle sea continuo).
	var delay := int(0.5 * beat * R)
	for _pass in 2:
		for i in n:
			buf[i] += buf[(i - delay + n) % n] * 0.25
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.55 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	return data


# --- Efectos ------------------------------------------------------------------------

## Campanita: seno con un armónico suave, ataque corto y cola larga.
func _chime(f: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		ph += TAU * f / RATE
		var env := exp(-float(i) / (0.22 * RATE)) * minf(1.0, i / (RATE * 0.006))
		var v := (sin(ph) + 0.18 * sin(ph * 2.0) + 0.06 * sin(ph * 3.0)) * env * vol
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


## Choque: un "toc" grave y corto, sin estridencias.
func _thud() -> AudioStreamWAV:
	var n := int(0.16 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += TAU * lerpf(170.0, 95.0, t) / RATE
		var env := pow(1.0 - t, 3.0) * minf(1.0, i / (RATE * 0.003))
		data.encode_s16(i * 2, int(clampf(sin(ph) * env * 0.32, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _arpeggio(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var total := step * freqs.size() + 0.9
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in freqs.size():
		var start := int(k * step * RATE)
		var ph := 0.0
		for i in int(0.9 * RATE):
			if start + i >= n:
				break
			ph += TAU * freqs[k] / RATE
			buf[start + i] += (sin(ph) + 0.15 * sin(ph * 2.0)) * exp(-i / (0.25 * RATE)) * vol * minf(1.0, i / (RATE * 0.005))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
