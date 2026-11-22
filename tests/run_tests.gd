extends SceneTree
## Ejecutar con:  godot --headless --path . --script tests/run_tests.gd [-- --quick]
## Código de salida 0 si todo pasa, 1 si algo falla.

const SUITES := [
	"res://tests/test_core.gd",
	"res://tests/test_circuito.gd",
	"res://tests/test_sendero.gd",
	"res://tests/test_piezas.gd",
]


func _init() -> void:
	var quick := "--quick" in OS.get_cmdline_user_args()
	var total_checks := 0
	var total_fail := 0
	for path in SUITES:
		var s = load(path).new()
		s.quick = quick
		var t0 := Time.get_ticks_msec()
		s.run()
		total_checks += s.checks
		total_fail += s.failures.size()
		print("[%s] %s: %d comprobaciones, %d fallos (%d ms)" % [
			"OK" if s.failures.is_empty() else "FALLO", s.name, s.checks, s.failures.size(),
			Time.get_ticks_msec() - t0])
		for f in s.failures.slice(0, 15):
			print("    - ", f)
	print("TOTAL: %d comprobaciones, %d fallos" % [total_checks, total_fail])
	quit(1 if total_fail > 0 else 0)
