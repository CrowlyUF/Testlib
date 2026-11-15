local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local LocalizationService = game:GetService("LocalizationService")

local BRAND = "West Shaders"
local FILE = "WestShaders_config.json"

local lp = Players.LocalPlayer
local terrain = Workspace:FindFirstChildOfClass("Terrain")
local env = (getgenv and getgenv()) or _G

local S = {
	dirty = false, lastTouch = 0,
	visualOn = false, futureOn = false, dayFactor = 1,
	muffle = 0, muffleTarget = 0, floorExposed = false,
	soundOk = false, windOk = false, stepOk = false,
	wetness = 0, lastWetness = 0, lastWetScan = -100, wetOrigin = Vector3.zero,
	puddleLevel = 0, dryTimer = 0, puddleTimer = 0, lightCursor = 1,
	clock = 0, accum = 0, slowAccum = 0, restored = false,
	windDir = Vector3.new(1, 0, 0), windVec = Vector3.zero, windSpeed = 0,
	flash = 0, nextBolt = os.clock() + 20,
	seqIdx = 1, seqTime = 60, currentWeather = "sunny", touchedTime = false,
	stepTimer = 0, stepToken = 0, muffleTimer = 0, cellCursor = 1, lightsOn = false,
	cleanTimer = 0, stabilizeTimer = 0, waterTimer = 0, waterScanTimer = 0,
	waterApplied = false, reflTimer = 0, dropAcc = 0,
}

local COL = {
	sunLow = Color3.fromRGB(255, 170, 110),
	dawnAir = Color3.fromRGB(255, 190, 160),
	sunStrong = Color3.fromRGB(255, 236, 205),
	decayLow = Color3.fromRGB(255, 150, 90),
	airNight = Color3.fromRGB(25, 30, 45),
	decayNight = Color3.fromRGB(10, 10, 20),
	cloudNight = Color3.fromRGB(70, 78, 100),
	cloudSunset = Color3.fromRGB(255, 196, 160),
}

if env.__westshaders then
	pcall(env.__westshaders.unload)
end

local RAIN_SOUNDS = {
	"rbxassetid://5808527322",
	"rbxassetid://2304892796",
	"rbxassetid://184352854",
	"rbxassetid://365362615",
	"rbxassetid://136295008740997",
}

local WIND_SOUNDS = {
	"rbxassetid://8202539690",
	"rbxassetid://665381802",
	"rbxassetid://8355232958",
	"rbxassetid://5799870105",
	"rbxassetid://18435238",
}

local STEP_SOUNDS = {
	"rbxassetid://5429319100",
	"rbxassetid://142431247",
	"rbxassetid://130778103",
	"rbxassetid://5930519356",
	"rbxassetid://6569949256",
}

