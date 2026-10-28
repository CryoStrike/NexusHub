--[[
	NEXUS HUB  -  languages.lua      (every text of the hub + the list of languages)

	HOW IT WORKS
		Each text is stored under a KEY, once per language, and looked up with  tr("key").
		hub.lua never contains visible text directly: it calls  tr("combat_module")  and gets
		"Combat Module" / "Module de combat" / ... depending on the chosen language.

	HOW TO ADD A TEXT
		1. Add   my_key = "My text",   to EVERY language block below (English is the fallback).
		2. Use it in hub.lua:   Name = tr("my_key")

	HOW TO ADD A LANGUAGE
		1. Add its name to  Language.List  (this is the order shown in the dropdown).
		2. Copy the whole English block in  Language.Strings, rename it, translate the values.
		   Names with accents need brackets:   ["Français"] = { ... }

	GOOD TO KNOW
		- A missing key never breaks the hub: it falls back to English, then to the key itself.
		  init.lua prints a warning for every missing key (see Language.Validate).
		- Texts containing %s are filled in with values (version, name, key...). Keep the %s in the translation.
		- Use Latin letters only: the Gotham font cannot draw Chinese, Japanese, Korean, Arabic or Cyrillic.
		- Keep tab names short (about 10 characters): the sidebar is narrow.
]]

local Language = {}

Language.Default = "English"       -- used as the fallback and as the preselected language
Language.Current = Language.Default
Language.List = { "English", "Français", "Español", "Deutsch", "Português" }

