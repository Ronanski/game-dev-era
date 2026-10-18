extends Node
## Tiny synthesized sound kit (no audio files) plus haptic feedback.

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams.tap = _tone([880.0], 0.05, 0.25, "sine")
	_streams.soft = _tone([620.0], 0.04, 0.18, "sine")
	_streams.mark = _tone([440.0], 0.04, 0.16, "sine")
	_streams.place = _tone([660.0, 990.0], 0.09, 0.28, "sine")
	_streams.rotate = _tone([520.0], 0.035, 0.18, "tri")
	_streams.undo = _tone([700.0, 520.0], 0.08, 0.2, "sine")
	_streams.error = _tone([170.0, 140.0], 0.16, 0.3, "tri")
	_streams.flash = _tone([1046.5], 0.12, 0.2, "sine")
	_streams.connect = _tone([523.25, 783.99], 0.12, 0.22, "sine")
	_streams.win = _tone([523.25, 659.25, 783.99, 1046.5], 0.5, 0.3, "chord")
	_streams.hint = _tone([987.77, 1318.5], 0.14, 0.2, "sine")


func play(name: String, pitch := 1.0) -> void:
	if not Save.setting("sound") or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.play()


func buzz(ms := 12) -> void:
	if Save.setting("haptics") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Builds a short PCM clip. Multiple freqs play in sequence ("sine"/"tri")
## or as an arpeggiated chord ("chord").
func _tone(freqs: Array, dur: float, vol: float, wave: String) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var seg := n / freqs.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		if wave == "chord":
			for k in freqs.size():
				var start := k * 0.06
				if t >= start:
					var tt := t - start
					v += sin(TAU * freqs[k] * tt) * exp(-tt * 5.0) / freqs.size() * 1.6
		else:
			var f: float = freqs[min(i / max(seg, 1), freqs.size() - 1)]
			phase += f / RATE
			var x := fmod(phase, 1.0)
			v = sin(TAU * x) if wave == "sine" else (4.0 * absf(x - 0.5) - 1.0)
			var env := minf(1.0, t * 400.0) * exp(-t / dur * 4.0)
			v *= env
		var s := int(clampf(v * vol, -1.0, 1.0) * 32767.0)
		buf.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = buf
	return w
