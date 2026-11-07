----------------------------------------------------------------------
-- chat.lua  –  Rediseño Completo de Ventana Flotante de Chat y Ajustes
--              - Selector rápido Local (llama.cpp) vs. Cloud API
--              - Indicador de generación en streaming + telemetría RAM
--              - Menú de Configuraciones organizado en 6 secciones:
--                (General, Modelos Locales, API Cloud, Música, Gramática, OpenClaw)
--              - Seguimiento dinámico en tiempo real (chat.reposition)
--              - Cero emojis y contraste garantizado en todos los estados
----------------------------------------------------------------------
local lgi    = require("lgi")
local Gtk    = lgi.require("Gtk", "3.0")
local Gdk    = lgi.require("Gdk", "3.0")
local GLib   = lgi.GLib
local Pango  = lgi.Pango
local cairo  = lgi.cairo

local config    = require("config")
local utils     = require("utils")
local ai_engine = require("ai_engine")
local model_mgr = require("model_manager")
local animator  = require("animator")
local openclaw  = require("openclaw_agent")
local player    = require("player")
local manager   = require("skills.manager")

local ok_native, qwen_native = pcall(require, "qwen_native")
if not ok_native then qwen_native = nil end

local chat = {}

chat.window           = nil
chat.visible          = false
chat.textview         = nil
chat.entry            = nil
chat.scroll           = nil
chat.buffer           = nil
chat.status_label     = nil
chat.model_label      = nil
chat.ram_label        = nil
chat.provider_btn     = nil
chat.on_invoke_bubble = nil
chat.on_state_change  = nil -- function("chatting" | "thinking" | "error" | "idle")

local last_bx, last_by = 0, 0
local last_bsize       = config.BUBBLE_SIZE or 72
local last_edge        = "right"
local cur_cx, cur_cy   = nil, nil

local CSS = [[
/* Base Window Containers */
.chat-window {
    background-color: transparent;
}
.chat-scroll {
    background-color: transparent;
}
.chat-scroll scrollbar slider {
    background-color: rgba(97, 133, 217, 0.40);
    min-width: 5px;
    border-radius: 3px;
}
.chat-scroll scrollbar slider:hover {
    background-color: rgba(97, 133, 217, 0.85);
}

/* Chat text display - Modo Oscuro (Pure White Text) */
.chat-text {
    background-color: transparent;
    color: #FFFFFF;
    font-family: "Sans";
    font-size: 11.5px;
    padding: 8px 12px;
}
.chat-text text {
    background-color: transparent;
    color: #FFFFFF;
}

/* Text entries - Modo Oscuro */
.chat-entry {
    background-color: #12141A;
    color: #FFFFFF;
    border: 1.2px solid #2D3039;
    border-radius: 10px;
    padding: 7px 12px;
    font-family: "Sans";
    font-size: 11.5px;
    caret-color: #FFFFFF;
}
.chat-entry:focus {
    border-color: #6185D9;
    background-color: #181A22;
}

/* Send button - Modo Oscuro */
.send-btn {
    background-color: #2D313B;
    background-image: none;
    color: #FFFFFF;
    border: 1px solid #4B5160;
    border-radius: 10px;
    min-width: 62px;
    min-height: 30px;
    padding: 0 10px;
    font-family: "Sans";
    font-size: 10.5px;
    font-weight: bold;
}
.send-btn:hover {
    background-color: #FFFFFF;
    background-image: none;
    color: #0E1014;
    border-color: #FFFFFF;
}
.send-btn:disabled {
    background-color: #16181F;
    color: #6B7280;
    border-color: #242730;
}

/* Header bar elements - Modo Oscuro */
.chat-header {
    color: #FFFFFF;
    font-family: "Sans";
    font-weight: bold;
    font-size: 12px;
}
.model-pill {
    background-color: #181A22;
    background-image: none;
    color: #D1D5DB;
    border: 1px solid #373C47;
    border-radius: 8px;
    padding: 2px 8px;
    font-family: "Sans";
    font-size: 9.5px;
    font-weight: bold;
}
.model-pill:hover {
    background-color: #FFFFFF;
    color: #0E1014;
    border-color: #FFFFFF;
}
.ram-badge {
    color: #E2E8F0;
    font-family: "Monospace";
    font-size: 9px;
    font-weight: bold;
}
.status-label {
    color: #9CA3AF;
    font-family: "Sans";
    font-size: 10px;
    font-weight: 600;
}
.chat-close-btn {
    background-color: #181A20;
    background-image: none;
    color: #9CA3AF;
    border: 1px solid #2D3039;
    border-radius: 7px;
    min-width: 24px;
    min-height: 22px;
    padding: 0 6px;
    font-family: "Sans";
    font-size: 10px;
    font-weight: bold;
}
.chat-close-btn:hover {
    color: #FFFFFF;
    background-color: #DC2626;
    border-color: #EF4444;
}

/* Action toolbar - Modo Oscuro */
.toolbar-box {
    background-color: #111216;
    border-radius: 10px;
    padding: 4px 8px;
    margin: 4px 12px;
    border: 1px solid #22252E;
}
.tool-btn {
    background-color: #181920;
    background-image: none;
    color: #D1D5DB;
    border: 1px solid #323640;
    border-radius: 8px;
    padding: 3px 9px;
    font-family: "Sans";
    font-size: 9.5px;
    font-weight: 600;
}
.tool-btn:hover {
    background-color: #FFFFFF;
    background-image: none;
    color: #0E1014;
    border-color: #FFFFFF;
}
.tool-btn-accent {
    background-color: #2D313B;
    background-image: none;
    color: #FFFFFF;
    border: 1px solid #637394;
    border-radius: 8px;
    padding: 3px 9px;
    font-family: "Sans";
    font-size: 9.5px;
    font-weight: bold;
}
.tool-btn-accent:hover {
    background-color: #FFFFFF;
    background-image: none;
    color: #0E1014;
    border-color: #FFFFFF;
}

/* Navigation tabs - Modo Oscuro */
.tab-btn {
    background-color: #14161C;
    background-image: none;
    color: #9CA3AF;
    border: 1px solid #282B33;
    border-radius: 9px;
    padding: 4px 12px;
    font-family: "Sans";
    font-size: 10px;
    font-weight: bold;
}
.tab-btn:hover {
    color: #0E1014;
    background-color: #FFFFFF;
    border-color: #FFFFFF;
}
.tab-btn-active {
    background-color: #2D313B;
    background-image: none;
    color: #FFFFFF;
    border: 1px solid #8E95A5;
    border-radius: 9px;
    padding: 4px 12px;
    font-family: "Sans";
    font-size: 10px;
    font-weight: bold;
}

/* Config view - Modo Oscuro (Pure White Text & Titles) */
.config-scroll {
    background-color: transparent;
}
.config-box {
    padding: 6px 14px 16px 14px;
}
.config-section-title {
    color: #FFFFFF;
    font-family: "Sans";
    font-size: 10.5px;
    font-weight: bold;
    margin-top: 10px;
    margin-bottom: 4px;
}
.config-card {
    background-color: #121317;
    border: 1px solid #262932;
    border-radius: 10px;
    padding: 7px 10px;
    margin-bottom: 8px;
}
.config-row {
    padding: 3px 0;
}
.config-label {
    color: #FFFFFF;
    font-family: "Sans";
    font-size: 10.5px;
    font-weight: 600;
}
.config-desc {
    color: #9CA3AF;
    font-family: "Sans";
    font-size: 8.5px;
}
.config-entry {
    background-color: #0B0C10;
    background-image: none;
    color: #FFFFFF;
    border: 1px solid #323640;
    border-radius: 7px;
    padding: 3px 8px;
    font-family: "Sans";
    font-size: 10px;
}
.config-entry:focus {
    border-color: #8E95A5;
}
.pill-choice {
    background-color: #181A22;
    background-image: none;
    color: #D1D5DB;
    border: 1px solid #373C47;
    border-radius: 7px;
    padding: 3px 8px;
    font-family: "Sans";
    font-size: 9.5px;
    font-weight: 600;
}
.pill-choice:hover {
    background-color: #FFFFFF;
    background-image: none;
    color: #0E1014;
    border-color: #FFFFFF;
}
.pill-choice-active {
    background-color: #2D313B;
    background-image: none;
    color: #FFFFFF;
    border: 1px solid #8E95A5;
    border-radius: 7px;
    padding: 3px 8px;
    font-family: "Sans";
    font-size: 9.5px;
    font-weight: bold;
}
switch {
    background-color: #1C1E26;
    border: 1px solid #373C47;
    border-radius: 12px;
}
switch:checked {
    background-color: #3E4452;
    border-color: #8E95A5;
}
switch slider {
    background-color: #FFFFFF;
    border-radius: 10px;
}
combobox,
combobox button,
combobox window {
    background-color: #181A22;
    color: #FFFFFF;
    border: 1px solid #373C47;
    border-radius: 7px;
    padding: 2px 6px;
    font-family: "Sans";
}
combobox button:hover {
    border-color: #D1D5DB;
}

/* ====================================================================
   Modo Claro (.theme-light) - Pure Black Text & High Contrast Light UI
   ==================================================================== */
.theme-light .chat-text,
.theme-light .chat-text text {
    color: #000000;
}
.theme-light .chat-entry {
    background-color: #FFFFFF;
    color: #000000;
    border: 1.2px solid #CBD5E1;
    caret-color: #000000;
}
.theme-light .chat-entry:focus {
    background-color: #F8FAFC;
    border-color: #000000;
}
.theme-light .send-btn {
    background-color: #0E1014;
    background-image: none;
    color: #FFFFFF;
    border: 1px solid #000000;
}
.theme-light .send-btn:hover {
    background-color: #2D313B;
    color: #FFFFFF;
}
.theme-light .tab-btn {
    background-color: #F1F5F9;
    color: #475569;
    border: 1px solid #CBD5E1;
}
.theme-light .tab-btn:hover {
    background-color: #0E1014;
    color: #FFFFFF;
}
.theme-light .tab-btn-active {
    background-color: #0E1014;
    background-image: none;
    color: #FFFFFF;
    border: 1px solid #000000;
}
.theme-light .toolbar-box {
    background-color: #F1F5F9;
    border: 1px solid #E2E8F0;
}
.theme-light .tool-btn {
    background-color: #FFFFFF;
    color: #000000;
    border: 1px solid #CBD5E1;
}
.theme-light .tool-btn:hover {
    background-color: #0E1014;
    color: #FFFFFF;
}
.theme-light .tool-btn-accent {
    background-color: #0E1014;
    color: #FFFFFF;
    border: 1px solid #000000;
}
.theme-light .tool-btn-accent:hover {
    background-color: #2D313B;
    color: #FFFFFF;
}
.theme-light .chat-header {
    color: #000000;
}
.theme-light .model-pill {
    background-color: #FFFFFF;
    color: #000000;
    border: 1px solid #CBD5E1;
}
.theme-light .model-pill:hover {
    background-color: #0E1014;
    color: #FFFFFF;
}
.theme-light .chat-close-btn {
    background-color: #F1F5F9;
    color: #000000;
    border: 1px solid #CBD5E1;
}
.theme-light .chat-close-btn:hover {
    background-color: #DC2626;
    color: #FFFFFF;
    border-color: #EF4444;
}
.theme-light .status-label {
    color: #0369A1;
}
.theme-light .ram-badge {
    color: #047857;
}
.theme-light .config-card {
    background-color: #FFFFFF;
    border: 1px solid #CBD5E1;
}
.theme-light .config-label {
    color: #000000;
}
.theme-light .config-desc {
    color: #475569;
}
.theme-light .config-section-title {
    color: #000000;
}
.theme-light .config-entry {
    background-color: #FFFFFF;
    color: #000000;
    border: 1px solid #CBD5E1;
}
.theme-light .pill-choice {
    background-color: #F8FAFC;
    color: #000000;
    border: 1px solid #CBD5E1;
}
.theme-light .pill-choice:hover {
    background-color: #0E1014;
    color: #FFFFFF;
}
.theme-light .pill-choice-active {
    background-color: #0E1014;
    background-image: none;
    color: #FFFFFF;
    border: 1px solid #000000;
}
.theme-light switch {
    background-color: #E2E8F0;
    border: 1px solid #CBD5E1;
}
.theme-light switch:checked {
    background-color: #0E1014;
}
.theme-light combobox,
.theme-light combobox button {
    background-color: #FFFFFF;
    color: #000000;
    border: 1px solid #CBD5E1;
}

/* Sharp Corners (0px) when rounded_corners = false */
.sharp-corners .chat-entry,
.sharp-corners .send-btn,
.sharp-corners .tab-btn,
.sharp-corners .tab-btn-active,
.sharp-corners .tool-btn,
.sharp-corners .tool-btn-accent,
.sharp-corners .model-pill,
.sharp-corners .chat-close-btn,
.sharp-corners .toolbar-box,
.sharp-corners .config-card,
.sharp-corners .config-entry,
.sharp-corners .pill-choice,
.sharp-corners .pill-choice-active,
.sharp-corners switch,
.sharp-corners switch slider,
.sharp-corners combobox,
.sharp-corners combobox button,
.sharp-corners .chat-avatar {
    border-radius: 0px;
}
]]

