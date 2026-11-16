local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
	waterApplied = false, reflTimer = 0, dropAcc = 0, metalTimer = 0, stepIdx = 1,
	snowCover = 0, lastSnow = 0, lastTW = 0, lastTS = 0, snowIdx = 1, snowOk = false,
	moundTimer = 0, shadowCount = 0, farCursor = 1,
	inNight = false, preNight = 12, returning = false, lastRain = 0, mistV = 0, wetHold = 0,
	thunderIdx = 1, thunderOk = false, nightOk = false, owlOk = false, owlTimer = 40,
	nightGate = false, nightTimer = 10, snowHold = 0,
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
	snow = Color3.fromRGB(243, 247, 252),
}

local N = {
	far = { cells = {}, n = 0, ix = nil, iz = nil },
	mounds = {}, prints = {}, printIdx = 1, trackers = {},
	WQ = { queue = {}, checked = {} },
	snowPool = {}, extra = {}, thunderPool = {},
	thunderIds = {
		"rbxassetid://9120018627",
		"rbxassetid://9120018695",
		"rbxassetid://9120021267",
		"rbxassetid://133426162",
		"rbxassetid://6128635929",
		"rbxassetid://1848269635",
	},
	owlIds = { "rbxassetid://9117182190" },
	nightIds = {
		"rbxassetid://7274920568",
		"rbxassetid://7274926294",
		"rbxassetid://138089070",
		"rbxassetid://183214531",
	},
	snowIds = {
		"rbxassetid://7965263099",
		"rbxassetid://7026435208",
		"rbxassetid://6540859678",
		"rbxassetid://7437372937",
		"rbxassetid://6175296453",
		"rbxassetid://332621136",
		"rbxassetid://1835852359",
	},
	tex = "rbxasset://textures/particles/smoke_main.dds",
	printParams = RaycastParams.new(),
}
N.printParams.FilterType = Enum.RaycastFilterType.Exclude
N.printParams.IgnoreWater = true

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
		w_night = "Pre-dawn",
		rain_mist = "Rain mist",
		rain_mist_d = "Occasional drifting mist during rain",
		rainbow = "Rainbow",
		rainbow_d = "A rainbow appears when rain gives way to sun",
		aurora = "Aurora borealis",
		aurora_d = "Moving northern lights in pre-dawn mode",
		night_sound = "Night sounds",
		night_sound_d = "Owls and crickets in pre-dawn mode",
		lightning_d = "Bolts and thunder during rain and storms",
		w_snow = "Snow",
		sec_snow = "Snow",
		snow = "Falling snow",
		snow_d = "Soft flakes fall from the sky in snow mode",
		snow_ground = "Snow on the ground",
		snow_ground_d = "Whitens exposed ground, builds snow drifts and footprints",
		shine = "Surface shine",
		shine_d = "Subtle reflections on metal, plastic and glass",
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
		w_night = "Madrugada",
		rain_mist = "Névoa de chuva",
		rain_mist_d = "Névoa que passa de vez em quando durante a chuva",
		rainbow = "Arco-íris",
		rainbow_d = "Um arco-íris aparece quando a chuva dá lugar ao sol",
		aurora = "Aurora boreal",
		aurora_d = "Luzes do norte em movimento no modo madrugada",
		night_sound = "Sons da madrugada",
		night_sound_d = "Corujas e grilos no modo madrugada",
		lightning_d = "Raios e trovões durante chuva e tempestades",
		w_snow = "Neve",
		sec_snow = "Neve",
		snow = "Neve caindo",
		snow_d = "Flocos suaves caem do céu no modo neve",
		snow_ground = "Neve no chão",
		snow_ground_d = "Deixa o chão exposto branco e forma montes de neve e pegadas",
		shine = "Brilho das superfícies",
		shine_d = "Reflexos sutis em metal, plástico e vidro",
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
		w_night = "Madrugada",
		rain_mist = "Neblina de lluvia",
		rain_mist_d = "Neblina que pasa de vez en cuando durante la lluvia",
		rainbow = "Arcoíris",
		rainbow_d = "Aparece un arcoíris cuando la lluvia da paso al sol",
		aurora = "Aurora boreal",
		aurora_d = "Luces del norte en movimiento en modo madrugada",
		night_sound = "Sonidos de madrugada",
		night_sound_d = "Búhos y grillos en modo madrugada",
		lightning_d = "Rayos y truenos durante lluvia y tormentas",
		w_snow = "Nieve",
		sec_snow = "Nieve",
		snow = "Nieve cayendo",
		snow_d = "Copos suaves caen del cielo en modo nieve",
		snow_ground = "Nieve en el suelo",
		snow_ground_d = "Blanquea el suelo expuesto y forma montones de nieve y huellas",
		shine = "Brillo de superficies",
		shine_d = "Reflejos sutiles en metal, plástico y vidrio",
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
		w_night = "Petit matin",
		rain_mist = "Brume de pluie",
		rain_mist_d = "Brume qui passe de temps en temps pendant la pluie",
		rainbow = "Arc-en-ciel",
		rainbow_d = "Un arc-en-ciel apparaît quand la pluie laisse place au soleil",
		aurora = "Aurore boréale",
		aurora_d = "Aurores boréales en mouvement en mode petit matin",
		night_sound = "Sons de la nuit",
		night_sound_d = "Hiboux et grillons en mode petit matin",
		lightning_d = "Éclairs et tonnerre pendant la pluie et les orages",
		w_snow = "Neige",
		sec_snow = "Neige",
		snow = "Chute de neige",
		snow_d = "De doux flocons tombent du ciel en mode neige",
		snow_ground = "Neige au sol",
		snow_ground_d = "Blanchit le sol exposé et forme des congères et des traces de pas",
		shine = "Brillance des surfaces",
		shine_d = "Reflets discrets sur le métal, le plastique et le verre",
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
		w_night = "Morgengrauen",
		rain_mist = "Regennebel",
		rain_mist_d = "Gelegentlich ziehender Nebel bei Regen",
		rainbow = "Regenbogen",
		rainbow_d = "Ein Regenbogen erscheint, wenn der Regen der Sonne weicht",
		aurora = "Polarlicht",
		aurora_d = "Bewegte Polarlichter im Morgengrauen-Modus",
		night_sound = "Nachtgeräusche",
		night_sound_d = "Eulen und Grillen im Morgengrauen-Modus",
		lightning_d = "Blitze und Donner bei Regen und Gewitter",
		w_snow = "Schnee",
		sec_snow = "Schnee",
		snow = "Schneefall",
		snow_d = "Sanfte Flocken fallen im Schneemodus vom Himmel",
		snow_ground = "Schnee am Boden",
		snow_ground_d = "Färbt freien Boden weiß und bildet Schneehaufen und Fußspuren",
		shine = "Oberflächenglanz",
		shine_d = "Dezente Spiegelungen auf Metall, Kunststoff und Glas",
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

local T
do
	local locale = "en"
	pcall(function()
		local id = game:GetService("LocalizationService").RobloxLocaleId
		if not id or id == "" then
			id = lp.LocaleId
		end
		locale = tostring(id):sub(1, 2):lower()
	end)
	local strings = LANGS[locale] or LANGS.en
	T = function(key)
		return strings[key] or LANGS.en[key] or key
	end
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
	metalShine = true,
	snow = true,
	snowGround = true,
	rainMist = true,
	rainbow = true,
	aurora = true,
	nightSound = true,
	manualTime = false,
	hour = 15,
	light = 1,
	strength = 1,
	volume = 0.6,
	mode = "auto",
	quality = 3,
}

local Q = {
	{ rain = 0.5, wind = 0.45, trails = 0, puddles = 0, mounds = 0, prints = 0, far = 3, dof = false, rays = false, future = false, soft = 0.2, n = 3, cell = 40, wet = 80, mist = 0, aurora = 0, shaftN = 0, shaftStep = 2, reflect = 0, drops = 6 },
	{ rain = 0.8, wind = 0.75, trails = 3, puddles = 1, mounds = 2, prints = 14, far = 5, dof = false, rays = true, future = false, soft = 0.45, n = 5, cell = 26, wet = 250, mist = 0.6, aurora = 4, shaftN = 9, shaftStep = 2.5, reflect = 1, drops = 10 },
	{ rain = 1, wind = 1, trails = 6, puddles = 2, mounds = 4, prints = 30, far = 7, dof = true, rays = true, future = true, soft = 0.7, n = 7, cell = 22, wet = 450, mist = 1, aurora = 7, shaftN = 13, shaftStep = 2, reflect = 4, drops = 14 },
}

local TYPES = {
	shaders = "boolean", shadows = "boolean", rain = "boolean", rainSound = "boolean",
	wetGround = "boolean", footSplash = "boolean", wind = "boolean", fog = "boolean",
	dof = "boolean", lightning = "boolean", flare = "boolean", shafts = "boolean", manualTime = "boolean",
	windSound = "boolean", stepSound = "boolean", lights = "boolean", waterFx = "boolean", screenDrops = "boolean", metalShine = "boolean", snow = "boolean", snowGround = "boolean", rainMist = "boolean", rainbow = "boolean", aurora = "boolean", nightSound = "boolean",
	hour = "number", light = "number", strength = "number", volume = "number", quality = "number",
	mode = "string",
}

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
	local MODES = { auto = true, sunny = true, cloudy = true, rainy = true, storm = true, snow = true, night = true }
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
		rain = 0, snow = 0, night = 0, wind = 0.55,
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
		rain = 0, snow = 0, night = 0, wind = 0.8,
	},
	rainy = {
		brightness = 1.4, exposure = -0.02, sun = 0,
		ambient = Color3.fromRGB(95, 104, 120), outdoor = Color3.fromRGB(108, 118, 135),
		shiftTop = Color3.fromRGB(205, 215, 230),
		shiftBottom = Color3.fromRGB(60, 66, 78),
		atmDensity = 0.52, atmOffset = 0, atmHaze = 2.6, atmGlare = 0,
		atmColor = Color3.fromRGB(172, 182, 198), atmDecay = Color3.fromRGB(150, 158, 172),
		bloom = 0.3, ccSat = -0.1, ccContrast = 0.12, ccBright = 0,
		ccTint = Color3.fromRGB(225, 232, 245),
		rays = 0, cloudCover = 0.82, cloudDensity = 0.55, cloudColor = Color3.fromRGB(178, 186, 200),
		rain = 1, snow = 0, night = 0, wind = 1.1,
	},
	storm = {
		brightness = 1.0, exposure = -0.1, sun = 0,
		ambient = Color3.fromRGB(80, 88, 105), outdoor = Color3.fromRGB(92, 102, 122),
		shiftTop = Color3.fromRGB(190, 200, 220),
		shiftBottom = Color3.fromRGB(50, 56, 70),
		atmDensity = 0.68, atmOffset = 0, atmHaze = 3.4, atmGlare = 0,
		atmColor = Color3.fromRGB(140, 150, 168), atmDecay = Color3.fromRGB(118, 126, 142),
		bloom = 0.28, ccSat = -0.14, ccContrast = 0.16, ccBright = -0.02,
		ccTint = Color3.fromRGB(215, 224, 240),
		rays = 0, cloudCover = 1, cloudDensity = 0.62, cloudColor = Color3.fromRGB(150, 158, 175),
		rain = 1.9, snow = 0, night = 0, wind = 1.8,
	},
	snow = {
		brightness = 1.9, exposure = 0.05, sun = 0.25,
		ambient = Color3.fromRGB(125, 135, 152), outdoor = Color3.fromRGB(150, 162, 180),
		shiftTop = Color3.fromRGB(225, 235, 250),
		shiftBottom = Color3.fromRGB(110, 122, 142),
		atmDensity = 0.55, atmOffset = 0, atmHaze = 3.0, atmGlare = 0.05,
		atmColor = Color3.fromRGB(208, 218, 232), atmDecay = Color3.fromRGB(190, 200, 214),
		bloom = 0.4, ccSat = -0.18, ccContrast = 0.08, ccBright = 0.01,
		ccTint = Color3.fromRGB(232, 240, 252),
		rays = 0.04, cloudCover = 0.9, cloudDensity = 0.45, cloudColor = Color3.fromRGB(218, 225, 236),
		rain = 0, snow = 1, night = 0, wind = 0.7,
	},
	night = {
		brightness = 1.4, exposure = 0.3, sun = 0,
		ambient = Color3.fromRGB(85, 105, 155), outdoor = Color3.fromRGB(110, 135, 190),
		shiftTop = Color3.fromRGB(165, 190, 250),
		shiftBottom = Color3.fromRGB(55, 70, 105),
		atmDensity = 0.2, atmOffset = 0, atmHaze = 1.2, atmGlare = 0,
		atmColor = Color3.fromRGB(70, 95, 150), atmDecay = Color3.fromRGB(50, 62, 105),
		bloom = 0.6, ccSat = 0.1, ccContrast = 0.1, ccBright = 0.03,
		ccTint = Color3.fromRGB(225, 232, 255),
		rays = 0, cloudCover = 0.3, cloudDensity = 0.3, cloudColor = Color3.fromRGB(95, 110, 150),
		rain = 0, snow = 0, night = 1, wind = 0.3,
	},
}