Language.Strings = {
	English = {
		tab_combat = "Combat", tab_character = "Character", tab_farm = "Farm", tab_troll = "Troll",
		tab_visuals = "Visuals", tab_settings = "Settings", tab_about = "About",
		combat_module = "Combat Module", range = "Range", priority = "Target Priority", combat_key = "Combat Key",
		walk_speed = "Walk Speed", jump_power = "Jump Power", anti_afk = "Anti-AFK", reset_char = "Reset Character",
		farm_toggle = "Auto Farm", farm_mode = "Farm Mode", farm_delay = "Farm Delay", target_name = "Target Name", target_ph = "Enter a name...",
		troll_module = "Troll Module", effect = "Effect", intensity = "Intensity", run_effect = "Run Effect", stop_all = "Stop All",
		tp_target = "Select Target", tp_button = "Teleport to Player", tp_success = "Teleported to %s!", tp_err = "Invalid player.",
		reset_requested = "Reset requested.", tp_title = "Teleport", effect_started = "Effect started.", effects_stopped = "Effects stopped.",
		sec_display = "Display & ESP", highlight = "Player ESP", fov = "Field of View", style = "Style", sec_theme = "Theme", accent = "Accent Colour",
		sec_esp_colors = "ESP Role Colors", col_murder = "Murderer Color", col_sheriff = "Sheriff Color", col_innocent = "Innocent Color",
		sec_interface = "Interface", hide_key = "Hide Hub Key", minimize = "Minimize Hub", language = "Language", unload = "Unload NEXUS",
		resize_hint = "Drag the bottom-right corner to resize the hub.",
		about_title = "NEXUS UI", about_version = "Translucid Theme - v%s", about_signed = "Signed in as %s (@%s)",
		loaded_title = "NEXUS loaded", loaded_text = "Press %s to hide or show the hub.", lang_set = "Language: %s",
	},
	["Français"] = {
		tab_combat = "Combat", tab_character = "Personnage", tab_farm = "Farm", tab_troll = "Troll",
		tab_visuals = "Visuels", tab_settings = "Paramètres", tab_about = "À propos",
		combat_module = "Module de combat", range = "Portée", priority = "Priorité de cible", combat_key = "Touche de combat",
		walk_speed = "Vitesse de marche", jump_power = "Puissance de saut", anti_afk = "Anti-AFK", reset_char = "Réinitialiser le personnage",
		farm_toggle = "Auto Farm", farm_mode = "Mode de farm", farm_delay = "Délai de farm", target_name = "Nom de la cible", target_ph = "Entrez un nom...",
		troll_module = "Module Troll", effect = "Effet", intensity = "Intensité", run_effect = "Lancer l'effet", stop_all = "Tout arrêter",
		tp_target = "Sélectionner la cible", tp_button = "Se téléporter au joueur", tp_success = "Téléporté à %s !", tp_err = "Joueur invalide.",
		reset_requested = "Réinitialisation demandée.", tp_title = "Téléportation", effect_started = "Effet lancé.", effects_stopped = "Effets arrêtés.",
		sec_display = "Affichage & ESP", highlight = "ESP Joueur", fov = "Champ de vision", style = "Style", sec_theme = "Thème", accent = "Couleur d'accent",
		sec_esp_colors = "Couleurs des Rôles ESP", col_murder = "Couleur Meurtrier", col_sheriff = "Couleur Shérif", col_innocent = "Couleur Innocent",
		sec_interface = "Interface", hide_key = "Touche pour masquer", minimize = "Réduire le hub", language = "Langue", unload = "Décharger NEXUS",
		resize_hint = "Faites glisser le coin inférieur droit pour redimensionner.",
		about_title = "NEXUS UI", about_version = "Thème Translucid - v%s", about_signed = "Connecté en tant que %s (@%s)",
		loaded_title = "NEXUS chargé", loaded_text = "Appuyez sur %s pour masquer ou afficher le hub.", lang_set = "Langue : %s",
	},
	["Español"] = {
		tab_combat = "Combate", tab_character = "Personaje", tab_farm = "Farmeo", tab_troll = "Troll",
		tab_visuals = "Visuales", tab_settings = "Ajustes", tab_about = "Acerca de",
		combat_module = "Módulo de combate", range = "Alcance", priority = "Prioridad de objetivo", combat_key = "Tecla de combate",
		walk_speed = "Velocidad de caminar", jump_power = "Fuerza de salto", anti_afk = "Anti-AFK", reset_char = "Reiniciar personaje",
		farm_toggle = "Auto Farm", farm_mode = "Modo de farmeo", farm_delay = "Retraso de farmeo", target_name = "Nombre del objetivo", target_ph = "Introduce un nombre...",
		troll_module = "Módulo Troll", effect = "Efecto", intensity = "Intensidad", run_effect = "Ejecutar efecto", stop_all = "Detener todo",
		tp_target = "Seleccionar objetivo", tp_button = "Teletransportarse al jugador", tp_success = "¡Teletransportado a %s!", tp_err = "Jugador no válido.",
		reset_requested = "Reinicio solicitado.", tp_title = "Teletransporte", effect_started = "Efecto iniciado.", effects_stopped = "Efectos detenidos.",
		sec_display = "Pantalla y ESP", highlight = "ESP de Jugador", fov = "Campo de visión", style = "Estilo", sec_theme = "Tema", accent = "Color de acento",
		sec_esp_colors = "Colores de Roles ESP", col_murder = "Color Asesino", col_sheriff = "Color Sheriff", col_innocent = "Color Inocente",
		sec_interface = "Interfaz", hide_key = "Tecla para ocultar", minimize = "Minimizar hub", language = "Idioma", unload = "Descargar NEXUS",
		resize_hint = "Arrastra la esquina inferior derecha para cambiar el tamaño.",
		about_title = "NEXUS UI", about_version = "Tema Translucid - v%s", about_signed = "Sesión iniciada como %s (@%s)",
		loaded_title = "NEXUS cargado", loaded_text = "Pulsa %s para ocultar o mostrar el hub.", lang_set = "Idioma: %s",
	},
	Deutsch = {
		tab_combat = "Kampf", tab_character = "Charakter", tab_farm = "Farm", tab_troll = "Troll",
		tab_visuals = "Visuals", tab_settings = "Optionen", tab_about = "Info",
		combat_module = "Kampfmodul", range = "Reichweite", priority = "Zielpriorität", combat_key = "Kampftaste",
		walk_speed = "Laufgeschwindigkeit", jump_power = "Sprungkraft", anti_afk = "Anti-AFK", reset_char = "Charakter zurücksetzen",
		farm_toggle = "Auto-Farm", farm_mode = "Farm-Modus", farm_delay = "Farm-Verzögerung", target_name = "Zielname", target_ph = "Namen eingeben...",
		troll_module = "Troll-Modul", effect = "Effekt", intensity = "Intensität", run_effect = "Effekt ausführen", stop_all = "Alles stoppen",
		tp_target = "Ziel auswählen", tp_button = "Zum Spieler teleportieren", tp_success = "Zu %s teleportiert!", tp_err = "Ungültiger Spieler.",
		reset_requested = "Zurücksetzen angefordert.", tp_title = "Teleport", effect_started = "Effekt gestartet.", effects_stopped = "Effekte gestoppt.",
		sec_display = "Anzeige & ESP", highlight = "Spieler-ESP", fov = "Sichtfeld", style = "Stil", sec_theme = "Design", accent = "Akzentfarbe",
		sec_esp_colors = "ESP-Rollenfarben", col_murder = "Mörder-Farbe", col_sheriff = "Sheriff-Farbe", col_innocent = "Unschuldigen-Farbe",
		sec_interface = "Oberfläche", hide_key = "Taste zum Ausblenden", minimize = "Hub minimieren", language = "Sprache", unload = "NEXUS entladen",
		resize_hint = "Ziehe die untere rechte Ecke, um die Größe zu ändern.",
		about_title = "NEXUS UI", about_version = "Translucid-Design - v%s", about_signed = "Angemeldet als %s (@%s)",
		loaded_title = "NEXUS geladen", loaded_text = "Drücke %s, um den Hub aus- oder einzublenden.", lang_set = "Sprache: %s",
	},
	["Português"] = {
		tab_combat = "Combate", tab_character = "Personagem", tab_farm = "Farm", tab_troll = "Troll",
		tab_visuals = "Visuais", tab_settings = "Opções", tab_about = "Sobre",
		combat_module = "Módulo de combate", range = "Alcance", priority = "Prioridade de alvo", combat_key = "Tecla de combate",
		walk_speed = "Velocidade de caminhada", jump_power = "Força do pulo", anti_afk = "Anti-AFK", reset_char = "Reiniciar personagem",
		farm_toggle = "Auto Farm", farm_mode = "Modo de farm", farm_delay = "Atraso do farm", target_name = "Nome do alvo", target_ph = "Digite um nome...",
		troll_module = "Módulo Troll", effect = "Efeito", intensity = "Intensidade", run_effect = "Executar efeito", stop_all = "Parar tudo",
		tp_target = "Selecionar Alvo", tp_button = "Teleportar para Jogador", tp_success = "Teleportado para %s!", tp_err = "Jogador inválido.",
		reset_requested = "Reinício solicitado.", tp_title = "Teletransporte", effect_started = "Efeito iniciado.", effects_stopped = "Efeitos parados.",
		sec_display = "Exibição e ESP", highlight = "ESP de Jogador", fov = "Campo de visão", style = "Estilo", sec_theme = "Tema", accent = "Cor de destaque",
		sec_esp_colors = "Cores de Cargos ESP", col_murder = "Cor Assassino", col_sheriff = "Cor Xerife", col_innocent = "Cor Inocente",
		sec_interface = "Interface", hide_key = "Tecla para ocultar", minimize = "Minimizar hub", language = "Idioma", unload = "Descarregar NEXUS",
		resize_hint = "Arraste o canto inferior direito para redimensionar.",
		about_title = "NEXUS UI", about_version = "Tema Translucid - v%s", about_signed = "Conectado como %s (@%s)",
		loaded_title = "NEXUS carregado", loaded_text = "Pressione %s para ocultar ou mostrar o hub.", lang_set = "Idioma: %s",
	},
}