local css_applied = false
local function apply_css()
    if css_applied then return end
    css_applied = true
    local provider = Gtk.CssProvider()
    pcall(function()
        provider:load_from_data(CSS, #CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    end)
end

local function scroll_to_bottom()
    if not chat.scroll then return end
    GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
        local adj = chat.scroll:get_vadjustment()
        adj:set_value(adj:get_upper() - adj:get_page_size())
        return false
    end)
end

local function update_header_badges()
    local mode = config.inference_provider or "local"
    if chat.provider_btn then
        if mode == "cloud" then
            local prov = (config.cloud_provider or "openai"):upper()
            chat.provider_btn:set_label("CLOUD: " .. prov)
        else
            local m = (config.chat_model or "qwen3.0-0.8b.gguf"):gsub("%.gguf$", "")
            chat.provider_btn:set_label("LOCAL: " .. m)
        end
    end
    if chat.ram_label and qwen_native and qwen_native.get_memory_stats then
        local ms = qwen_native.get_memory_stats()
        if ms and ms.total_rss_mb then
            chat.ram_label:set_text(string.format("%.0f/500MB", ms.total_rss_mb))
        end
    end
end

local function md_to_pango(text)
    if not text or #text == 0 then return "" end
    local is_light = (config.theme_mode == "light")
    local s = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

    local bold_color = is_light and "#000000" or "#FFFFFF"
    local code_bg    = is_light and "#E2E8F0" or "#161D33"
    local code_fg    = is_light and "#0F172A" or "#93C5FD"
    local block_bg   = is_light and "#EDF2F7" or "#0B0E1A"
    local block_fg   = is_light and "#0F172A" or "#38BDF8"
    local italic_fg  = is_light and "#334155" or "#CBD5E1"
    local h1_color   = is_light and "#000000" or "#FFFFFF"
    local h2_color   = is_light and "#0284C7" or "#60A5FA"
    local h3_color   = is_light and "#0369A1" or "#38BDF8"

    s = s:gsub("```[%w_%-]*\n?(.-)```", function(code)
        local clean = code:gsub("^[\r\n]+", ""):gsub("[\r\n]+$", "")
        return string.format(
            '<span font_family="Monospace" background="%s" foreground="%s">\n  %s\n</span>',
            block_bg, block_fg,
            clean:gsub("\n", "\n  ")
        )
    end)

    s = s:gsub("`([^`\n]+)`", string.format('<span font_family="Monospace" background="%s" foreground="%s"> %%1 </span>', code_bg, code_fg))
    s = s:gsub("%*%*([^\n%*]+)%*%*", string.format('<span weight="bold" foreground="%s">%%1</span>', bold_color))
    s = s:gsub("__([^\n_]+)__", string.format('<span weight="bold" foreground="%s">%%1</span>', bold_color))
    s = s:gsub("(%f[%w*])%*([^\n%*]+)%*(%f[%W*])", string.format('<span style="italic" foreground="%s">%%2</span>', italic_fg))
    s = s:gsub("(^|\n)###%s+([^\n]+)", string.format('%%1<span weight="bold" foreground="%s">%%2</span>', h3_color))
    s = s:gsub("(^|\n)##%s+([^\n]+)", string.format('%%1<span weight="bold" size="larger" foreground="%s">%%2</span>', h2_color))
    s = s:gsub("(^|\n)#%s+([^\n]+)", string.format('%%1<span weight="bold" size="x-large" foreground="%s">%%2</span>', h1_color))
    return s
end

local function style_prefix(prefix)
    if not prefix or #prefix == 0 then return "" end
    local is_light = (config.theme_mode == "light")
    local p = prefix:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

    local tu_color       = is_light and "#BE185D" or "#EC5DA3"
    local openclaw_color = is_light and "#0284C7" or "#38BDF8"
    local qwen_color     = is_light and "#1D4ED8" or "#60A5FA"
    local skill_color    = is_light and "#047857" or "#34D399"
    local error_color    = is_light and "#B91C1C" or "#F87171"
    local arrow_color    = is_light and "#475569" or "#94A3B8"

    if p:find("%[Tu%]") then
        p = p:gsub("%[Tu%]", string.format('<span weight="bold" foreground="%s">[Tu]</span>', tu_color))
    elseif p:find("%[OpenClaw%]") then
        p = p:gsub("%[OpenClaw%]", string.format('<span weight="bold" foreground="%s">[OpenClaw]</span>', openclaw_color))
    elseif p:find("%[Qwen IA%]") then
        p = p:gsub("%[Qwen IA%]", string.format('<span weight="bold" foreground="%s">[Qwen IA]</span>', qwen_color))
    elseif p:find("%[Skill%]") then
        p = p:gsub("%[Skill%]", string.format('<span weight="bold" foreground="%s">[Skill]</span>', skill_color))
    elseif p:find("%[Error%]") then
        p = p:gsub("%[Error%]", string.format('<span weight="bold" foreground="%s">[Error]</span>', error_color))
    elseif p:find("&gt;&gt;") then
        p = p:gsub("&gt;&gt;", string.format('<span foreground="%s">&gt;&gt;</span>', arrow_color))
    end
    return p
end

local function append_colored(prefix, text)
    local buf = chat.buffer
    if not buf then return end

    local markup = style_prefix(prefix) .. md_to_pango(text)
    local iter = buf:get_end_iter()
    local ok = pcall(function()
        buf:insert_markup(iter, markup, -1)
    end)
    if not ok then
        iter = buf:get_end_iter()
        buf:insert(iter, (prefix or "") .. (text or ""), -1)
    end
    scroll_to_bottom()
end

local function on_send()
    local text = chat.entry:get_text()
    if not text or #text:match("^%s*(.-)%s*$") == 0 then return end

    local clean_text = text:match("^%s*(.-)%s*$")
    chat.entry:set_text("")

    if clean_text:sub(1, 1) == "/" then
        append_colored("\n  [Tu] ", clean_text .. "\n")
        local handled = openclaw.handle_slash_command(clean_text, function(res)
            GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
                append_colored("  [OpenClaw]\n  ", (res or ""):gsub("\n", "\n  ") .. "\n")
                if chat.status_label then chat.status_label:set_text("LISTO") end
                update_header_badges()
                chat.entry:grab_focus()
                return false
            end)
        end)
        if handled then return end
    end

    chat.entry:set_sensitive(false)
    if chat.send_btn then chat.send_btn:set_sensitive(false) end
    if chat.status_label then chat.status_label:set_text("GENERANDO...") end
    if chat.on_state_change then pcall(chat.on_state_change, "thinking") end

    append_colored("\n  [Tu] ", clean_text .. "\n")
    append_colored("  [Qwen IA] ", "")

    local response_chunks = {}
    local stream_start_offset = chat.buffer:get_char_count()

    ai_engine.send(clean_text,
        function(token, done)
            GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
                if done then
                    local full_resp = table.concat(response_chunks)

                    local iter_start = chat.buffer:get_iter_at_offset(stream_start_offset)
                    local iter_end = chat.buffer:get_end_iter()
                    chat.buffer:delete(iter_start, iter_end)

                    local iter_now = chat.buffer:get_end_iter()
                    local ok = pcall(function()
                        chat.buffer:insert_markup(iter_now, md_to_pango(full_resp .. "\n"), -1)
                    end)
                    if not ok then
                        chat.buffer:insert(iter_now, full_resp .. "\n", -1)
                    end
                    scroll_to_bottom()
                    update_header_badges()

                    local tool_name, tool_args = openclaw.detect_tool_call(full_resp)
                    if tool_name then
                        append_colored("  [Skill] ", string.format("Ejecutando %s...\n", tool_name))
                        if chat.status_label then chat.status_label:set_text("EJECUTANDO: " .. tool_name:upper()) end

                        openclaw.execute(tool_name, tool_args, function(_, res_str)
                            GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
                                append_colored("  >> ", (res_str or ""):gsub("\n", "\n  ") .. "\n")
                                chat.entry:set_sensitive(true)
                                if chat.send_btn then chat.send_btn:set_sensitive(true) end
                                chat.entry:grab_focus()
                                if chat.status_label then chat.status_label:set_text("LISTO") end
                                if chat.on_state_change then pcall(chat.on_state_change, chat.visible and "chatting" or "idle") end
                                return false
                            end)
                        end)
                    else
                        chat.entry:set_sensitive(true)
                        if chat.send_btn then chat.send_btn:set_sensitive(true) end
                        chat.entry:grab_focus()
                        if chat.status_label then chat.status_label:set_text("LISTO") end
                        if chat.on_state_change then pcall(chat.on_state_change, chat.visible and "chatting" or "idle") end
                    end
                    collectgarbage("step", 100)
                else
                    response_chunks[#response_chunks + 1] = token
                    local buf = chat.buffer
                    local iter = buf:get_end_iter()
                    buf:insert(iter, token, -1)
                    scroll_to_bottom()
                    if chat.status_label then chat.status_label:set_text("STREAMING...") end
                end
                return false
            end)
        end,
        function(err)
            GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
                append_colored("  [Error] ", tostring(err) .. "\n")
                chat.entry:set_sensitive(true)
                if chat.send_btn then chat.send_btn:set_sensitive(true) end
                chat.entry:grab_focus()
                if chat.status_label then chat.status_label:set_text("ERROR") end
                if chat.on_state_change then pcall(chat.on_state_change, "error") end
                collectgarbage("step", 50)
                return false
            end)
        end)