N.night = {
	brightness = 1.5, exposure = 0.35,
	ambient = Color3.fromRGB(85, 105, 155), outdoor = Color3.fromRGB(110, 135, 190),
	shiftTop = Color3.fromRGB(165, 190, 250), shiftBottom = Color3.fromRGB(55, 70, 105),
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
		for _, b in ipairs(p.blobs) do
			b:Destroy()
		end
		p.emit:Destroy()
	end
	table.clear(puddles)
	for _, c in ipairs(N.far.cells) do
		c.col:Destroy()
	end
	N.far.cells = {}
	N.far.n, N.far.ix, N.far.iz = 0, nil, nil
	for _, m in ipairs(N.mounds) do
		for _, part in ipairs(m.lumps) do
			part:Destroy()
		end
	end
	table.clear(N.mounds)
	for _, pr in ipairs(N.prints) do
		pr.rim:Destroy()
		pr.dent:Destroy()
	end
	table.clear(N.prints)
	table.clear(N.trackers)
	for _, o in ipairs(N.extra) do
		o:Destroy()
	end
	table.clear(N.extra)
	N.bolt, N.aurora, N.rainbow, N.mist, N.mistPart = nil, nil, nil, nil, nil
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
	if windPart and windPart.Parent == cam and gridN == q.n and gridSize == q.cell and N.far.n == q.far then
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
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0.24) }),
		Lifetime = NumberRange.new(3, 4.5),
		Speed = NumberRange.new(5, 8), SpreadAngle = Vector2.new(14, 14),
		EmissionDirection = Enum.NormalId.Front,
		RotSpeed = NumberRange.new(-220, 220), Rotation = NumberRange.new(0, 360),
		LightInfluence = 0.8, LockedToPart = false,
	}, windPart)
	windPollen = create("ParticleEmitter", {
		Texture = TEX, Enabled = false, Rate = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 246, 215)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 0.06) }),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Front,
		RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360),
		LightEmission = 0.9, LightInfluence = 0.3, LockedToPart = false,
	}, windPart)

	for i = 1, q.trails do
		local part = emptyPart("ws_air", Vector3.new(0.2, 0.2, 0.2), cam)
		local a0 = create("Attachment", { Position = Vector3.new(0, 0.14, 0) }, part)
		local a1 = create("Attachment", { Position = Vector3.new(0, -0.14, 0) }, part)
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

	N.footPuff = create("ParticleEmitter", {
		Texture = N.tex, Enabled = false, Rate = 0,
		Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.1) }),
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0, 0.5, 0), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, LightInfluence = 0.9,
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
			local snow = create("ParticleEmitter", {
				Texture = N.tex, Enabled = false, Rate = 0,
				Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.08, 0.35), NumberSequenceKeypoint.new(0.9, 0.35), NumberSequenceKeypoint.new(1, 1) }),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2, 0.12), NumberSequenceKeypoint.new(1, 0.2, 0.12) }),
				Lifetime = NumberRange.new(8.5, 10), Speed = NumberRange.new(1, 3),
				Acceleration = Vector3.new(0, -6, 0), Drag = 1.4,
				EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(40, 40),
				RotSpeed = NumberRange.new(-40, 40), Rotation = NumberRange.new(0, 360),
				LightEmission = 0.15, LightInfluence = 0.9, LockedToPart = false,
			}, col)
			pcall(function()
				snow.WindAffectsDrag = true
			end)
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
				col = col, em = em, snow = snow, floor = floor, ripples = ripples, drops = drops,
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
		shafts.pool[i] = { holder = holder, a0 = a0, a1 = a1, layers = layers, motes = motes, alpha = 0, want = false, lastK = -1, len = 8, w = 2, center = Vector3.zero, miss = 0 }
	end

	N.mistPart = emptyPart("ws_mist", Vector3.new(140, 10, 140), cam)
	N.extra[#N.extra + 1] = N.mistPart
	N.mist = create("ParticleEmitter", {
		Texture = N.tex, Enabled = false, Rate = 0,
		Color = ColorSequence.new(Color3.fromRGB(196, 205, 218)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.9), NumberSequenceKeypoint.new(0.7, 0.92), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12, 7), NumberSequenceKeypoint.new(1, 24, 10) }),
		Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0, 0.6), NumberSequenceKeypoint.new(1, 0, 0.6) }),
		Lifetime = NumberRange.new(9, 14), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Front, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-5, 5),
		LightInfluence = 1, LockedToPart = false,
	}, N.mistPart)

	N.far.n = q.far
	if q.far > 0 then
		local mid = (q.far + 1) / 2
		for i = 1, q.far do
			for j = 1, q.far do
				local col = emptyPart("ws_rain_far", Vector3.new(96, 1, 96), cam)
				local em = create("ParticleEmitter", {
					Texture = TEX, Enabled = false, Rate = 0,
					Color = ColorSequence.new(Color3.fromRGB(215, 228, 248)),
					Transparency = NumberSequence.new(0.5), Size = NumberSequence.new(1.2),
					Squash = NumberSequence.new(-4),
					Lifetime = NumberRange.new(0.4, 0.46), Speed = NumberRange.new(130, 150),
					Acceleration = Vector3.new(0, -40, 0), EmissionDirection = Enum.NormalId.Bottom,
					SpreadAngle = Vector2.new(2, 2), LightEmission = 0.4, LightInfluence = 0.3,
					Orientation = Enum.ParticleOrientation.VelocityParallel, LockedToPart = false,
				}, col)
				N.far.cells[#N.far.cells + 1] = {
					col = col, em = em, di = i - mid, dj = j - mid, cx = 0, cz = 0,
					exposed = false, pending = true, stamp = 0, area = 96 * 96,
				}
			end
		end
	end

	for i = 1, q.mounds do
		local lumps = {}
		for b = 1, 6 do
			local part = create("Part", {
				Name = "ws_snowpile", Size = Vector3.new(2, 1, 2), Anchored = true, CanCollide = false,
				CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1, Locked = true,
				Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(244, 248, 253),
			}, cam)
			pcall(function()
				part.Material = Enum.Material.Snow
			end)
			create("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, part)
			lumps[b] = part
		end
		N.mounds[i] = { lumps = lumps, offs = {}, placed = false, pos = Vector3.zero, size = 3 }
	end

	for i = 1, q.prints do
		local function printPart(size, color)
			return create("Part", {
				Name = "ws_print", Shape = Enum.PartType.Cylinder, Size = size, Anchored = true, CanCollide = false,
				CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1, Locked = true,
				Material = Enum.Material.SmoothPlastic, Color = color,
			}, cam)
		end
		N.prints[i] = {
			rim = printPart(Vector3.new(0.05, 1.55, 0.9), Color3.fromRGB(250, 252, 255)),
			dent = printPart(Vector3.new(0.05, 1.2, 0.62), Color3.fromRGB(186, 201, 224)),
			t = 0, life = 1, alive = false,
		}
	end

	for i = 1, q.puddles do
		local blobs = {}
		for b = 1, 4 do
			blobs[b] = create("Part", {
				Name = "ws_puddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 3, 3),
				Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
				Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(30, 40, 52),
				Reflectance = 0.75, Transparency = 1, Locked = true,
			}, cam)
		end
		local emit = emptyPart("ws_puddle_fx", Vector3.new(2, 0.1, 2), cam)
		local ripples = create("ParticleEmitter", {
			Texture = TEX, Enabled = false, Rate = 0,
			Color = ColorSequence.new(Color3.fromRGB(235, 242, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 1.1) }),
			Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(0),
			EmissionDirection = Enum.NormalId.Top,
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			LightEmission = 0.4, LightInfluence = 0.6,
		}, emit)
		local splash = create("ParticleEmitter", {
			Texture = TEX, Enabled = false, Rate = 0,
			Color = ColorSequence.new(Color3.fromRGB(240, 247, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.9) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.03) }),
			Lifetime = NumberRange.new(0.2, 0.35), Speed = NumberRange.new(2, 4),
			Acceleration = Vector3.new(0, -30, 0), SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Top, LightEmission = 0.5, LightInfluence = 0.5,
		}, emit)
		puddles[i] = { blobs = blobs, offs = {}, emit = emit, ripples = ripples, splash = splash, size = 3, placed = false, pos = Vector3.zero }
	end
end

local function hideWeatherFx()
	for _, e in ipairs({ windLeaves, windPollen, footRipples, footDrops, N.footPuff }) do
		if e then
			e.Enabled = false
		end
	end
	for _, c in ipairs(grid) do
		c.em.Enabled = false
		c.ripples.Enabled = false
		c.drops.Enabled = false
		c.snow.Enabled = false
	end
	for _, c in ipairs(N.far.cells) do
		c.em.Enabled = false
	end
	for _, m in ipairs(N.mounds) do
		for _, part in ipairs(m.lumps) do
			part.Transparency = 1
		end
		m.placed = false
	end
	for _, pr in ipairs(N.prints) do
		pr.alive = false
		pr.rim.Transparency = 1
		pr.dent.Transparency = 1
	end
	if N.mist then
		N.mist.Enabled = false
	end
	if N.bolt then
		N.bolt.active = false
		for _, e in ipairs(N.bolt.beams) do
			e.beam.Enabled = false
		end
	end
	if N.aurora then
		N.aurora.shown = false
		for _, rb in ipairs(N.aurora.ribbons) do
			for _, layers in ipairs(rb.segs) do
				for _, L in ipairs(layers) do
					L.beam.Enabled = false
				end
			end
		end
		for _, ry in ipairs(N.aurora.rays) do
			for _, L in ipairs(ry.layers) do
				L.beam.Enabled = false
			end
		end
	end
	if N.rainbow then
		N.rainbow.active = false
		for _, band in ipairs(N.rainbow.bands) do
			for _, e in ipairs(band.beams) do
				e.beam.Enabled = false
			end
		end
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
		for _, b in ipairs(p.blobs) do
			b.Transparency = 1
		end
		p.ripples.Enabled = false
		p.splash.Enabled = false
		p.placed = false
	end
