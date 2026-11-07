----------------------------------------------------------------------
-- config.lua  –  Configuracion centralizada y persistente para Qwen-Widget
--                Arquitectura Hibrida Lua + C/C++, llama.cpp y Cloud API
----------------------------------------------------------------------
local config = {}

local ok_j, json = pcall(require, "json")
if not ok_j then json = nil end

local ok_lgi, lgi = pcall(require, "lgi")
local GLib = ok_lgi and lgi.GLib or nil

local function ensure_dir(dir_path)
    if not dir_path or dir_path == "" then return false end
    if GLib and GLib.mkdir_with_parents then
        return GLib.mkdir_with_parents(dir_path, 493) == 0 -- 0755
    end
    if dir_path:match("^[A-Za-z0-9%_%-%./]+$") then
        os.execute(string.format("mkdir -p '%s' 2>/dev/null", dir_path))
        return true
    end
    return false
end

----------- Paths (se sobreescriben en main.lua) ---------------------
local home_user = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
local kitsu_conf_dir = home_user .. "/.config/kitsu"
local legacy_conf_dir = home_user .. "/.config/qwen-widget"

-- Migracion transparente desde configuraciones anteriores si existen
if not io.open(kitsu_conf_dir .. "/config.json", "r") and io.open(legacy_conf_dir .. "/config.json", "r") then
    ensure_dir(kitsu_conf_dir)
    if kitsu_conf_dir:match("^[A-Za-z0-9%_%-%./]+$") and legacy_conf_dir:match("^[A-Za-z0-9%_%-%./]+$") then
        os.execute(string.format("cp -a '%s/'* '%s/' 2>/dev/null", legacy_conf_dir, kitsu_conf_dir))
    end
end

local function detect_base_dir()
    local env_dir = os.getenv("KITSU_DIR") or os.getenv("KITSU_ROOT") or os.getenv("QWEN_WIDGET_DIR")
    if env_dir and #env_dir > 0 then return env_dir end

    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local dir = src:match("(.+)/lib/[^/]+$") or src:match("(.+)/[^/]+$")
        if dir and dir ~= "" then return dir end
    end

    for _, cand in ipairs({ "/opt/kitsu", "/opt/qwen-widget", "." }) do
        local f = io.open(cand .. "/lib/main.lua", "r")
        if f then f:close(); return cand end
    end
    return "."
end

config.BASE_DIR    = detect_base_dir()
config.ASSETS_DIR  = config.BASE_DIR .. "/assets"
config.AVATAR      = config.ASSETS_DIR .. "/avatar.jpg"
config.custom_avatar = nil
config.theme       = "navi_lain"
config.theme_mode  = "dark"
config.system_prompt = nil
config.chat_header   = nil
config.CONFIG_PATH = kitsu_conf_dir .. "/config.json"
config.SECRETS_PATH = kitsu_conf_dir .. "/secrets.json"

----------- Configuracion de Modelos e Inferencia (llama.cpp + Cloud)
config.inference_provider = "local"              -- "local" (llama.cpp) | "cloud"
config.backend_mode       = "llama"              -- Embebido llama.cpp por defecto
config.chat_model         = "qwen3.0-0.8b.gguf"  -- Modelo conversacional GGUF (0.8b)
config.grammar_model      = "es-grammar.gguf"    -- Modelo corrector gramatical GGUF
config.llama_model        = "qwen3.0-0.8b.gguf"
config.ollama_model       = "qwen3.0-0.8b.gguf"  -- Alias de compatibilidad
config.threads            = 4                    -- Hilos CPU
config.ctx_size           = 512                  -- Contexto optimizado (<= 500 MB RAM)
config.kv_quant           = "q4_0"               -- Cuantizacion de cache KV
config.ram_limit          = "500MB"              -- Presupuesto estricto <= 500 MB

----------- Configuracion Cloud API ----------------------------------
config.cloud_provider     = "openai"             -- "openai" | "gemini" | "anthropic" | "openrouter" | "custom"
config.cloud_model        = "gpt-4o-mini"
config.cloud_endpoint     = "https://api.openai.com/v1/chat/completions"