end

----------------------------------------------------------------------
-- Build 6-Section Settings Panel (Zero Emojis, High Contrast)
----------------------------------------------------------------------
local function build_config_view()
    local sw = Gtk.ScrolledWindow {
        hscrollbar_policy = Gtk.PolicyType.NEVER,
        vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
    }
    sw:get_style_context():add_class("config-scroll")

    local cbox = Gtk.Box {
        orientation = Gtk.Orientation.VERTICAL,
        spacing = 4,
    }
    cbox:get_style_context():add_class("config-box")

    local function add_section_header(title)
        local lbl = Gtk.Label { label = title }
        lbl:get_style_context():add_class("config-section-title")
        lbl:set_xalign(0)
        cbox:pack_start(lbl, false, false, 4)
    end

    local function create_switch_row(label_text, desc_text, skill_key, on_toggle)
        local row = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 8 }
        row:get_style_context():add_class("config-row")

        local text_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 1 }
        local lbl = Gtk.Label { label = label_text }
        lbl:get_style_context():add_class("config-label")
        lbl:set_xalign(0)
        text_box:pack_start(lbl, false, false, 0)

        if desc_text and #desc_text > 0 then
            local desc = Gtk.Label { label = desc_text }
            desc:get_style_context():add_class("config-desc")
            desc:set_xalign(0)
            text_box:pack_start(desc, false, false, 0)
        end

        row:pack_start(text_box, true, true, 0)

        local sw_widget = Gtk.Switch {
            active = (config.skills and config.skills[skill_key] ~= false)
        }
        sw_widget.valign = Gtk.Align.CENTER

        sw_widget.on_state_set = function(_, state)
            config.skills[skill_key] = state
            config.save()
            config.notify_change(skill_key, state)
            if on_toggle then pcall(on_toggle, state) end
            if not state then collectgarbage("step", 100) end
            return false
        end

        row:pack_end(sw_widget, false, false, 0)
        return row
    end

    -- ===============================================================
    -- SECCION 1: GENERAL
    -- ===============================================================
    add_section_header("1. GENERAL Y PRESUPUESTO DE MEMORIA")
    local card_gen = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5 }
    card_gen:get_style_context():add_class("config-card")

    local row_inf = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 4 }
    local lbl_inf = Gtk.Label { label = "Motor de Inferencia Activo:" }
    lbl_inf:get_style_context():add_class("config-label")
    lbl_inf:set_xalign(0)
    row_inf:pack_start(lbl_inf, true, true, 0)

    local inf_btns = {}
    local function update_inf_btns()
        local cur = config.inference_provider or "local"
        for k, b in pairs(inf_btns) do
            b:get_style_context():remove_class("pill-choice")
            b:get_style_context():remove_class("pill-choice-active")
            b:get_style_context():add_class(k == cur and "pill-choice-active" or "pill-choice")
        end
        update_header_badges()
    end

    for _, item in ipairs({ { id = "local", label = "Local (llama.cpp)" }, { id = "cloud", label = "Cloud API" } }) do
        local b = Gtk.Button { label = item.label }
        inf_btns[item.id] = b
        b.on_clicked = function()
            config.inference_provider = item.id
            config.save()
            update_inf_btns()
        end
        row_inf:pack_start(b, false, false, 0)
    end
    update_inf_btns()
    card_gen:pack_start(row_inf, false, false, 2)

    local row_mem = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_mem_info = Gtk.Label { label = "Presupuesto RAM (<= 500 MB):" }
    lbl_mem_info:get_style_context():add_class("config-label")
    lbl_mem_info:set_xalign(0)
    row_mem:pack_start(lbl_mem_info, true, true, 0)

    local btn_trim = Gtk.Button { label = "Liberar Memoria Ahora" }
    btn_trim:get_style_context():add_class("pill-choice")
    btn_trim.on_clicked = function()
        if qwen_native and qwen_native.trim_memory then
            pcall(qwen_native.trim_memory)
        end
        collectgarbage("collect")
        update_header_badges()
    end
    row_mem:pack_end(btn_trim, false, false, 0)
    card_gen:pack_start(row_mem, false, false, 2)

    -- Selector Dinamico de Tema y Persona
    local row_theme = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_theme = Gtk.Label { label = "Tema Visual / Persona:" }
    lbl_theme:get_style_context():add_class("config-label")
    lbl_theme:set_xalign(0)
    row_theme:pack_start(lbl_theme, true, true, 0)

    local combo_theme = Gtk.ComboBoxText()
    local ok_tm, theme_mgr = pcall(require, "theme_manager")
    if ok_tm and theme_mgr then
        local themes = theme_mgr.list_themes()
        for _, t in ipairs(themes) do
            combo_theme:append(t.id, t.name)
        end
        combo_theme:set_active_id(config.theme or "default")
        combo_theme.on_changed = function(self)
            local sel = self:get_active_id()
            if sel and sel ~= config.theme then
                theme_mgr.apply_theme(sel)
                config.theme = sel
                config.save()
                local ok_w, widget = pcall(require, "widget")
                if ok_w and widget and widget.reload_avatar then
                    widget.reload_avatar()
                end
                chat.update_avatar()
                chat.update_header()
                if chat.window then
                    chat.window:queue_draw()
                end
            end
        end
    end
    combo_theme:get_style_context():add_class("pill-choice")
    row_theme:pack_end(combo_theme, false, false, 0)
    card_gen:pack_start(row_theme, false, false, 2)

    -- Modo de Color: Oscuro / Claro
    local row_mode = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_mode = Gtk.Label { label = "Modo de Color:" }
    lbl_mode:get_style_context():add_class("config-label")
    lbl_mode:set_xalign(0)
    row_mode:pack_start(lbl_mode, true, true, 0)

    local btn_mode_dark = Gtk.Button { label = "Oscuro" }
    local btn_mode_light = Gtk.Button { label = "Claro" }
    if config.theme_mode == "light" then
        btn_mode_light:get_style_context():add_class("pill-choice-active")
        btn_mode_dark:get_style_context():add_class("pill-choice")
    else
        btn_mode_dark:get_style_context():add_class("pill-choice-active")
        btn_mode_light:get_style_context():add_class("pill-choice")
    end

    btn_mode_dark.on_clicked = function()
        if ok_tm and theme_mgr and theme_mgr.set_theme_mode then
            theme_mgr.set_theme_mode("dark")
        else
            config.theme_mode = "dark"
            config.save()
        end
        if chat.update_theme_mode then chat.update_theme_mode() end
    end

    btn_mode_light.on_clicked = function()
        if ok_tm and theme_mgr and theme_mgr.set_theme_mode then
            theme_mgr.set_theme_mode("light")
        else
            config.theme_mode = "light"
            config.save()
        end
        if chat.update_theme_mode then chat.update_theme_mode() end
    end

    chat.btn_mode_dark = btn_mode_dark
    chat.btn_mode_light = btn_mode_light

    row_mode:pack_end(btn_mode_light, false, false, 0)
    row_mode:pack_end(btn_mode_dark, false, false, 4)
    card_gen:pack_start(row_mode, false, false, 2)

    -- Opcion: Bordes Redondeados (Rectos / Curvos)
    local row_corners = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_corners_box = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 1 }
    local lbl_corners = Gtk.Label { label = "Bordes Redondeados:" }
    lbl_corners:get_style_context():add_class("config-label")
    lbl_corners:set_xalign(0)
    lbl_corners_box:pack_start(lbl_corners, false, false, 0)
    local desc_corners = Gtk.Label { label = "Curvar esquinas del widget y ventanas (desactivado = esquinas rectas)" }
    desc_corners:get_style_context():add_class("config-desc")
    desc_corners:set_xalign(0)
    lbl_corners_box:pack_start(desc_corners, false, false, 0)
    row_corners:pack_start(lbl_corners_box, true, true, 0)

    local sw_corners = Gtk.Switch { active = (config.rounded_corners == true) }
    sw_corners:set_valign(Gtk.Align.CENTER)
    sw_corners.on_state_set = function(_, state)
        config.rounded_corners = (state == true)
        config.save()
        local ok_w, widget = pcall(require, "widget")
        if ok_w and widget and widget.window then
            widget.window:queue_draw()
        end
        if chat.update_corners then chat.update_corners() end
        local ok_p, player = pcall(require, "player")
        if ok_p and player then
            if player.update_corners then player.update_corners() end
            if player.window then player.window:queue_draw() end
        end
        return true
    end
    chat.switch_corners = sw_corners
    row_corners:pack_end(sw_corners, false, false, 0)
    card_gen:pack_start(row_corners, false, false, 2)

    -- Personalización Visual de Avatar
    local row_avatar = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_avatar = Gtk.Label { label = "Imagen / Avatar del Widget:" }
    lbl_avatar:get_style_context():add_class("config-label")
    lbl_avatar:set_xalign(0)
    row_avatar:pack_start(lbl_avatar, true, true, 0)

    local btn_reset_avatar = Gtk.Button { label = "Restablecer" }
    btn_reset_avatar:get_style_context():add_class("pill-choice")
    btn_reset_avatar.on_clicked = function()
        local ok_ac, ac = pcall(require, "avatar_customizer")
        if ok_ac and ac then
            ac.reset_default()
            chat.update_avatar()
        end
    end
    row_avatar:pack_end(btn_reset_avatar, false, false, 0)

    local btn_change_avatar = Gtk.Button { label = "Cambiar Imagen..." }
    btn_change_avatar:get_style_context():add_class("pill-choice-active")
    btn_change_avatar.on_clicked = function()
        local ok_ac, ac = pcall(require, "avatar_customizer")
        if ok_ac and ac then
            ac.open_dialog(chat.window, function(success, res)
                if success then
                    chat.update_avatar()
                end
            end)
        end
    end
    row_avatar:pack_end(btn_change_avatar, false, false, 0)
    card_gen:pack_start(row_avatar, false, false, 2)

    card_gen:pack_start(create_switch_row("Burbujas de Datos Dinamicas", "Tipo de cambio, criptomonedas, clima y telemetria", "data_bubbles"), false, false, 1)
    card_gen:pack_start(create_switch_row("Mini-Reproductor Multimedia", "Panel acoplado para YouTube Music y Spotify", "player"), false, false, 1)
    card_gen:pack_start(create_switch_row("Letras Sincronizadas (LRC)", "Burbuja superior con sincronizacion en tiempo real", "lyrics"), false, false, 1)

    cbox:pack_start(card_gen, false, false, 2)

    -- ===============================================================
    -- SECCION 2: MODELOS LOCALES (llama.cpp)
    -- ===============================================================
    add_section_header("2. MODELOS LOCALES (LLAMA.CPP EMBEBIDO)")
    local card_local = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5 }
    card_local:get_style_context():add_class("config-card")

    -- Chat Model
    local row_cmodel = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_cmodel = Gtk.Label { label = "Chat Conversacional (.gguf):" }
    lbl_cmodel:get_style_context():add_class("config-label")
    row_cmodel:pack_start(lbl_cmodel, false, false, 0)

    local entry_cmodel = Gtk.Entry { text = config.chat_model or "qwen3.0-0.8b.gguf" }
    entry_cmodel:get_style_context():add_class("config-entry")
    entry_cmodel.on_activate = function(e)
        local val = e:get_text():gsub("%s+", "")
        if #val > 0 then
            config.chat_model = val
            config.save()
            update_header_badges()
        end
    end
    row_cmodel:pack_start(entry_cmodel, true, true, 0)
    card_local:pack_start(row_cmodel, false, false, 2)

    -- Grammar Model
    local row_gmodel = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_gmodel = Gtk.Label { label = "Corrector Gramatical (.gguf):" }
    lbl_gmodel:get_style_context():add_class("config-label")
    row_gmodel:pack_start(lbl_gmodel, false, false, 0)

    local entry_gmodel = Gtk.Entry { text = config.grammar_model or "es-grammar.gguf" }
    entry_gmodel:get_style_context():add_class("config-entry")
    entry_gmodel.on_activate = function(e)
        local val = e:get_text():gsub("%s+", "")
        if #val > 0 then
            config.grammar_model = val
            config.save()
        end
    end
    row_gmodel:pack_start(entry_gmodel, true, true, 0)
    card_local:pack_start(row_gmodel, false, false, 2)

    -- Threads & Context Size
    local row_threads = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 4 }
    local lbl_threads = Gtk.Label { label = "Hilos CPU / Contexto:" }
    lbl_threads:get_style_context():add_class("config-label")
    row_threads:pack_start(lbl_threads, true, true, 0)

    local thread_btns = {}
    local thread_opts = { 2, 4, 8 }
    local function update_thread_btns()
        for _, t in ipairs(thread_opts) do
            local b = thread_btns[t]
            if b then
                b:get_style_context():remove_class("pill-choice")
                b:get_style_context():remove_class("pill-choice-active")
                b:get_style_context():add_class(config.threads == t and "pill-choice-active" or "pill-choice")
            end
        end
    end
    for _, t in ipairs(thread_opts) do
        local b = Gtk.Button { label = tostring(t) .. "T" }
        thread_btns[t] = b
        b.on_clicked = function()
            config.threads = t
            config.save()
            update_thread_btns()
        end
        row_threads:pack_start(b, false, false, 0)
    end
    update_thread_btns()

    local ctx_lbl = Gtk.Label { label = "CTX 512 | KV q4_0" }
    ctx_lbl:get_style_context():add_class("config-desc")
    row_threads:pack_start(ctx_lbl, false, false, 4)
    card_local:pack_start(row_threads, false, false, 2)

    -- Model verification & auto-download button
    local row_dl = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local dl_status = Gtk.Label { label = "Estado GGUF: Verificando..." }
    dl_status:get_style_context():add_class("config-desc")
    dl_status:set_xalign(0)
    row_dl:pack_start(dl_status, true, true, 0)

    local function refresh_dl_status()
        local st = model_mgr.status()
        if st.grammar.ready and st.chat.ready then
            dl_status:set_text(string.format("Modelos listos: es-grammar (%.0fMB) | qwen3.0-0.8b (%.0fMB)",
                st.grammar.size_mb, st.chat.size_mb))
        else
            dl_status:set_text("Faltan modelos por defecto. Pulsa Verificar/Descargar.")
        end
    end
    refresh_dl_status()

    local btn_dl = Gtk.Button { label = "Verificar / Descargar" }
    btn_dl:get_style_context():add_class("pill-choice")
    btn_dl.on_clicked = function()
        model_mgr.ensure_defaults(
            function(_, msg) dl_status:set_text(msg) end,
            function() refresh_dl_status() end
        )
    end
    row_dl:pack_end(btn_dl, false, false, 0)
    card_local:pack_start(row_dl, false, false, 2)

    cbox:pack_start(card_local, false, false, 2)

    -- ===============================================================
    -- SECCION 3: API CLOUD
    -- ===============================================================
    add_section_header("3. PROVEEDORES DE API CLOUD (NATIVO)")
    local card_cloud = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5 }
    card_cloud:get_style_context():add_class("config-card")

    local row_prov = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 3 }
    local prov_btns = {}
    local prov_list = {
        { id = "openai",     label = "OpenAI" },
        { id = "gemini",     label = "Gemini" },
        { id = "anthropic",  label = "Anthropic" },
        { id = "openrouter", label = "OpenRouter" },
        { id = "custom",     label = "Custom" },
    }

    local entry_cmod = Gtk.Entry { text = config.cloud_model or "gpt-4o-mini" }
    entry_cmod:get_style_context():add_class("config-entry")

    local entry_ckey = Gtk.Entry {
        text = ai_engine.get_cloud_token(config.cloud_provider or "openai"),
        visibility = false,
        placeholder_text = "Pega tu clave de API y presiona Guardar...",
    }
    entry_ckey:get_style_context():add_class("config-entry")

    local function update_prov_btns()
        local cur = config.cloud_provider or "openai"
        for k, b in pairs(prov_btns) do
            b:get_style_context():remove_class("pill-choice")
            b:get_style_context():remove_class("pill-choice-active")
            b:get_style_context():add_class(k == cur and "pill-choice-active" or "pill-choice")
        end
        entry_ckey:set_text(ai_engine.get_cloud_token(cur))
    end

    for _, p in ipairs(prov_list) do
        local b = Gtk.Button { label = p.label }
        prov_btns[p.id] = b
        b.on_clicked = function()
            config.cloud_provider = p.id
            local pinfo = ai_engine.CLOUD_PROVIDERS[p.id]
            if pinfo then
                config.cloud_model = pinfo.default_model
                entry_cmod:set_text(config.cloud_model)
            end
            config.save()
            update_prov_btns()
            update_header_badges()
        end
        row_prov:pack_start(b, true, true, 0)
    end
    update_prov_btns()
    card_cloud:pack_start(row_prov, false, false, 2)

    local row_cm = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_cm = Gtk.Label { label = "Modelo Cloud:" }
    lbl_cm:get_style_context():add_class("config-label")
    row_cm:pack_start(lbl_cm, false, false, 0)
    entry_cmod.on_activate = function(e)
        config.cloud_model = e:get_text():gsub("%s+", "")
        config.save()
    end
    row_cm:pack_start(entry_cmod, true, true, 0)
    card_cloud:pack_start(row_cm, false, false, 2)

    local row_ck = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_ck = Gtk.Label { label = "API Key:" }
    lbl_ck:get_style_context():add_class("config-label")
    row_ck:pack_start(lbl_ck, false, false, 0)
    row_ck:pack_start(entry_ckey, true, true, 0)

    local btn_save_key = Gtk.Button { label = "Guardar Key" }
    btn_save_key:get_style_context():add_class("pill-choice-active")
    btn_save_key.on_clicked = function()
        config.cloud_model = entry_cmod:get_text():gsub("%s+", "")
        ai_engine.set_cloud_token(config.cloud_provider or "openai", entry_ckey:get_text())
        config.save()
        btn_save_key:set_label("Guardada")
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1200, function()
            btn_save_key:set_label("Guardar Key")
            return false
        end)
    end
    row_ck:pack_end(btn_save_key, false, false, 0)
    card_cloud:pack_start(row_ck, false, false, 2)

    cbox:pack_start(card_cloud, false, false, 2)

    -- ===============================================================
    -- SECCION 4: MUSICA (YOUTUBE MUSIC + SPOTIFY)
    -- ===============================================================
    add_section_header("4. MUSICA Y LETRAS SINCRONIZADAS (YT MUSIC + SPOTIFY)")
    local card_music = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 5 }
    card_music:get_style_context():add_class("config-card")

    local row_msrc = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 4 }
    local lbl_msrc = Gtk.Label { label = "Fuente Preferida MPRIS2:" }
    lbl_msrc:get_style_context():add_class("config-label")
    lbl_msrc:set_xalign(0)
    row_msrc:pack_start(lbl_msrc, true, true, 0)

    local msrc_btns = {}
    local function update_msrc_btns()
        local cur = config.music_source or "auto"
        for k, b in pairs(msrc_btns) do
            b:get_style_context():remove_class("pill-choice")
            b:get_style_context():remove_class("pill-choice-active")
            b:get_style_context():add_class(k == cur and "pill-choice-active" or "pill-choice")
        end
    end
    for _, s in ipairs({ { id = "auto", label = "Auto" }, { id = "ytmusic", label = "YT Music" }, { id = "spotify", label = "Spotify" } }) do
        local b = Gtk.Button { label = s.label }
        msrc_btns[s.id] = b
        b.on_clicked = function()
            config.music_source = s.id
            config.save()
            update_msrc_btns()
            if player.update_ui then player.update_ui() end
        end
        row_msrc:pack_start(b, false, false, 0)
    end
    update_msrc_btns()
    card_music:pack_start(row_msrc, false, false, 2)

    cbox:pack_start(card_music, false, false, 2)

    -- ===============================================================
    -- SECCION 5: GRAMATICA Y SELECCION
    -- ===============================================================
    add_section_header("5. CORRECTOR GRAMATICAL Y MENU DE SELECCION")
    local card_text = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 4 }
    card_text:get_style_context():add_class("config-card")

    card_text:pack_start(create_switch_row("Aparicion Automatica al Seleccionar Texto", "Hook nativo C/C++ en X11/Wayland junto al cursor", "global_text_menu", function(state)
        local ok_tp, text_popup = pcall(require, "text_popup")
        if ok_tp and text_popup then
            if state then text_popup.start_watcher() else text_popup.stop_watcher() end
        end
    end), false, false, 2)

    local writing_skills = {
        { id = "skill_grammar",   label = "Corregir Gramatica",       desc = "Sintaxis, concordancia y puntuacion con es-grammar" },
        { id = "skill_spelling",  label = "Mejorar Ortografia",       desc = "Tildes, acentuacion y grafias en espanol" },
        { id = "skill_formalize", label = "Formalizar Texto",         desc = "Registro profesional, ejecutivo y cortes" },
        { id = "skill_summarize", label = "Resumir Texto",            desc = "Sintesis directa de puntos clave" },
        { id = "skill_simplify",  label = "Simplificar y Clarificar", desc = "Redaccion clara y concisa" },
        { id = "skill_humanize",  label = "Humanizar Texto",          desc = "Tono natural, empatico y fluido" },
        { id = "skill_expand",    label = "Desarrollar Ideas",        desc = "Expansion estructurada de argumentos" },
    }
    for _, ws in ipairs(writing_skills) do
        card_text:pack_start(create_switch_row(ws.label, ws.desc, ws.id), false, false, 1)
    end

    cbox:pack_start(card_text, false, false, 2)

    -- ===============================================================
    -- SECCION 6: OPENCLAW
    -- ===============================================================
    add_section_header("6. INTEGRACION CON OPENCLAW Y HABILIDADES")
    local card_agent = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 4 }
    card_agent:get_style_context():add_class("config-card")

    local row_gw = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    local lbl_gw = Gtk.Label { label = "Gateway URL:" }
    lbl_gw:get_style_context():add_class("config-label")
    row_gw:pack_start(lbl_gw, false, false, 0)

    local entry_gw = Gtk.Entry { text = config.OPENCLAW_GATEWAY_URL or "http://127.0.0.1:18789" }
    entry_gw:get_style_context():add_class("config-entry")
    entry_gw.on_activate = function(e)
        config.OPENCLAW_GATEWAY_URL = e:get_text():gsub("%s+", "")
        config.save()
    end
    row_gw:pack_start(entry_gw, true, true, 0)
    card_agent:pack_start(row_gw, false, false, 2)

    local agent_skills = {
        { id = "system_info",      label = "Diagnostico de Sistema", desc = "Uso de CPU, RAM del sistema y RAM del widget" },
        { id = "bash",             label = "Ejecucion Shell Segura", desc = "Comandos locales con control de timeout" },
        { id = "media_control",    label = "Control Multimedia IPC", desc = "MPRIS2 para YouTube Music y Spotify" },
        { id = "web_search",       label = "Busqueda Web",           desc = "Consultas rapidas DuckDuckGo" },
        { id = "app_launch",       label = "Lanzador de Apps",       desc = "Apertura directa de aplicaciones" },
        { id = "screenshot",       label = "Captura de Pantalla",    desc = "Capturas completas de escritorio" },
        { id = "notify",           label = "Notificaciones Nativas", desc = "Alertas de sistema" },
        { id = "openclaw_gateway", label = "Gateway OpenClaw IPC",   desc = "Reconexion automatica y envio de payloads" },
    }

    for _, as in ipairs(agent_skills) do
        card_agent:pack_start(create_switch_row(as.label, as.desc, as.id, function(state)
            if not state then manager.unload(as.id) end
        end), false, false, 1)
    end

    cbox:pack_start(card_agent, false, false, 2)

    sw:add(cbox)
    return sw