end

local sound = create("Sound", { Name = "ws_rain_sound", Looped = true, Volume = 0 }, SoundService)
local eq = create("EqualizerSoundEffect", {}, sound)
local windSnd = create("Sound", { Name = "ws_wind_sound", Looped = true, Volume = 0 }, SoundService)
local windEq = create("EqualizerSoundEffect", {}, windSnd)
local stepSnd = create("Sound", { Name = "ws_step_sound", Volume = 0.3 }, SoundService)
N.snowSnd = create("Sound", { Name = "ws_snow_step", Volume = 0 }, SoundService)
N.nightSnd = create("Sound", { Name = "ws_night", Looped = true, Volume = 0 }, SoundService)
N.owlSnd = create("Sound", { Name = "ws_owl", Volume = 0 }, SoundService)
N.thunderTemplate = create("Sound", { Name = "ws_thunder", Volume = 0 }, SoundService)

local metalParts = {}
local shineMats = {}
do
	local SHINE = { Metal = 0.12, DiamondPlate = 0.1, Foil = 0.18, CorrodedMetal = 0.06, Marble = 0.04, Granite = 0.02, Glass = 0.05, Plastic = 0.02, SmoothPlastic = 0.03, Concrete = 0.012, Asphalt = 0.015, Pavement = 0.012, Brick = 0.01, Cobblestone = 0.012, Slate = 0.015, WoodPlanks = 0.01, Wood = 0.008, Ice = 0.08, Glacier = 0.08 }
	for n, v in pairs(SHINE) do
		local ok, m = pcall(function()
			return Enum.Material[n]
		end)
		if ok and m then
			shineMats[m] = v
		end
	end
end

function N.nearParts(origin, radius)
	local list = Workspace:GetPartBoundsInRadius(origin, radius, overlap)
	local rc = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if rc and (rc.Position - origin).Magnitude > 30 then
		for _, p in ipairs(Workspace:GetPartBoundsInRadius(rc.Position, radius, overlap)) do
			list[#list + 1] = p
		end
	end
	return list
end

local function scanMetal(origin, limit)
	overlap.FilterDescendantsInstances = lp.Character and { lp.Character } or {}
	local fresh, n = {}, 0
	for _, p in ipairs(N.nearParts(origin, 130)) do
		if n >= limit then
			break
		end
		if p.Anchored and p.Transparency < 0.9 and shineMats[p.Material] and p.Name:sub(1, 3) ~= "ws_" and not fresh[p] then
			fresh[p] = true
			n += 1
		end
	end
	for p, d in pairs(metalParts) do
		if not fresh[p] then
			if p.Parent then
				p.Reflectance = d
			end
			metalParts[p] = nil
		end
	end
	for p in pairs(fresh) do
		if not metalParts[p] then
			local want = shineMats[p.Material]
			if p.Reflectance < want then
				metalParts[p] = p.Reflectance
				p.Reflectance = want
			end
		end
	end
end

local function restoreMetal()
	for p, d in pairs(metalParts) do
		if p.Parent then
			p.Reflectance = d
		end
	end
	table.clear(metalParts)
end

local wetParts = {}
local wetMaterials, terrainColors = {}, {}

do
	local wetSkip = { Glass = true, ForceField = true, Neon = true, Water = true, Air = true }
	for _, m in ipairs(Enum.Material:GetEnumItems()) do
		if not wetSkip[m.Name] then
			wetMaterials[m] = true
		end
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

function N.tint(c)
	return c:Lerp(darken(c), S.wetness * 0.75):Lerp(COL.snow, S.snowCover * 0.9)
end

local function wetten(p, d)
	local col = d.color:Lerp(darken(d.color), S.wetness * 0.75)
	if d.flat then
		col = col:Lerp(COL.snow, S.snowCover * 0.92)
		if S.snowCover > 0.5 and not d.snowMat then
			d.snowMat = true
			pcall(function()
				p.Material = Enum.Material.Snow
			end)
		elseif S.snowCover < 0.35 and d.snowMat then
			d.snowMat = false
			p.Material = d.mat
		end
	end
	p.Color = col
	p.Reflectance = math.max(d.refl, S.wetness * 0.18 * (1 - S.snowCover))
end

local function dryAll()
	for p, d in pairs(wetParts) do
		if p.Parent then
			p.Color = d.color
			p.Reflectance = d.refl
			if d.snowMat then
				p.Material = d.mat
			end
		end
	end
	table.clear(wetParts)
	table.clear(N.WQ.queue)
	table.clear(N.WQ.checked)
	if terrain then
		for m, c in pairs(terrainColors) do
			pcall(terrain.SetMaterialColor, terrain, m, c)
		end
	end
	S.wetness, S.lastWetness, S.snowCover, S.lastSnow, S.lastTW, S.lastTS = 0, 0, 0, 0, 0, 0
end

local function scanWet(origin, limit)
	S.lastWetScan, S.wetOrigin = os.clock(), origin
	overlap.FilterDescendantsInstances = lp.Character and { lp.Character } or {}
	local fresh, n = {}, 0
	for _, p in ipairs(N.nearParts(origin, 120)) do
		if n >= limit then
			break
		end
		if p.Anchored and p.Transparency < 0.4 and wetMaterials[p.Material] and p.Name:sub(1, 3) ~= "ws_" and not fresh[p] then
			fresh[p] = true
			n += 1
		end
	end
	for p, d in pairs(wetParts) do
		if not fresh[p] then
			if p.Parent then
				p.Color = d.color
				p.Reflectance = d.refl
				if d.snowMat then
					p.Material = d.mat
				end
			end
			wetParts[p] = nil
		end
	end
	for p in pairs(N.WQ.checked) do
		if not fresh[p] then
			N.WQ.checked[p] = nil
		end
	end
	local now = os.clock()
	for p in pairs(fresh) do
		if not wetParts[p] then
			local t = N.WQ.checked[p]
			if not t or now - t > 30 then
				N.WQ.checked[p] = now
				N.WQ.queue[#N.WQ.queue + 1] = p
			end
		end
	end
end

function N.processWetQueue(budget)
	local queue = N.WQ.queue
	for _ = 1, budget do
		local p = table.remove(queue)
		if not p then
			break
		end
		if p.Parent and not wetParts[p] then
			local top = p.Position + Vector3.new(0, p.Size.Y / 2 + 0.3, 0)
			local roof = Workspace:Raycast(top, Vector3.new(0, 120, 0), rayParams)
			if not (roof and roof.Instance.Transparency < 0.9) then
				local sz = p.Size
				local d = {
					color = p.Color, refl = p.Reflectance, mat = p.Material,
					flat = math.abs(p.CFrame.UpVector.Y) > 0.9 and (sz.Y < 4 or sz.Y < math.min(sz.X, sz.Z) * 0.9),
				}
				wetParts[p] = d
				wetten(p, d)
			end
		end
	end
end

local function updateGround(dt, rainLevel, snowLevel, pos, q)
	local wetOn, snowOn = cfg.wetGround, cfg.snowGround
	if not wetOn and not snowOn then
		if next(wetParts) or S.lastWetness > 0 or S.lastSnow > 0 or S.lastTW > 0 or S.lastTS > 0 then
			dryAll()
		end
		return
	end
	if wetOn then
		if rainLevel > 0.15 then
			S.wetness = math.min(1, S.wetness + dt / (rainLevel > 1.3 and 6 or 12))
			S.wetHold = 0
		else
			S.wetHold += dt
			if S.wetHold > 6 then
				S.wetness = math.max(0, S.wetness - dt / 35)
			end
		end
	else
		S.wetness = 0
	end
	if snowOn then
		if snowLevel > 0.15 then
			S.snowCover = math.min(1, S.snowCover + dt / 45)
			S.snowHold = 0
		else
			S.snowHold += dt
			if S.snowHold > 4 then
				S.snowCover = math.max(0, S.snowCover - dt / 25)
			end
		end
	else
		S.snowCover = 0
	end
	local any = S.wetness > 0.02 or S.snowCover > 0.02
	if any then
		if os.clock() - S.lastWetScan > 6 or (pos - S.wetOrigin).Magnitude > 40 then
			scanWet(pos, q.wet)
		end
		N.processWetQueue(20)
	end
	if S.wetness <= 0 and S.snowCover <= 0 and (S.lastWetness > 0 or S.lastSnow > 0 or S.lastTW > 0 or S.lastTS > 0) then
		dryAll()
		return
	end
	if math.abs(S.wetness - S.lastWetness) >= 0.03 or math.abs(S.snowCover - S.lastSnow) >= 0.03 then
		S.lastWetness, S.lastSnow = S.wetness, S.snowCover
		for p, d in pairs(wetParts) do
			if p.Parent then
				wetten(p, d)
			end
		end
	end
	if terrain and math.abs(S.wetness - S.lastTW) + math.abs(S.snowCover - S.lastTS) >= 0.1 then
		S.lastTW, S.lastTS = S.wetness, S.snowCover
		for m, c in pairs(terrainColors) do
			pcall(terrain.SetMaterialColor, terrain, m, N.tint(c))
		end
	end
end

function N.flatSpot(pos, minR, maxR, clearance, others, minDist)
	local ang, rad = math.random() * 6.283, minR + math.random() * (maxR - minR)
	local o = Vector3.new(pos.X + math.cos(ang) * rad, pos.Y + 25, pos.Z + math.sin(ang) * rad)
	local hit = Workspace:Raycast(o, Vector3.new(0, -80, 0), rayParams)
	if not hit or hit.Normal.Y < 0.95 then
		return nil
	end
	local inst = hit.Instance
	if not (inst:IsA("Terrain") or (inst.Anchored and inst.Size.X >= 8 and inst.Size.Z >= 8)) then
		return nil
	end
	local roof = Workspace:Raycast(hit.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 120, 0), rayParams)
	if roof and roof.Instance.Transparency < 0.9 then
		return nil
	end
	for _, other in ipairs(others) do
		if other.placed and (other.pos - hit.Position).Magnitude < minDist then
			return nil
		end
	end
	local y = hit.Position.Y
	for _, d in ipairs({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }) do
		local h2 = Workspace:Raycast(hit.Position + d * clearance + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), rayParams)
		if not h2 or math.abs(h2.Position.Y - y) > 0.2 or h2.Normal.Y < 0.9 then
			return nil
		end
	end
	return hit
end

