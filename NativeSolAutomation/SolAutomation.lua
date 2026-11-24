-- Sol Automation Native 0.1.0
-- MDRG 0.97.12
-- Native MoonSharp mod. No external loader.

local PREFIX = "[SolAutomation] "
local KEY_STREAM = "SolAutomation.StreamingEnabled"
local KEY_FISH = "SolAutomation.FishingEnabled"
local KEY_FISH_SKIP = "SolAutomation.FishingSkipEnabled"
local SAFE_MIN = 0.10
local SAFE_GUARD = 0.115
local CUM_MIN = 5.0
local FAST_SCALE = 12.0

local previousTimeScale = 1.0
local streamFast = false
local optionsButtonInstalledFor = nil
local fishingButtonInstalledFor = nil
local lastFishingActive = false
local warned = {}
local fallbackNoticeShown = false

local function log(msg)
    print(PREFIX .. tostring(msg))
end

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    log("AVISO: " .. msg)
end

local function G(name)
    local ok, value = pcall(function()
        return _G[name]
    end)
    if ok then return value end
    return nil
end

local function getGV()
    local direct = G("gv")
    if direct ~= nil then return direct end

    local mu = G("ModUtilities")
    if mu ~= nil then
        local ok, value = pcall(function()
            return mu.GetGameVariables()
        end)
        if ok and value ~= nil then return value end
    end

    return nil
end

local function getCustomData()
    local g = getGV()
    if g == nil then return nil end

    local ok, data = pcall(function()
        return g.customData
    end)

    if ok then return data end
    return nil
end

local function getBool(key, defaultValue)
    local data = getCustomData()
    if data == nil then return defaultValue end

    local ok, value = pcall(function()
        return data:GetIntSpecialVariableOrDefaultCastBool(key, defaultValue)
    end)

    if ok then return value end
    return defaultValue
end

local function setBool(key, value)
    local data = getCustomData()
    if data == nil then
        warnOnce("customdata", "GameVariables.customData ainda nao esta disponivel.")
        return false
    end

    local ok, err = pcall(function()
        data:SetIntSpecialVariableCastBool(key, value)
    end)

    if not ok then
        warnOnce("customdata-write", "Nao consegui salvar configuracao: " .. tostring(err))
        return false
    end

    return true
end

local function toggleBool(key, defaultValue)
    local value = not getBool(key, defaultValue)
    setBool(key, value)
    return value
end

local function overlaySimplePopup(title, text, yesAction, noAction)
    local ui = G("UiOverlay")
    if ui == nil then return false end

    local ok = pcall(function()
        ui.SimplePopup(title, text, yesAction, noAction)
    end)

    return ok
end

local function overlayOk(title, text)
    local ui = G("UiOverlay")
    if ui == nil then return false end

    return pcall(function()
        ui.OkPopup(title, text)
    end)
end

local function openFishingSettings()
    local enabled = getBool(KEY_FISH, false)
    local skip = getBool(KEY_FISH_SKIP, false)

    local text =
        "Auto pesca: " .. (enabled and "LIGADA" or "DESLIGADA") ..
        "\nPular captura: " .. (skip and "LIGADO" or "DESLIGADO") ..
        "\n\nSIM: alternar auto pesca\nNAO: configurar modo de pular"

    local shown = overlaySimplePopup(
        "Sol Automation - Pesca",
        text,
        function()
            local value = toggleBool(KEY_FISH, false)
            log("Auto pesca = " .. tostring(value))
            openFishingSettings()
        end,
        function()
            local current = getBool(KEY_FISH_SKIP, false)
            overlaySimplePopup(
                "Sol Automation - Pular pesca",
                "Pular captura esta " .. (current and "LIGADO" or "DESLIGADO") ..
                ".\n\nQuando ativo, o mod tenta concluir o progresso usando a propria UI do minigame. " ..
                "O jogo continua responsavel por tempo, isca, vara, inventario e recompensas.\n\nAlternar?",
                function()
                    local value = toggleBool(KEY_FISH_SKIP, false)
                    log("Pular pesca = " .. tostring(value))
                end,
                function() end
            )
        end
    )

    if not shown then
        warnOnce("ui-overlay", "UiOverlay nao esta acessivel no sandbox Lua.")
    end
