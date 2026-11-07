#!/usr/bin/env lua5.3
----------------------------------------------------------------------
-- main.lua  –  Kitsu Hybrid Engine Entry Point (Lua + C/C++)
----------------------------------------------------------------------

local script_source = debug.getinfo(1, "S").source:match("^@?(.*)$")
local script_dir = script_source and script_source:match("(.*)/[^/]+")
local detected_base = nil
if script_dir then
    detected_base = script_dir:match("(.*)/lib") or script_dir
end
local base_dir = os.getenv("KITSU_DIR") or os.getenv("KITSU_ROOT") or os.getenv("QWEN_WIDGET_DIR") or os.getenv("QWEN_WIDGET_ROOT") or detected_base or "/opt/kitsu"
local lib_dir  = base_dir .. "/lib"

-- Prepend local lib/ and root to package.path and package.cpath
package.path  = lib_dir .. "/?.lua;" .. base_dir .. "/?.lua;" .. package.path
package.cpath = lib_dir .. "/?.so;" .. base_dir .. "/?.so;" .. package.cpath

local ok, lgi = pcall(require, "lgi")
if not ok then
    io.stderr:write("[kitsu] FATAL: cannot load LGI bindings.\n")
    io.stderr:write("  Error: " .. tostring(lgi) .. "\n")
    os.exit(1)
end

local Gtk  = lgi.require("Gtk", "3.0")
local GLib = lgi.GLib

local config = require("config")
config.BASE_DIR   = base_dir
config.ASSETS_DIR = base_dir .. "/assets"
config.AVATAR     = config.ASSETS_DIR .. "/avatar.jpg"

local ok_native, qwen_native = pcall(require, "qwen_native")
local native_ver = (ok_native and qwen_native and qwen_native.VERSION) or "fallback-lua"

local ai_engine = require("ai_engine")
local widget    = require("widget")
local theme_mgr = require("theme_manager")

-- 1. Resolver el tema prioritario (CLI --theme > ENV KITSU_THEME > Config > "default")
local cli_theme = nil
if arg and type(arg) == "table" then
    for i = 1, #arg do
        if arg[i] == "--theme" and arg[i+1] then
            cli_theme = arg[i+1]
        elseif arg[i]:match("^%-%-theme=(.+)$") then
            cli_theme = arg[i]:match("^%-%-theme=(.+)$")
        end
    end
end

Gtk.init()

pcall(function()
    local s = Gtk.Settings.get_default()
    if s then
        s.gtk_application_prefer_dark_theme = (config.theme_mode ~= "light")
    end
end)

local active_theme = cli_theme or os.getenv("KITSU_THEME") or config.theme or "default"
local ok_th, th_msg = theme_mgr.apply_theme(active_theme)
if not ok_th then
    io.stderr:write(string.format("[kitsu] WARN: No se pudo aplicar tema '%s': %s\n", active_theme, tostring(th_msg)))
end

io.stderr:write(string.format(
    "[kitsu] Starting Kitsu Hybrid Engine (%s) | Theme=%s | Chat=%s | Grammar=%s\n",
    native_ver,
    theme_mgr.active_theme_id or "default",
    config.chat_model or "qwen3.0-0.8b.gguf",
    config.grammar_model or "es-grammar.gguf"
))
io.stderr:write("[kitsu] Base dir: " .. base_dir .. "\n")

widget.build()
widget.start()

-- Ensure clean shutdown of embedded llama.cpp on exit
GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, 15, function()
    ai_engine.stop_local()
    Gtk.main_quit()
    return false
end)
GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, 2, function()
    ai_engine.stop_local()
    Gtk.main_quit()
    return false
end)

Gtk.main()

ai_engine.stop_local()
io.stderr:write("[qwen-widget] Exited cleanly.\n")