end

----------------------------------------------------------------------
-- Build Chat Window
----------------------------------------------------------------------
function chat.build()
    if chat.window then return end
    apply_css()

    local win = Gtk.Window {
        type = Gtk.WindowType.TOPLEVEL,
        decorated = false,
        skip_taskbar_hint = true,
        skip_pager_hint = true,
        resizable = false,
        accept_focus = true,
        type_hint = Gdk.WindowTypeHint.UTILITY,
        default_width  = config.CHAT_W or 400,
        default_height = config.CHAT_H or 510,
    }
    win:set_keep_above(true)
    win:get_style_context():add_class("chat-window")
    if config.theme_mode == "light" then
        win:get_style_context():add_class("theme-light")
    end
    if config.rounded_corners == false then
        win:get_style_context():add_class("sharp-corners")
    end

    local screen = win:get_screen()
    local visual = screen:get_rgba_visual()
    if visual then win:set_visual(visual) end
    win:set_app_paintable(true)

    win.on_draw = function(self, cr)
        local w = self:get_allocated_width()
        local h = self:get_allocated_height()
        local is_round = (config.rounded_corners == true)
        local r = is_round and (config.CHAT_RADIUS or 14) or 0

        cr:set_operator(cairo.Operator.SOURCE)
        cr:set_source_rgba(0, 0, 0, 0)
        cr:paint()
        cr:set_operator(cairo.Operator.OVER)

        for k = 3, 1, -1 do
            cr:new_sub_path()
            utils.rounded_rect(cr, 1, 1 + k * 0.7, w - 2, h - 2, r)
            cr:set_source_rgba(0, 0, 0, 0.05 * (4 - k))
            cr:fill()
        end

        utils.rounded_rect(cr, 1, 1, w - 2, h - 2, r)
        local bg_pat = cairo.Pattern.create_linear(0, 0, 0, h)
        if config.theme_mode == "light" then
            bg_pat:add_color_stop_rgba(0, 0.980, 0.985, 0.990, 0.99)
            bg_pat:add_color_stop_rgba(1, 0.935, 0.945, 0.960, 0.99)
            cr:set_source(bg_pat)
            cr:fill_preserve()
            cr:set_source_rgba(0.0, 0.0, 0.0, 0.15)
            cr:set_line_width(1.2)
            cr:stroke()
        else
            local bg = config.BG_CHAT or config.BG or { 0.086, 0.090, 0.098, 0.98 }
            bg_pat:add_color_stop_rgba(0, bg[1] + 0.015, bg[2] + 0.015, bg[3] + 0.020, bg[4] or 0.98)
            bg_pat:add_color_stop_rgba(1, bg[1], bg[2], bg[3], bg[4] or 0.98)
            cr:set_source(bg_pat)
            cr:fill_preserve()
            local acc = config.ACCENT or { 0.38, 0.52, 0.85 }
            cr:set_source_rgba(acc[1], acc[2], acc[3], 0.45)
            cr:set_line_width(1.2)
            cr:stroke()
        end
        return false
    end

    local vbox = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 0 }

    -- Header Bar
    local hbar = Gtk.Box {
        orientation = Gtk.Orientation.HORIZONTAL, spacing = 6,
        margin_start = 14, margin_end = 12,
        margin_top = 10, margin_bottom = 4,
    }

    local avatar_mini = utils.load_sprite("idle", 24) or utils.load_pixbuf(config.custom_avatar or config.AVATAR, 24)
    if avatar_mini then
        local img = Gtk.Image.new_from_pixbuf(avatar_mini)
        hbar:pack_start(img, false, false, 0)
        chat.avatar_image = img
    end

    local title = Gtk.Label { label = config.chat_header or config.agent_name or "KITSU AI" }
    title:get_style_context():add_class("chat-header")
    hbar:pack_start(title, false, false, 0)
    chat.title_label = title

    -- Quick Local vs. Cloud Toggle Button
    local prov_btn = Gtk.Button { label = "LOCAL: qwen3.0-0.8b" }
    prov_btn:get_style_context():add_class("model-pill")
    prov_btn:set_tooltip_text("Alternar rapidamente entre inferencia Local (llama.cpp) y Cloud API")
    prov_btn.on_clicked = function()
        if config.inference_provider == "cloud" then
            config.inference_provider = "local"
        else
            config.inference_provider = "cloud"
        end
        config.save()
        update_header_badges()
    end
    hbar:pack_start(prov_btn, false, false, 0)
    chat.provider_btn = prov_btn
    chat.model_label  = prov_btn

    -- Quick Claro / Oscuro Toggle Button
    local mode_btn = Gtk.Button { label = (config.theme_mode == "light") and "MODO: CLARO" or "MODO: OSCURO" }
    mode_btn:get_style_context():add_class("model-pill")
    mode_btn:set_tooltip_text("Alternar entre modo Claro y Oscuro")
    mode_btn.on_clicked = function()
        local ok_tm, theme_mgr = pcall(require, "theme_manager")
        if ok_tm and theme_mgr and theme_mgr.toggle_theme_mode then
            theme_mgr.toggle_theme_mode()
        else
            config.theme_mode = (config.theme_mode == "light") and "dark" or "light"
            config.save()
        end
        if chat.update_theme_mode then chat.update_theme_mode() end
    end
    hbar:pack_start(mode_btn, false, false, 0)
    chat.mode_btn = mode_btn

    local ram_lbl = Gtk.Label { label = "RAM OK" }
    ram_lbl:get_style_context():add_class("ram-badge")
    hbar:pack_start(ram_lbl, false, false, 2)
    chat.ram_label = ram_lbl

    hbar:pack_start(Gtk.Label { label = "" }, true, true, 0)

    chat.status_label = Gtk.Label { label = "EN LINEA" }
    chat.status_label:get_style_context():add_class("status-label")
    hbar:pack_end(chat.status_label, false, false, 0)

    local close_btn = Gtk.Button { label = "X" }
    close_btn:get_style_context():add_class("chat-close-btn")
    close_btn:set_tooltip_text("Cerrar ventana (Esc)")
    close_btn.on_clicked = function() chat.hide() end
    hbar:pack_end(close_btn, false, false, 4)

    vbox:pack_start(hbar, false, false, 0)

    -- Segmented Navigation Tabs (Zero Emojis)
    local tab_bar = Gtk.Box {
        orientation = Gtk.Orientation.HORIZONTAL,
        spacing = 6,
        margin_start = 14, margin_end = 14,
        margin_top = 2, margin_bottom = 4,
    }
    local tab_chat = Gtk.Button { label = "CONVERSACION" }
    tab_chat:get_style_context():add_class("tab-btn-active")

    local tab_config = Gtk.Button { label = "CONFIGURACION" }
    tab_config:get_style_context():add_class("tab-btn")

    tab_bar:pack_start(tab_chat, true, true, 0)
    tab_bar:pack_start(tab_config, true, true, 0)
    vbox:pack_start(tab_bar, false, false, 0)

    chat.tab_chat = tab_chat
    chat.tab_config = tab_config

    -- Container 1: Chat View
    local chat_view = Gtk.Box { orientation = Gtk.Orientation.VERTICAL, spacing = 0 }

    local action_bar = Gtk.Box { orientation = Gtk.Orientation.HORIZONTAL, spacing = 6 }
    action_bar:get_style_context():add_class("toolbar-box")

    local btn_bubble = Gtk.Button { label = "Datos" }
    btn_bubble:get_style_context():add_class("tool-btn-accent")
    btn_bubble:set_tooltip_text("Mostrar burbuja de datos en el widget")
    btn_bubble.on_clicked = function()
        if chat.on_invoke_bubble then chat.on_invoke_bubble() end
    end
    action_bar:pack_start(btn_bubble, false, false, 0)

    local btn_player = Gtk.Button { label = "Reproductor" }
    btn_player:get_style_context():add_class("tool-btn")
    btn_player:set_tooltip_text("Abrir mini-reproductor YouTube Music / Spotify")
    btn_player.on_clicked = function()
        player.toggle(last_bx, last_by, last_bsize, last_edge)
    end
    action_bar:pack_start(btn_player, false, false, 0)

    local btn_sys = Gtk.Button { label = "Sistema" }
    btn_sys:get_style_context():add_class("tool-btn")
    btn_sys:set_tooltip_text("Diagnostico de CPU, RAM y presupuesto de memoria")
    btn_sys.on_clicked = function()
        openclaw.handle_slash_command("/sys", function(res)
            GLib.idle_add(GLib.PRIORITY_DEFAULT, function()
                append_colored("\n  [Tu] /sys\n  [OpenClaw]\n  ", (res or ""):gsub("\n", "\n  ") .. "\n")
                update_header_badges()
                return false
            end)
        end)
    end
    action_bar:pack_start(btn_sys, false, false, 0)

    action_bar:pack_start(Gtk.Label { label = "" }, true, true, 0)

    local btn_clear = Gtk.Button { label = "Limpiar" }
    btn_clear:get_style_context():add_class("tool-btn")
    btn_clear:set_tooltip_text("Reiniciar historial y liberar memoria")
    btn_clear.on_clicked = function()
        ai_engine.clear()
        if chat.buffer then
            chat.buffer:set_text("", 0)
            local it = chat.buffer:get_end_iter()
            local reset_msg = md_to_pango("  **[Historial reiniciado]**\n  Escribe una consulta o usa `/help` para ver comandos.\n")
            pcall(function() chat.buffer:insert_markup(it, reset_msg, -1) end)
        end
        update_header_badges()
        collectgarbage("step", 100)
    end
    action_bar:pack_end(btn_clear, false, false, 0)

    chat_view:pack_start(action_bar, false, false, 0)

    local sep = Gtk.Separator { orientation = Gtk.Orientation.HORIZONTAL }
    sep:set_opacity(0.15)
    chat_view:pack_start(sep, false, false, 0)

    local sw = Gtk.ScrolledWindow {
        hscrollbar_policy = Gtk.PolicyType.NEVER,
        vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
    }
    sw:get_style_context():add_class("chat-scroll")

    local tv = Gtk.TextView {
        editable = false,
        cursor_visible = false,
        wrap_mode = Gtk.WrapMode.WORD_CHAR,
        left_margin = 8, right_margin = 8,
        top_margin = 6, bottom_margin = 6,
    }
    tv:get_style_context():add_class("chat-text")
    local buf = tv:get_buffer()

    local iter = buf:get_end_iter()
    local welcome_md = "  **QWEN DESKTOP ASSISTANT (LUA + C/C++ + LLAMA.CPP)**\n" ..
                       "  Motor hibrido con presupuesto estricto <= 500 MB RAM.\n" ..
                       "  - Modelo Chat Local: `qwen3.0-0.8b.gguf`\n" ..
                       "  - Modelo Gramatica Local: `es-grammar.gguf`\n" ..
                       "  - Multimedia: YouTube Music + Spotify (MPRIS2)\n" ..
                       "  Escribe un mensaje o usa `/help` para comandos de OpenClaw.\n"
    local ok_w = pcall(function() buf:insert_markup(iter, md_to_pango(welcome_md), -1) end)
    if not ok_w then buf:insert(iter, welcome_md, -1) end

    sw:add(tv)
    chat_view:pack_start(sw, true, true, 0)

    local input_box = Gtk.Box {
        orientation = Gtk.Orientation.HORIZONTAL, spacing = 8,
        margin_start = 12, margin_end = 12,
        margin_top = 6, margin_bottom = 12,
    }
    local entry = Gtk.Entry { placeholder_text = "Escribe un mensaje o comando (/help)..." }
    entry:get_style_context():add_class("chat-entry")
    entry.on_activate = function() on_send() end
    input_box:pack_start(entry, true, true, 0)

    local send_btn = Gtk.Button { label = "ENVIAR" }
    send_btn:get_style_context():add_class("send-btn")
    send_btn:set_tooltip_text("Enviar mensaje (Enter)")
    send_btn.on_clicked = function() on_send() end
    input_box:pack_end(send_btn, false, false, 0)
    chat.send_btn = send_btn

    chat_view:pack_start(input_box, false, false, 0)
    vbox:pack_start(chat_view, true, true, 0)

    -- Container 2: Config View
    local config_view = build_config_view()
    vbox:pack_start(config_view, true, true, 0)
    config_view:hide()

    chat.chat_view = chat_view
    chat.config_view = config_view
    chat.current_tab = "chat"

    tab_chat.on_clicked = function()
        chat.set_tab("chat")
    end

    tab_config.on_clicked = function()
        chat.set_tab("config")
    end

    win:add(vbox)

    chat.window   = win
    chat.textview = tv
    chat.entry    = entry
    chat.scroll   = sw
    chat.buffer   = buf

    win.on_key_press_event = function(_, event)
        if event.keyval == Gdk.KEY_Escape then
            chat.hide()
            return true
        end
        return false
    end

    win.on_delete_event = function()
        chat.hide()
        return true
    end