local conns = {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local function create(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function setp(o, k, v)
	if o[k] ~= v then
		o[k] = v
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local LANGS = {
	en = {
		wind_sound = "Wind sound",
		wind_sound_d = "Very soft breeze ambience",
		step_sound = "Water footsteps",
		step_sound_d = "Splash sound while walking in the rain",
		lights = "Enhanced lights",
		lights_d = "Boosts lamps and light sources, with shadows up close",
		water = "Water enhancement",
		water_d = "Better water look and approximate character reflections",
		screen_drops = "Screen raindrops",
		screen_drops_d = "A few subtle drops on the screen while it rains",
		beta = "The script is still in beta; set your graphics settings to maximum for a better experience.",
		saved = "The settings you make will be saved, and when you run it again, it will load automatically.",
		open_pc = "Click RSHIFT to open the GUI",
		open_mobile = "Click the sun icon to open the GUI",
		disclaimer = "Some effects may not work perfectly in all games.",
		tab_weather = "Weather", tab_light = "Sun & Light", tab_general = "General",
		sec_sky = "Sky", weather = "Weather", strength = "Weather intensity (%)",
		w_auto = "Automatic", w_sunny = "Sunny", w_cloudy = "Cloudy", w_rainy = "Rainy", w_storm = "Storm",
		sec_rain = "Rain", rain = "Rain", rain_d = "Drops only fall where the sky is open",
		rain_sound = "Rain sound", rain_sound_d = "Muffled inside buildings",
		wet = "Wet ground", wet_d = "Darkens and reflects surfaces",
		feet = "Foot splashes", feet_d = "Water splashes while you walk",
		lightning = "Lightning", lightning_d = "Flashes during heavy rain", volume = "Rain volume (%)",
		sec_air = "Atmosphere", wind = "Wind", wind_d = "Air ribbons, leaves, pollen and moving grass",
		fog = "Fog", fog_d = "Depth and atmosphere",
		sec_light = "Lighting", shaders = "Shaders", shaders_d = "Bloom, color grading, sun rays and atmosphere",
		flare = "Sun glare", flare_d = "Soft glow when you look at the sun",
		shafts = "Light shafts", shafts_d = "Sunbeams through roof holes and windows",
		shadows = "Soft shadows", dof = "Depth of field", dof_d = "High quality only", light = "Lighting intensity (%)",
		sec_time = "Time of day", manual_time = "Control time of day", hour = "Hour",
		sec_perf = "Performance", quality = "Quality", q1 = "Low", q2 = "Medium", q3 = "High",
		sec_fx = "Effects", restore = "Restore original graphics", restore_d = "Turns everything off and returns the game's lighting",
		enable = "Enable effects again", fx_off = "Effects disabled, original graphics restored", fx_on = "Effects enabled",
		sec_cfg = "Configuration", save = "Save settings now", save_d = "Settings are also saved automatically",
		save_ok = "Saved to ", save_fail = "Your executor can't save files",
		delete = "Delete saved settings", deleted = "Deleted, defaults will load next time", nothing = "Nothing to delete",
		unload = "Unload script", no_sound = "No rain sound loaded. Replace the IDs in RAIN_SOUNDS.",
	},
	pt = {
		wind_sound = "Som do vento",
		wind_sound_d = "Brisa bem suave ao fundo",
		step_sound = "Passos na água",
		step_sound_d = "Som de respingo ao andar na chuva",
		lights = "Luzes melhoradas",
		lights_d = "Realça lâmpadas e fontes de luz, com sombras de perto",
		water = "Água melhorada",
		water_d = "Água mais bonita e reflexos aproximados dos personagens",
		screen_drops = "Gotas na tela",
		screen_drops_d = "Algumas gotas discretas na tela durante a chuva",
		beta = "O script ainda está em beta; coloque seus gráficos no máximo para uma experiência melhor.",
		saved = "As configurações que você fizer serão salvas e carregadas automaticamente na próxima vez que executar.",
		open_pc = "Pressione RSHIFT para abrir a GUI",
		open_mobile = "Toque no ícone do sol para abrir a GUI",
		disclaimer = "Alguns efeitos podem não funcionar perfeitamente em todos os jogos.",
		tab_weather = "Clima", tab_light = "Sol e luz", tab_general = "Geral",
		sec_sky = "Céu", weather = "Clima", strength = "Intensidade do clima (%)",
		w_auto = "Automático", w_sunny = "Ensolarado", w_cloudy = "Nublado", w_rainy = "Chuvoso", w_storm = "Tempestade",
		sec_rain = "Chuva", rain = "Chuva", rain_d = "As gotas só caem onde o céu está aberto",
		rain_sound = "Som da chuva", rain_sound_d = "Abafado dentro de construções",
		wet = "Chão molhado", wet_d = "Escurece e reflete as superfícies",
		feet = "Respingos nos pés", feet_d = "Água espirrando enquanto você anda",
		lightning = "Relâmpagos", lightning_d = "Clarões durante chuva forte", volume = "Volume da chuva (%)",
		sec_air = "Atmosfera", wind = "Vento", wind_d = "Faixas de ar, folhas, pólen e grama se movendo",
		fog = "Neblina", fog_d = "Profundidade e atmosfera",
		sec_light = "Iluminação", shaders = "Shaders", shaders_d = "Bloom, cores, raios de sol e atmosfera",
		flare = "Brilho do sol", flare_d = "Brilho suave ao olhar para o sol",
		shafts = "Feixes de luz", shafts_d = "Raios de sol por furos no telhado e janelas",
		shadows = "Sombras suaves", dof = "Profundidade de campo", dof_d = "Somente na qualidade alta", light = "Intensidade da iluminação (%)",
		sec_time = "Hora do dia", manual_time = "Controlar hora do dia", hour = "Hora",
		sec_perf = "Desempenho", quality = "Qualidade", q1 = "Baixa", q2 = "Média", q3 = "Alta",
		sec_fx = "Efeitos", restore = "Restaurar gráficos originais", restore_d = "Desliga tudo e devolve a iluminação do jogo",
		enable = "Ativar efeitos novamente", fx_off = "Efeitos desativados, gráficos originais restaurados", fx_on = "Efeitos ativados",
		sec_cfg = "Configuração", save = "Salvar configurações agora", save_d = "As configurações também são salvas automaticamente",
		save_ok = "Salvo em ", save_fail = "Seu executor não permite salvar arquivos",
		delete = "Apagar configurações salvas", deleted = "Apagado, o padrão será carregado na próxima vez", nothing = "Nada para apagar",
		unload = "Descarregar script", no_sound = "Nenhum som de chuva carregou. Troque os IDs em RAIN_SOUNDS.",
	},
	es = {
		wind_sound = "Sonido del viento",
		wind_sound_d = "Brisa muy suave de fondo",
		step_sound = "Pasos en el agua",
		step_sound_d = "Sonido de salpicadura al caminar bajo la lluvia",
		lights = "Luces mejoradas",
		lights_d = "Realza lámparas y fuentes de luz, con sombras de cerca",
		water = "Agua mejorada",
		water_d = "Mejor aspecto del agua y reflejos aproximados de personajes",
		screen_drops = "Gotas en pantalla",
		screen_drops_d = "Unas pocas gotas discretas en la pantalla mientras llueve",
		beta = "El script sigue en beta; pon tus gráficos al máximo para una mejor experiencia.",
		saved = "Los ajustes que hagas se guardarán y se cargarán automáticamente cuando lo vuelvas a ejecutar.",
		open_pc = "Pulsa RSHIFT para abrir la GUI",
		open_mobile = "Toca el icono del sol para abrir la GUI",
		disclaimer = "Algunos efectos pueden no funcionar perfectamente en todos los juegos.",
		tab_weather = "Clima", tab_light = "Sol y luz", tab_general = "General",
		sec_sky = "Cielo", weather = "Clima", strength = "Intensidad del clima (%)",
		w_auto = "Automático", w_sunny = "Soleado", w_cloudy = "Nublado", w_rainy = "Lluvioso", w_storm = "Tormenta",
		sec_rain = "Lluvia", rain = "Lluvia", rain_d = "Las gotas solo caen donde el cielo está abierto",
		rain_sound = "Sonido de lluvia", rain_sound_d = "Amortiguado dentro de edificios",
		wet = "Suelo mojado", wet_d = "Oscurece y refleja las superficies",
		feet = "Salpicaduras en los pies", feet_d = "El agua salpica mientras caminas",
		lightning = "Relámpagos", lightning_d = "Destellos durante lluvia fuerte", volume = "Volumen de lluvia (%)",
		sec_air = "Atmósfera", wind = "Viento", wind_d = "Corrientes de aire, hojas, polen y hierba en movimiento",
		fog = "Niebla", fog_d = "Profundidad y atmósfera",
		sec_light = "Iluminación", shaders = "Shaders", shaders_d = "Bloom, color, rayos de sol y atmósfera",
		flare = "Brillo del sol", flare_d = "Resplandor suave al mirar al sol",
		shafts = "Haces de luz", shafts_d = "Rayos de sol por agujeros del techo y ventanas",
		shadows = "Sombras suaves", dof = "Profundidad de campo", dof_d = "Solo en calidad alta", light = "Intensidad de iluminación (%)",
		sec_time = "Hora del día", manual_time = "Controlar la hora del día", hour = "Hora",
		sec_perf = "Rendimiento", quality = "Calidad", q1 = "Baja", q2 = "Media", q3 = "Alta",
		sec_fx = "Efectos", restore = "Restaurar gráficos originales", restore_d = "Apaga todo y devuelve la iluminación del juego",
		enable = "Activar efectos de nuevo", fx_off = "Efectos desactivados, gráficos originales restaurados", fx_on = "Efectos activados",
		sec_cfg = "Configuración", save = "Guardar ajustes ahora", save_d = "Los ajustes también se guardan automáticamente",
		save_ok = "Guardado en ", save_fail = "Tu executor no puede guardar archivos",
		delete = "Borrar ajustes guardados", deleted = "Borrado, se cargarán los valores por defecto", nothing = "Nada que borrar",
		unload = "Descargar script", no_sound = "No se cargó ningún sonido de lluvia. Cambia los IDs en RAIN_SOUNDS.",
	},
	fr = {
		wind_sound = "Son du vent",
		wind_sound_d = "Brise très douce en fond",
		step_sound = "Pas dans l'eau",
		step_sound_d = "Bruit d'éclaboussure en marchant sous la pluie",
		lights = "Lumières améliorées",
		lights_d = "Renforce lampes et sources de lumière, avec ombres de près",
		water = "Eau améliorée",
		water_d = "Eau plus belle et reflets approximatifs des personnages",
		screen_drops = "Gouttes à l'écran",
		screen_drops_d = "Quelques gouttes discrètes à l'écran pendant la pluie",
		beta = "Le script est encore en bêta ; mettez vos graphismes au maximum pour une meilleure expérience.",
		saved = "Vos réglages seront enregistrés et chargés automatiquement à la prochaine exécution.",
		open_pc = "Appuyez sur RSHIFT pour ouvrir la GUI",
		open_mobile = "Touchez l'icône du soleil pour ouvrir la GUI",
		disclaimer = "Certains effets peuvent ne pas fonctionner parfaitement dans tous les jeux.",
		tab_weather = "Météo", tab_light = "Soleil et lumière", tab_general = "Général",
		sec_sky = "Ciel", weather = "Météo", strength = "Intensité de la météo (%)",
		w_auto = "Automatique", w_sunny = "Ensoleillé", w_cloudy = "Nuageux", w_rainy = "Pluvieux", w_storm = "Tempête",
		sec_rain = "Pluie", rain = "Pluie", rain_d = "Les gouttes tombent seulement à ciel ouvert",
		rain_sound = "Son de la pluie", rain_sound_d = "Étouffé à l'intérieur des bâtiments",
		wet = "Sol mouillé", wet_d = "Assombrit et fait refléter les surfaces",
		feet = "Éclaboussures aux pieds", feet_d = "L'eau éclabousse quand vous marchez",
		lightning = "Éclairs", lightning_d = "Flashs pendant les fortes pluies", volume = "Volume de la pluie (%)",
		sec_air = "Atmosphère", wind = "Vent", wind_d = "Rubans d'air, feuilles, pollen et herbe qui bouge",
		fog = "Brouillard", fog_d = "Profondeur et atmosphère",
		sec_light = "Éclairage", shaders = "Shaders", shaders_d = "Bloom, couleurs, rayons de soleil et atmosphère",
		flare = "Éblouissement du soleil", flare_d = "Lueur douce en regardant le soleil",
		shafts = "Faisceaux de lumière", shafts_d = "Rayons de soleil par les trous du toit et les fenêtres",
		shadows = "Ombres douces", dof = "Profondeur de champ", dof_d = "Qualité élevée uniquement", light = "Intensité de l'éclairage (%)",
		sec_time = "Heure du jour", manual_time = "Contrôler l'heure du jour", hour = "Heure",
		sec_perf = "Performances", quality = "Qualité", q1 = "Basse", q2 = "Moyenne", q3 = "Élevée",
		sec_fx = "Effets", restore = "Restaurer les graphismes d'origine", restore_d = "Désactive tout et rend l'éclairage du jeu",
		enable = "Réactiver les effets", fx_off = "Effets désactivés, graphismes d'origine restaurés", fx_on = "Effets activés",
		sec_cfg = "Configuration", save = "Enregistrer les réglages", save_d = "Les réglages sont aussi enregistrés automatiquement",
		save_ok = "Enregistré dans ", save_fail = "Votre executor ne peut pas enregistrer de fichiers",
		delete = "Supprimer les réglages", deleted = "Supprimé, les valeurs par défaut seront chargées", nothing = "Rien à supprimer",
		unload = "Décharger le script", no_sound = "Aucun son de pluie chargé. Remplacez les IDs dans RAIN_SOUNDS.",
	},
	de = {
		wind_sound = "Windgeräusch",
		wind_sound_d = "Sehr leise Brise im Hintergrund",
		step_sound = "Schritte im Wasser",
		step_sound_d = "Platschgeräusch beim Gehen im Regen",
		lights = "Verbesserte Lichter",
		lights_d = "Verstärkt Lampen und Lichtquellen, mit Schatten in der Nähe",
		water = "Besseres Wasser",
		water_d = "Schöneres Wasser und angenäherte Spiegelungen von Charakteren",
		screen_drops = "Tropfen auf dem Bildschirm",
		screen_drops_d = "Ein paar dezente Tropfen auf dem Bildschirm bei Regen",
		beta = "Das Skript ist noch in der Beta; stelle deine Grafik auf Maximum für ein besseres Erlebnis.",
		saved = "Deine Einstellungen werden gespeichert und beim nächsten Ausführen automatisch geladen.",
		open_pc = "Drücke RSHIFT, um die GUI zu öffnen",
		open_mobile = "Tippe auf das Sonnensymbol, um die GUI zu öffnen",
		disclaimer = "Einige Effekte funktionieren möglicherweise nicht in jedem Spiel perfekt.",
		tab_weather = "Wetter", tab_light = "Sonne und Licht", tab_general = "Allgemein",
		sec_sky = "Himmel", weather = "Wetter", strength = "Wetterintensität (%)",
		w_auto = "Automatisch", w_sunny = "Sonnig", w_cloudy = "Bewölkt", w_rainy = "Regnerisch", w_storm = "Sturm",
		sec_rain = "Regen", rain = "Regen", rain_d = "Tropfen fallen nur bei offenem Himmel",
		rain_sound = "Regengeräusch", rain_sound_d = "Gedämpft in Gebäuden",
		wet = "Nasser Boden", wet_d = "Dunkelt Oberflächen ab und lässt sie spiegeln",
		feet = "Spritzer an den Füßen", feet_d = "Wasser spritzt beim Gehen",
		lightning = "Blitze", lightning_d = "Lichtblitze bei starkem Regen", volume = "Regenlautstärke (%)",
		sec_air = "Atmosphäre", wind = "Wind", wind_d = "Luftbänder, Blätter, Pollen und bewegtes Gras",
		fog = "Nebel", fog_d = "Tiefe und Atmosphäre",
		sec_light = "Beleuchtung", shaders = "Shader", shaders_d = "Bloom, Farben, Sonnenstrahlen und Atmosphäre",
		flare = "Sonnenblendung", flare_d = "Sanftes Leuchten beim Blick zur Sonne",
		shafts = "Lichtstrahlen", shafts_d = "Sonnenstrahlen durch Dachlöcher und Fenster",
		shadows = "Weiche Schatten", dof = "Tiefenschärfe", dof_d = "Nur bei hoher Qualität", light = "Beleuchtungsintensität (%)",
		sec_time = "Tageszeit", manual_time = "Tageszeit steuern", hour = "Stunde",
		sec_perf = "Leistung", quality = "Qualität", q1 = "Niedrig", q2 = "Mittel", q3 = "Hoch",
		sec_fx = "Effekte", restore = "Originalgrafik wiederherstellen", restore_d = "Schaltet alles aus und stellt die Spielbeleuchtung wieder her",
		enable = "Effekte wieder aktivieren", fx_off = "Effekte deaktiviert, Originalgrafik wiederhergestellt", fx_on = "Effekte aktiviert",
		sec_cfg = "Konfiguration", save = "Einstellungen jetzt speichern", save_d = "Einstellungen werden auch automatisch gespeichert",
		save_ok = "Gespeichert in ", save_fail = "Dein Executor kann keine Dateien speichern",
		delete = "Gespeicherte Einstellungen löschen", deleted = "Gelöscht, Standardwerte werden beim nächsten Mal geladen", nothing = "Nichts zu löschen",
		unload = "Skript entladen", no_sound = "Kein Regengeräusch geladen. Ersetze die IDs in RAIN_SOUNDS.",
	},
}

local locale = "en"
pcall(function()
	local id = LocalizationService.RobloxLocaleId
	if not id or id == "" then
		id = lp.LocaleId
	end
	locale = tostring(id):sub(1, 2):lower()
end)
local strings = LANGS[locale] or LANGS.en
local function T(key)
	return strings[key] or LANGS.en[key] or key
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local cfg = {
	master = true,
	shaders = true,
	shadows = true,
	rain = true,
	rainSound = true,
	wetGround = true,
	footSplash = true,
	wind = true,
	fog = true,
	dof = true,
	lightning = true,
	flare = true,
	shafts = true,
	windSound = true,
	stepSound = true,
	lights = true,
	waterFx = true,
	screenDrops = true,
	manualTime = false,
	hour = 15,
	light = 1,
	strength = 1,
	volume = 0.6,
	mode = "auto",
	quality = 3,
}

local Q = {
	{ rain = 0.5, wind = 0.45, trails = 0, puddles = 0, dof = false, rays = false, future = false, soft = 0.2, n = 3, cell = 30, wet = 80, shaftN = 0, shaftStep = 2, reflect = 0, drops = 6 },
	{ rain = 0.8, wind = 0.75, trails = 5, puddles = 10, dof = false, rays = true, future = false, soft = 0.45, n = 5, cell = 20, wet = 250, shaftN = 9, shaftStep = 2.5, reflect = 1, drops = 10 },
	{ rain = 1, wind = 1, trails = 9, puddles = 22, dof = true, rays = true, future = true, soft = 0.7, n = 7, cell = 16, wet = 450, shaftN = 13, shaftStep = 2, reflect = 4, drops = 14 },
}

local TYPES = {
	shaders = "boolean", shadows = "boolean", rain = "boolean", rainSound = "boolean",
	wetGround = "boolean", footSplash = "boolean", wind = "boolean", fog = "boolean",
	dof = "boolean", lightning = "boolean", flare = "boolean", shafts = "boolean", manualTime = "boolean",
	windSound = "boolean", stepSound = "boolean", lights = "boolean", waterFx = "boolean", screenDrops = "boolean",
	hour = "number", light = "number", strength = "number", volume = "number", quality = "number",
	mode = "string",
}
local MODES = { auto = true, sunny = true, cloudy = true, rainy = true, storm = true }

local function markDirty()
	S.dirty = true
	S.lastTouch = os.clock()
end

local function saveConfig()
	S.dirty = false
	if not writefile then
		return false
	end
	local t = {}
	for k in pairs(TYPES) do
		t[k] = cfg[k]
	end
	return pcall(function()
		writefile(FILE, HttpService:JSONEncode(t))
	end)
end

do
	if isfile and readfile then
		local ok, data = pcall(function()
			if isfile(FILE) then
				return HttpService:JSONDecode(readfile(FILE))
			end
		end)
		if ok and type(data) == "table" then
			for k, v in pairs(data) do
				if TYPES[k] and type(v) == TYPES[k] then
					cfg[k] = v
				end
			end
			cfg.hour = math.clamp(cfg.hour, 0, 24)
			cfg.light = math.clamp(cfg.light, 0.3, 1.5)
			cfg.strength = math.clamp(cfg.strength, 0, 1.5)
			cfg.volume = math.clamp(cfg.volume, 0, 1)
			cfg.quality = math.clamp(math.floor(cfg.quality), 1, 3)
			if not MODES[cfg.mode] then
				cfg.mode = "auto"
			end
		end
	end
end

local weathers = {
	sunny = {
		brightness = 3.2, exposure = 0.25, sun = 1,
		ambient = Color3.fromRGB(80, 92, 112), outdoor = Color3.fromRGB(122, 136, 160),
		shiftTop = Color3.fromRGB(255, 240, 214),
		shiftBottom = Color3.fromRGB(60, 70, 90),
		atmDensity = 0.28, atmOffset = 0.25, atmHaze = 1.0, atmGlare = 0.6,
		atmColor = Color3.fromRGB(199, 220, 255), atmDecay = Color3.fromRGB(255, 226, 190),
		bloom = 0.5, ccSat = 0.2, ccContrast = 0.14, ccBright = 0,
		ccTint = Color3.fromRGB(255, 248, 238),
		rays = 0.32, cloudCover = 0.38, cloudDensity = 0.36, cloudColor = Color3.fromRGB(255, 255, 255),
		rain = 0, wind = 0.55,
	},
	cloudy = {
		brightness = 1.8, exposure = -0.03, sun = 0.35,
		ambient = Color3.fromRGB(100, 106, 118), outdoor = Color3.fromRGB(110, 118, 132),
		shiftTop = Color3.fromRGB(228, 233, 242),
		shiftBottom = Color3.fromRGB(70, 75, 85),
		atmDensity = 0.4, atmOffset = 0, atmHaze = 2.0, atmGlare = 0.15,
		atmColor = Color3.fromRGB(185, 195, 210), atmDecay = Color3.fromRGB(175, 180, 190),
		bloom = 0.32, ccSat = -0.05, ccContrast = 0.1, ccBright = -0.01,
		ccTint = Color3.fromRGB(238, 242, 250),
		rays = 0.08, cloudCover = 0.7, cloudDensity = 0.5, cloudColor = Color3.fromRGB(236, 239, 246),
		rain = 0, wind = 0.8,
	},
	rainy = {
		brightness = 1.4, exposure = -0.02, sun = 0,
		ambient = Color3.fromRGB(95, 104, 120), outdoor = Color3.fromRGB(108, 118, 135),
		shiftTop = Color3.fromRGB(205, 215, 230),
		shiftBottom = Color3.fromRGB(60, 66, 78),
		atmDensity = 0.45, atmOffset = 0, atmHaze = 2.6, atmGlare = 0,
		atmColor = Color3.fromRGB(172, 182, 198), atmDecay = Color3.fromRGB(150, 158, 172),
		bloom = 0.3, ccSat = -0.1, ccContrast = 0.12, ccBright = 0,
		ccTint = Color3.fromRGB(225, 232, 245),
		rays = 0, cloudCover = 0.82, cloudDensity = 0.55, cloudColor = Color3.fromRGB(178, 186, 200),
		rain = 1, wind = 1.1,
	},
	storm = {
		brightness = 1.0, exposure = -0.1, sun = 0,
		ambient = Color3.fromRGB(80, 88, 105), outdoor = Color3.fromRGB(92, 102, 122),
		shiftTop = Color3.fromRGB(190, 200, 220),
		shiftBottom = Color3.fromRGB(50, 56, 70),
		atmDensity = 0.62, atmOffset = 0, atmHaze = 3.4, atmGlare = 0,
		atmColor = Color3.fromRGB(140, 150, 168), atmDecay = Color3.fromRGB(118, 126, 142),
		bloom = 0.28, ccSat = -0.14, ccContrast = 0.16, ccBright = -0.02,
		ccTint = Color3.fromRGB(215, 224, 240),
		rays = 0, cloudCover = 1, cloudDensity = 0.62, cloudColor = Color3.fromRGB(150, 158, 175),
		rain = 1.9, wind = 1.8,
	},
}


local cur = {}
for k, v in pairs(weathers.sunny) do
	cur[k] = v
end

local LIGHT_PROPS = { "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local SHADOW_PROPS = { "GlobalShadows", "ShadowSoftness" }

local orig = {}
for _, list in ipairs({ LIGHT_PROPS, SHADOW_PROPS, { "ClockTime" } }) do
	for _, k in ipairs(list) do
		local ok, v = pcall(function()
			return Lighting[k]
		end)
		if ok then
			orig[k] = v
		end
	end
end
if gethiddenproperty then
	pcall(function()
		orig.Technology = gethiddenproperty(Lighting, "Technology")
	end)
end
pcall(function()
	orig.GlobalWind = Workspace.GlobalWind
end)

local bloom = create("BloomEffect", { Name = "ws_bloom", Enabled = false, Size = 24, Threshold = 1.6 }, Lighting)
local cc = create("ColorCorrectionEffect", { Name = "ws_cc", Enabled = false }, Lighting)
local sunRays = create("SunRaysEffect", { Name = "ws_rays", Enabled = false, Spread = 0.8 }, Lighting)
local dofEffect = create("DepthOfFieldEffect", { Name = "ws_dof", Enabled = false, FocusDistance = 150, InFocusRadius = 80, NearIntensity = 0 }, Lighting)

local OTHER_EFFECTS = { "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect", "DepthOfFieldEffect" }
local disabledOthers = {}
local atm, atmOwned, atmBackup
local clouds, cloudsOwned, cloudsBackup
local sky, skySunSize, skyStars

local function setTechnology(future)
	if S.futureOn == future then
		return
	end
	if sethiddenproperty and orig.Technology then
		local ok = pcall(sethiddenproperty, Lighting, "Technology", future and Enum.Technology.Future or orig.Technology)
		if ok then
			S.futureOn = future
		end
	end
end

local function backup(inst, names)
	local t = {}
	for _, n in ipairs(names) do
		t[n] = inst[n]
	end
	return t
end

local function enterVisual()
	S.visualOn = true
	for _, inst in ipairs(Lighting:GetChildren()) do
		for _, cls in ipairs(OTHER_EFFECTS) do
			if inst:IsA(cls) and inst.Name:sub(1, 3) ~= "ws_" and inst.Enabled then
				disabledOthers[#disabledOthers + 1] = inst
				inst.Enabled = false
			end
		end
	end
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a then
		atm, atmOwned = a, false
		atmBackup = backup(a, { "Density", "Offset", "Color", "Decay", "Glare", "Haze" })
	else
		atm, atmOwned = create("Atmosphere", { Name = "ws_atmosphere" }, Lighting), true
	end
	if terrain then
		local c = terrain:FindFirstChildOfClass("Clouds")
		if c then
			clouds, cloudsOwned = c, false
			cloudsBackup = backup(c, { "Cover", "Density", "Color", "Enabled" })
		else
			clouds, cloudsOwned = create("Clouds", { Name = "ws_clouds" }, terrain), true
		end
	end
	sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		skySunSize = sky.SunAngularSize
		skyStars = sky.StarCount
		sky.StarCount = math.max(skyStars, 3000)
	end
	bloom.Enabled = true
	cc.Enabled = true
end

local function exitVisual()
	if not S.visualOn then
		return
	end
	S.visualOn = false
	bloom.Enabled, cc.Enabled, sunRays.Enabled, dofEffect.Enabled = false, false, false, false
	for _, k in ipairs(LIGHT_PROPS) do
		if orig[k] ~= nil then
			pcall(function()
				Lighting[k] = orig[k]
			end)
		end
	end
	for _, inst in ipairs(disabledOthers) do
		if inst.Parent then
			inst.Enabled = true
		end
	end
	table.clear(disabledOthers)
	if atm then
		if atmOwned then
			atm:Destroy()
		else
			for k, v in pairs(atmBackup) do
				atm[k] = v
			end
		end
		atm = nil
	end
	if clouds then
		if cloudsOwned then
			clouds:Destroy()
		else
			for k, v in pairs(cloudsBackup) do
				clouds[k] = v
			end
		end
		clouds = nil
	end
	if sky and sky.Parent and skySunSize then
		sky.SunAngularSize = skySunSize
		sky.StarCount = skyStars
	end
	sky = nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.MaxParts = 2000

local function setFilter(cam)
	local list = { cam }
	if lp.Character then
		list[2] = lp.Character
	end
	rayParams.FilterDescendantsInstances = list
end

local TEX = "rbxasset://textures/particles/sparkles_main.dds"

local windPart, windLeaves, windPollen
local trails = {}
local footPart, footRipples, footDrops
local grid, gridN, gridSize = {}, 0, 0
local gridIx, gridIz = nil, nil
local cellCache = {}
local puddles = {}

local shafts = {
	pool = {}, cells = {}, idx = 1, n = 0, step = 2, running = false, timer = 0,
	origin = Vector3.zero, dir = Vector3.new(0, 1, 0), I = 0, color = Color3.fromRGB(255, 235, 190),
}
local MAX_SHAFTS = 4

local function emptyPart(name, size, parent)
	return create("Part", {
		Name = name, Size = size, Anchored = true, CanCollide = false, CanQuery = false,
		CanTouch = false, CastShadow = false, Transparency = 1, Locked = true,
	}, parent)
end

local function clearParts()
	for _, p in ipairs({ windPart, footPart }) do
		if p then
			p:Destroy()
		end
	end
	for _, c in ipairs(grid) do
		c.col:Destroy()
		c.floor:Destroy()
	end
	table.clear(grid)
	for _, b in ipairs(shafts.pool) do
		b.holder:Destroy()
	end
	table.clear(shafts.pool)
	for _, t in ipairs(trails) do
		t.part:Destroy()
	end
	table.clear(trails)
	for _, p in ipairs(puddles) do
		p.part:Destroy()
	end
	table.clear(puddles)
	windPart, footPart = nil, nil
	gridIx, gridIz = nil, nil
	table.clear(cellCache)
	shafts.running = false
end

local function rainStyle(c, s)
	c.storm = s
	local vMin, vMax = 115 + s * 45, 135 + s * 50
	local life = 41 / ((vMin + vMax) / 2)
	c.em.Speed = NumberRange.new(vMin, vMax)
	c.em.Lifetime = NumberRange.new(life * 0.94, life * 1.04)
	c.em.Size = NumberSequence.new(0.38 + s * 0.22)
	c.em.Transparency = NumberSequence.new(0.25 - s * 0.1)
end

local function ensureParts(cam)
	local q = Q[cfg.quality]
	if windPart and windPart.Parent == cam and gridN == q.n and gridSize == q.cell then
		return
	end
	clearParts()
	setFilter(cam)

	windPart = emptyPart("ws_wind", Vector3.new(90, 30, 90), cam)
	windLeaves = create("ParticleEmitter", {
		Texture = TEX, Enabled = false, Rate = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 175, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 165, 95)),
		}),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.25), NumberSequenceKeypoint.new(0.88, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.45) }),
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(5, 8), SpreadAngle = Vector2.new(14, 14),
		EmissionDirection = Enum.NormalId.Front,
		RotSpeed = NumberRange.new(-220, 220), Rotation = NumberRange.new(0, 360),
		LightInfluence = 0.8, LockedToPart = false,
	}, windPart)
	windPollen = create("ParticleEmitter", {
		Texture = TEX, Enabled = false, Rate = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 246, 215)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0.12) }),
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Front,
		RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360),
		LightEmission = 0.9, LightInfluence = 0.3, LockedToPart = false,
	}, windPart)

	for i = 1, q.trails do
		local part = emptyPart("ws_air", Vector3.new(0.2, 0.2, 0.2), cam)
		local a0 = create("Attachment", { Position = Vector3.new(0, 0.25, 0) }, part)
		local a1 = create("Attachment", { Position = Vector3.new(0, -0.25, 0) }, part)
		local trail = create("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 1.7, MinLength = 0.1, FaceCamera = true,
			LightEmission = 0.55, LightInfluence = 0.4, Enabled = false,
			Color = ColorSequence.new(Color3.fromRGB(236, 243, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(1, 0) }),
		}, part)
		trails[i] = { part = part, trail = trail, base = Vector3.zero, phase = 0, freq = 1, amp = 2, fresh = true, hold = 0 }
	end

	footPart = emptyPart("ws_foot", Vector3.new(2, 0.2, 2), cam)
	footRipples = create("ParticleEmitter", {
		Texture = TEX, Enabled = false, Rate = 0,
		Color = ColorSequence.new(Color3.fromRGB(225, 235, 250)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.8) }),
		Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(0),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		LightEmission = 0.3, LightInfluence = 0.7,
	}, footPart)
	footDrops = create("ParticleEmitter", {
		Texture = TEX, Enabled = false, Rate = 0,
		Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.9) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.05) }),
		Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(5, 10),
		Acceleration = Vector3.new(0, -55, 0), SpreadAngle = Vector2.new(55, 55),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 0.4, LightInfluence = 0.5,
	}, footPart)

	gridN, gridSize = q.n, q.cell
	local mid = (gridN + 1) / 2
	for i = 1, gridN do
		for j = 1, gridN do
			local col = emptyPart("ws_rain", Vector3.new(gridSize, 1, gridSize), cam)
			local em = create("ParticleEmitter", {
				Texture = TEX, Enabled = false, Rate = 0,
				Color = ColorSequence.new(Color3.fromRGB(215, 228, 248)),
				Squash = NumberSequence.new(-2.5),
				Acceleration = Vector3.new(0, -40, 0),
				EmissionDirection = Enum.NormalId.Bottom,
				SpreadAngle = Vector2.new(2, 2),
				LightEmission = 0.35, LightInfluence = 0.3,
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				LockedToPart = false,
			}, col)
			local floor = emptyPart("ws_splash", Vector3.new(gridSize, 0.2, gridSize), cam)
			local ripples = create("ParticleEmitter", {
				Texture = TEX, Enabled = false, Rate = 0,
				Color = ColorSequence.new(Color3.fromRGB(225, 235, 250)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 2.4) }),
				Lifetime = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(0),
				EmissionDirection = Enum.NormalId.Top,
				Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
				LightEmission = 0.3, LightInfluence = 0.7,
			}, floor)
			local drops = create("ParticleEmitter", {
				Texture = TEX, Enabled = false, Rate = 0,
				Color = ColorSequence.new(Color3.fromRGB(235, 245, 255)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.9) }),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.06) }),
				Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(4, 9),
				Acceleration = Vector3.new(0, -45, 0), SpreadAngle = Vector2.new(35, 35),
				EmissionDirection = Enum.NormalId.Top,
				LightEmission = 0.4, LightInfluence = 0.5,
			}, floor)
			local c = {
				col = col, em = em, floor = floor, ripples = ripples, drops = drops,
				di = i - mid, dj = j - mid, wx = 0, wz = 0, cx = 0, cz = 0, y = nil,
				exposed = false, pending = true, stamp = 0, area = gridSize * gridSize, storm = -1,
			}
			rainStyle(c, 0)
			grid[#grid + 1] = c
		end
	end

	for i = 1, MAX_SHAFTS do
		local holder = create("Part", {
			Name = "ws_shaft", Size = Vector3.new(2, 2, 2), Anchored = true, CanCollide = false, CanQuery = false,
			CanTouch = false, CastShadow = false, Transparency = 1, Locked = true,
		}, cam)
		local a0 = create("Attachment", {}, holder)
		local a1 = create("Attachment", {}, holder)
		local layers = {}
		for _, L in ipairs({ { 1.6, 0.94 }, { 1.0, 0.88 }, { 0.5, 0.8 } }) do
			local beam = create("Beam", {
				Attachment0 = a0, Attachment1 = a1, FaceCamera = true, LightEmission = 1, LightInfluence = 0,
				Segments = 1, Enabled = false, Width0 = 2, Width1 = 2,
				Transparency = NumberSequence.new(1), Color = ColorSequence.new(shafts.color),
			}, holder)
			layers[#layers + 1] = { beam = beam, mult = L[1], base = L[2] }
		end
		local motes = create("ParticleEmitter", {
			Texture = TEX, Enabled = false, Rate = 0,
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 200)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new(0.14),
			Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.2, 0.7),
			SpreadAngle = Vector2.new(180, 180), LightEmission = 1, LightInfluence = 0,
			RotSpeed = NumberRange.new(-40, 40), LockedToPart = false,
		}, holder)
		shafts.pool[i] = { holder = holder, a0 = a0, a1 = a1, layers = layers, motes = motes, alpha = 0, want = false, lastK = -1 }
	end

	for i = 1, q.puddles do
		local part = create("Part", {
			Name = "ws_puddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 4, 4),
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(28, 36, 48),
			Reflectance = 0.55, Transparency = 1, Locked = true,
		}, cam)
		puddles[i] = { part = part, size = 4, placed = false }
	end
