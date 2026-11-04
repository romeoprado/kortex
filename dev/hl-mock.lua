-- Um "hl" de mentira, para rodar fora do Hyprland a configuração em Lua que o Kortex gera.
--   lua dev/hl-mock.lua <hyprland.lua>
--
-- Executa o arquivo (e o que ele carrega) com uma imitação da API do Hyprland que confere a forma
-- de cada chamada: atalhos com teclas em texto e uma ação, regras com match, monitores com output,
-- hl.config só com tabelas. Não sabe quais opções existem: isso só o Hyprland confere (hyprctl
-- configerrors). Imprime um resumo e sai com código 1 no primeiro erro, ou se a configuração mandou
-- um aviso (o kortex_load do hyprland.lua avisa quando um arquivo do Kortex tem erro).
local file = arg[1]
if not file then
    io.stderr:write("uso: lua hl-mock.lua <hyprland.lua>\n")
    os.exit(2)
end

local count = { bind = 0, config = 0, monitor = 0, window_rule = 0, layer_rule = 0, env = 0, exec = 0, animation = 0, curve = 0 }
local notices = {}

local function check(cond, msg)
    if not cond then error(msg, 3) end
end

-- hl.dsp.qualquer.coisa(...) devolve uma descrição da ação, como o Hyprland (que só a executa depois)
local function namespace(path)
    return setmetatable({}, {
        __index = function(_, k) return namespace(path .. "." .. k) end,
        __call = function(_, ...) return { dispatcher = path, args = { ... } } end,
    })
end

local function is_action(a)
    return type(a) == "function" or (type(a) == "table" and a.dispatcher ~= nil)
end

hl = {
    dsp = namespace("hl.dsp"),
    config = function(t)
        check(type(t) == "table", "hl.config: esperava uma tabela")
        count.config = count.config + 1
    end,
    bind = function(keys, action, opts)
        check(type(keys) == "string" and keys ~= "", "hl.bind: teclas vazias")
        check(is_action(action), "hl.bind(" .. keys .. "): a ação não é um hl.dsp nem uma função")
        check(opts == nil or type(opts) == "table", "hl.bind(" .. keys .. "): opções devem ser uma tabela")
        count.bind = count.bind + 1
        return { unbind = function() end, remove = function() end, set_enabled = function() end }
    end,
    unbind = function(keys) check(type(keys) == "string", "hl.unbind: esperava texto") end,
    monitor = function(spec)
        check(type(spec) == "table" and type(spec.output) == "string", "hl.monitor: falta o output")
        count.monitor = count.monitor + 1
    end,
    window_rule = function(spec)
        check(type(spec) == "table" and type(spec.match) == "table", "hl.window_rule: falta o match")
        count.window_rule = count.window_rule + 1
        return { set_enabled = function() end }
    end,
    layer_rule = function(spec)
        check(type(spec) == "table" and type(spec.match) == "table", "hl.layer_rule: falta o match")
        count.layer_rule = count.layer_rule + 1
        return { set_enabled = function() end }
    end,
    env = function(k, v)
        check(type(k) == "string" and type(v) == "string", "hl.env: nome e valor em texto")
        count.env = count.env + 1
    end,
    exec_cmd = function(cmd)
        check(type(cmd) == "string", "hl.exec_cmd: comando em texto")
        count.exec = count.exec + 1
    end,
    curve = function(name, spec)
        check(type(name) == "string" and type(spec) == "table", "hl.curve: nome e tabela")
        count.curve = count.curve + 1
    end,
    animation = function(spec)
        check(type(spec) == "table" and type(spec.leaf) == "string", "hl.animation: falta o leaf")
        count.animation = count.animation + 1
    end,
    -- o início da sessão roda na hora, para conferir o que está dentro
    on = function(event, fn)
        check(type(event) == "string" and type(fn) == "function", "hl.on: evento e função")
        if event == "hyprland.start" then fn() end
    end,
    dispatch = function(a) check(is_action(a), "hl.dispatch: esperava um hl.dsp") end,
    notification = {
        create = function(opts) notices[#notices + 1] = tostring(opts and opts.text) end,
    },
}

-- require("user") procura ao lado do hyprland.lua, como no Hyprland
package.path = (file:match("^(.*)/") or ".") .. "/?.lua;" .. package.path

local ok, err = pcall(dofile, file)
if not ok then
    io.stderr:write("erro: " .. tostring(err) .. "\n")
    os.exit(1)
end
for _, n in ipairs(notices) do io.stderr:write("aviso: " .. n .. "\n") end

local parts = {}
for _, k in ipairs({ "bind", "config", "monitor", "window_rule", "layer_rule", "env", "exec", "curve", "animation" }) do
    parts[#parts + 1] = k .. "=" .. count[k]
end
print(table.concat(parts, " "))
os.exit(#notices == 0 and 0 or 1)