----------- Musica y Letras Sincronizadas (YT Music + Spotify) -------
config.music_source       = "auto"               -- "auto" | "ytmusic" | "spotify"
config.lyrics_offset_ms   = 0                    -- Ajuste fino de sincronizacion en ms

----------- Habilidades del Widget y Menu Global ---------------------
config.skills = {
    -- Menu Global Autodesplegable al seleccionar texto (C/C++ Native Hook)
    global_text_menu = true,

    -- Habilidades individuales de escritura (es-grammar.gguf)
    skill_formalize = true,
    skill_spelling  = true,
    skill_expand    = true,
    skill_summarize = true,
    skill_humanize  = true,
    skill_simplify  = true,
    skill_grammar   = true,

    -- Habilidades operativas del agente (OpenClaw)
    system_info      = true,
    bash             = true,
    media_control    = true,
    web_search       = true,
    app_launch       = true,
    screenshot       = true,
    notify           = true,
    openclaw_gateway = true,

    -- Componentes de interfaz del widget
    data_bubbles     = true,
    lyrics           = true,
    player           = true,
}

----------- Bubble (circulo flotante con sprites de estado) ----------
config.BUBBLE_SIZE      = 72
config.BUBBLE_MARGIN    = 8
config.BUBBLE_RADIUS    = 36
config.GLOW_WIDTH       = 2
config.rounded_corners  = true -- Bordes redondeados por defecto (modo original)

----------- Launcher radial ------------------------------------------
config.LAUNCHER_ENABLED  = false
config.LAUNCHER_RADIUS   = 80
config.LAUNCHER_SPAN_DEG = 185
config.LAUNCHER_BTN_SIZE = 42
config.LAUNCHER_HOVER_MS = 200
config.LAUNCHER_LEAVE_MS = 450
config.LAUNCHER_ANIM_MS  = 300

----------- Chat panel -----------------------------------------------
config.CHAT_W      = 400
config.CHAT_H      = 510
config.CHAT_GAP    = 12
config.CHAT_RADIUS = 16

----------- Data bubbles (burbujas de datos dinamicas) ---------------
config.DBUBBLE_MAX_TEXT_W = 290
config.DBUBBLE_SHOW_MS    = 12000
config.DBUBBLE_CYCLE_MS   = 60000
config.DBUBBLE_FADE_MS    = 200

----------- Sistema de Diseno y Contraste Garantizado (Paleta Profesional) ----
config.BG           = { 0.086, 0.090, 0.098, 0.96 } -- #161719 Deep Graphite Slate
config.BG_CHAT      = { 0.098, 0.102, 0.110, 0.97 } -- #191A1C Neutral Dark Slate
config.BG_DBUBBLE   = { 0.118, 0.122, 0.133, 0.96 } -- #1E1F22 Dark Neutral Slate
config.TEXT         = { 1.000, 1.000, 1.000, 1.0  } -- #FFFFFF Pure High-Contrast White
config.TEXT_DIM     = { 0.700, 0.720, 0.760, 1.0  } -- #B0B5C0 Refined Titanium Gray
config.ACCENT       = { 0.380, 0.520, 0.850, 1.0  } -- #6185D9 Professional Slate Blue
config.ACCENT_PINK  = { 0.820, 0.420, 0.520, 1.0  } -- #D16B85 Muted Coral
config.ACCENT_CYAN  = { 0.280, 0.700, 0.820, 1.0  } -- #47B2D1 Cool Steel
config.INPUT_BG     = { 0.130, 0.135, 0.145, 0.96 } -- #212225 Dark Charcoal
config.NOTIFICATION = { 0.940, 0.680, 0.220, 1.0  } -- #F0AD38 Titanium Gold

-- Variables explicitas de alto contraste para menus y botones
config.CONTRAST = {
    normal   = { background = "#161719", foreground = "#FFFFFF", border = "#2E3138" },
    hover    = { background = "#FFFFFF", foreground = "#121316", border = "#FFFFFF" },
    active   = { background = "#384358", foreground = "#FFFFFF", border = "#637394" },
    disabled = { background = "#1C1D21", foreground = "#6B7280", border = "#282A30" },
}