end

local last_toggle_time = 0

local function calc_chat_pos(bx, by, bsize, edge)
    local cw = config.CHAT_W or 400
    local ch = config.CHAT_H or 510
    local gap = config.CHAT_GAP or 12
    local tx, ty = utils.compute_dock(bx, by, bsize, cw, ch, gap, edge or "auto", 8)
    return tx, ty
end

-- Real-time smooth coordinate tracking when the main bubble is dragged or snapped
function chat.reposition(bx, by, bsize, edge)
    last_bx = bx or last_bx
    last_by = by or last_by
    last_bsize = bsize or last_bsize
    last_edge = edge or last_edge

    if not chat.window or not chat.visible then return end

    local tx, ty = calc_chat_pos(last_bx, last_by, last_bsize, last_edge)
    if cur_cx and cur_cy and qwen_native and qwen_native.lerp_point then
        cur_cx, cur_cy = qwen_native.lerp_point(cur_cx, cur_cy, tx, ty, 0.65)
    else
        cur_cx, cur_cy = tx, ty
    end
    chat.window:move(math.floor(cur_cx), math.floor(cur_cy))
end

function chat.set_tab(tab_name)
    chat.current_tab = tab_name or "chat"
    if not chat.chat_view or not chat.config_view then return end

    if chat.current_tab == "chat" then
        if chat.tab_chat and chat.tab_config then
            chat.tab_chat:get_style_context():add_class("tab-btn-active")
            chat.tab_chat:get_style_context():remove_class("tab-btn")
            chat.tab_config:get_style_context():remove_class("tab-btn-active")
            chat.tab_config:get_style_context():add_class("tab-btn")
        end
        chat.config_view:hide()
        chat.chat_view:show()
        if chat.entry then chat.entry:grab_focus() end
    else
        if chat.tab_chat and chat.tab_config then
            chat.tab_config:get_style_context():add_class("tab-btn-active")
            chat.tab_config:get_style_context():remove_class("tab-btn")
            chat.tab_chat:get_style_context():remove_class("tab-btn-active")
            chat.tab_chat:get_style_context():add_class("tab-btn")
        end
        chat.chat_view:hide()
        chat.config_view:show()
    end
    collectgarbage("step", 50)