end

function SolAutomationOpenSettings()
    local enabled = getBool(KEY_STREAM, false)

    local text =
        "Streaming automatico: " .. (enabled and "LIGADO" or "DESLIGADO") ..
        "\n\nSIM: alternar streaming automatico\nNAO: abrir configuracoes da pesca"

    local shown = overlaySimplePopup(
        "Sol Automation",
        text,
        function()
            local value = toggleBool(KEY_STREAM, false)
            log("Streaming automatico = " .. tostring(value))
            SolAutomationOpenSettings()
        end,
        function()
            openFishingSettings()
        end
    )

    if not shown then
        warnOnce("settings-popup", "Nao consegui abrir o popup de configuracoes.")
    end
end

local function getGameScript()
    local gs = G("GameScript")
    if gs == nil then return nil end

    local ok, instance = pcall(function()
        return gs.Instance
    end)

    if ok then return instance end
    return nil
end

local function getGameState()
    local gs = getGameScript()
    if gs == nil then return nil end

    local ok, state = pcall(function()
        return gs.GameState
    end)

    if ok then return state end
    return nil
end

local function objectTypeName(obj)
    if obj == nil then return "" end

    local ok, name = pcall(function()
        return obj:GetType().Name
    end)

    if ok and name ~= nil then return tostring(name) end
    return tostring(obj)
end

local function isStreamSexActive()
    local state = getGameState()

    if state ~= nil then
        local ok, manager = pcall(function()
            return state.CurrentStreamManager
        end)

        if ok and manager ~= nil then return true end

        local okFlag, flag = pcall(function()
            return state.StreamOnFlagSet
        end)

        if okFlag and flag == true then return true end
    end

    return false
end

local function getTimeScale()
    local t = G("Time")
    if t == nil then t = G("UnityEngine.Time") end
    if t == nil then return nil end

    local ok, value = pcall(function()
        return t.timeScale
    end)

    if ok then return value end
    return nil
end

local function setTimeScale(value)
    local t = G("Time")
    if t == nil then t = G("UnityEngine.Time") end
    if t == nil then return false end

    local ok = pcall(function()
        t.timeScale = value
    end)

    return ok
end

local function stopStreamFastForward()
    if not streamFast then return end

    if setTimeScale(previousTimeScale) then
        log("Streaming: velocidade normal restaurada.")
    end

    streamFast = false
end

local function updateStreaming()
    if not getBool(KEY_STREAM, false) then
        stopStreamFastForward()
        return
    end

    local g = getGV()
    if g == nil then
        stopStreamFastForward()
        return
    end

    if not isStreamSexActive() then
        stopStreamFastForward()
        return
    end

    local okS, stamina = pcall(function() return g.Stamina end)
    local okH, hunger = pcall(function() return g.Satiation end)
    local okC, remainingCum = pcall(function() return g.RemainingCum end)

    if not okS or not okH then
        warnOnce("resources", "Stamina/Satiation nao estao acessiveis.")
        stopStreamFastForward()
        return
    end

    if (okC and remainingCum < CUM_MIN) or stamina <= SAFE_GUARD or hunger <= SAFE_GUARD then
        -- Guard against a single accelerated frame crossing the requested 10% floor.
        if stamina < SAFE_MIN then
            pcall(function() g.Stamina = SAFE_MIN end)
        end

        if hunger < SAFE_MIN then
            pcall(function() g.Satiation = SAFE_MIN end)
        end

        stopStreamFastForward()
        return
    end

    local currentScale = getTimeScale()
    if currentScale == nil then
        warnOnce("time", "UnityEngine.Time nao esta exposto ao Lua; streaming nao pode ser acelerado com seguranca.")
        return
    end

    if not streamFast then
        previousTimeScale = currentScale
        streamFast = true
        log("Streaming: avanço automatico iniciado.")
    end

    setTimeScale(FAST_SCALE)