----------- Fonts (con fallback seguro) ------------------------------
config.FONT_DATA    = "Sans 11"
config.FONT_LABEL   = "Sans Bold 9"
config.FONT_CHAT    = "Sans 11.5"
config.FONT_INPUT   = "Sans 11.5"
config.FONT_NOTIF   = "Sans Bold 10"
config.FONT_DBUBBLE = "Sans 10.5"

----------- Data refresh intervals (ms) ------------------------------
config.CLOCK_INTERVAL      = 1000
config.DATA_FETCH_INTERVAL = 300000

----------- API endpoints --------------------------------------------
config.WEATHER_URL         = "https://wttr.in/?format=j1"
config.CRYPTO_URL          = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=mxn,usd&include_24hr_change=true"
config.CRYPTO_FALLBACK_URL = "https://api.binance.com/api/v3/ticker/24hr?symbol=BTCUSDT"
config.FOREX_URL           = "https://open.er-api.com/v6/latest/USD"

----------- Compatibilidad -------------------------------------------
config.OLLAMA_URL   = "http://127.0.0.1:18089/v1/chat/completions"
config.OLLAMA_MODEL = config.chat_model

----------- Animations -----------------------------------------------
config.FADE_DURATION_MS = 280
config.SNAP_DURATION_MS = 220
config.ANIM_FPS         = 60
config.SNAP_THRESHOLD   = 50

----------- DBus / KDE Connect ---------------------------------------
config.KDECONNECT_BUS   = "org.kde.kdeconnect"
config.NOTIF_TIMEOUT_MS = 8000

----------- YouTube Music + Spotify Mini Player ----------------------
config.PLAYER_W            = 372
config.PLAYER_H            = 192
config.PLAYER_RADIUS       = 15
config.PLAYER_GAP          = 10
config.PLAYER_AUTO_HIDE_MS = 14000
config.PLAYER_COVER_SIZE   = 68
config.PLAYER_UPDATE_MS    = 250

----------- Letras Sincronizadas (YT Music + Spotify) ----------------
config.LYRICS_ENABLED = config.skills.lyrics
config.LYRICS_MAX_W   = 330
config.LYRICS_MIN_W   = 130
config.FONT_LYRICS    = "Sans Bold 11"
config.BG_LYRICS      = { 0.07, 0.08, 0.14, 0.95 }
config.BORDER_LYRICS  = { 0.925, 0.365, 0.640, 0.85 }
config.LYRICS_GAP     = 8
config.LYRICS_FADE_MS = 160

----------- OpenClaw Agent -------------------------------------------
config.OPENCLAW_AGENT_MODE  = true
config.OPENCLAW_GATEWAY_URL = "http://127.0.0.1:18789"
config.OPENCLAW_TIMEOUT_SEC = 6
config.OPENCLAW_RETRIES     = 2
config.AGENT_NAME           = "OpenClaw-Qwen"
config.AGENT_VERSION        = "2.4.1-native"

----------- Getters / Setters seguros --------------------------------
function config.get(key, default_val)
    if config[key] ~= nil then
        return config[key]
    end
    if config.skills and config.skills[key] ~= nil then
        return config.skills[key]
    end
    return default_val
end

function config.set(key, val)
    if config.skills and config.skills[key] ~= nil and type(val) == "boolean" then
        config.skills[key] = val
    else
        config[key] = val
    end
    config.notify_change(key, val)
end

----------- Listeners para actualizacion en caliente -----------------
config._listeners = {}

function config.add_listener(fn)
    if type(fn) == "function" then
        table.insert(config._listeners, fn)
    end
end

function config.notify_change(key, value)
    config.OLLAMA_MODEL   = config.chat_model
    config.LYRICS_ENABLED = (config.skills.lyrics == true)
    for _, fn in ipairs(config._listeners) do
        pcall(fn, key, value)
    end
end