-- Switch the active language. Returns false (and changes nothing) if the language has no texts.
function Language.set(name)
	if Language.Strings[name] then
		Language.Current = name
		return true
	end
	return false
end

-- tr("key")  or  tr("key", a, b)  -> text in the current language (extra arguments fill the %s of the text)
function Language.tr(key, ...)
	local set = Language.Strings[Language.Current]
	local text = (set and set[key]) or Language.Strings[Language.Default][key] or key
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, text, ...)
		if ok then return out end
	end
	return text
end

-- Returns a list of problems (empty = everything is translated). Nothing is changed.
function Language.Validate()
	local problems = {}
	local english = Language.Strings[Language.Default]
	for _, name in ipairs(Language.List) do
		local set = Language.Strings[name]
		if not set then
			table.insert(problems, "language '" .. name .. "' is in Language.List but has no texts in Language.Strings")
		else
			local missing, unknown = {}, {}
			for key in pairs(english) do if set[key] == nil then table.insert(missing, key) end end
			for key in pairs(set) do if english[key] == nil then table.insert(unknown, key) end end
			table.sort(missing)
			table.sort(unknown)
			for _, key in ipairs(missing) do
				table.insert(problems, name .. ": missing '" .. key .. "' (showing English instead)")
			end
			for _, key in ipairs(unknown) do
				table.insert(problems, name .. ": '" .. key .. "' does not exist in English (unused or typo)")
			end
		end
	end
	return problems
end

return Language