local function tryPlacePuddle(pd, pos)
	local size = 2.6 + math.random() * 2.4
	local hit = N.flatSpot(pos, 6, 36, size * 0.7, puddles, 26)
	if not hit then
		return false
	end
	local inst = hit.Instance
	local base
	if inst:IsA("Terrain") then
		base = terrainColors[hit.Material]
	else
		base = inst.Color
	end
	base = (base or Color3.fromRGB(80, 80, 80)):Lerp(Color3.fromRGB(35, 50, 70), 0.5)
	local col = Color3.new(base.R * 0.55, base.G * 0.55, base.B * 0.6)
	pd.size, pd.pos = size, hit.Position
	pd.offs[1] = { size = size, x = 0, z = 0 }
	for i = 2, #pd.blobs do
		local a2 = math.random() * 6.283
		pd.offs[i] = { size = size * (0.45 + math.random() * 0.35), x = math.cos(a2) * size * 0.38, z = math.sin(a2) * size * 0.38 }
	end
	for i, b in ipairs(pd.blobs) do
		local off = pd.offs[i]
		b.Color = col
		b.CFrame = CFrame.new(hit.Position + Vector3.new(off.x, 0.07 + i * 0.015, off.z)) * CFrame.Angles(0, 0, math.pi / 2)
	end
	pd.emit.Size = Vector3.new(size * 0.8, 0.1, size * 0.8)
	pd.emit.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.12, 0))
	return true
end

local function updatePuddles(dt, pos, level)
	if #puddles == 0 then
		return
	end
	local a = cfg.wetGround and math.clamp((S.puddleLevel - 0.15) / 0.6, 0, 1) or 0
	S.puddleTimer -= dt
	local refresh = S.puddleTimer <= 0
	if refresh then
		S.puddleTimer = 0.5
	end
	local placedNow = 0
	for _, pd in ipairs(puddles) do
		if refresh then
			local far = pd.placed and Vector2.new(pd.pos.X - pos.X, pd.pos.Z - pos.Z).Magnitude > 45
			if S.puddleLevel > 0.75 and (not pd.placed or far) and placedNow < 1 and math.random() < 0.12 then
				placedNow += 1
				pd.placed = tryPlacePuddle(pd, pos)
			end
			if pd.placed and a > 0.01 then
				for i, b in ipairs(pd.blobs) do
					local sz = pd.offs[i].size * (0.35 + 0.65 * a)
					b.Size = Vector3.new(0.05, sz, sz)
					b.Transparency = 1 - 0.92 * a
				end
			else
				for _, b in ipairs(pd.blobs) do
					b.Transparency = 1
				end
			end
		end
		local active = pd.placed and a > 0.3 and level > 0.1
		local rr = active and (3 + 5 * math.min(level, 2)) * (pd.size / 3) or 0
		pd.ripples.Rate, pd.ripples.Enabled = rr, rr > 0.5
		pd.splash.Rate, pd.splash.Enabled = rr * 0.5, rr > 0.5
	end
end

function N.placeMound(m, pos)
	local w = 2.6 + math.random() * 2.6
	local hit = N.flatSpot(pos, 8, 40, w * 0.8, N.mounds, 26)
	if not hit then
		return false
	end
	local yaw = math.atan2(-S.windDir.Z, S.windDir.X) + (math.random() - 0.5) * 0.7
	local axis = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	local cross = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	m.size, m.pos, m.yaw = w, hit.Position, yaw
	for i, part in ipairs(m.lumps) do
		local main = i == 1
		local ws = main and w or w * (0.35 + math.random() * 0.4)
		local wl = ws * (1.3 + math.random() * 0.6)
		local along = main and 0 or (math.random() - 0.5) * w * 1.5
		local across = main and 0 or (math.random() - 0.5) * w * 0.55
		local falloff = 1 - math.clamp(math.abs(along) / (w * 0.9), 0, 0.6)
		m.offs[i] = { ws = ws, wl = wl, hv = ws * (0.2 + math.random() * 0.1) * falloff }
		local shade = math.random()
		part.Color = Color3.fromRGB(246 - shade * 12, 249 - shade * 9, 253)
		part.CFrame = CFrame.new(hit.Position + axis * along + cross * across + Vector3.new(0, -0.03, 0)) * CFrame.Angles(0, yaw, 0)
	end
	return true
end

function N.updateMounds(dt, pos)
	if #N.mounds == 0 then
		return
	end
	S.moundTimer -= dt
	if S.moundTimer > 0 then
		return
	end
	S.moundTimer = 0.6
	local a = cfg.snowGround and math.clamp((S.snowCover - 0.35) / 0.5, 0, 1) or 0
	local placedNow = 0
	for _, m in ipairs(N.mounds) do
		local far = m.placed and Vector2.new(m.pos.X - pos.X, m.pos.Z - pos.Z).Magnitude > 50
		if S.snowCover > 0.6 and a > 0.05 and (not m.placed or far) and placedNow < 1 and math.random() < 0.15 then
			placedNow += 1
			m.placed = N.placeMound(m, pos)
		end
		if m.placed and a > 0.01 then
			local g = 0.3 + 0.7 * a
			for i, part in ipairs(m.lumps) do
				local o = m.offs[i]
				part.Size = Vector3.new(o.wl * g, o.hv * 2 * g, o.ws * g)
				part.Transparency = 1 - math.clamp(a * 3, 0, 1)
			end
		else
			for _, part in ipairs(m.lumps) do
				part.Transparency = 1
			end
			if a <= 0.01 then
				m.placed = false
			end
		end
	end
end