end

function chat.show(bx, by, bsize, edge)
    chat.build()
    if not chat.window then return end

    chat.visible = true
    if chat.on_state_change then pcall(chat.on_state_change, "chatting") end

    last_bx = bx or last_bx
    last_by = by or last_by
    last_bsize = bsize or last_bsize
    last_edge = edge or last_edge

    local ok_b, bubbles = pcall(require, "bubbles")
    if ok_b and bubbles then bubbles.hide() end

    local tx, ty = calc_chat_pos(last_bx, last_by, last_bsize, last_edge)
    cur_cx, cur_cy = tx, ty

    update_header_badges()
    chat.window:move(math.floor(tx), math.floor(ty))
    if not chat.window:get_visible() then
        chat.window:set_opacity(0)
        chat.window:show_all()
    end

    -- Fix: Re-enforce tab visibility because show_all() unhides all children including config_view
    chat.set_tab(chat.current_tab or "chat")
    if chat.update_theme_mode then chat.update_theme_mode() end
    if chat.update_corners then chat.update_corners() end

    animator.fade(chat.window, "in", function()
        if chat.visible and chat.entry and (chat.current_tab or "chat") == "chat" then
            chat.entry:grab_focus()
        end
    end)
end

function chat.hide(instant)
    if not chat.window then return end
    chat.visible = false
    ai_engine.cancel()
    if chat.on_state_change then pcall(chat.on_state_change, "idle") end

    if instant then
        animator.stop(chat.window)
        chat.window:set_opacity(0)
        chat.window:hide()
        collectgarbage("step", 50)
        return
    end

    animator.fade(chat.window, "out", function()
        if not chat.visible and chat.window then
            chat.window:hide()
            chat.window:set_opacity(0)
        end
        collectgarbage("step", 50)
    end)
