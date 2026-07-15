class_name PlaytestService
extends Node

# ==============================================================================
# Playtest Service — O Agente IA "joga" um jogo e gera artefato com prints
# Fluxo:
#   1. Carrega a cena no SubViewport
#   2. Chama capture_screenshot (tela inicial)
#   3. O motor ReAct analisa visualmente + interage
#   4. Tira mais prints durante a gameplay
#   5. Monta um relatório (artefato) com prints + análise
# ==============================================================================

signal playtest_started(game_id: String)
signal screenshot_captured(game_id: String, image_path: String)
signal playtest_finished(game_id: String, report: Dictionary)

var _engine: Node  # Referência ao NativeReActEngine
var _viewport: SubViewport
var _current_game_id: String = ""
var _screenshots: Array[String] = []
var _report: Dictionary = {}

func setup(react_engine: Node, viewport: SubViewport) -> void:
	_engine = react_engine
	_viewport = viewport

func start_playtest(game_info: Dictionary) -> void:
	_current_game_id = game_info["id"]
	_screenshots.clear()
	_report = {
		"game_id": game_info["id"],
		"game_name": game_info["name"],
		"game_type": game_info["type"],
		"started_at": Time.get_datetime_string_from_system(),
		"screenshots": [],
		"agent_analysis": "",
		"suggestions": [],
		"duration_seconds": 0.0,
	}
	
	playtest_started.emit(_current_game_id)
	
	# Capturar screenshot inicial
	_capture_viewport_screenshot("inicio")
	
	# Enviar prompt para o agente jogar e analisar
	if _engine and _engine.has_method("send_user_prompt"):
		var prompt := """Você é o Agente QA de Jogos do CromAI. Sua tarefa é testar o jogo '%s' (%s).

INSTRUÇÕES:
1. PRIMEIRO: Chame capture_screenshot para ver a tela atual do jogo.
2. Descreva EXATAMENTE o que você vê na tela (elementos visuais, posição dos objetos, cores, layout).
3. Analise se o jogo parece funcional e visualmente correto.
4. Identifique problemas visuais (cortes, sobreposições, elementos fora da tela).
5. Dê sugestões concretas de melhoria (gameplay, visual, responsividade).

Retorne sua análise em formato estruturado com: [VISUAL], [GAMEPLAY], [SUGESTÕES].""" % [game_info["name"], game_info["tscn"]]
		
		_engine.send_user_prompt(prompt)

func _capture_viewport_screenshot(label: String) -> void:
	if not _viewport or not is_instance_valid(_viewport):
		return
	
	var image := _viewport.get_texture().get_image()
	if not image:
		return
	
	var timestamp := Time.get_unix_time_from_system()
	var filename := "playtest_%s_%s_%d.png" % [_current_game_id, label, timestamp]
	var save_path := "user://playtest_reports/" + filename
	
	DirAccess.make_dir_recursive_absolute("user://playtest_reports")
	image.save_png(save_path)
	
	_screenshots.append(save_path)
	_report["screenshots"].append({"path": save_path, "label": label, "timestamp": timestamp})
	screenshot_captured.emit(_current_game_id, save_path)

func finish_playtest(agent_analysis: String) -> Dictionary:
	_report["agent_analysis"] = agent_analysis
	_report["finished_at"] = Time.get_datetime_string_from_system()
	
	# Capturar screenshot final
	_capture_viewport_screenshot("final")
	
	playtest_finished.emit(_current_game_id, _report)
	return _report

func get_last_report() -> Dictionary:
	return _report
