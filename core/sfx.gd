extends Node
## Autoload "Sfx": sonido y vibración. Todo se sintetiza por código (sin archivos de audio).
##  - Efectos zen: campanitas en escala pentatónica (suben de nota al encadenar flechas).
##  - Música ambiente: pad de acordes suaves con campanitas y eco, en bucle. Se genera en un
##    hilo aparte la primera vez y se guarda en user:// para que las siguientes sea inmediata.

const RATE := 22050
const MUSIC_RATE := 16000
const MUSIC_VERSION := 1
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


## Pad de 4 acordes (8 s cada uno) con campanitas pentatónicas y eco. El bucle no tiene
## corte: lo que sobrepasa el final se suma al principio.
func _ambient() -> PackedByteArray:
	var chord_len := 8.0
	var chords := [
		[110.0, 164.81, 196.0, 246.94, 261.63],  # La m9
		[87.31, 130.81, 164.81, 220.0],          # Fa maj7
		[130.81, 196.0, 246.94, 329.63],         # Do maj7
		[98.0, 146.83, 246.94, 293.66],          # Sol 6
	]
	var n := int(chord_len * chords.size() * MUSIC_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	# Pad: cada voz entra despacio, se mantiene y se apaga solapándose con el siguiente acorde.
	var voice_len := int((chord_len + 3.0) * MUSIC_RATE)
	var att := 3.0 * MUSIC_RATE
	for ci in chords.size():
		var start := int(ci * chord_len * MUSIC_RATE)
		for f in chords[ci]:
			var ph := 0.0
			var amp := 0.055 if f < 200.0 else 0.04
			for i in voice_len:
				var env := minf(1.0, i / att) * minf(1.0, (voice_len - i) / att)
				ph += TAU * f * (1.0 + 0.0015 * sin(i * 0.00031)) / MUSIC_RATE
				buf[(start + i) % n] += (sin(ph) + 0.12 * sin(ph * 2.0)) * env * amp
	# Campanitas suaves al azar (semilla fija: siempre la misma melodía).
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var bells := [440.0, 523.25, 587.33, 659.25, 783.99, 880.0]
	var t := 1.0
	var bell_len := int(2.6 * MUSIC_RATE)
	while t < chord_len * chords.size():
		if rng.randf() < 0.7:
			var f: float = bells[rng.randi() % bells.size()]
			var start := int(t * MUSIC_RATE)
			var ph := 0.0
			for i in bell_len:
				ph += TAU * f / MUSIC_RATE
				var env := exp(-i / (0.55 * MUSIC_RATE)) * minf(1.0, i / 60.0)
				buf[(start + i) % n] += (sin(ph) + 0.25 * sin(ph * 2.01)) * env * 0.05
		t += rng.randf_range(1.2, 2.8)
	# Eco (con vuelta al principio para que el bucle sea continuo).
	var delay := int(0.42 * MUSIC_RATE)
	for _pass in 2:
		for i in n:
			buf[i] += buf[(i - delay + n) % n] * 0.28
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