end

function chat.update_avatar()
    if chat.avatar_image then
        local avatar_mini = utils.load_sprite("idle", 24) or utils.load_pixbuf(config.custom_avatar or config.AVATAR, 24)
        if avatar_mini then
            chat.avatar_image:set_from_pixbuf(avatar_mini)
        end
    end
end

function chat.update_header()
    if chat.title_label then
        chat.title_label:set_text(config.chat_header or config.agent_name or "KITSU AI")
    end
end

function chat.update_theme_mode()
    if not chat.window then return end

    pcall(function()
        local s = Gtk.Settings.get_default()
        if s then
            s.gtk_application_prefer_dark_theme = (config.theme_mode ~= "light")
        end
    end)

    local ctx = chat.window:get_style_context()
    if config.theme_mode == "light" then
        ctx:add_class("theme-light")
    else
        ctx:remove_class("theme-light")
    end

    if chat.mode_btn then
        chat.mode_btn:set_label((config.theme_mode == "light") and "MODO: CLARO" or "MODO: OSCURO")
    end

    if chat.btn_mode_dark and chat.btn_mode_light then
        if config.theme_mode == "light" then
            chat.btn_mode_light:get_style_context():add_class("pill-choice-active")
            chat.btn_mode_light:get_style_context():remove_class("pill-choice")
            chat.btn_mode_dark:get_style_context():add_class("pill-choice")
            chat.btn_mode_dark:get_style_context():remove_class("pill-choice-active")
        else
            chat.btn_mode_dark:get_style_context():add_class("pill-choice-active")
            chat.btn_mode_dark:get_style_context():remove_class("pill-choice")
            chat.btn_mode_light:get_style_context():add_class("pill-choice")
            chat.btn_mode_light:get_style_context():remove_class("pill-choice-active")
        end
    end

    chat.window:queue_draw()
end

function chat.update_corners()
    if not chat.window then return end
    local ctx = chat.window:get_style_context()
    if config.rounded_corners == true then
        ctx:remove_class("sharp-corners")
    else
        ctx:add_class("sharp-corners")
    end

    if chat.switch_corners then
        chat.switch_corners:set_active(config.rounded_corners == true)
    end

    chat.window:queue_draw()
end

function chat.toggle(bx, by, bsize, edge)
    local now = GLib.get_monotonic_time() / 1000
    if (now - last_toggle_time) < 150 then
        return
    end
    last_toggle_time = now

    if chat.visible then
        chat.hide()
    else
        chat.show(bx, by, bsize, edge)
    end
end

return chat