end

local function hideWeatherFx()
	for _, e in ipairs({ windLeaves, windPollen, footRipples, footDrops }) do
		if e then
			e.Enabled = false
		end
	end
	for _, c in ipairs(grid) do
		c.em.Enabled = false
		c.ripples.Enabled = false
		c.drops.Enabled = false
	end
	for _, b in ipairs(shafts.pool) do
		b.want, b.alpha, b.lastK = false, 0, -1
		b.motes.Enabled = false
		for _, L in ipairs(b.layers) do
			L.beam.Enabled = false
		end
	end
	for _, t in ipairs(trails) do
		t.trail.Enabled = false
		t.fresh = true
	end
	for _, p in ipairs(puddles) do
		p.part.Transparency = 1
		p.placed = false
	end
end

local sound = create("Sound", { Name = "ws_rain_sound", Looped = true, Volume = 0 }, SoundService)
local eq = create("EqualizerSoundEffect", {}, sound)
local windSnd = create("Sound", { Name = "ws_wind_sound", Looped = true, Volume = 0 }, SoundService)
local windEq = create("EqualizerSoundEffect", {}, windSnd)
local stepSnd = create("Sound", { Name = "ws_step_sound", Volume = 0.3 }, SoundService)

local wetParts = {}
local wetSkip = { Glass = true, ForceField = true, Neon = true, Water = true, Air = true }
local wetMaterials, terrainColors = {}, {}