function N.updatePrints(dt)
	for _, pr in ipairs(N.prints) do
		if pr.alive then
			pr.t += dt
			local k = pr.t / pr.life
			if k >= 1 then
				pr.alive = false
				pr.rim.Transparency = 1
				pr.dent.Transparency = 1
			else
				local fade = math.clamp((k - 0.55) / 0.45, 0, 1)
				pr.rim.Transparency = 0.3 + 0.7 * fade
				pr.dent.Transparency = 0.2 + 0.8 * fade
			end
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
	lightList[#lightList + 1] = { inst = inst, b = inst.Brightness, r = ok and r or nil, s = inst.Shadows, set = nil, boost = 1, changes = 0, sh = false, skip = false }
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
			if e.sh then
				S.shadowCount -= 1
			end
			lightList[S.lightCursor] = lightList[n]
			lightList[n] = nil
			lightSet[inst] = nil
			n -= 1
		else
			if not e.skip then
				if e.set and math.abs(inst.Brightness - e.set) > 0.002 then
					e.changes += 1
					e.b = inst.Brightness / e.boost
					if e.changes > 2 then
						e.skip = true
					end
				end
				if not e.skip then
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
						if p then
							local d = (p - camPos).Magnitude
							if e.sh then
								if d > 75 then
									e.sh = false
									S.shadowCount -= 1
								end
							elseif d < 45 and S.shadowCount < 4 and not e.s then
								e.sh = true
								S.shadowCount += 1
							end
						end
						want = (e.s or e.sh) and true or false
					elseif e.sh then
						e.sh = false
						S.shadowCount -= 1
					end
					setp(inst, "Shadows", want)
				end
			end
			S.lightCursor += 1
		end
	end
end

local function restoreLights()
	for _, e in ipairs(lightList) do
		local inst = e.inst
		if inst.Parent and e.set and not e.skip then
			pcall(function()
				inst.Brightness = e.b
				if e.r then
					inst.Range = e.r
				end
				inst.Shadows = e.s
			end)
		end
		e.set, e.boost, e.sh = nil, 1, false
	end
	S.shadowCount = 0
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
	local used = {}
	for gi = 1, math.min(#groups, MAX_SHAFTS) do
		local g = groups[gi]
		local sum, ceil = Vector3.zero, 0
		for _, c in ipairs(g) do
			sum += c.pos
			ceil += c.ceil
		end
		local center = sum / #g
		ceil = ceil / #g
		local w = math.clamp(math.sqrt(#g) * shafts.step, 1.2, 6)
		local len = math.clamp(ceil / math.max(dir.Y, 0.2), 4, 45)
		local best, bd = nil, 6
		for bi, b in ipairs(shafts.pool) do
			if not used[bi] and b.want then
				local d = (b.center - center).Magnitude
				if d < bd then
					best, bd = bi, d
				end
			end
		end
		if not best then
			for bi, b in ipairs(shafts.pool) do
				if not used[bi] and not b.want then
					best = bi
					break
				end
			end
		end
		if not best then
			local low = 2
			for bi, b in ipairs(shafts.pool) do
				if not used[bi] and b.alpha < low then
					best, low = bi, b.alpha
				end
			end
		end
		if best then
			used[best] = true
			local b = shafts.pool[best]
			local mid = center + dir * (len / 2)
			b.tcf = CFrame.lookAt(mid, mid + dir)
			b.tlen, b.tw, b.center, b.miss = len, w, center, 0
			if not b.want then
				b.holder.CFrame = b.tcf
				b.len, b.w = len, w
			end
			b.want = true
		end
	end
	for bi, b in ipairs(shafts.pool) do
		if not used[bi] and b.want then
			b.miss += 1
			if b.miss > 1 then
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

	local k2 = 1 - math.exp(-dt * 6)
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
			if b.tcf then
				b.holder.CFrame = b.holder.CFrame:Lerp(b.tcf, k2)
				b.len += (b.tlen - b.len) * k2
				b.w += (b.tw - b.w) * k2
				b.holder.Size = Vector3.new(b.w, b.w, b.len)
				b.a0.Position = Vector3.new(0, 0, b.len / 2)
				b.a1.Position = Vector3.new(0, 0, -b.len / 2)
				for _, L in ipairs(b.layers) do
					local wv = b.w * L.mult
					L.beam.Width0 = wv
					L.beam.Width1 = wv
				end
			end
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

local waterOrig = {}
if terrain then
	for _, k in ipairs({ "WaterColor", "WaterTransparency", "WaterReflectance", "WaterWaveSize", "WaterWaveSpeed" }) do
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
	for _, p in ipairs(N.nearParts(origin, 150)) do
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
	day = math.floor(day * 10 + 0.5) / 10
	local target = Color3.fromRGB(34, 96, 118):Lerp(Color3.fromRGB(8, 20, 32), 1 - day):Lerp(Color3.fromRGB(40, 150, 120), (N.auroraAlpha or 0) * 0.25)
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
					e.last = os.clock()
					wanted[ch] = true
				end
			end
		end
		for ch, e in pairs(reflections) do
			if not ch.Parent then
				e.folder:Destroy()
				reflections[ch] = nil
			elseif not wanted[ch] and os.clock() - (e.last or 0) > 1.2 then
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
		local goal = cfg.volume * 0.4 * level * (1 - S.muffle * 0.6)
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
		local snowF = math.clamp(cur.snow, 0, 1)
		local base = (0.015 + 0.04 * math.clamp(windLevel / 1.8, 0, 1)) * (1 - 0.2 * snowF)
		local goal = (cfg.windSound and cfg.wind) and base * (1 - S.muffle * 0.6) * (1 - 0.5 * math.min(rainLevel, 1)) or 0
		windSnd.Volume = windSnd.Volume + (goal - windSnd.Volume) * (1 - math.exp(-dt * 1.5))
		setp(windSnd, "PlaybackSpeed", math.floor((1 + 0.08 * snowF) * 50 + 0.5) / 50)
		windEq.HighGain = -30 * S.muffle + 2 * snowF
		windEq.MidGain = -4 * snowF
		windEq.LowGain = -10 * snowF
		if goal > 0.003 and not windSnd.IsPlaying then
			windSnd:Play()
		elseif goal <= 0.003 and windSnd.Volume < 0.002 and windSnd.IsPlaying then
			windSnd:Stop()
		end
	end
	local nightF = cfg.nightSound and math.clamp(cur.night, 0, 1) * (1 - S.dayFactor) or 0
	if S.nightOk then
		S.nightTimer -= dt
		if S.nightTimer <= 0 then
			S.nightGate = not S.nightGate
			S.nightTimer = S.nightGate and (20 + math.random() * 25) or (45 + math.random() * 70)
		end
		local goal = S.nightGate and 0.08 * nightF * (1 - S.muffle * 0.5) or 0
		N.nightSnd.Volume = N.nightSnd.Volume + (goal - N.nightSnd.Volume) * (1 - math.exp(-dt * 1.2))
		if goal > 0.004 and not N.nightSnd.IsPlaying then
			N.nightSnd:Play()
		elseif goal <= 0.004 and N.nightSnd.Volume < 0.002 and N.nightSnd.IsPlaying then
			N.nightSnd:Stop()
		end
	end
	if S.owlOk and nightF > 0.8 then
		S.owlTimer -= dt
		if S.owlTimer <= 0 then
			S.owlTimer = 40 + math.random() * 60
			N.owlSnd.Volume = (0.06 + math.random() * 0.08) * (1 - S.muffle * 0.6)
			N.owlSnd.PlaybackSpeed = 0.95 + math.random() * 0.1
			N.owlSnd.TimePosition = 0
			N.owlSnd:Play()
		end
	end
end

local stepPool = {}

local function playStep(kind, wetF)
	local pool = kind == "snow" and N.snowPool or stepPool
	local key = kind == "snow" and "snowIdx" or "stepIdx"
	local snd = pool[S[key]]
	if not snd or not snd.IsLoaded then
		return
	end
	S[key] = S[key] % #pool + 1
	snd.Volume = 0
	snd.PlaybackSpeed = 0.92 + math.random() * 0.16
	snd.TimePosition = snd.TimeLength > 1.2 and math.random() * (snd.TimeLength - 0.7) or 0
	snd:Play()
	local peak = kind == "snow" and math.clamp(0.06 + 0.06 * wetF, 0.05, 0.12) or math.clamp(0.05 + 0.06 * wetF, 0.04, 0.12)
	TweenService:Create(snd, TweenInfo.new(0.06), { Volume = peak }):Play()
	task.delay(0.14, function()
		TweenService:Create(snd, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Volume = 0 }):Play()
	end)
	task.delay(0.5, function()
		snd:Stop()
	end)
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

function N.evalFar(c, camY)
	local o = Vector3.new(c.cx, camY + 2, c.cz)
	local ground = Workspace:Raycast(o, Vector3.new(0, -250, 0), rayParams)
	local base
	if ground then
		base = ground.Position.Y
		local roof = Workspace:Raycast(ground.Position + Vector3.new(0, 0.6, 0), Vector3.new(0, 150, 0), rayParams)
		c.exposed = not (roof and roof.Instance.Transparency < 0.9)
	else
		base = camY - 3
		local roof = Workspace:Raycast(o, Vector3.new(0, 150, 0), rayParams)
		c.exposed = not (roof and roof.Instance.Transparency < 0.9)
	end
	c.col.CFrame = CFrame.new(c.cx, base + 60, c.cz)
	c.pending, c.stamp = false, os.clock()
end

function N.stamp(hitPos, dir, sideSign)
	local pr = N.prints[N.printIdx]
	N.printIdx = N.printIdx % #N.prints + 1
	local p = hitPos + Vector3.new(-dir.Z, 0, dir.X) * 0.4 * sideSign
	local yaw = math.atan2(-dir.Z, dir.X)
	local base = CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.pi / 2)
	pr.rim.CFrame = base + Vector3.new(0, 0.05, 0)
	pr.dent.CFrame = base + Vector3.new(0, 0.07, 0)
	pr.t, pr.life, pr.alive = 0, 28 + math.random() * 22, true
	pr.rim.Transparency, pr.dent.Transparency = 0.3, 0.2
end

function N.trackSteps(dt, pos)
	if #N.prints == 0 or not cfg.snowGround or S.snowCover < 0.3 then
		return
	end
	local chars = {}
	if char then
		chars[1] = char
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		local ch = pl.Character
		if pl ~= lp and ch and #chars < 5 then
			local r = ch:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - pos).Magnitude < 50 then
				chars[#chars + 1] = ch
			end
		end
	end
	local filter = { Workspace.CurrentCamera }
	for _, ch in ipairs(chars) do
		filter[#filter + 1] = ch
	end
	N.printParams.FilterDescendantsInstances = filter
	for _, ch in ipairs(chars) do
		local r = ch:FindFirstChild("HumanoidRootPart")
		local h = ch:FindFirstChildOfClass("Humanoid")
		if r and h and h.FloorMaterial ~= Enum.Material.Air then
			local flat = Vector3.new(r.Position.X, 0, r.Position.Z)
			local tr = N.trackers[ch]
			if not tr then
				N.trackers[ch] = { last = flat, side = 1 }
			else
				local delta = flat - tr.last
				if delta.Magnitude >= 1.4 then
					local hit = Workspace:Raycast(r.Position, Vector3.new(0, -7, 0), N.printParams)
					if hit and hit.Normal.Y > 0.9 then
						local roof = Workspace:Raycast(hit.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 120, 0), N.printParams)
						if not (roof and roof.Instance.Transparency < 0.9) then
							N.stamp(hit.Position, delta.Unit, tr.side)
						end
					end
					tr.side = -tr.side
					tr.last = flat
				end
			end
		end
	end
	for ch in pairs(N.trackers) do
		if not ch.Parent then
			N.trackers[ch] = nil
		end
	end
end

local function holderPart(name, cam)
	local p = create("Part", {
		Name = name, Size = Vector3.new(1, 1, 1), Anchored = true, CanCollide = false, CanQuery = false,
		CanTouch = false, CastShadow = false, Transparency = 1, Locked = true,
	}, cam)
	N.extra[#N.extra + 1] = p
	return p
end

function N.ensureBolt(cam)
	if N.bolt and N.bolt.holder.Parent == cam then
		return
	end
	local holder = holderPart("ws_bolt", cam)
	local atts, beams = {}, {}
	for i = 1, 20 do
		atts[i] = create("Attachment", {}, holder)
	end
	local function link(a, b, w, glow)
		local bm = create("Beam", {
			Attachment0 = atts[a], Attachment1 = atts[b], FaceCamera = true, LightEmission = 1, LightInfluence = 0,
			Segments = 1, Enabled = false, Width0 = w, Width1 = w,
			Color = ColorSequence.new(Color3.fromRGB(225, 235, 255)), Transparency = NumberSequence.new(1),
		}, holder)
		beams[#beams + 1] = { beam = bm, glow = glow }
	end
	for i = 1, 13 do
		link(i, i + 1, 1.6, false)
		link(i, i + 1, 6, true)
	end
	for i = 15, 19 do
		link(i, i + 1, 1.2, false)
		link(i, i + 1, 4.5, true)
	end
	N.bolt = { holder = holder, atts = atts, beams = beams, t = 0, life = 0.6, active = false }
end

function N.queueThunder(dist)
	if not (S.thunderOk and cfg.lightning) then
		return
	end
	task.delay(0.4 + dist / 140, function()
		local snd = N.thunderPool[S.thunderIdx]
		if not snd or not snd.Parent then
			return
		end
		S.thunderIdx = S.thunderIdx % #N.thunderPool + 1
		snd.Volume = math.clamp(0.55 - dist / 1100, 0.15, 0.5) * (1 - S.muffle * 0.5)
		snd.PlaybackSpeed = 0.85 + math.random() * 0.25
		local f = snd:FindFirstChildOfClass("EqualizerSoundEffect")
		if f then
			f.HighGain = -40 * S.muffle
		end
		snd.TimePosition = 0
		snd:Play()
	end)
end

function N.spawnBolt(cam, pos)
	N.ensureBolt(cam)
	local b = N.bolt
	local look = cam.CFrame.LookVector
	local az = math.atan2(look.X, look.Z) + (math.random() - 0.5) * 2
	local dist = 220 + math.random() * 300
	local dir = Vector3.new(math.sin(az), 0, math.cos(az))
	local top = pos + dir * dist + Vector3.new(0, 280 + math.random() * 120, 0)
	local ground = Vector3.new(top.X + (math.random() - 0.5) * 60, pos.Y - 4, top.Z + (math.random() - 0.5) * 60)
	local pts = {}
	local jit = Vector3.zero
	for i = 0, 13 do
		jit += Vector3.new((math.random() - 0.5) * 34, 0, (math.random() - 0.5) * 34)
		local k = (i == 0) and 0 or ((i == 13) and 0.3 or 1)
		pts[i + 1] = top:Lerp(ground, i / 13) + jit * k
	end
	b.holder.CFrame = CFrame.new(pos)
	for i = 1, 14 do
		b.atts[i].Position = pts[i] - pos
	end
	local start = pts[math.random(4, 9)]
	local bdir = Vector3.new((math.random() - 0.5) * 2, -0.8, (math.random() - 0.5) * 2).Unit
	b.atts[15].Position = start - pos
	local p2 = start
	for i = 16, 20 do
		p2 += bdir * (30 + math.random() * 20) + Vector3.new((math.random() - 0.5) * 20, 0, (math.random() - 0.5) * 20)
		b.atts[i].Position = p2 - pos
	end
	b.t, b.active = 0, true
	for _, e in ipairs(b.beams) do
		e.beam.Enabled = true
	end
	N.queueThunder(dist)
end

function N.updateBolt(dt)
	local b = N.bolt
	if not b or not b.active then
		return
	end
	b.t += dt
	if b.t >= b.life then
		b.active = false
		for _, e in ipairs(b.beams) do
			e.beam.Enabled = false
		end
		return
	end
	local a
	if b.t < 0.08 then
		a = 1
	elseif b.t < 0.14 then
		a = 0.25
	elseif b.t < 0.24 then
		a = 0.9
	else
		a = math.clamp(1 - (b.t - 0.24) / 0.36, 0, 1)
	end
	local main = NumberSequence.new(1 - a)
	local glow = NumberSequence.new(1 - 0.25 * a)
	for _, e in ipairs(b.beams) do
		e.beam.Transparency = e.glow and glow or main
	end
end

function N.seedRibbon(rb)
	rb.span = math.rad(110 + math.random() * 90)
	rb.azOff = math.rad(-55 + math.random() * 110)
	rb.e0 = math.rad(8 + math.random() * 25)
	rb.slope = math.rad(-25 + math.random() * 60)
	rb.wiggle = math.rad(3 + math.random() * 6)
	rb.freq = 2 + math.random() * 3
	rb.speed = 0.15 + math.random() * 0.35
	rb.thick = math.rad(5 + math.random() * 9)
	rb.hue = math.random()
	rb.phase = math.random() * 6.28
	rb.life = 45 + math.random() * 60
	rb.age = 0
end

function N.seedRay(A, ry)
	ry.rb = A.ribbons[math.random(#A.ribbons)]
	ry.u = 0.12 + math.random() * 0.76
	ry.h = 110 + math.random() * 170
	ry.w = 8 + math.random() * 22
	ry.life = 6 + math.random() * 14
	ry.age = 0
	ry.phase = math.random() * 6.28
	ry.flicker = 0.4 + math.random() * 1.2
	ry.lean = (math.random() - 0.5) * 0.5
end

function N.ensureAurora(cam, q)
	if N.aurora and N.aurora.holder.Parent == cam and N.aurora.n == q.aurora then
		return
	end
	if N.aurora then
		N.aurora.holder:Destroy()
		N.aurora = nil
	end
	if q.aurora == 0 then
		return
	end
	local holder = holderPart("ws_aurora", cam)
	local M = 13
	local function newBeam(a0, a1)
		return create("Beam", {
			Attachment0 = a0, Attachment1 = a1, FaceCamera = true, LightEmission = 1, LightInfluence = 0,
			Segments = 1, Enabled = false, Width0 = 20, Width1 = 20,
			Transparency = NumberSequence.new(1), Color = ColorSequence.new(Color3.fromRGB(90, 255, 160)),
		}, holder)
	end
	local ribbons = {}
	for r = 1, q.aurora do
		local atts, segs = {}, {}
		for i = 1, M do
			atts[i] = create("Attachment", {}, holder)
		end
		for i = 1, M - 1 do
			local layers = {}
			for _, L in ipairs({ { 1.0, 0.9 }, { 0.6, 0.8 }, { 0.3, 0.65 } }) do
				layers[#layers + 1] = { beam = newBeam(atts[i], atts[i + 1]), mult = L[1], base = L[2] }
			end
			segs[i] = layers
		end
		local rb = { atts = atts, segs = segs, pts = {}, seed = math.random() * 100 }
		N.seedRibbon(rb)
		rb.age = math.random() * rb.life * 0.5
		ribbons[r] = rb
	end
	local rays = {}
	for i = 1, q.aurora * 3 do
		local a0 = create("Attachment", {}, holder)
		local a1 = create("Attachment", {}, holder)
		local layers = {}
		for _, L in ipairs({ { 1.0, 0.82 }, { 0.4, 0.55 } }) do
			layers[#layers + 1] = { beam = newBeam(a0, a1), mult = L[1], base = L[2] }
		end
		rays[i] = { a0 = a0, a1 = a1, layers = layers }
	end
	local A = { holder = holder, ribbons = ribbons, rays = rays, n = q.aurora, M = M, t = 0, colorT = 0, shown = false }
	for _, ry in ipairs(rays) do
		N.seedRay(A, ry)
		ry.age = math.random() * ry.life
	end
	N.aurora = A
end

function N.auroraColor(rb, u, t)
	local shift = 0.5 + 0.5 * math.sin(t * 0.12 + rb.hue * 6.28)
	local core = Color3.fromRGB(80, 255, 150):Lerp(Color3.fromRGB(60, 235, 215), shift * 0.55)
	local edge = Color3.fromRGB(150, 95, 255):Lerp(Color3.fromRGB(235, 100, 215), shift)
	local e = math.abs(u - 0.5) * 2
	return core:Lerp(edge, math.clamp((e - 0.45) * 1.6, 0, 0.85))
end

function N.updateAurora(dt, cam, alpha)
	local q = Q[cfg.quality]
	local A = N.aurora
	if alpha < 0.01 or q.aurora == 0 then
		N.auroraAlpha = 0
		if A and A.shown then
			A.shown = false
			for _, rb in ipairs(A.ribbons) do
				for _, layers in ipairs(rb.segs) do
					for _, L in ipairs(layers) do
						L.beam.Enabled = false
					end
				end
			end
			for _, ry in ipairs(A.rays) do
				for _, L in ipairs(ry.layers) do
					L.beam.Enabled = false
				end
			end
		end
		return
	end
	N.ensureAurora(cam, q)
	A = N.aurora
	if not A then
		return
	end
	A.t += dt
	A.shown = true
	A.holder.CFrame = CFrame.new(cam.CFrame.Position)
	local look = cam.CFrame.LookVector
	local yaw = math.atan2(look.X, look.Z)
	if not A.yaw then
		A.yaw = yaw
	end
	A.yaw += ((yaw - A.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * 0.3))
	local activity = math.clamp(0.7 + math.noise(A.t * 0.03, 2.2) * 1.2, 0.35, 1)
	local M = A.M
	local D = 330
	local total = 0

	for _, rb in ipairs(A.ribbons) do
		rb.age += dt
		if rb.age >= rb.life then
			N.seedRibbon(rb)
		end
		rb.alpha = math.min(rb.age / 8, 1) * math.clamp((rb.life - rb.age) / 8, 0, 1)
		total += rb.alpha
		local base = A.yaw + rb.azOff
		for i = 1, M do
			local u = (i - 1) / (M - 1)
			local az = base + (u - 0.5) * rb.span + math.sin(A.t * 0.11 + rb.phase) * 0.05
			local el = rb.e0 + rb.slope * u
				+ math.sin(u * rb.freq + A.t * rb.speed + rb.phase) * rb.wiggle
				+ math.sin(u * 7 + A.t * 0.4 + rb.phase * 2) * rb.wiggle * 0.35
			el = math.clamp(el, math.rad(4), math.rad(75))
			local ce = math.cos(el)
			local d = Vector3.new(math.sin(az) * ce, math.sin(el), math.cos(az) * ce)
			rb.pts[i] = d
			rb.atts[i].Position = d * D
		end
	end

	for _, ry in ipairs(A.rays) do
		ry.age += dt
		if ry.age >= ry.life then
			N.seedRay(A, ry)
		end
		local rb = ry.rb
		local pos = ry.u * (M - 1) + 1
		local i0 = math.clamp(math.floor(pos), 1, M - 1)
		local d = rb.pts[i0]:Lerp(rb.pts[i0 + 1], pos - i0)
		local base = d.Unit * D
		ry.a0.Position = base
		ry.a1.Position = base + Vector3.new(ry.lean * ry.h * 0.4, ry.h, 0)
	end

	N.auroraAlpha = alpha * activity * (total / #A.ribbons) * 0.9

	A.colorT -= dt
	if A.colorT > 0 then
		return
	end
	A.colorT = 0.1
	for _, rb in ipairs(A.ribbons) do
		local fa = {}
		local cs = {}
		local ws = {}
		for i = 1, M do
			local u = (i - 1) / (M - 1)
			local bright = (math.sin(math.pi * u) ^ 0.7) * (0.65 + 0.35 * math.sin(u * 9 + A.t * 0.5 + rb.phase))
			fa[i] = math.clamp(bright, 0, 1) * rb.alpha * activity * alpha
			cs[i] = N.auroraColor(rb, u, A.t)
			ws[i] = D * math.tan(rb.thick * (0.55 + 0.45 * math.sin(math.pi * u)))
		end
		for i = 1, M - 1 do
			local f = (fa[i] + fa[i + 1]) / 2
			local seq = ColorSequence.new(cs[i], cs[i + 1])
			for _, L in ipairs(rb.segs[i]) do
				L.beam.Width0 = ws[i] * L.mult
				L.beam.Width1 = ws[i + 1] * L.mult
				L.beam.Transparency = NumberSequence.new(1 - (1 - L.base) * f)
				L.beam.Color = seq
				L.beam.Enabled = f > 0.02
			end
		end
	end
	for _, ry in ipairs(A.rays) do
		local k = math.sin(math.pi * ry.age / ry.life) ^ 0.8
		local pulse = 0.55 + 0.45 * math.sin(A.t * ry.flicker + ry.phase)
		local f = k * pulse * ry.rb.alpha * activity * alpha
		local c0 = N.auroraColor(ry.rb, ry.u, A.t)
		local c1 = c0:Lerp(Color3.fromRGB(190, 120, 255), 0.6)
		local seq = ColorSequence.new(c0, c1)
		for _, L in ipairs(ry.layers) do
			local t0 = 1 - (1 - L.base) * f
			L.beam.Width0 = ry.w * L.mult
			L.beam.Width1 = ry.w * L.mult * 0.4
			L.beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, t0), NumberSequenceKeypoint.new(0.55, math.min(1, t0 + (1 - t0) * 0.55)),
				NumberSequenceKeypoint.new(1, 1),
			})
			L.beam.Color = seq
			L.beam.Enabled = f > 0.02
		end
	end
end

function N.ensureRainbow(cam)
	if N.rainbow and N.rainbow.holder.Parent == cam then
		return
	end
	local holder = holderPart("ws_rainbow", cam)
	local colors = {
		Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 230, 80),
		Color3.fromRGB(90, 225, 110), Color3.fromRGB(80, 200, 235), Color3.fromRGB(80, 120, 255), Color3.fromRGB(160, 100, 235),
	}
	local bands = {}
	for b = 1, 7 do
		local atts, beams = {}, {}
		for i = 1, 25 do
			atts[i] = create("Attachment", {}, holder)
		end
		for i = 1, 24 do
			beams[i] = {
				beam = create("Beam", {
					Attachment0 = atts[i], Attachment1 = atts[i + 1], FaceCamera = true, LightEmission = 0.55,
					LightInfluence = 0, Segments = 1, Enabled = false, Width0 = 2.7, Width1 = 2.7,
					Color = ColorSequence.new(colors[b]), Transparency = NumberSequence.new(1),
				}, holder),
				f = math.sin(math.pi * (i - 0.5) / 24) ^ 0.6, vis = false,
			}
		end
		bands[b] = { atts = atts, beams = beams, ys = {} }
	end
	N.rainbow = { holder = holder, bands = bands, t = 0, active = false, lastA = -1, lastPlace = 0, fading = false, fadeT = 0, fadeDur = 10, acc = 1 }
end

function N.placeRainbow()
	local r = N.rainbow
	local sd = sun.dir
	local horiz = Vector3.new(sd.X, 0, sd.Z)
	horiz = horiz.Magnitude < 0.01 and Vector3.new(1, 0, 0) or horiz.Unit
	local ce = math.min(math.asin(math.clamp(sd.Y, -1, 1)), math.rad(24))
	local c = (-horiz * math.cos(ce) + Vector3.new(0, -math.sin(ce), 0)).Unit
	local u = c:Cross(Vector3.new(0, 1, 0)).Unit
	local v = u:Cross(c)
	if v.Y < 0 then
		v = -v
	end
	for b, band in ipairs(r.bands) do
		local R = math.rad(42 - (b - 1) * 0.9)
		for i = 1, 25 do
			local th = -0.5 + (math.pi + 1) * ((i - 1) / 24)
			local d = c * math.cos(R) + (u * math.cos(th) + v * math.sin(th)) * math.sin(R)
			band.atts[i].Position = d * 330
			band.ys[i] = d.Y
		end
		for i = 1, 24 do
			band.beams[i].vis = band.ys[i] > -0.01 and band.ys[i + 1] > -0.01
		end
	end
	r.lastA = -1
end

function N.updateRainbow(dt, cam)
	local r = N.rainbow
	if not r or not r.active then
		return
	end
	r.t += dt
	r.holder.CFrame = CFrame.new(cam.CFrame.Position)
	local abort = not (cfg.rainbow and cfg.master) or cfg.mode == "night" or S.inNight or S.returning or sun.dir.Y < 0.03
	if abort and not r.fading then
		r.fading, r.fadeT, r.fadeDur = true, 0, 1.8
	end
	if not r.fading and r.t >= 25 then
		r.fading, r.fadeT, r.fadeDur = true, 0, 10
	end
	local fo = 0
	if r.fading then
		r.fadeT += dt
		fo = math.clamp(r.fadeT / r.fadeDur, 0, 1)
	end
	if fo >= 1 then
		r.active = false
		for _, band in ipairs(r.bands) do
			for _, e in ipairs(band.beams) do
				e.beam.Enabled = false
			end
		end
		return
	end
	r.acc += dt
	if r.acc < 0.05 then
		return
	end
	r.acc = 0
	local fi = math.clamp(r.t / 4, 0, 1)
	fi = fi * fi * (3 - 2 * fi)
	for b, band in ipairs(r.bands) do
		for _, e in ipairs(band.beams) do
			if e.vis then
				local a = math.clamp((1 - fo) * 1.5 - (1 - e.f) * 0.5 - (b - 1) * 0.04 * fo, 0, 1) * fi
				if a > 0.01 then
					e.beam.Transparency = NumberSequence.new(1 - 0.6 * a * e.f)
					e.beam.Enabled = true
				else
					e.beam.Enabled = false
				end
			else
				e.beam.Enabled = false
			end
		end
	end
end

function N.driveClock(dt)
	local night = cfg.mode == "night"
	if night and not S.inNight then
		S.inNight, S.preNight, S.returning = true, Lighting.ClockTime, false
	elseif not night and S.inNight then
		S.inNight, S.returning = false, true
	end
	local want
	if night then
		want = 4.7
	elseif S.returning then
		want = S.preNight
	elseif cfg.manualTime then
		want = cfg.hour
	end
	if not want then
		return
	end
	S.touchedTime = true
	if night or S.returning then
		local c = Lighting.ClockTime
		local diff = (want - c) % 24
		if diff < 0.03 or diff > 23.97 then
			if night then
				setp(Lighting, "ClockTime", want)
			end
			S.returning = false
			return
		end
		Lighting.ClockTime = (c + math.min(diff, dt * 2.5)) % 24
	else
		setp(Lighting, "ClockTime", want)
	end
end

local function slowUpdate(dt, cam, pos, q, strength)
	local storm = math.clamp(cur.rain - 1, 0, 1)
	local baseLevel = cur.rain * strength
	local level = cfg.rain and math.min(baseLevel, 3) or 0
	local snowLevel = cfg.snow and math.min(cur.snow * strength, 2) or 0
	local windLevel = cur.wind * strength
	local accel = Vector3.new(S.windVec.X * 0.6, -40, S.windVec.Z * 0.6)
	local snowAccel = Vector3.new(S.windVec.X * 0.25, -6, S.windVec.Z * 0.25)

	for _, c in ipairs(grid) do
		if math.abs(c.storm - storm) > 0.05 then
			rainStyle(c, storm)
		end
		local near = (c.cx - pos.X) ^ 2 + (c.cz - pos.Z) ^ 2 < 1600
		local active = c.exposed and level > 0.03
		local r = active and 0.09 * c.area * q.rain * level or 0
		c.em.Rate = r
		c.em.Acceleration = accel
		c.em.Enabled = r > 0.5
		local rr = (active and c.y and near) and 0.12 * c.area * q.rain * level or 0
		local rd = (active and c.y and near) and 0.08 * c.area * q.rain * level or 0
		c.ripples.Rate, c.ripples.Enabled = rr, rr > 1
		c.drops.Rate, c.drops.Enabled = rd, rd > 1
		local sr = (c.exposed and snowLevel > 0.03) and 0.011 * c.area * q.rain * snowLevel or 0
		c.snow.Rate = sr
		c.snow.Acceleration = snowAccel
		c.snow.Enabled = sr > 0.3
	end

	local inner = (gridN * gridSize) / 2 + 20
	for _, c in ipairs(N.far.cells) do
		local outside = math.abs(c.cx - pos.X) > inner or math.abs(c.cz - pos.Z) > inner
		local r = (outside and c.exposed and level > 0.03) and 0.014 * c.area * q.rain * level or 0
		c.em.Rate = r
		c.em.Acceleration = accel
		c.em.Enabled = r > 0.5
	end

	if cfg.wind then
		local v = math.max(S.windSpeed, 5)
		windLeaves.Speed = NumberRange.new(v * 0.85, v * 1.1)
		windPollen.Speed = NumberRange.new(v * 0.8, v * 1.05)
		local open = (1 - S.muffle) ^ 2
		local rl = (3 + 7 * cur.wind) * q.wind * math.clamp(strength, 0.4, 1.5) * open
		local rp = (5 + 9 * cur.wind) * q.wind * math.clamp(strength, 0.4, 1.5) * open
		windLeaves.Rate, windLeaves.Enabled = rl, rl > 0.5
		windPollen.Rate, windPollen.Enabled = rp, rp > 0.5
	else
		windLeaves.Enabled, windPollen.Enabled = false, false
	end

	if N.mist then
		local open = (1 - S.muffle) ^ 2
		local wave = math.clamp(math.noise(S.clock * 0.04, 5.5) * 2.2 + 0.25, 0, 1)
		local target = (cfg.rainMist and q.mist > 0 and cur.rain > 0.4) and wave * math.min(cur.rain, 1.5) / 1.5 * open or 0
		S.mistV += (target - S.mistV) * (1 - math.exp(-dt * 0.8))
		local v = math.max(S.windSpeed, 4)
		N.mist.Speed = NumberRange.new(v * 0.35, v * 0.6)
		N.mist.Rate = (0.6 + 2.4 * S.mistV) * q.mist
		N.mist.Enabled = S.mistV > 0.03
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

	local dropRate, rippleRate, puffRate = 0, 0, 0
	local snowHere = cfg.snowGround and S.snowCover > 0.25 and S.floorExposed
	local rainingHere = cfg.rain and level > 0.1 and S.floorExposed
	local walking = false
	if cfg.footSplash and (snowHere or rainingHere) and hum and root and hum.FloorMaterial ~= Enum.Material.Air then
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed > 2 then
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rayParams)
			if hit then
				walking = true
				footPart.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.1, 0))
				local sp = math.clamp(speed / 16, 0, 1.6)
				S.stepTimer -= dt
				if snowHere then
					puffRate = 22 * sp * S.snowCover * q.rain
					if S.snowOk and cfg.stepSound and S.stepTimer <= 0 then
						S.stepTimer = math.clamp(0.62 - speed * 0.02, 0.3, 0.6)
						playStep("snow", S.snowCover)
					end
				else
					local wetF = 0.45 + 0.55 * S.wetness
					local f = sp * wetF * math.min(level, 1.5) * q.rain
					dropRate, rippleRate = 70 * f, 12 * f
					if S.stepOk and cfg.stepSound and S.stepTimer <= 0 then
						S.stepTimer = math.clamp(0.62 - speed * 0.02, 0.3, 0.6)
						playStep("water", wetF)
					end
				end
			end
		end
	end
	if not walking then
		S.stepTimer = 0
	end
	footDrops.Rate, footDrops.Enabled = dropRate, dropRate > 1
	footRipples.Rate, footRipples.Enabled = rippleRate, rippleRate > 1
	N.footPuff.Rate, N.footPuff.Enabled = puffRate, puffRate > 1

	updateGround(dt, level, snowLevel, pos, q)

	if level > 0.15 then
		S.puddleLevel = math.min(1, S.puddleLevel + dt / (level > 1.3 and 12 or 22))
		S.dryTimer = 0
	else
		S.dryTimer += dt
		if S.dryTimer > 8 then
			S.puddleLevel = math.max(0, S.puddleLevel - dt / 25)
		end
	end
	updatePuddles(dt, pos, level)
	N.updateMounds(dt, pos)
	N.trackSteps(dt, pos)
	N.updatePrints(dt)

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

	if cfg.metalShine and cfg.shaders and cfg.quality >= 2 then
		S.metalTimer -= dt
		if S.metalTimer <= 0 then
			S.metalTimer = 8
			scanMetal(pos, q.wet)
		end
	elseif next(metalParts) then
		restoreMetal()
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
	local indoor = S.muffle > 0.4
	local side = Vector3.new(-S.windDir.Z, 0, S.windDir.X)
	local speed = math.max(S.windSpeed, 5)
	for _, t in ipairs(trails) do
		if indoor then
			t.trail.Enabled = false
			t.fresh = true
			t.hold = 0
		else
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
	if N.mistPart then
		local mp = pos + Vector3.new(0, 3, 0)
		N.mistPart.CFrame = CFrame.lookAt(mp, mp + S.windDir)
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

	local now = os.clock()
	local farN = #N.far.cells
	if farN > 0 then
		local fx = math.floor(pos.X / 96 + 0.5)
		local fz = math.floor(pos.Z / 96 + 0.5)
		if fx ~= N.far.ix or fz ~= N.far.iz then
			N.far.ix, N.far.iz = fx, fz
			for _, c in ipairs(N.far.cells) do
				c.cx, c.cz = (fx + c.di) * 96, (fz + c.dj) * 96
				c.pending, c.exposed = true, false
			end
		end
		local fb = 2
		for _ = 1, farN do
			if fb <= 0 then
				break
			end
			S.farCursor = S.farCursor % farN + 1
			local c = N.far.cells[S.farCursor]
			if c.pending or now - c.stamp > 10 then
				N.evalFar(c, pos.Y)
				fb -= 1
			end
		end
	end

	local n = #grid
	local budget = 4
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

	if N.boltPending then
		N.boltPending = false
		N.spawnBolt(cam, pos)
	end
	N.updateBolt(dt)
	if N.rainbowPending then
		N.rainbowPending = false
		N.ensureRainbow(cam)
		local r = N.rainbow
		r.active, r.t, r.fading, r.fadeT, r.acc = true, 0, false, 0, 1
		N.placeRainbow()
	end
	N.updateRainbow(dt, cam)
	N.updateAurora(dt, cam, (cfg.aurora and cfg.shaders) and cur.night * (1 - S.dayFactor) or 0)

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

	N.driveClock(dt)

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
		S.dayFactor = 1
		return
	end
	if not S.visualOn then
		enterVisual()
	end

	local sinE = math.sin((Lighting.ClockTime - 6) / 12 * math.pi)
	local day = math.clamp((sinE + 0.05) / 0.3, 0, 1)
	S.dayFactor = day
	local nm = cur.night
	local warm = (1 - math.clamp(sinE * 2.2, 0, 1)) * day * math.clamp(cur.sun, 0, 1)
	local f = sun.facing * (1 - 0.88 * sun.occ) * math.clamp(cur.sun, 0, 1) * day
	sun.f = f
	shafts.I = math.clamp(cur.sun, 0, 1) * day
	shafts.color = Color3.fromRGB(255, 236, 195):Lerp(COL.sunLow, warm * 0.6)

	if cur.rain > 0.5 then
		S.lastRain = os.clock()
	end
	if cfg.rainbow and S.currentWeather == "sunny" and S.lastRain > 0 and os.clock() - S.lastRain < 150
		and cur.rain < 0.35 and cur.sun > 0.6 and day > 0.6 and sun.dir.Y > 0.06
		and not (N.rainbow and N.rainbow.active) then
		N.rainbowPending = true
		S.lastRain = 0
	end

	if cfg.lightning and cur.rain > 0.8 and os.clock() > S.nextBolt then
		local heavy = cur.rain > 1.4
		S.flash = heavy and 0.7 or 0.5
		S.nextBolt = os.clock() + (heavy and math.random(4, 12) or math.random(22, 55))
		N.boltPending = heavy or math.random() < 0.6
		task.delay(0.25, function()
			S.flash = math.max(S.flash, 0.3)
		end)
	end
	S.flash = math.max(0, S.flash - dt * 2.2)

	local B = N.night
	local baseB = lerp(orig.Brightness or 2, B.brightness, nm)
	local baseE = lerp(orig.ExposureCompensation or 0, B.exposure, nm)
	local baseA = (orig.Ambient or cur.ambient):Lerp(B.ambient, nm)
	local baseO = (orig.OutdoorAmbient or cur.outdoor):Lerp(B.outdoor, nm)
	local baseT = (orig.ColorShift_Top or Color3.new()):Lerp(B.shiftTop, nm)
	local baseBt = (orig.ColorShift_Bottom or Color3.new()):Lerp(B.shiftBottom, nm)
	setp(Lighting, "Brightness", lerp(baseB, cur.brightness * light, day))
	setp(Lighting, "ExposureCompensation", lerp(baseE, cur.exposure * light + f * 0.05, day) + S.flash * 0.7)
	local au = N.auroraAlpha or 0
	setp(Lighting, "Ambient", baseA:Lerp(cur.ambient, day):Lerp(Color3.fromRGB(70, 150, 130), au * 0.12))
	setp(Lighting, "OutdoorAmbient", baseO:Lerp(cur.outdoor, day):Lerp(Color3.fromRGB(80, 170, 150), au * 0.12))
	setp(Lighting, "ColorShift_Top", baseT:Lerp(cur.shiftTop:Lerp(COL.sunLow, warm * 0.6), day))
	setp(Lighting, "ColorShift_Bottom", baseBt:Lerp(cur.shiftBottom, day))
	if cfg.quality >= 2 then
		setp(Lighting, "EnvironmentDiffuseScale", math.max(orig.EnvironmentDiffuseScale or 0, 0.8))
		setp(Lighting, "EnvironmentSpecularScale", math.max(orig.EnvironmentSpecularScale or 0, 0.3 + 0.4 * S.wetness))
	end

	if sky and skySunSize then
		setp(sky, "SunAngularSize", lerp(skySunSize, skySunSize * 1.3, math.clamp(cur.sun, 0, 1)))
	end

	if atm then
		local fog = (0.4 + 0.6 * strength) * (cfg.fog and 1 or 0.3)
		atm.Density = math.clamp((cur.atmDensity * fog + 0.05 * S.mistV) * (1 - 0.4 * au), 0, 0.8)
		atm.Offset = cur.atmOffset
		atm.Haze = cur.atmHaze * (0.4 + 0.6 * strength) * (1 + warm * 0.4) * (1 - 0.4 * au)
		atm.Glare = math.min(1, cur.atmGlare * day * (1 + f * 0.6))
		atm.Color = COL.airNight:Lerp(cur.atmColor, nm):Lerp(cur.atmColor:Lerp(COL.dawnAir, warm * 0.35), day):Lerp(Color3.fromRGB(60, 160, 140), au * 0.1)
		atm.Decay = COL.decayNight:Lerp(cur.atmDecay, nm):Lerp(cur.atmDecay:Lerp(COL.decayLow, warm * 0.7), day)
	end

	if clouds then
		setp(clouds, "Enabled", true)
		clouds.Cover = math.clamp(cur.cloudCover * (0.5 + 0.5 * strength), 0, 1)
		clouds.Density = cur.cloudDensity
		clouds.Color = COL.cloudNight:Lerp(cur.cloudColor, nm):Lerp(cur.cloudColor:Lerp(COL.cloudSunset, warm * 0.5), day)
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
	if S.inNight or S.returning then
		S.inNight, S.returning = false, false
		pcall(function()
			Lighting.ClockTime = S.preNight
		end)
		S.touchedTime = false
	elseif S.touchedTime and orig.ClockTime then
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
	restoreMetal()
	S.lightsOn = false
	S.puddleLevel, S.dryTimer, S.mistV = 0, 0, 0
	screenDrops.level = 0
	sound.Volume, windSnd.Volume = 0, 0
	N.nightSnd.Volume = 0
	for _, snd in ipairs({ sound, windSnd, stepSnd, N.nightSnd, N.owlSnd }) do
		if snd.IsPlaying then
			snd:Stop()
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

do
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

end

local dropsGui = newScreen("ws_drops", 4)
do
local dropPool = {}

local function roundFrame(props, parent)
	local f = create("Frame", props, parent)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	return f
end

for i = 1, 14 do
	local tail = roundFrame({
		AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(215, 228, 245),
		BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Size = UDim2.fromOffset(2, 2),
	}, dropsGui)
	local body = roundFrame({
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(200, 218, 240),
		BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Size = UDim2.fromOffset(8, 10),
	}, dropsGui)
	local stroke = create("UIStroke", { Thickness = 1.2, Transparency = 1, Color = Color3.new(1, 1, 1) }, body)
	create("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 185, 215)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 55, 75)),
		}),
	}, stroke)
	local shine = roundFrame({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.34, 0.3), Size = UDim2.fromScale(0.3, 0.24),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
	}, body)
	dropPool[i] = { tail = tail, body = body, stroke = stroke, shine = shine, alive = false, t = 0, life = 1, x = 0, y = 0, y0 = 0, vy = 0, w = 8, slides = false, slideAt = 0.5 }
