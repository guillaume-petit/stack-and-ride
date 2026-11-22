extends SceneTree
## Writes the provisional sounds of the game to assets/sounds/ (one .wav per Sfx.Sound).
##
## They are synthesized from sine waves and noise, so that the game has sounds before real ones
## are made. To replace a sound, overwrite its .wav file (same name) and stop running this script.
##
## Usage: godot --headless --path . --script res://scripts/make_sounds.gd
## (or scripts/make_sounds.sh / scripts\make_sounds.ps1). The output is always the same.

const FOLDER := "res://assets/sounds/"
const RATE := 22050

var _noise := RandomNumberGenerator.new()


func _initialize() -> void:
	_noise.seed = 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	var made := 0
	for sound_name: String in Sfx.Sound.keys():
		var samples := _make(sound_name)
		if samples.is_empty():
			push_error("No recipe for the sound %s" % sound_name)
			continue
		var path := FOLDER + sound_name.to_lower() + ".wav"
		var error := _stream(samples).save_to_wav(path)
		if error != OK:
			push_error("Could not write %s (error %d)" % [path, error])
			continue
		made += 1
		print("%s (%.2f s)" % [path, samples.size() / float(RATE)])
	print("%d sounds written. Open the project in the editor (or run with --import) to import them." % made)
	quit(0 if made == Sfx.Sound.size() else 1)


func _make(sound_name: String) -> PackedFloat32Array:
	match sound_name:
		"CLICK":
			return _tone(1400.0, 1400.0, 0.035, 0.35, 90.0)
		"CARD":
			# A card slid on the table: a short swish of noise.
			return _swish(0.13, 0.32)
		"PEDAL":
			return _tone(620.0, 520.0, 0.045, 0.22, 60.0)
		"TAKE":
			return _tone(380.0, 920.0, 0.09, 0.4, 25.0)
		"DROP":
			return _mix([_tone(150.0, 70.0, 0.16, 0.45, 22.0), _noise_burst(0.04, 0.15)])
		"DELIVER":
			# A bike bell: ding ding.
			return _mix([_bell(1900.0, 0.0, 0.35, 0.35), _bell(1900.0, 0.13, 0.45, 0.4)])
		"BAD":
			return _tone(320.0, 170.0, 0.28, 0.4, 6.0, true)
		"SHAKE":
			return _rattle(0.32, 0.4)
		"REFUSE":
			return _mix([_tone(230.0, 210.0, 0.07, 0.35, 20.0, true), _delayed(_tone(200.0, 180.0, 0.08, 0.35, 20.0, true), 0.09)])
		"BUY":
			return _mix([_noise_burst(0.05, 0.3), _delayed(_bell(2400.0, 0.0, 0.4, 0.3), 0.04)])
		"NIGHT_END":
			return _melody([523.25, 659.25, 783.99], 0.12, 0.3)
		"WIN":
			return _melody([523.25, 659.25, 783.99, 1046.5], 0.13, 0.4)
		"LOSE":
			return _melody([392.0, 329.63, 261.63], 0.2, 0.4)
	return PackedFloat32Array()


# --- Recipes --------------------------------------------------------------------------------

## A tone gliding from one frequency to another, fading out (decay: how fast). square: a harsher
## sound for bad news.
func _tone(from_hz: float, to_hz: float, seconds: float, volume: float, decay: float,
		square: bool = false) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var phase := 0.0
	for i in out.size():
		var t := i / float(RATE)
		phase += lerpf(from_hz, to_hz, t / seconds) / RATE
		var wave := sin(phase * TAU)
		if square:
			wave = clampf(wave * 3.0, -1.0, 1.0) * 0.6
		out[i] = wave * volume * exp(-decay * t) * _fade_out(t, seconds)
	return out


## A bell: a few inharmonic partials that ring and fade.
func _bell(base_hz: float, start: float, seconds: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int((start + seconds) * RATE))
	var partials := [[1.0, 1.0], [2.76, 0.4], [5.4, 0.2]]
	for i in range(int(start * RATE), out.size()):
		var t := i / float(RATE) - start
		var value := 0.0
		for partial: Array in partials:
			value += sin(t * base_hz * partial[0] * TAU) * partial[1]
		out[i] = value / 1.6 * volume * exp(-9.0 * t) * minf(1.0, t * 400.0) * _fade_out(t, seconds)
	return out


func _swish(seconds: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var smooth := 0.0
	for i in out.size():
		var t := i / float(RATE)
		# Noise smoothed more and more: the swish goes from bright to dull.
		smooth = lerpf(smooth, _noise.randf_range(-1.0, 1.0), lerpf(0.6, 0.15, t / seconds))
		out[i] = smooth * volume * sin(PI * t / seconds)
	return out


func _noise_burst(seconds: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	for i in out.size():
		var t := i / float(RATE)
		out[i] = _noise.randf_range(-1.0, 1.0) * volume * (1.0 - t / seconds)
	return out


## Things rattling in a bag: noise switched on and off quickly.
func _rattle(seconds: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	var smooth := 0.0
	for i in out.size():
		var t := i / float(RATE)
		smooth = lerpf(smooth, _noise.randf_range(-1.0, 1.0), 0.35)
		var knocks := pow(maxf(0.0, sin(t * TAU * 16.0)), 6.0)
		out[i] = smooth * volume * (0.25 + knocks) * (1.0 - t / seconds)
	return out


## Notes one after the other, each a soft tone.
func _melody(notes: Array, note_seconds: float, volume: float) -> PackedFloat32Array:
	var parts: Array[PackedFloat32Array] = []
	for index in notes.size():
		var length := note_seconds * (2.5 if index == notes.size() - 1 else 1.4)
		parts.append(_delayed(_soft_note(notes[index], length, volume), index * note_seconds))
	return _mix(parts)


func _soft_note(hz: float, seconds: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	for i in out.size():
		var t := i / float(RATE)
		var wave := sin(t * hz * TAU) + 0.3 * sin(t * hz * 2.0 * TAU)
		out[i] = wave / 1.3 * volume * minf(1.0, t * 200.0) * exp(-4.0 * t) * _fade_out(t, seconds)
	return out


# --- Helpers --------------------------------------------------------------------------------

## The last 10 ms fade to silence, so that the sound ends without a click.
func _fade_out(t: float, seconds: float) -> float:
	return clampf((seconds - t) / 0.01, 0.0, 1.0)


func _delayed(samples: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	out.append_array(samples)
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part: PackedFloat32Array in parts:
		if part.size() > out.size():
			out.resize(part.size())
		for i in part.size():
			out[i] += part[i]
	return out


func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