for _, m in ipairs(Enum.Material:GetEnumItems()) do
	if not wetSkip[m.Name] then
		wetMaterials[m] = true
	end
end

if terrain then
	for _, n in ipairs({ "Grass", "LeafyGrass", "Sand", "Ground", "Mud", "Rock", "Pavement", "Asphalt", "Slate", "Sandstone", "Limestone", "Basalt", "Cobblestone", "Concrete", "Salt", "Brick", "WoodPlanks" }) do
		local ok, m = pcall(function()
			return Enum.Material[n]
		end)
		if ok and m then
			local ok2, c = pcall(terrain.GetMaterialColor, terrain, m)
			if ok2 and c then
				terrainColors[m] = c
			end
		end
	end
end

local function darken(c)
	return Color3.new(c.R * 0.45, c.G * 0.45, c.B * 0.5)
end

local function wetten(p, d)
	p.Color = d.color:Lerp(darken(d.color), S.wetness * 0.75)
	p.Reflectance = math.max(d.refl, S.wetness * 0.3)
end

local function dryAll()
	for p, d in pairs(wetParts) do
		if p.Parent then
			p.Color = d.color
			p.Reflectance = d.refl
		end
	end
	table.clear(wetParts)
	if terrain then
		for m, c in pairs(terrainColors) do
			pcall(terrain.SetMaterialColor, terrain, m, c)
		end
	end
	S.wetness, S.lastWetness = 0, 0
end

local function scanWet(origin, limit)
	S.lastWetScan, S.wetOrigin = os.clock(), origin
	overlap.FilterDescendantsInstances = lp.Character and { lp.Character } or {}
	local fresh, n = {}, 0
	for _, p in ipairs(Workspace:GetPartBoundsInRadius(origin, 110, overlap)) do
		if n >= limit then
			break
		end
		if p.Anchored and p.Transparency < 0.4 and wetMaterials[p.Material] and p.Name:sub(1, 3) ~= "ws_" then
			fresh[p] = true
			n += 1
		end
	end
	for p, d in pairs(wetParts) do
		if not fresh[p] then
			if p.Parent then
				p.Color = d.color
				p.Reflectance = d.refl
			end
			wetParts[p] = nil
		end
	end
	for p in pairs(fresh) do
		if not wetParts[p] then
			local d = { color = p.Color, refl = p.Reflectance }
			wetParts[p] = d
			wetten(p, d)
		end
	end
end

local function updateGround(dt, level, pos, q)
	if not cfg.wetGround then
		if next(wetParts) or S.lastWetness > 0 then
			dryAll()
		end
		return
	end
	if level > 0.15 then
		S.wetness = math.min(1, S.wetness + dt / (level > 1.3 and 6 or 12))
	else
		S.wetness = math.max(0, S.wetness - dt / 90)
	end
	if S.wetness > 0.02 then
		if os.clock() - S.lastWetScan > 6 or (pos - S.wetOrigin).Magnitude > 40 then
			scanWet(pos, q.wet)
		end
	end
	if S.wetness <= 0 and S.lastWetness > 0 then
		dryAll()
		return
	end
	if math.abs(S.wetness - S.lastWetness) >= 0.03 then
		S.lastWetness = S.wetness
		for p, d in pairs(wetParts) do
			if p.Parent then
				wetten(p, d)
			end
		end
		if terrain then
			for m, c in pairs(terrainColors) do
				pcall(terrain.SetMaterialColor, terrain, m, c:Lerp(darken(c), S.wetness * 0.75))
			end
		end
	end
end

local function updatePuddles(dt, pos)
	if #puddles == 0 then
		return
	end
	S.puddleTimer -= dt
	if S.puddleTimer > 0 then
		return
	end
	S.puddleTimer = 0.5
	local a = cfg.wetGround and math.clamp((S.puddleLevel - 0.1) / 0.5, 0, 1) or 0
	local placedNow = 0
	for _, pd in ipairs(puddles) do
		local far = pd.placed and Vector2.new(pd.part.Position.X - pos.X, pd.part.Position.Z - pos.Z).Magnitude > 55
		if a > 0.05 and (not pd.placed or far) and placedNow < 2 then
			placedNow += 1
			pd.placed = false
			local ang, rad = math.random() * 6.283, 6 + math.random() * 40
			local o = Vector3.new(pos.X + math.cos(ang) * rad, pos.Y + 25, pos.Z + math.sin(ang) * rad)
			local hit = Workspace:Raycast(o, Vector3.new(0, -80, 0), rayParams)
			if hit and hit.Normal.Y > 0.92 and (hit.Instance:IsA("Terrain") or hit.Instance.Anchored) then
				local roof = Workspace:Raycast(hit.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 120, 0), rayParams)
				if not (roof and roof.Instance.Transparency < 0.9) then
					pd.size = 3 + math.random() * 5
					pd.part.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2)
					pd.placed = true
				end
			end
		end
		if pd.placed and a > 0.01 then
			local s = pd.size * (0.4 + 0.6 * a)
			pd.part.Size = Vector3.new(0.06, s, s)
			pd.part.Transparency = 1 - 0.65 * a
		else
			pd.part.Transparency = 1
		end
	end
end

local lightList, lightSet = {}, {}