end

local function getInput()
    local input = G("Input")
    if input == nil then input = G("UnityEngine.Input") end
    return input
end

local function getKeyCode()
    local kc = G("KeyCode")
    if kc == nil then kc = G("UnityEngine.KeyCode") end
    return kc
end

local function keyPPressed()
    local input = getInput()
    local keyCode = getKeyCode()

    if input == nil or keyCode == nil then
        return false
    end

    local ok, pressed = pcall(function()
        return input.GetKeyDown(keyCode.P)
    end)

    return ok and pressed == true
end

local function getObjectClass()
    return G("Object") or G("UnityEngine.Object") or G("UnityEngineObject")
end

local function getGameObjectClass()
    return G("GameObject") or G("UnityEngine.GameObject")
end

local function findGO(names)
    local goClass = getGameObjectClass()
    if goClass == nil then return nil end

    for _, name in ipairs(names) do
        local ok, obj = pcall(function()
            return goClass.Find(name)
        end)

        if ok and obj ~= nil then return obj end
    end

    return nil
end

local function getComponent(go, names)
    if go == nil then return nil end

    for _, name in ipairs(names) do
        local ok, comp = pcall(function()
            return go:GetComponent(name)
        end)

        if ok and comp ~= nil then return comp end
    end

    return nil
end

local function walkTransforms(root, callback)
    if root == nil then return end

    local function visit(t, depth)
        if t == nil or depth > 12 then return end

        local continue = callback(t)
        if continue == false then return end

        local okCount, childCount = pcall(function()
            return t.childCount
        end)

        if not okCount or childCount == nil then return end

        for i = 0, childCount - 1 do
            local okChild, child = pcall(function()
                return t:GetChild(i)
            end)

            if okChild and child ~= nil then
                visit(child, depth + 1)
            end
        end
    end

    visit(root, 0)
end

local function transformName(t)
    local ok, value = pcall(function() return t.name end)
    if ok and value ~= nil then return string.lower(tostring(value)) end
    return ""
end

local function findTransformByTokens(root, tokens)
    local found = nil

    walkTransforms(root, function(t)
        local n = transformName(t)

        for _, token in ipairs(tokens) do
            if string.find(n, string.lower(token), 1, true) then
                found = t
                return false
            end
        end
    end)

    return found
end

local function setSameY(target, source)
    if target == nil or source == nil then return false end

    local ok = pcall(function()
        local targetPos = target.anchoredPosition
        local sourcePos = source.anchoredPosition
        targetPos.y = sourcePos.y
        target.anchoredPosition = targetPos
    end)

    if ok then return true end

    return pcall(function()
        local targetPos = target.localPosition
        local sourcePos = source.localPosition
        targetPos.y = sourcePos.y
        target.localPosition = targetPos
    end)
end

local function isFishingState()
    local state = getGameState()
    if state == nil then return false end

    local n = string.lower(objectTypeName(state))
    return string.find(n, "fishinggameplaystate", 1, true) ~= nil
end

local function findFishingRoot()
    local candidates = {
        "Fishing Gameplay",
        "Fishing Gameplay Static Gui",
        "Fishing Info Window",
        "Fishing Display Window",
        "Fishing Gauge"
    }

    local found = findGO(candidates)
    if found ~= nil then return found.transform end

    local gauge = findGO({"Fishing Gauge", "A_Fishing_Gauge"})
    if gauge ~= nil then return gauge.transform end

    return nil
end