----------- Persistencia Ligera --------------------------------------
function config.save()
    if not json then
        local ok, j = pcall(require, "json")
        if ok then json = j end
    end
    if not json then return false end

    local payload = {
        inference_provider = config.inference_provider,
        backend_mode       = config.backend_mode,
        chat_model         = config.chat_model,
        grammar_model      = config.grammar_model,
        llama_model        = config.llama_model,
        ollama_model       = config.ollama_model,
        threads            = config.threads,
        ctx_size           = config.ctx_size,
        kv_quant           = config.kv_quant,
        ram_limit          = config.ram_limit,
        cloud_provider     = config.cloud_provider,
        cloud_model        = config.cloud_model,
        cloud_endpoint     = config.cloud_endpoint,
        music_source       = config.music_source,
        lyrics_offset_ms   = config.lyrics_offset_ms,
        custom_avatar      = config.custom_avatar,
        theme              = config.theme,
        theme_mode         = config.theme_mode,
        rounded_corners    = (config.rounded_corners == true),
        OPENCLAW_GATEWAY_URL = config.OPENCLAW_GATEWAY_URL,
        skills             = config.skills,
    }

    local dir = config.CONFIG_PATH:match("(.+)/[^/]+$")
    if dir then
        ensure_dir(dir)
    end

    local f = io.open(config.CONFIG_PATH, "w")
    if f then
        f:write(json.encode(payload))
        f:close()
        payload = nil
        collectgarbage("step", 100)
        return true
    end
    return false
end

function config.load()
    local f = io.open(config.CONFIG_PATH, "r")
    if not f then return false end
    local content = f:read("*a")
    f:close()

    if not content or #content == 0 then return false end

    if not json then
        local ok, j = pcall(require, "json")
        if ok then json = j end
    end
    if not json then return false end

    local ok_d, d = pcall(json.decode, content)
    if ok_d and d and type(d) == "table" then
        if d.inference_provider then config.inference_provider = d.inference_provider end
        if d.backend_mode       then config.backend_mode       = d.backend_mode end
        if d.chat_model         then config.chat_model         = d.chat_model end
        if d.grammar_model      then config.grammar_model      = d.grammar_model end
        if d.llama_model        then config.llama_model        = d.llama_model end
        if d.threads            then config.threads            = tonumber(d.threads) or config.threads end
        if d.ctx_size           then config.ctx_size           = tonumber(d.ctx_size) or config.ctx_size end
        if d.kv_quant           then config.kv_quant           = d.kv_quant end
        if d.ram_limit          then config.ram_limit          = d.ram_limit end
        if d.cloud_provider     then config.cloud_provider     = d.cloud_provider end
        if d.cloud_model        then config.cloud_model        = d.cloud_model end
        if d.cloud_endpoint     then config.cloud_endpoint     = d.cloud_endpoint end
        if d.music_source       then config.music_source       = d.music_source end
        if d.lyrics_offset_ms   then config.lyrics_offset_ms   = tonumber(d.lyrics_offset_ms) or 0 end
        if d.custom_avatar and type(d.custom_avatar) == "string" and #d.custom_avatar > 0 then
            config.custom_avatar = d.custom_avatar
        else
            config.custom_avatar = nil
        end
        if d.theme and type(d.theme) == "string" and #d.theme > 0 then
            config.theme = d.theme
        end
        if d.theme_mode and type(d.theme_mode) == "string" and #d.theme_mode > 0 then
            config.theme_mode = d.theme_mode
        end
        if d.rounded_corners ~= nil then
            config.rounded_corners = (d.rounded_corners == true)
        else
            config.rounded_corners = false
        end
        if d.OPENCLAW_GATEWAY_URL then config.OPENCLAW_GATEWAY_URL = d.OPENCLAW_GATEWAY_URL end

        if d.skills and type(d.skills) == "table" then
            for k, v in pairs(d.skills) do
                config.skills[k] = (v == true)
            end
        end

        -- Garantizar migracion limpia a llama.cpp si un config antiguo tenia "ollama"
        if config.backend_mode == "ollama" then
            config.backend_mode = "llama"
        end

        config.OLLAMA_MODEL   = config.chat_model
        config.LYRICS_ENABLED = (config.skills.lyrics == true)
        d = nil
        content = nil
        collectgarbage("step", 100)
        return true
    end
    return false
end

config.load()

return config