local function registerLight(inst)
	if lightSet[inst] then
		return
	end
	lightSet[inst] = true
	local ok, r = pcall(function()
		return inst.Range
	end)
	lightList[#lightList + 1] = { inst = inst, b = inst.Brightness, r = ok and r or nil, s = inst.Shadows, set = nil, boost = 1 }
end

task.spawn(function()
	local n = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Light") then
			registerLight(inst)
		end
		n += 1
		if n % 3000 == 0 then
			task.wait()
		end
	end
end)

connect(Workspace.DescendantAdded, function(inst)
	if inst:IsA("Light") then
		registerLight(inst)
	end
end)

local function applyLights(camPos, boostB, boostR, shadowsOn, budget)
	local n = #lightList
	for _ = 1, math.min(budget, n) do
		if n == 0 then
			break
		end
		if S.lightCursor > n then
			S.lightCursor = 1
		end
		local e = lightList[S.lightCursor]
		local inst = e.inst
		if not inst.Parent then
			lightList[S.lightCursor] = lightList[n]
			lightList[n] = nil
			lightSet[inst] = nil
			n -= 1
		else
			if e.set and math.abs(inst.Brightness - e.set) > 0.001 then
				e.b = inst.Brightness / e.boost
			end
			e.boost = boostB
			e.set = e.b * boostB
			setp(inst, "Brightness", e.set)
			if e.r then
				setp(inst, "Range", e.r * boostR)
			end
			local want = e.s
			if shadowsOn then
				local par = inst.Parent
				local p
				if par:IsA("BasePart") then
					p = par.Position
				elseif par:IsA("Attachment") then
					p = par.WorldPosition
				end
				if p and (p - camPos).Magnitude < 70 then
					want = true
				end
			end
			setp(inst, "Shadows", want)
			S.lightCursor += 1
		end
	end
end

local function restoreLights()
	for _, e in ipairs(lightList) do
		local inst = e.inst
		if inst.Parent and e.set then
			pcall(function()
				inst.Brightness = e.b
				if e.r then
					inst.Range = e.r
				end
				inst.Shadows = e.s
			end)
			e.set = nil
			e.boost = 1
		end
	end
end

local sun = { facing = 0, occ = 0, f = 0, visible = false, screen = Vector2.zero, blocked = false, ray = 0, dir = Vector3.new(0, 1, 0) }
local flare = {}

local function updateSun(dt, cam)
	local ok, d = pcall(function()
		return Lighting:GetSunDirection()
	end)
	if not ok then
		return
	end
	sun.dir = d
	local target = math.clamp((cam.CFrame.LookVector:Dot(d) - 0.55) / 0.45, 0, 1)
	target = target * target * (3 - 2 * target)
	if d.Y < -0.05 then
		target = 0
	end
	sun.facing += (target - sun.facing) * (1 - math.exp(-dt * 6))
	local p = cam:WorldToViewportPoint(cam.CFrame.Position + d * 1000)
	sun.visible = p.Z > 0 and d.Y > -0.05
	sun.screen = Vector2.new(p.X, p.Y)
	sun.occ += ((sun.blocked and 1 or 0) - sun.occ) * (1 - math.exp(-dt * 4))
	sun.ray -= dt
	if sun.ray <= 0 then
		sun.ray = 0.12
		if sun.visible then
			setFilter(cam)
			local hit = Workspace:Raycast(cam.CFrame.Position, d * 600, rayParams)
			sun.blocked = hit ~= nil and hit.Instance.Transparency < 0.9
		else
			sun.blocked = false
		end
	end
end

local function clusterShafts()
	local n, cells = shafts.n, shafts.cells
	local seen, groups = {}, {}
	for idx = 1, n * n do
		local c = cells[idx]
		if c and c.lit and not seen[idx] then
			local stack, group = { idx }, {}
			seen[idx] = true
			while #stack > 0 do
				local k = table.remove(stack)
				group[#group + 1] = cells[k]
				local i = (k - 1) % n + 1
				local j = math.floor((k - 1) / n) + 1
				for _, nb in ipairs({ { i - 1, j }, { i + 1, j }, { i, j - 1 }, { i, j + 1 } }) do
					local a, b = nb[1], nb[2]
					if a >= 1 and a <= n and b >= 1 and b <= n then
						local nk = (b - 1) * n + a
						local nc = cells[nk]
						if nc and nc.lit and not seen[nk] then
							seen[nk] = true
							stack[#stack + 1] = nk
						end
					end
				end
			end
			if #group <= n * n * 0.45 then
				groups[#groups + 1] = group
			end
		end
	end
	table.sort(groups, function(a, b)
		return #a > #b
	end)
	local dir = shafts.dir
	for i = 1, MAX_SHAFTS do
		local g = groups[i]
		local b = shafts.pool[i]
		if b then
			if g then
				local sum, ceil = Vector3.zero, 0
				for _, c in ipairs(g) do
					sum += c.pos
					ceil += c.ceil
				end
				local center = sum / #g
				ceil = ceil / #g
				local w = math.clamp(math.sqrt(#g) * shafts.step, 1.2, 6)
				local len = math.clamp(ceil / math.max(dir.Y, 0.2), 4, 45)
				local mid = center + dir * (len / 2)
				b.holder.CFrame = CFrame.lookAt(mid, mid + dir)
				b.holder.Size = Vector3.new(w, w, len)
				b.a0.Position = Vector3.new(0, 0, len / 2)
				b.a1.Position = Vector3.new(0, 0, -len / 2)
				for _, L in ipairs(b.layers) do
					L.beam.Width0 = w * L.mult
					L.beam.Width1 = w * L.mult
				end
				b.want = true
				b.lastK = -1
			else
				b.want = false
			end
		end
	end
end

local function updateShafts(dt, cam, root)
	local q = Q[cfg.quality]
	local on = cfg.shafts and cfg.shaders and q.shaftN > 0 and shafts.I > 0.05
	if on and S.muffleTarget > 0.2 then
		if not shafts.running then
			shafts.timer -= dt
			if shafts.timer <= 0 then
				shafts.running = true
				shafts.idx = 1
				shafts.n = q.shaftN
				shafts.step = q.shaftStep
				shafts.origin = root and root.Position or cam.CFrame.Position
				shafts.dir = sun.dir
				table.clear(shafts.cells)
			end
		end
		if shafts.running then
			local n = shafts.n
			local total = n * n
			local half = (n + 1) / 2
			local budget = 8
			while budget > 0 and shafts.idx <= total do
				local i = (shafts.idx - 1) % n + 1
				local j = math.floor((shafts.idx - 1) / n) + 1
				local x = shafts.origin.X + (i - half) * shafts.step
				local z = shafts.origin.Z + (j - half) * shafts.step
				local cell = { lit = false }
				local floor = Workspace:Raycast(Vector3.new(x, shafts.origin.Y + 2, z), Vector3.new(0, -14, 0), rayParams)
				if floor then
					local fp = floor.Position + Vector3.new(0, 0.4, 0)
					local up = Workspace:Raycast(fp, Vector3.new(0, 45, 0), rayParams)
					if up and up.Instance.Transparency < 0.9 then
						local toSun = Workspace:Raycast(fp, shafts.dir * 300, rayParams)
						cell.ceil = up.Distance
						cell.pos = fp
						cell.lit = not (toSun and toSun.Instance.Transparency < 0.9)
					end
				end
				shafts.cells[shafts.idx] = cell
				shafts.idx += 1
				budget -= 1
			end
			if shafts.idx > total then
				clusterShafts()
				shafts.running = false
				shafts.timer = 1
			end
		end
	else
		shafts.running = false
		for _, b in ipairs(shafts.pool) do
			b.want = false
		end
	end

	for _, b in ipairs(shafts.pool) do
		local goal = (on and b.want) and 1 or 0
		b.alpha += (goal - b.alpha) * (1 - math.exp(-dt * 3))
		if b.alpha < 0.01 then
			if b.lastK ~= 0 then
				b.lastK = 0
				b.motes.Enabled = false
				for _, L in ipairs(b.layers) do
					L.beam.Enabled = false
				end
			end
		else
			local k = b.alpha * shafts.I
			if math.abs(k - b.lastK) > 0.02 then
				b.lastK = k
				for _, L in ipairs(b.layers) do
					local t = 1 - (1 - L.base) * k
					L.beam.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, t),
						NumberSequenceKeypoint.new(0.85, t), NumberSequenceKeypoint.new(1, 1),
					})
					L.beam.Color = ColorSequence.new(shafts.color)
					L.beam.Enabled = true
				end
				b.motes.Rate = 5 * k
				b.motes.Enabled = true
			end
		end
	end
end

local sequence = { "sunny", "cloudy", "rainy", "storm", "rainy", "cloudy" }
local char, hum, root
local screenDrops = { level = 0 }

local function refreshChar()
	char = lp.Character
	hum = char and char:FindFirstChildOfClass("Humanoid")
	root = char and char:FindFirstChild("HumanoidRootPart")
end
connect(lp.CharacterAdded, function()
	task.defer(refreshChar)
end)
refreshChar()

local WATER_PROPS = { "WaterColor", "WaterTransparency", "WaterReflectance", "WaterWaveSize", "WaterWaveSpeed" }
local waterOrig = {}
if terrain then
	for _, k in ipairs(WATER_PROPS) do
		local ok, v = pcall(function()
			return terrain[k]
		end)
		if ok then
			waterOrig[k] = v
		end
	end
end

local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Exclude
waterParams.IgnoreWater = false

local waterParts, waterSet = {}, {}
local WATER_MATERIALS = { Glass = true, SmoothPlastic = true, Plastic = true, ForceField = true, Neon = false }

local function looksLikeWater(p)
	if p.Name:sub(1, 3) == "ws_" or not p.Name:lower():find("water", 1, true) then
		return false
	end
	if p.Transparency < 0.15 or p.Transparency > 0.92 then
		return false
	end
	local s = p.Size
	if s.Y > 6 or s.X < 8 or s.Z < 8 then
		return false
	end
	if p.Color.B < p.Color.R or not WATER_MATERIALS[p.Material.Name] then
		return false
	end
	return p.Anchored
end

local function scanWaterParts(origin)
	overlap.FilterDescendantsInstances = lp.Character and { lp.Character } or {}
	local fresh = {}
	for _, p in ipairs(Workspace:GetPartBoundsInRadius(origin, 150, overlap)) do
		if looksLikeWater(p) and not wetParts[p] then
			fresh[p] = true
		end
	end
	for p, d in pairs(waterParts) do
		if not fresh[p] then
			if p.Parent then
				p.Reflectance = d.refl
			end
			waterParts[p] = nil
			waterSet[p] = nil
		end
	end
	for p in pairs(fresh) do
		if not waterParts[p] then
			waterParts[p] = { refl = p.Reflectance }
			waterSet[p] = true
			p.Reflectance = math.max(p.Reflectance, 0.25)
		end
	end
end

local function restoreWater()
	for p, d in pairs(waterParts) do
		if p.Parent then
			p.Reflectance = d.refl
		end
	end
	table.clear(waterParts)
	table.clear(waterSet)
	if terrain and S.waterApplied then
		for k, v in pairs(waterOrig) do
			pcall(function()
				terrain[k] = v
			end)
		end
	end
	S.waterApplied = false
end

local function applyWater(day, windLevel)
	if not terrain then
		return
	end
	S.waterApplied = true
	local target = Color3.fromRGB(34, 96, 118):Lerp(Color3.fromRGB(8, 20, 32), 1 - day)
	local wave = math.floor(math.clamp(0.18 + 0.25 * windLevel, 0.15, 0.55) * 10 + 0.5) / 10
	pcall(function()
		if waterOrig.WaterColor then
			setp(terrain, "WaterColor", waterOrig.WaterColor:Lerp(target, 0.4))
		end
		if waterOrig.WaterTransparency then
			setp(terrain, "WaterTransparency", math.min(waterOrig.WaterTransparency, 0.9))
		end
		setp(terrain, "WaterReflectance", 1)
		setp(terrain, "WaterWaveSize", wave)
		setp(terrain, "WaterWaveSpeed", 12 + math.floor(8 * math.min(windLevel, 1.5)))
	end)
end

local reflections = {}

local function buildReflection(character)
	local folder = Instance.new("Folder")
	folder.Name = "ws_reflection"
	local parts = {}
	for _, d in ipairs(character:GetDescendants()) do
		if #parts >= 26 then
			break
		end
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.95 then
			local ok, c = pcall(function()
				return d:Clone()
			end)
			if ok and c then
				for _, ch in ipairs(c:GetChildren()) do
					if not ch:IsA("DataModelMesh") then
						ch:Destroy()
					end
				end
				c.Name = "ws_refl"
				c.Anchored = true
				c.CanCollide = false
				c.CanQuery = false
				c.CanTouch = false
				c.CastShadow = false
				c.Massless = true
				c.Transparency = math.min(1, 0.62 + d.Transparency * 0.3)
				c.Parent = folder
				parts[#parts + 1] = { src = d, clone = c }
			end
		end
	end
	return { parts = parts, folder = folder, active = false, y = 0 }
end

local function hideReflections()
	for _, e in pairs(reflections) do
		e.active = false
		if e.folder.Parent then
			e.folder.Parent = nil
		end
	end
end

local function clearReflections()
	for ch, e in pairs(reflections) do
		e.folder:Destroy()
		reflections[ch] = nil
	end
end

local function updateReflections(dt, cam, q)
	if not (cfg.waterFx and cfg.shaders) or q.reflect == 0 or not root then
		hideReflections()
		return
	end
	S.reflTimer -= dt
	if S.reflTimer <= 0 then
		S.reflTimer = 0.3
		local wanted, count = {}, 0
		local list = { char }
		if q.reflect > 1 then
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl ~= lp and pl.Character then
					list[#list + 1] = pl.Character
				end
			end
		end
		for _, ch in ipairs(list) do
			if count >= q.reflect then
				break
			end
			local r = ch:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - root.Position).Magnitude < 45 then
				waterParams.FilterDescendantsInstances = { cam, ch }
				local hit = Workspace:Raycast(r.Position, Vector3.new(0, -40, 0), waterParams)
				if hit and r.Position.Y > hit.Position.Y + 1 and (hit.Material == Enum.Material.Water or waterSet[hit.Instance]) then
					count += 1
					local e = reflections[ch]
					if not e then
						e = buildReflection(ch)
						reflections[ch] = e
					end
					e.y = hit.Position.Y
					e.active = true
					wanted[ch] = true
				end
			end
		end
		for ch, e in pairs(reflections) do
			if not ch.Parent then
				e.folder:Destroy()
				reflections[ch] = nil
			elseif not wanted[ch] then
				e.active = false
			end
		end
	end
	local t = os.clock()
	for _, e in pairs(reflections) do
		if e.active then
			if e.folder.Parent ~= cam then
				e.folder.Parent = cam
			end
			for i, pr in ipairs(e.parts) do
				local src = pr.src
				if src.Parent then
					local cf = src.CFrame
					local p = cf.Position
					local R, U, B = cf.RightVector, cf.UpVector, -cf.LookVector
					local wob = Vector3.new(math.sin(t * 2.3 + i) * 0.05, 0, math.cos(t * 1.9 + i * 1.7) * 0.05)
					pr.clone.CFrame = CFrame.fromMatrix(
						Vector3.new(p.X, 2 * e.y - p.Y, p.Z) + wob,
						Vector3.new(-R.X, R.Y, -R.Z),
						Vector3.new(U.X, -U.Y, U.Z),
						Vector3.new(B.X, -B.Y, B.Z)
					)
				end
			end
		elseif e.folder.Parent then
			e.folder.Parent = nil
		end
	end
end

local function blend(a, b, t)
	for k, bv in pairs(b) do
		if typeof(bv) == "Color3" then
			a[k] = a[k]:Lerp(bv, t)
		else
			a[k] = a[k] + (bv - a[k]) * t
		end
	end
end

local function pickWeather(dt)
	if cfg.mode ~= "auto" then
		return cfg.mode
	end
	S.seqTime -= dt
	if S.seqTime <= 0 then
		S.seqIdx = S.seqIdx % #sequence + 1
		S.seqTime = math.random(90, 160)
	end
	return sequence[S.seqIdx]
end

local function updateSounds(dt, rainLevel, windLevel)
	if S.soundOk then
		local level = cfg.rainSound and math.min(rainLevel, 1.5) or 0
		local goal = cfg.volume * level * (1 - S.muffle * 0.6)
		sound.Volume = sound.Volume + (goal - sound.Volume) * (1 - math.exp(-dt * 2))
		eq.HighGain = -45 * S.muffle
		eq.MidGain = -12 * S.muffle
		eq.LowGain = 4 * S.muffle
		if goal > 0.01 and not sound.IsPlaying then
			sound:Play()
		elseif goal <= 0.01 and sound.Volume < 0.01 and sound.IsPlaying then
			sound:Stop()
		end
	end
	if S.windOk then
		local goal = (cfg.windSound and cfg.wind) and (0.04 + 0.1 * math.clamp(windLevel / 1.8, 0, 1)) * (1 - S.muffle * 0.55) or 0
		windSnd.Volume = windSnd.Volume + (goal - windSnd.Volume) * (1 - math.exp(-dt * 1.5))
		windEq.HighGain = -30 * S.muffle
		if goal > 0.005 and not windSnd.IsPlaying then
			windSnd:Play()
		elseif goal <= 0.005 and windSnd.Volume < 0.004 and windSnd.IsPlaying then
			windSnd:Stop()
		end
	end
end

local function playStep(wetF)
	S.stepToken += 1
	local tok = S.stepToken
	stepSnd:Stop()
	stepSnd.PlaybackSpeed = 0.9 + math.random() * 0.2
	stepSnd.Volume = math.clamp(0.16 + 0.18 * wetF, 0.1, 0.38)
	if stepSnd.TimeLength > 1.2 then
		stepSnd.TimePosition = math.random() * (stepSnd.TimeLength - 0.6)
		stepSnd:Play()
		task.delay(0.4, function()
			if tok == S.stepToken then
				stepSnd:Stop()
			end
		end)
	else
		stepSnd.TimePosition = 0
		stepSnd:Play()
	end
end

local DIRS = { Vector3.new(0, 1, 0) }
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	DIRS[#DIRS + 1] = Vector3.new(math.cos(a) * 0.84, 0.54, math.sin(a) * 0.84).Unit
end

local function getCache(ix, iz)
	local col = cellCache[ix]
	return col and col[iz]
end

local function setCache(ix, iz, data)
	local col = cellCache[ix]
	if not col then
		col = {}
		cellCache[ix] = col
	end
	col[iz] = data
end

local function applyCell(c, d)
	c.y, c.exposed, c.pending, c.stamp = d.y, d.exposed, false, d.stamp
	c.col.CFrame = CFrame.new(c.cx, d.base + 40, c.cz)
	c.floor.CFrame = CFrame.new(c.cx, d.base + 0.12, c.cz)
end

local function evalCell(c, camY)
	local o = Vector3.new(c.cx, camY + 2, c.cz)
	local ground = Workspace:Raycast(o, Vector3.new(0, -250, 0), rayParams)
	local y, exposed
	if ground then
		y = ground.Position.Y
		local roof = Workspace:Raycast(ground.Position + Vector3.new(0, 0.6, 0), Vector3.new(0, 150, 0), rayParams)
		exposed = not (roof and roof.Instance.Transparency < 0.9)
	else
		local roof = Workspace:Raycast(o, Vector3.new(0, 150, 0), rayParams)
		exposed = not (roof and roof.Instance.Transparency < 0.9)
	end
	local d = { y = y, exposed = exposed, stamp = os.clock(), base = y or (camY - 3) }
	setCache(c.wx, c.wz, d)
	applyCell(c, d)
end

local function cleanCache()
	local now = os.clock()
	for ix, col in pairs(cellCache) do
		local empty = true
		for iz, d in pairs(col) do
			if now - d.stamp > 60 then
				col[iz] = nil
			else
				empty = false
			end
		end
		if empty then
			cellCache[ix] = nil
		end
	end
end

local function stabilizeAtmosphere()
	if not S.visualOn then
		return
	end
	if atm and atmOwned then
		for _, inst in ipairs(Lighting:GetChildren()) do
			if inst:IsA("Atmosphere") and inst ~= atm then
				atm:Destroy()
				atm, atmOwned = inst, false
				atmBackup = backup(inst, { "Density", "Offset", "Color", "Decay", "Glare", "Haze" })
				break
			end
		end
	end
	if clouds and cloudsOwned and terrain then
		for _, inst in ipairs(terrain:GetChildren()) do
			if inst:IsA("Clouds") and inst ~= clouds then
				clouds:Destroy()
				clouds, cloudsOwned = inst, false
				cloudsBackup = backup(inst, { "Cover", "Density", "Color", "Enabled" })
				break
			end
		end
	end
end

connect(Lighting.ChildAdded, function(inst)
	if not S.visualOn or inst.Name:sub(1, 3) == "ws_" then
		return
	end
	for _, cls in ipairs(OTHER_EFFECTS) do
		if inst:IsA(cls) then
			task.defer(function()
				if inst.Parent and inst.Enabled then
					disabledOthers[#disabledOthers + 1] = inst
					inst.Enabled = false
				end
			end)
		end
	end
end)

local function slowUpdate(dt, cam, pos, q, strength)
	local storm = math.clamp(cur.rain - 1, 0, 1)
	local baseLevel = cur.rain * strength
	local level = cfg.rain and math.min(baseLevel, 3) or 0
	local windLevel = cur.wind * strength
	local accel = Vector3.new(S.windVec.X * 0.6, -40, S.windVec.Z * 0.6)

	for _, c in ipairs(grid) do
		if math.abs(c.storm - storm) > 0.05 then
			rainStyle(c, storm)
		end
		local active = c.exposed and level > 0.03
		local r = active and 0.09 * c.area * q.rain * level or 0
		c.em.Rate = r
		c.em.Acceleration = accel
		c.em.Enabled = r > 0.5
		local rr = (active and c.y) and 0.12 * c.area * q.rain * level or 0
		local rd = (active and c.y) and 0.08 * c.area * q.rain * level or 0
		c.ripples.Rate, c.ripples.Enabled = rr, rr > 1
		c.drops.Rate, c.drops.Enabled = rd, rd > 1
	end

	if cfg.wind then
		local v = math.max(S.windSpeed, 5)
		windLeaves.Speed = NumberRange.new(v * 0.85, v * 1.1)
		windPollen.Speed = NumberRange.new(v * 0.8, v * 1.05)
		local rl = (6 + 14 * cur.wind) * q.wind * math.clamp(strength, 0.4, 1.5)
		local rp = (10 + 18 * cur.wind) * q.wind * math.clamp(strength, 0.4, 1.5)
		windLeaves.Rate, windLeaves.Enabled = rl, rl > 0.5
		windPollen.Rate, windPollen.Enabled = rp, rp > 0.5
	else
		windLeaves.Enabled, windPollen.Enabled = false, false
	end

	local nearest, best = nil, math.huge
	if root then
		for _, c in ipairs(grid) do
			local d = (c.cx - root.Position.X) ^ 2 + (c.cz - root.Position.Z) ^ 2
			if d < best then
				best, nearest = d, c
			end
		end
	end
	S.floorExposed = nearest ~= nil and nearest.exposed

	local dropRate, rippleRate = 0, 0
	local rainingHere = cfg.rain and level > 0.1 and S.floorExposed
	if cfg.footSplash and rainingHere and hum and root and hum.FloorMaterial ~= Enum.Material.Air then
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed > 2 then
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rayParams)
			if hit then
				footPart.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.1, 0))
				local wetF = 0.45 + 0.55 * S.wetness
				local f = math.clamp(speed / 16, 0, 1.6) * wetF * math.min(level, 1.5) * q.rain
				dropRate, rippleRate = 70 * f, 12 * f
				S.stepTimer -= dt
				if S.stepOk and cfg.stepSound and S.stepTimer <= 0 then
					S.stepTimer = math.clamp(0.62 - speed * 0.02, 0.3, 0.6)
					playStep(wetF)
				end
			end
		else
			S.stepTimer = 0
		end
	else
		S.stepTimer = 0
	end
	footDrops.Rate, footDrops.Enabled = dropRate, dropRate > 1
	footRipples.Rate, footRipples.Enabled = rippleRate, rippleRate > 1

	updateGround(dt, level, pos, q)

	if level > 0.15 then
		S.puddleLevel = math.min(1, S.puddleLevel + dt / (level > 1.3 and 12 or 22))
		S.dryTimer = 0
	else
		S.dryTimer += dt
		if S.dryTimer > 8 then
			S.puddleLevel = math.max(0, S.puddleLevel - dt / 25)
		end
	end
	updatePuddles(dt, pos)

	updateSounds(dt, baseLevel, windLevel)
	screenDrops.level = (cfg.rain and cfg.screenDrops) and math.min(baseLevel, 1.2) * (1 - S.muffle) or 0

	if cfg.lights and cfg.shaders then
		local night = 1 - S.dayFactor
		S.lightsOn = true
		applyLights(pos, lerp(1.1, 1.4, night), lerp(1.05, 1.25, night), S.futureOn and cfg.quality >= 3, 120)
	elseif S.lightsOn then
		S.lightsOn = false
		restoreLights()
	end

	if cfg.waterFx and cfg.shaders then
		S.waterTimer -= dt
		if S.waterTimer <= 0 then
			S.waterTimer = 1.5
			applyWater(S.dayFactor, windLevel)
		end
		S.waterScanTimer -= dt
		if S.waterScanTimer <= 0 then
			S.waterScanTimer = 12
			scanWaterParts(pos)
		end
	elseif S.waterApplied or next(waterParts) then
		restoreWater()
	end

	S.cleanTimer += dt
	if S.cleanTimer > 30 then
		S.cleanTimer = 0
		cleanCache()
	end
	S.stabilizeTimer += dt
	if S.stabilizeTimer > 2 then
		S.stabilizeTimer = 0
		stabilizeAtmosphere()
	end
end

local function updateTrails(dt, pos)
	if #trails == 0 then
		return
	end
	local side = Vector3.new(-S.windDir.Z, 0, S.windDir.X)
	local speed = math.max(S.windSpeed, 5)
	for _, t in ipairs(trails) do
		if t.hold > 0 then
			t.hold -= 1
			if t.hold == 0 then
				t.trail:Clear()
				t.trail.Enabled = true
			end
		end
		t.base += S.windDir * speed * 0.9 * dt
		local rel = t.base - pos
		if t.fresh or rel:Dot(S.windDir) > 75 or rel.Magnitude > 110 then
			t.fresh = false
			t.base = pos - S.windDir * (30 + math.random() * 40) + side * ((math.random() - 0.5) * 70) + Vector3.new(0, math.random() * 14 - 2, 0)
			t.phase = math.random() * 6.28
			t.freq = 0.8 + math.random() * 0.9
			t.amp = 1.2 + math.random() * 2.4
			t.trail.Enabled = false
			t.hold = 2
		end
		local w = S.clock * t.freq + t.phase
		t.part.CFrame = CFrame.new(t.base + side * (math.sin(w) * t.amp) + Vector3.new(0, math.cos(w * 0.7) * t.amp * 0.6, 0))
	end
end

local function updateEnvironment(dt)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	ensureParts(cam)
	if not root or not root.Parent then
		refreshChar()
	end
	local q = Q[cfg.quality]
	local strength = math.clamp(cfg.strength, 0, 1.5)
	local pos = cam.CFrame.Position

	local ang = math.noise(S.clock * 0.02, 11.3) * 6.28 + 0.8
	local g1 = math.noise(S.clock * 0.35, 4.1)
	local g2 = math.noise(S.clock * 0.9, 8.7)
	local gust = math.clamp(0.85 + g1 * 1.1 + g2 * 0.45, 0.55, 1.6)
	S.windSpeed = cur.wind * strength * gust * 24
	S.windDir = Vector3.new(math.cos(ang), 0, math.sin(ang))
	S.windVec = S.windDir * S.windSpeed

	if cfg.wind then
		pcall(function()
			Workspace.GlobalWind = S.windVec
		end)
		local wp = pos + Vector3.new(0, 8, 0)
		windPart.CFrame = CFrame.lookAt(wp, wp + S.windDir)
		updateTrails(dt, pos)
	else
		for _, t in ipairs(trails) do
			t.trail.Enabled = false
			t.fresh = true
		end
		if orig.GlobalWind then
			pcall(function()
				Workspace.GlobalWind = orig.GlobalWind
			end)
		end
	end

	local ix = math.floor(pos.X / gridSize + 0.5)
	local iz = math.floor(pos.Z / gridSize + 0.5)
	if ix ~= gridIx or iz ~= gridIz then
		gridIx, gridIz = ix, iz
		for _, c in ipairs(grid) do
			c.wx, c.wz = ix + c.di, iz + c.dj
			c.cx, c.cz = c.wx * gridSize, c.wz * gridSize
			local d = getCache(c.wx, c.wz)
			if d then
				applyCell(c, d)
			else
				c.pending, c.exposed = true, false
			end
		end
	end

	local n = #grid
	local budget = 4
	local now = os.clock()
	for _ = 1, n do
		if budget <= 0 then
			break
		end
		S.cellCursor = S.cellCursor % n + 1
		local c = grid[S.cellCursor]
		if c.pending or now - c.stamp > 6 then
			evalCell(c, pos.Y)
			budget -= 1
		end
	end

	S.muffleTimer -= dt
	if S.muffleTimer <= 0 then
		S.muffleTimer = 0.5
		setFilter(cam)
		local blocked = 0
		for _, d in ipairs(DIRS) do
			local h = Workspace:Raycast(pos, d * 60, rayParams)
			if h and h.Instance.Transparency < 0.9 then
				blocked += 1
			end
		end
		S.muffleTarget = blocked / #DIRS
	end
	S.muffle += (S.muffleTarget - S.muffle) * (1 - math.exp(-dt * 3))

	updateSun(dt, cam)
	updateShafts(dt, cam, root)
	updateReflections(dt, cam, q)

	S.slowAccum += dt
	if S.slowAccum >= 0.1 then
		local sdt = S.slowAccum
		S.slowAccum = 0
		slowUpdate(sdt, cam, pos, q, strength)
	end
end

local function updateVisual(dt)
	local light = cfg.light
	local strength = math.clamp(cfg.strength, 0, 1.5)
	local q = Q[cfg.quality]

	if cfg.manualTime then
		S.touchedTime = true
		setp(Lighting, "ClockTime", cfg.hour)
	end

	if cfg.shadows then
		setp(Lighting, "GlobalShadows", true)
		pcall(function()
			setp(Lighting, "ShadowSoftness", q.soft)
		end)
		setTechnology(cfg.shaders and q.future)
	else
		setp(Lighting, "GlobalShadows", false)
		setTechnology(false)
	end

	if not cfg.shaders then
		exitVisual()
		sun.f = 0
		shafts.I = 0
		return
	end
	if not S.visualOn then
		enterVisual()
	end

	local sinE = math.sin((Lighting.ClockTime - 6) / 12 * math.pi)
	local day = math.clamp((sinE + 0.05) / 0.3, 0, 1)
	S.dayFactor = day
	local warm = (1 - math.clamp(sinE * 2.2, 0, 1)) * day * math.clamp(cur.sun, 0, 1)
	local f = sun.facing * (1 - 0.88 * sun.occ) * math.clamp(cur.sun, 0, 1) * day
	sun.f = f
	shafts.I = math.clamp(cur.sun, 0, 1) * day
	shafts.color = Color3.fromRGB(255, 236, 195):Lerp(COL.sunLow, warm * 0.6)

	if cfg.lightning and cur.rain > 1.2 and os.clock() > S.nextBolt then
		S.flash = 0.7
		S.nextBolt = os.clock() + math.random(8, 22)
		task.delay(0.25, function()
			S.flash = math.max(S.flash, 0.35)
		end)
	end
	S.flash = math.max(0, S.flash - dt * 2.2)

	setp(Lighting, "Brightness", lerp(orig.Brightness or 2, cur.brightness * light, day))
	setp(Lighting, "ExposureCompensation", lerp(orig.ExposureCompensation or 0, cur.exposure * light + f * 0.05, day) + S.flash * 0.7)
	setp(Lighting, "Ambient", (orig.Ambient or cur.ambient):Lerp(cur.ambient, day))
	setp(Lighting, "OutdoorAmbient", (orig.OutdoorAmbient or cur.outdoor):Lerp(cur.outdoor, day))
	setp(Lighting, "ColorShift_Top", (orig.ColorShift_Top or Color3.new()):Lerp(cur.shiftTop:Lerp(COL.sunLow, warm * 0.6), day))
	setp(Lighting, "ColorShift_Bottom", (orig.ColorShift_Bottom or Color3.new()):Lerp(cur.shiftBottom, day))
	if cfg.quality >= 2 then
		setp(Lighting, "EnvironmentDiffuseScale", 1)
		setp(Lighting, "EnvironmentSpecularScale", 1)
	end

	if sky and skySunSize then
		setp(sky, "SunAngularSize", lerp(skySunSize, skySunSize * 1.3, math.clamp(cur.sun, 0, 1)))
	end

	if atm then
		local fog = (0.4 + 0.6 * strength) * (cfg.fog and 1 or 0.3)
		atm.Density = math.clamp(cur.atmDensity * fog, 0, 0.8)
		atm.Offset = cur.atmOffset
		atm.Haze = cur.atmHaze * (0.4 + 0.6 * strength) * (1 + warm * 0.4)
		atm.Glare = math.min(1, cur.atmGlare * day * (1 + f * 0.6))
		atm.Color = COL.airNight:Lerp(cur.atmColor:Lerp(COL.dawnAir, warm * 0.35), day)
		atm.Decay = COL.decayNight:Lerp(cur.atmDecay:Lerp(COL.decayLow, warm * 0.7), day)
	end

	if clouds then
		setp(clouds, "Enabled", true)
		clouds.Cover = math.clamp(cur.cloudCover * (0.5 + 0.5 * strength), 0, 1)
		clouds.Density = cur.cloudDensity
		clouds.Color = COL.cloudNight:Lerp(cur.cloudColor:Lerp(COL.cloudSunset, warm * 0.5), day)
	end

	bloom.Intensity = cur.bloom * light + (1 - day) * 0.12 + S.flash * 0.4 + f * 0.4
	bloom.Size = 24 + f * 14
	bloom.Threshold = 1.6 - f * 0.3
	cc.Saturation = cur.ccSat * light
	cc.Contrast = cur.ccContrast * light
	cc.Brightness = cur.ccBright + S.flash * 0.06 + f * 0.015
	cc.TintColor = cur.ccTint:Lerp(COL.sunStrong, f * 0.3)

	setp(sunRays, "Enabled", q.rays)
	sunRays.Intensity = (cur.rays * (1 + warm * 0.8) + f * 0.3) * light * day
	sunRays.Spread = 0.75 + 0.2 * f

	setp(dofEffect, "Enabled", cfg.dof and q.dof)
	dofEffect.FarIntensity = 0.12 + 0.1 * math.clamp(cur.atmDensity, 0, 0.6)
end

local function restoreAll()
	exitVisual()
	sun.f = 0
	shafts.I = 0
	for _, k in ipairs(SHADOW_PROPS) do
		if orig[k] ~= nil then
			pcall(function()
				Lighting[k] = orig[k]
			end)
		end
	end
	setTechnology(false)
	if S.touchedTime and orig.ClockTime then
		pcall(function()
			Lighting.ClockTime = orig.ClockTime
		end)
		S.touchedTime = false
	end
	if orig.GlobalWind then
		pcall(function()
			Workspace.GlobalWind = orig.GlobalWind
		end)
	end
	hideWeatherFx()
	hideReflections()
	restoreWater()
	restoreLights()
	dryAll()
	S.puddleLevel, S.dryTimer = 0, 0
	screenDrops.level = 0
	sound.Volume = 0
	windSnd.Volume = 0
	for _, s in ipairs({ sound, windSnd, stepSnd }) do
		if s.IsPlaying then
			s:Stop()
		end
	end
end

local function step(dt)
	S.clock += dt
	if S.dirty and os.clock() - S.lastTouch > 1.5 then
		saveConfig()
	end
	if not cfg.master then
		if not S.restored then
			restoreAll()
			S.restored = true
		end
	else
		S.restored = false
		S.currentWeather = pickWeather(dt)
		updateEnvironment(dt)
		S.accum += dt
		if S.accum >= 0.05 then
			blend(cur, weathers[S.currentWeather], 1 - math.exp(-S.accum * 0.4))
			updateVisual(S.accum)
			S.accum = 0
		end
	end
	if flare.update then
		flare.update()
	end
	if screenDrops.update then
		screenDrops.update(dt)
	end
end

connect(RunService.RenderStepped, function(dt)
	local ok, err = pcall(step, dt)
	if not ok then
		warn("westshaders: " .. tostring(err))
	end
end)

local function guiRoots()
	local list = {}
	local ok, h = pcall(function()
		return gethui()
	end)
	if ok and h then
		list[#list + 1] = h
	end
	pcall(function()
		list[#list + 1] = game:GetService("CoreGui")
	end)
	local pg = lp:FindFirstChildOfClass("PlayerGui")
	if pg then
		list[#list + 1] = pg
	end
	return list
end

local function newScreen(name, order)
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = order
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, g)
	end
	for _, r in ipairs(guiRoots()) do
		local ok = pcall(function()
			g.Parent = r
		end)
		if ok and g.Parent then
			break
		end
	end
	return g
end

local flareGui = newScreen("ws_glare", 5)
flareGui.Enabled = false

local glowItems = {}
local function disc(t, px, color, base)
	local f = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(px, px),
		BackgroundColor3 = color, BackgroundTransparency = 1, BorderSizePixel = 0,
	}, flareGui)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	glowItems[#glowItems + 1] = { frame = f, t = t, px = px, base = base }
end

local WARM_GLOW = Color3.fromRGB(255, 236, 200)
for i = 1, 14 do
	disc(0, 30 * (1.32 ^ (i - 1)), WARM_GLOW, 0.978)
end
local ghosts = {
	{ 0.55, 70, Color3.fromRGB(255, 205, 150) },
	{ 1.0, 38, Color3.fromRGB(170, 210, 255) },
	{ 1.45, 110, Color3.fromRGB(255, 190, 235) },
}
for _, g in ipairs(ghosts) do
	for k = 1, 4 do
		disc(g[1], g[2] * (0.5 + k * 0.25), g[3], 0.985)
	end
end

local streak = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(800, 4),
	BackgroundColor3 = WARM_GLOW, BackgroundTransparency = 1, BorderSizePixel = 0,
}, flareGui)
create("UIGradient", {
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
}, streak)

flare.update = function()
	local cam = Workspace.CurrentCamera
	local I = (cfg.master and cfg.shaders and cfg.flare) and sun.f or 0
	if not cam or I < 0.01 or not sun.visible then
		flareGui.Enabled = false
		return
	end
	local vp = cam.ViewportSize
	local center = vp / 2
	local p = sun.screen
	I *= 1 - math.clamp((p - center).Magnitude / (vp.Magnitude * 0.5), 0, 1) * 0.6
	flareGui.Enabled = true
	local scale = vp.Y / 900
	for _, e in ipairs(glowItems) do
		local pos = p + (center - p) * e.t
		local s = e.px * scale
		e.frame.Position = UDim2.fromOffset(pos.X, pos.Y)
		e.frame.Size = UDim2.fromOffset(s, s)
		e.frame.BackgroundTransparency = 1 - (1 - e.base) * I
	end
	streak.Position = UDim2.fromOffset(p.X, p.Y)
	streak.Size = UDim2.fromOffset(vp.X * 0.6, 3 * scale)
	streak.BackgroundTransparency = 1 - 0.07 * I
end

local dropsGui = newScreen("ws_drops", 4)
local dropPool = {}
for i = 1, 14 do
	local f = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), Visible = false,
		BackgroundColor3 = Color3.fromRGB(225, 235, 250), BackgroundTransparency = 1, BorderSizePixel = 0,
	}, dropsGui)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	local st = create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 1, Thickness = 1 }, f)
	dropPool[i] = { frame = f, stroke = st, alive = false, t = 0, life = 1, x = 0, y = 0, vy = 0, size = 8 }
