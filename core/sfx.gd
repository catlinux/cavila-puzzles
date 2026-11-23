extends Node
## Autoload "Sfx": efectos de sonido sintetizados por código (sin archivos de audio).

var _streams := {}
var _players: Array = []
var _next := 0


func _ready() -> void:
	_streams["pop"] = _tone(720.0, 1180.0, 0.11, 0.32)
	_streams["bump"] = _tone(190.0, 110.0, 0.16, 0.45)
	_streams["tap"] = _tone(900.0, 900.0, 0.035, 0.15)
	_streams["hint"] = _tone(980.0, 1480.0, 0.18, 0.22)
	_streams["lose"] = _tone(320.0, 140.0, 0.45, 0.35)
	_streams["win"] = _arpeggio([523.3, 659.3, 784.0, 1046.5], 0.09, 0.28)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(name: String, pitch := 1.0) -> void:
	if not Progress.setting("sound") or not _streams.has(name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.play()


func vibrate(ms: int) -> void:
	if Progress.setting("vibration"):
		Input.vibrate_handheld(ms)


## Tono con barrido de frecuencia y envolvente de golpe suave (tipo "pluck").
func _tone(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / rate
		var env := pow(1.0 - t, 2.2) * minf(1.0, i / (rate * 0.004))
		var v := (sin(phase) + 0.25 * sin(phase * 2.0)) * env * vol
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data, rate)


func _arpeggio(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var total := step * freqs.size() + 0.35
	var n := int(total * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in freqs.size():
		var start := int(k * step * rate)
		var len := int(0.4 * rate)
		var phase := 0.0
		for i in len:
			if start + i >= n:
				break
			var t := float(i) / len
			phase += TAU * freqs[k] / rate
			buf[start + i] += (sin(phase) + 0.2 * sin(phase * 3.0)) * pow(1.0 - t, 2.5) * vol * minf(1.0, i / (rate * 0.003))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	return _wav(data, rate)


func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s
