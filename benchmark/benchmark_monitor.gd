extends Node

# ==============================================================================
# CromBenchmarkMonitor: Sistema de Telemetria, Medição e Análise (Godot 4)
# Monitora FPS, memória, tempo de quadro, nós da cena e consumo de IA.
# ==============================================================================

signal benchmark_started(game_id: String)
signal benchmark_progress(time_elapsed: float, duration: float)
signal benchmark_finished(game_id: String, report_data: Dictionary)

var is_recording: bool = false
var current_game_id: String = ""
var record_duration: float = 5.0
var time_elapsed: float = 0.0

# Métricas acumuladas durante o teste
var fps_samples: Array[float] = []
var delta_samples: Array[float] = []
var memory_samples: Array[float] = []
var node_count_samples: Array[int] = []

# Estimador de custos de IA (CromAI / OpenRouter / Gemini)
var ai_prompt_tokens_used: int = 0
var ai_completion_tokens_used: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[CromBenchmarkMonitor] Sistema de Telemetria e Benchmark inicializado.")

func _process(delta: float) -> void:
	if not is_recording:
		return
		
	time_elapsed += delta
	var fps = float(Engine.get_frames_per_second())
	var delta_ms = delta * 1000.0
	var mem_mb = float(OS.get_static_memory_usage()) / 1048576.0
	var nodes = get_tree().get_node_count()
	
	fps_samples.append(fps)
	delta_samples.append(delta_ms)
	memory_samples.append(mem_mb)
	node_count_samples.append(nodes)
	
	emit_signal("benchmark_progress", time_elapsed, record_duration)
	
	if time_elapsed >= record_duration:
		stop_benchmark()

func start_benchmark(game_id: String, duration: float = 5.0) -> void:
	current_game_id = game_id
	record_duration = duration
	time_elapsed = 0.0
	fps_samples.clear()
	delta_samples.clear()
	memory_samples.clear()
	node_count_samples.clear()
	is_recording = true
	print("[CromBenchmarkMonitor] Iniciando benchmark de %.1fs para o jogo: %s" % [duration, game_id])
	emit_signal("benchmark_started", game_id)

func stop_benchmark() -> Dictionary:
	is_recording = false
	if fps_samples.size() == 0:
		return {}
		
	var sum_fps: float = 0.0
	var min_fps: float = 9999.0
	var max_fps: float = 0.0
	
	var sum_delta: float = 0.0
	var max_delta: float = 0.0
	
	var sum_mem: float = 0.0
	var max_mem: float = 0.0
	
	for i in range(fps_samples.size()):
		var f = fps_samples[i]
		var d = delta_samples[i]
		var m = memory_samples[i]
		
		sum_fps += f
		if f < min_fps: min_fps = f
		if f > max_fps: max_fps = f
		
		sum_delta += d
		if d > max_delta: max_delta = d
		
		sum_mem += m
		if m > max_mem: max_mem = m
		
	var avg_fps = sum_fps / fps_samples.size()
	var avg_delta = sum_delta / delta_samples.size()
	var avg_mem = sum_mem / memory_samples.size()
	var final_nodes = node_count_samples[-1] if node_count_samples.size() > 0 else 0
	
	var cost_usd = (float(ai_prompt_tokens_used) / 1000000.0 * 0.075) + (float(ai_completion_tokens_used) / 1000000.0 * 0.30)
	
	var report = {
		"game_id": current_game_id,
		"timestamp": Time.get_datetime_string_from_system(),
		"duration_sec": record_duration,
		"samples_count": fps_samples.size(),
		"fps": {
			"average": round(avg_fps * 10) / 10.0,
			"min": round(min_fps * 10) / 10.0,
			"max": round(max_fps * 10) / 10.0
		},
		"frame_time_ms": {
			"average": round(avg_delta * 100) / 100.0,
			"max_spike": round(max_delta * 100) / 100.0
		},
		"memory_mb": {
			"average": round(avg_mem * 100) / 100.0,
			"peak": round(max_mem * 100) / 100.0
		},
		"scene_nodes": final_nodes,
		"ai_consumption": {
			"prompt_tokens": ai_prompt_tokens_used,
			"completion_tokens": ai_completion_tokens_used,
			"estimated_cost_usd": round(cost_usd * 100000) / 100000.0
		},
		"insights": _generate_insights(avg_fps, min_fps, max_delta, max_mem, final_nodes)
	}
	
	_save_report(report)
	emit_signal("benchmark_finished", current_game_id, report)
	return report