end

screenDrops.update = function(dt)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local scale = vp.Y / 900
	local n = Q[cfg.quality].drops
	if cfg.master and screenDrops.level > 0.08 then
		S.dropAcc += dt * 1.8 * math.min(screenDrops.level, 1.2)
		while S.dropAcc >= 1 do
			S.dropAcc -= 1
			for i = 1, n do
				local d = dropPool[i]
				if not d.alive then
					d.alive = true
					d.t = 0
					d.life = 2.5 + math.random() * 2.5
					d.size = (6 + math.random() * 8) * scale
					d.x = math.random() * vp.X
					d.y = math.random() * vp.Y * 0.85
					d.vy = 0
					d.frame.Size = UDim2.fromOffset(d.size, d.size)
					d.frame.Visible = true
					break
				end
			end
		end
	else
		S.dropAcc = 0
	end
	for i = 1, #dropPool do
		local d = dropPool[i]
		if d.alive then
			d.t += dt
			local k = d.t / d.life
			if k >= 1 or not cfg.master then
				d.alive = false
				d.frame.Visible = false
			else
				local a = math.min(k / 0.12, 1) * (1 - math.clamp((k - 0.55) / 0.45, 0, 1))
				d.vy += dt * 14 * k * scale
				d.y += d.vy * dt
				d.frame.Position = UDim2.fromOffset(d.x, d.y)
				d.frame.BackgroundTransparency = 1 - 0.14 * a
				d.stroke.Transparency = 1 - 0.5 * a
			end
		end
	end
