-- Project Azmuth — integração com o Hyprland.
-- Instalado via symlink em ~/.config/hypr/azmuth.lua e carregado no
-- hyprland.lua com require("azmuth"). Versionado dentro do projeto.

local HOME    = os.getenv("HOME")
local PROJECT = HOME .. "/Documents/Coding/Project Azmuth"
local AZ      = HOME .. "/.local/bin/azmuth"
local HUD     = "'" .. PROJECT .. "/hud'"
local PY      = "'" .. PROJECT .. "/.venv/bin/python'"
local mainMod = "SUPER"

---------------------------
---- AUTOSTART (Azmuth) ----
---------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd(AZ .. " restore")                                 -- reaplica o último DNA (sobe a waybar)
    hl.exec_cmd(PY .. " -u '" .. PROJECT .. "/src/context_engine.py' >> " .. HOME .. "/.local/state/azmuth/context.log 2>&1") -- Context Engine
    hl.exec_cmd("command -v qs >/dev/null && qs -p " .. HUD)       -- Omnitrix HUD (Quickshell)
end)

-- HUD e flash de transformação desenham a própria animação
hl.layer_rule({
    name   = "azmuth-layers",
    match  = { namespace = "^azmuth-(hud|flash)$" },
    no_anim = true,
})

------------------------------
---- OMNITRIX HUD (seletor) ----
------------------------------

local function hud_open()
    return #hl.get_layers({ namespace = "azmuth-hud" }) > 0
end

local function hud(action)
    hl.exec_cmd("qs -p " .. HUD .. " ipc call hud " .. action)
end

-- Super + Space: ativa o disco (cai para um seletor em rofi se o Quickshell faltar)
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(AZ .. " hud toggle"))
-- botões laterais do Redragon M909 (com Super, para não roubar voltar/avançar do navegador)
hl.bind(mainMod .. " + mouse:275", hl.dsp.exec_cmd(AZ .. " hud toggle"))
hl.bind(mainMod .. " + mouse:276", hl.dsp.exec_cmd(AZ .. " hud toggle"))

-- Super + ←/→ giram o disco quando o HUD está aberto; senão, foco normal de janela
hl.bind(mainMod .. " + left", function()
    if hud_open() then hud("prev") else hl.dispatch(hl.dsp.focus({ direction = "left" })) end
end)
hl.bind(mainMod .. " + right", function()
    if hud_open() then hud("next") else hl.dispatch(hl.dsp.focus({ direction = "right" })) end
end)
-- Super + Enter confirma a transformação
hl.bind(mainMod .. " + Return", function()
    if hud_open() then hud("confirm") end
end)

------------------------------------------
---- MASTER CONTROL (Super + Numpad 1–0) ----
------------------------------------------
-- Numpad com NumLock ligado (KP_n) e desligado (nomes de navegação), mais
-- Super + Alt + 1–0 como alternativa para o Ajazz AK820 (75%, sem numpad).

local numpad_nav = {
    [1] = "KP_End", [2] = "KP_Down", [3] = "KP_Next", [4] = "KP_Left", [5] = "KP_Begin",
    [6] = "KP_Right", [7] = "KP_Home", [8] = "KP_Up", [9] = "KP_Prior", [0] = "KP_Insert",
}
for n = 0, 9 do
    local cmd = hl.dsp.exec_cmd(AZ .. " slot " .. n)
    hl.bind(mainMod .. " + KP_" .. n, cmd)
    hl.bind(mainMod .. " + " .. numpad_nav[n], cmd)
    hl.bind(mainMod .. " + ALT + " .. n, cmd)
end

-- Rollback para o Neutral
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(AZ .. " neutral"))
-- Randomizer ("falha" do relógio)
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(AZ .. " random"))
-- Context Engine: aceitar sugestão / ligar-desligar Master Control (troca automática)
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd(AZ .. " accept"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(AZ .. " master toggle"))

----------------------------------
---- MINIMIZAR (workspace oculto) ----
----------------------------------
-- O Hyprland não tem "minimizar" nativo: a janela vai para special:minimized.
-- Ela volta com Super+Shift+N (a última minimizada) ou clicando nela na taskbar
-- da waybar — qualquer foco numa janela minimizada a restaura no workspace atual.

local MIN = "special:minimized"

local function restore(w)
    local ws = hl.get_active_workspace()
    if not ws then return end
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws.id), window = "address:" .. w.address }))
    hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
    local sp = hl.get_active_special_workspace()
    if sp and sp.name == MIN then
        hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))
    end
end

hl.bind(mainMod .. " + N", function()
    local w = hl.get_active_window()
    if w then
        hl.dispatch(hl.dsp.window.move({ workspace = MIN, window = "address:" .. w.address, follow = false }))
    end
end)

hl.bind(mainMod .. " + SHIFT + N", function()
    local wins = hl.get_workspace_windows(MIN)
    if wins and #wins > 0 then restore(wins[#wins]) end
end)

hl.on("window.active", function(w)
    if w and w.workspace and w.workspace.name == MIN then restore(w) end
end)

---------------------------------
---- BLOQUEIO E ENERGIA ----
---------------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("command -v hypridle >/dev/null && hypridle")
end)

-- Super + M bloqueia (antes fazia logout). Sair/reiniciar/desligar: Super + Shift + Q.
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(AZ .. " lock"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd(AZ .. " power"))