local function fishingPerfectTrack()
    if not getBool(KEY_FISH, false) then return end
    if not isFishingState() then return end

    local root = findFishingRoot()
    if root == nil then
        warnOnce("fishing-root", "Minigame detectado, mas a arvore visual da pesca nao foi encontrada pelos nomes conhecidos.")
        return
    end

    local rod = findTransformByTokens(root, {
        "fishing gauge rod",
        "gauge rod",
        "catch bar",
        "white bar"
    })

    local fish = findTransformByTokens(root, {
        "fishing gauge fish",
        "gauge fish"
    })

    if rod ~= nil and fish ~= nil then
        setSameY(rod, fish)
    else
        warnOnce("fish-bar", "Nao encontrei a barra branca e/ou o peixe na hierarquia da UI.")
    end

    -- Keep throw slider in the center as a safe fallback for the perfect zone.
    local throwGO = findGO({"Fishing Throw", "A_Fishing_Throw"})
    local throwSlider = getComponent(throwGO, {"UnityEngine.UI.Slider", "Slider"})
    if throwSlider ~= nil then
        pcall(function()
            throwSlider.value = 0.5
        end)
    end

    if getBool(KEY_FISH_SKIP, false) then
        -- Do not create rewards directly. We only push the minigame's own
        -- progress UI/state to completion and let its result path award items.
        local progressGO = findGO({"Fishing Progress", "A_Fishing_Progress"})
        local progress = getComponent(progressGO, {
            "UnityEngine.UI.Scrollbar",
            "Scrollbar",
            "UnityEngine.UI.Slider",
            "Slider"
        })

        if progress ~= nil then
            pcall(function()
                progress.value = 1.0
            end)
            pcall(function()
                progress.size = 1.0
            end)
        end
    end
end

local function setButtonText(go, text)
    if go == nil then return false end

    local root = go.transform
    local changed = false

    walkTransforms(root, function(t)
        local childGO = nil
        pcall(function() childGO = t.gameObject end)

        if childGO ~= nil then
            local label = getComponent(childGO, {
                "TMPro.TextMeshProUGUI",
                "TextMeshProUGUI",
                "UnityEngine.UI.Text",
                "Text"
            })

            if label ~= nil then
                local ok = pcall(function()
                    label.text = text
                end)

                if ok then changed = true end
            end
        end
    end)

    return changed
end

local function cloneButton(sourceButton, newName, label, onClick, yOffset)
    if sourceButton == nil then return nil end

    local objectClass = getObjectClass()
    if objectClass == nil then return nil end

    local sourceGO = nil
    pcall(function() sourceGO = sourceButton.gameObject end)
    if sourceGO == nil then return nil end

    local parent = nil
    pcall(function() parent = sourceGO.transform.parent end)

    local ok, clone = pcall(function()
        return objectClass.Instantiate(sourceGO, parent)
    end)

    if not ok or clone == nil then return nil end

    pcall(function() clone.name = newName end)
    setButtonText(clone, label)

    local button = getComponent(clone, {"UnityEngine.UI.Button", "Button"})
    if button == nil then return nil end

    pcall(function()
        button.onClick:RemoveAllListeners()
        button.onClick:AddListener(onClick)
    end)

    if yOffset ~= nil then
        pcall(function()
            local p = clone.transform.anchoredPosition
            p.y = p.y + yOffset
            clone.transform.anchoredPosition = p
        end)
    end

    return clone
end

local function findFirstButton(root)
    local found = nil

    walkTransforms(root, function(t)
        local go = nil
        pcall(function() go = t.gameObject end)

        if go ~= nil then
            local button = getComponent(go, {"UnityEngine.UI.Button", "Button"})
            if button ~= nil then
                found = button
                return false
            end
        end
    end)

    return found
end

local function tryInstallOptionsButton()
    local options = G("OptionsPopup")
    if options == nil then
        warnOnce("options-type", "OptionsPopup nao esta registrado no Lua. O popup nativo de configuracao continuara disponivel como fallback.")
        return
    end

    local ok, instance = pcall(function()
        return options.CurrentInstance
    end)

    if not ok or instance == nil then return end
    if optionsButtonInstalledFor == instance then return end

    local root = nil
    pcall(function() root = instance.transform end)
    if root == nil then
        warnOnce("options-transform", "OptionsPopup existe, mas o Transform nao esta acessivel.")
        return
    end

    local source = findFirstButton(root)
    if source == nil then
        warnOnce("options-button-source", "Nao encontrei um botao-base nas Opcoes para clonar.")
        return
    end

    local clone = cloneButton(
        source,
        "SolAutomationSettingsButton",
        "Sol Automation",
        function()
            SolAutomationOpenSettings()
        end,
        -46.0
    )

    if clone ~= nil then
        optionsButtonInstalledFor = instance
        log("Botao Sol Automation adicionado em Opcoes.")
    else
        warnOnce("options-clone", "A API Unity Object/Button nao esta exposta o suficiente para criar o botao em Opcoes.")
    end