end

local okLib, WindUI = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

local Window
local menuGuis = {}

local function notify(text)
	if okLib and WindUI then
		local ok = pcall(function()
			WindUI:Notify({ Title = BRAND, Content = text, Duration = 5 })
		end)
		if ok then
			return
		end
	end
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = BRAND, Text = text, Duration = 5 })
	end)
end

local function loadFirst(snd, ids, minLen)
	for _, id in ipairs(ids) do
		snd.SoundId = id
		local t = os.clock()
		while not snd.IsLoaded and os.clock() - t < 4 do
			task.wait(0.1)
		end
		if snd.IsLoaded and snd.TimeLength > minLen then
			return true
		end
	end
	snd.SoundId = ""
	return false
end

local function loadSounds()
	task.spawn(function()
		S.soundOk = loadFirst(sound, RAIN_SOUNDS, 3)
		if not S.soundOk then
			notify(T("no_sound"))
		end
	end)
	task.spawn(function()
		S.windOk = loadFirst(windSnd, WIND_SOUNDS, 3)
	end)
	task.spawn(function()
		S.stepOk = loadFirst(stepSnd, STEP_SOUNDS, 0.05)
	end)
end

local iconGui
local unload

local function removeOpenPill()
	pcall(function()
		Window:EditOpenButton({ Enabled = false })
	end)
	for _, g in ipairs(menuGuis) do
		for _, d in ipairs(g:GetDescendants()) do
			if d.Name:lower():find("openbutton", 1, true) then
				pcall(function()
					d:Destroy()
				end)
			end
		end
	end