end

local function killDrop(d)
	d.alive = false
	d.tail.Visible = false
	d.body.Visible = false
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
		S.dropAcc += dt * 1.2 * math.min(screenDrops.level, 1.2)
		while S.dropAcc >= 1 do
			S.dropAcc -= 1
			for i = 1, n do
				local d = dropPool[i]
				if not d.alive then
					d.alive = true
					d.t = 0
					d.life = 3.5 + math.random() * 2.5
					d.w = (6 + math.random() * 7) * scale
					d.x = math.random() * vp.X
					d.y = math.random() * vp.Y * 0.8
					d.y0 = d.y
					d.vy = 0
					d.slides = math.random() < 0.55
					d.slideAt = 0.4 + math.random() * 0.3
					d.body.Visible = true
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
				killDrop(d)
			else
				local a = math.min(k / 0.1, 1) * (1 - math.clamp((k - 0.7) / 0.3, 0, 1))
				local grow = 0.6 + 0.4 * math.min(k / 0.2, 1)
				local sliding = d.slides and k > d.slideAt
				if sliding then
					d.vy += dt * 220 * scale
					d.y += d.vy * dt
				end
				local h = d.w * grow * (sliding and 1.45 or 1.2)
				d.body.Size = UDim2.fromOffset(d.w * grow, h)
				d.body.Position = UDim2.fromOffset(d.x, d.y)
				d.body.BackgroundTransparency = 1 - 0.1 * a
				d.stroke.Transparency = 1 - 0.65 * a
				d.shine.BackgroundTransparency = 1 - 0.65 * a
				local len = d.y - d.y0
				if sliding and len > 3 then
					d.tail.Visible = true
					d.tail.Position = UDim2.fromOffset(d.x, d.y0)
					d.tail.Size = UDim2.fromOffset(d.w * 0.28, len)
					d.tail.BackgroundTransparency = 1 - 0.1 * a
				end
			end
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
		if S.stepOk then
			for i = 1, 3 do
				local c = stepSnd:Clone()
				c.Name = "ws_step_" .. i
				c.Volume = 0
				c.Parent = SoundService
				stepPool[i] = c
			end
		end
	end)
	task.spawn(function()
		S.snowOk = loadFirst(N.snowSnd, N.snowIds, 0.05)
		if S.snowOk then
			for i = 1, 3 do
				local c = N.snowSnd:Clone()
				c.Name = "ws_snow_" .. i
				c.Volume = 0
				c.Parent = SoundService
				N.snowPool[i] = c
			end
		end
	end)
	task.spawn(function()
		S.nightOk = loadFirst(N.nightSnd, N.nightIds, 3)
	end)
	task.spawn(function()
		S.owlOk = loadFirst(N.owlSnd, N.owlIds, 0.5)
	end)
	task.spawn(function()
		S.thunderOk = loadFirst(N.thunderTemplate, N.thunderIds, 0.5)
		if S.thunderOk then
			for i = 1, 2 do
				local c = N.thunderTemplate:Clone()
				c.Name = "ws_thunder_" .. i
				c.Volume = 0
				c.Parent = SoundService
				create("EqualizerSoundEffect", {}, c)
				N.thunderPool[i] = c
			end
		end
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

	local weatherIds = { "auto", "sunny", "cloudy", "rainy", "storm", "snow", "night" }
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
	toggle(secRain, T("rain_mist"), T("rain_mist_d"), "rainMist")
	toggle(secRain, T("lightning"), T("lightning_d"), "lightning")
	slider(secRain, T("volume"), "volume", 0, 100, 100)

	local secSnow = tabWeather:Section({ Title = T("sec_snow") })
	toggle(secSnow, T("snow"), T("snow_d"), "snow")
	toggle(secSnow, T("snow_ground"), T("snow_ground_d"), "snowGround")

	local secNight = tabWeather:Section({ Title = T("w_night") })
	toggle(secNight, T("aurora"), T("aurora_d"), "aurora")
	toggle(secNight, T("night_sound"), T("night_sound_d"), "nightSound")

	local secAir = tabWeather:Section({ Title = T("sec_air") })
	toggle(secAir, T("wind"), T("wind_d"), "wind")
	toggle(secAir, T("wind_sound"), T("wind_sound_d"), "windSound")
	toggle(secAir, T("fog"), T("fog_d"), "fog")

	local tabLight = Window:Tab({ Title = T("tab_light"), Icon = "sun" })
	local secLight = tabLight:Section({ Title = T("sec_light") })
	toggle(secLight, T("shaders"), T("shaders_d"), "shaders")
	toggle(secLight, T("flare"), T("flare_d"), "flare")
	toggle(secLight, T("rainbow"), T("rainbow_d"), "rainbow")
	toggle(secLight, T("shafts"), T("shafts_d"), "shafts")
	toggle(secLight, T("shadows"), nil, "shadows")
	toggle(secLight, T("lights"), T("lights_d"), "lights")
	toggle(secLight, T("water"), T("water_d"), "waterFx")
	toggle(secLight, T("shine"), T("shine_d"), "metalShine")
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
	for _, list in ipairs({ stepPool, N.snowPool, N.thunderPool }) do
		for _, c in ipairs(list) do
			pcall(function()
				c:Destroy()
			end)
		end
	end
	for _, o in ipairs({ N.snowSnd, N.nightSnd, N.owlSnd, N.thunderTemplate }) do
		pcall(function()
			o:Destroy()
		end)
	end
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