end

local function tryInstallFishingButton()
    if not isFishingState() then
        fishingButtonInstalledFor = nil
        return
    end

    local root = findFishingRoot()
    if root == nil then return end
    if fishingButtonInstalledFor == root then return end

    local source = findFirstButton(root)

    if source == nil then
        warnOnce("fishing-button-source", "Nao encontrei um botao-base no minigame para clonar.")
        return
    end

    local clone = cloneButton(
        source,
        "SolAutomationFishingButton",
        getBool(KEY_FISH, false) and "AUTO PESCA [P]: ON" or "AUTO PESCA [P]: OFF",
        function()
            local value = toggleBool(KEY_FISH, false)
            log("Auto pesca = " .. tostring(value))
            setButtonText(clone, value and "AUTO PESCA [P]: ON" or "AUTO PESCA [P]: OFF")
        end,
        -46.0
    )

    if clone ~= nil then
        fishingButtonInstalledFor = root
        log("Botao AUTO PESCA instalado no minigame.")
    end
end

local function updateFishing()
    local active = isFishingState()

    if active and not lastFishingActive then
        log("Minigame de pesca detectado.")
    elseif not active and lastFishingActive then
        log("Minigame de pesca encerrado.")
        fishingButtonInstalledFor = nil
    end

    lastFishingActive = active

    if not active then return end

    if keyPPressed() then
        local value = toggleBool(KEY_FISH, false)
        log("Tecla P: Auto pesca = " .. tostring(value))
    end

    tryInstallFishingButton()
    fishingPerfectTrack()
end

local function showFallbackNoticeOnce()
    if fallbackNoticeShown then return end

    local optionsExposed = G("OptionsPopup") ~= nil
    local inputExposed = getInput() ~= nil and getKeyCode() ~= nil
    local timeExposed = G("Time") ~= nil or G("UnityEngine.Time") ~= nil

    log(
        "API: OptionsPopup=" .. tostring(optionsExposed) ..
        ", Input=" .. tostring(inputExposed) ..
        ", Time=" .. tostring(timeExposed) ..
        ", GameScript=" .. tostring(G("GameScript") ~= nil)
    )

    if not optionsExposed then
        local shown = overlayOk(
            "Sol Automation",
            "O mod nativo foi carregado. A API de Opcoes nao ficou exposta ao Lua nesta instalacao, " ..
            "entao o botao dentro de Opcoes nao pode ser criado nesta execucao. " ..
            "Use o registro exportado do jogo para a proxima revisao."
        )

        if shown then fallbackNoticeShown = true end
    else
        fallbackNoticeShown = true
    end
end

local function mainLoop()
    log("Sol Automation Native 0.1.0 carregado.")

    while true do
        local ok, err = pcall(function()
            tryInstallOptionsButton()
            updateStreaming()
            updateFishing()
            showFallbackNoticeOnce()
        end)

        if not ok then
            warnOnce("loop-error-" .. tostring(err), "Erro protegido no loop: " .. tostring(err))
        end

        coroutine.yield()
    end
end

local mu = G("ModUtilities")

if mu ~= nil then
    local ok, result = pcall(function()
        return mu.StartCoroutine(mainLoop, function()
            stopStreamFastForward()
            log("Coroutine finalizada.")
        end)
    end)

    if not ok then
        log("ModUtilities.StartCoroutine falhou; tentando coroutine Lua simples: " .. tostring(result))
        local co = coroutine.create(mainLoop)
        coroutine.resume(co)
    end
else
    log("ERRO: ModUtilities nao esta disponivel no ambiente Lua.")
end