end

local function buildMenu()
	local before = {}
	for _, r in ipairs(guiRoots()) do
		for _, g in ipairs(r:GetChildren()) do
			before[g] = true
		end
	end

	local pending = true
	local function changed()
		if not pending then
			markDirty()
		end
	end

	Window = WindUI:CreateWindow({
		Title = BRAND,
		Icon = "sun",
		Author = "shaders, weather & rain",
		Folder = "WestShaders",
		Size = UDim2.fromOffset(580, 460),
		Theme = "Dark",
	})

	local function toggle(section, title, desc, key)
		section:Toggle({
			Title = title,
			Desc = desc,
			Value = cfg[key],
			Callback = function(v)
				cfg[key] = v
				changed()
			end,
		})
	end

	local function slider(section, title, key, min, max, scale)
		section:Slider({
			Title = title,
			Step = 1,
			Value = { Min = min, Max = max, Default = math.floor(cfg[key] * scale + 0.5) },
			Callback = function(v)
				cfg[key] = v / scale
				changed()
			end,
		})
	end

	local weatherIds = { "auto", "sunny", "cloudy", "rainy", "storm" }
	local weatherLabels, labelToId, idToLabel = {}, {}, {}
	for _, id in ipairs(weatherIds) do
		local label = T("w_" .. id)
		weatherLabels[#weatherLabels + 1] = label
		labelToId[label] = id
		idToLabel[id] = label
	end

	local tabWeather = Window:Tab({ Title = T("tab_weather"), Icon = "cloud-rain" })
	local secSky = tabWeather:Section({ Title = T("sec_sky") })
	secSky:Dropdown({
		Title = T("weather"),
		Values = weatherLabels,
		Value = idToLabel[cfg.mode],
		Callback = function(v)
			cfg.mode = labelToId[v] or "auto"
			changed()
		end,
	})
	slider(secSky, T("strength"), "strength", 0, 150, 100)

	local secRain = tabWeather:Section({ Title = T("sec_rain") })
	toggle(secRain, T("rain"), T("rain_d"), "rain")
	toggle(secRain, T("rain_sound"), T("rain_sound_d"), "rainSound")
	toggle(secRain, T("wet"), T("wet_d"), "wetGround")
	toggle(secRain, T("feet"), T("feet_d"), "footSplash")
	toggle(secRain, T("step_sound"), T("step_sound_d"), "stepSound")
	toggle(secRain, T("screen_drops"), T("screen_drops_d"), "screenDrops")
	toggle(secRain, T("lightning"), T("lightning_d"), "lightning")
	slider(secRain, T("volume"), "volume", 0, 100, 100)

	local secAir = tabWeather:Section({ Title = T("sec_air") })
	toggle(secAir, T("wind"), T("wind_d"), "wind")
	toggle(secAir, T("wind_sound"), T("wind_sound_d"), "windSound")
	toggle(secAir, T("fog"), T("fog_d"), "fog")

	local tabLight = Window:Tab({ Title = T("tab_light"), Icon = "sun" })
	local secLight = tabLight:Section({ Title = T("sec_light") })
	toggle(secLight, T("shaders"), T("shaders_d"), "shaders")
	toggle(secLight, T("flare"), T("flare_d"), "flare")
	toggle(secLight, T("shafts"), T("shafts_d"), "shafts")
	toggle(secLight, T("shadows"), nil, "shadows")
	toggle(secLight, T("lights"), T("lights_d"), "lights")
	toggle(secLight, T("water"), T("water_d"), "waterFx")
	toggle(secLight, T("dof"), T("dof_d"), "dof")
	slider(secLight, T("light"), "light", 30, 150, 100)

	local secTime = tabLight:Section({ Title = T("sec_time") })
	toggle(secTime, T("manual_time"), nil, "manualTime")
	slider(secTime, T("hour"), "hour", 0, 24, 1)

	local tabGeneral = Window:Tab({ Title = T("tab_general"), Icon = "settings" })
	local okP = pcall(function()
		tabGeneral:Paragraph({ Title = BRAND, Desc = T("disclaimer") })
	end)
	if not okP then
		tabGeneral:Section({ Title = T("disclaimer") })
	end

	local qualityLabels = { T("q1"), T("q2"), T("q3") }
	local secPerf = tabGeneral:Section({ Title = T("sec_perf") })
	secPerf:Dropdown({
		Title = T("quality"),
		Values = qualityLabels,
		Value = qualityLabels[cfg.quality],
		Callback = function(v)
			for i, n in ipairs(qualityLabels) do
				if n == v then
					cfg.quality = i
				end
			end
			changed()
		end,
	})

	local secFx = tabGeneral:Section({ Title = T("sec_fx") })
	secFx:Button({
		Title = T("restore"),
		Desc = T("restore_d"),
		Callback = function()
			cfg.master = false
			restoreAll()
			S.restored = true
			notify(T("fx_off"))
		end,
	})
	secFx:Button({
		Title = T("enable"),
		Callback = function()
			cfg.master = true
			notify(T("fx_on"))
		end,
	})

	local secCfg = tabGeneral:Section({ Title = T("sec_cfg") })
	secCfg:Button({
		Title = T("save"),
		Desc = T("save_d"),
		Callback = function()
			if writefile and saveConfig() then
				notify(T("save_ok") .. FILE)
			else
				notify(T("save_fail"))
			end
		end,
	})
	secCfg:Button({
		Title = T("delete"),
		Callback = function()
			local ok = delfile and pcall(function()
				delfile(FILE)
			end)
			notify(ok and T("deleted") or T("nothing"))
		end,
	})
	secCfg:Button({
		Title = T("unload"),
		Callback = function()
			unload()
		end,
	})

	pending = false

	table.clear(menuGuis)
	for _, r in ipairs(guiRoots()) do
		for _, g in ipairs(r:GetChildren()) do
			if not before[g] and g:IsA("ScreenGui") and not g.Name:lower():find("notif") then
				menuGuis[#menuGuis + 1] = g
			end
		end
	end
	removeOpenPill()
end

local function toggleMenu()
	if not (okLib and WindUI) then
		return
	end
	if Window and menuGuis[1] and menuGuis[1].Parent then
		local ok = pcall(function()
			Window:Toggle()
		end)
		if not ok then
			local show = not menuGuis[1].Enabled
			for _, g in ipairs(menuGuis) do
				g.Enabled = show
			end
		end
		return
	end
	if Window and #menuGuis == 0 then
		pcall(function()
			Window:Toggle()
		end)
		return
	end
	Window = nil
	local ok, err = pcall(buildMenu)
	if not ok then
		warn("westshaders: " .. tostring(err))
	end
end

unload = function()
	if S.dirty then
		saveConfig()
	end
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(conns)
	pcall(restoreAll)
	pcall(clearReflections)
	clearParts()
	for _, o in ipairs({ bloom, cc, sunRays, dofEffect, sound, windSnd, stepSnd, flareGui, dropsGui, iconGui }) do
		if o then
			pcall(function()
				o:Destroy()
			end)
		end
	end
	for _, g in ipairs(menuGuis) do
		pcall(function()
			g:Destroy()
		end)
	end
	if Window then
		pcall(function()
			Window:Destroy()
		end)
	end
	env.__westshaders = nil
end

env.__westshaders = { unload = unload, cfg = cfg }

local function buildSunIcon()
	iconGui = newScreen("ws_icon", 20)
	local holder = create("Frame", {
		Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, 14, 0.3, 0),
		BackgroundColor3 = Color3.fromRGB(20, 22, 30), BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}, iconGui)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, holder)
	create("UIStroke", { Color = Color3.fromRGB(255, 200, 80), Transparency = 0.5, Thickness = 1.5 }, holder)
	local core = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.fromRGB(255, 205, 70), BorderSizePixel = 0,
	}, holder)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, core)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(a) * 19, 0.5, -math.cos(a) * 19),
			Size = UDim2.fromOffset(3, 8), Rotation = i * 45,
			BackgroundColor3 = Color3.fromRGB(255, 205, 70), BorderSizePixel = 0,
		}, holder)
	end
	local hit = create("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
	}, holder)

	local dragging, startInput, startPos, moved = false, nil, nil, 0
	connect(hit.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, startInput, startPos, moved = true, i.Position, holder.Position, 0
		end
	end)
	connect(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = i.Position - startInput
			moved = math.max(moved, d.Magnitude)
			holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	connect(UserInputService.InputEnded, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = false
			if moved < 8 then
				toggleMenu()
			end
		end
	end)
end

if isMobile then
	buildSunIcon()
else
	connect(UserInputService.InputBegan, function(i, gpe)
		if not gpe and i.KeyCode == Enum.KeyCode.RightShift then
			toggleMenu()
		end
	end)
end

loadSounds()

task.spawn(function()
	notify(T("beta"))
	task.wait(5)
	notify(T("saved"))
	task.wait(5)
	notify(isMobile and T("open_mobile") or T("open_pc"))
end)

if not (writefile and readfile) then
	warn("westshaders: your executor has no writefile/readfile, settings will not be saved")
end