func _generate_insights(avg_fps: float, min_fps: float, max_delta: float, max_mem: float, nodes: int) -> Array[String]:
	var insights: Array[String] = []
	if avg_fps < 58.0:
		insights.append("⚠️ FPS médio abaixo de 60 FPS (%.1f). Verifique laços _process pesados ou física desnecessária." % avg_fps)
	else:
		insights.append("✅ Desempenho excelente com média de %.1f FPS." % avg_fps)
		
	if min_fps < 30.0:
		insights.append("🚨 Queda brusca de FPS detectada (Mínimo: %.1f FPS). Possível gargalo de alocação (Garbage Collection ou instanciação síncrona)." % min_fps)
		
	if max_delta > 33.3:
		insights.append("⏱️ Pico de tempo de quadro (Spike) de %.2f ms. Considere usar Object Pooling ou call_deferred." % max_delta)
		
	if max_mem > 200.0:
		insights.append("🧠 Uso de memória estática em %.2f MB. Verifique vazamentos de referências ou texturas de alta resolução não compactadas." % max_mem)
	else:
		insights.append("💡 Uso de memória extremamente leve (%.2f MB)." % max_mem)
		
	if nodes > 1000:
		insights.append("🌳 Árvore com %d nós. Otimize agrupando ou destruindo projéteis/partículas fora de tela." % nodes)
		
	return insights

func _save_report(report: Dictionary) -> void:
	var dir_path = "user://benchmark_logs"
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Salvar JSON
	var json_path = dir_path + "/" + report["game_id"] + "_report.json"
	var f_json = FileAccess.open(json_path, FileAccess.WRITE)
	if f_json:
		f_json.store_string(JSON.stringify(report, "\t"))
		f_json.close()
		
	# Salvar Markdown
	var md_path = dir_path + "/" + report["game_id"] + "_report.md"
	var f_md = FileAccess.open(md_path, FileAccess.WRITE)
	if f_md:
		var md = "# Relatório de Desempenho e Telemetria: `%s`\n\n" % report["game_id"]
		md += "- **Data/Hora:** %s\n" % report["timestamp"]
		md += "- **Duração do Teste:** %.1f segundos (%d quadros amostrados)\n\n" % [report["duration_sec"], report["samples_count"]]
		md += "## 📈 Métricas de Desempenho\n"
		md += "| Métrica | Média | Mínimo / Pico |\n|---|---|---|\n"
		md += "| **FPS** | `%.1f` | Mínimo: `%.1f` / Máximo: `%.1f` |\n" % [report["fps"]["average"], report["fps"]["min"], report["fps"]["max"]]
		md += "| **Tempo de Quadro (Delta)** | `%.2f ms` | Pico (Spike): `%.2f ms` |\n" % [report["frame_time_ms"]["average"], report["frame_time_ms"]["max_spike"]]
		md += "| **Memória Estática (RAM)** | `%.2f MB` | Pico: `%.2f MB` |\n" % [report["memory_mb"]["average"], report["memory_mb"]["peak"]]
		md += "| **Contagem de Nós** | `%d nós` | — |\n\n" % report["scene_nodes"]
		
		md += "## 🤖 Consumo & Custos de Inteligência Artificial (CromAI / Gemini)\n"
		md += "- **Tokens de Entrada (Prompt):** %d\n" % report["ai_consumption"]["prompt_tokens"]
		md += "- **Tokens de Saída (Completion):** %d\n" % report["ai_consumption"]["completion_tokens"]
		md += "- **Custo Estimado (USD):** `$%.6f`\n\n" % report["ai_consumption"]["estimated_cost_usd"]
		
		md += "## 💡 Insights e Diagnóstico Técnico\n"
		for ins in report["insights"]:
			md += "- %s\n" % ins
		md += "\n---\n*Gerado automaticamente pelo CromBenchmarkMonitor.*"
		
		f_md.store_string(md)
		f_md.close()
		
	print("[CromBenchmarkMonitor] Relatório salvo com sucesso: %s e %s" % [json_path, md_path])

func get_current_metrics() -> Dictionary:
	return {
		"fps": round(Engine.get_frames_per_second() * 10) / 10.0,
		"delta_ms": round(get_process_delta_time() * 1000.0 * 100) / 100.0,
		"memory_mb": round((float(OS.get_static_memory_usage()) / 1048576.0) * 100) / 100.0,
		"nodes": get_tree().get_node_count() if get_tree() else 0
	}
