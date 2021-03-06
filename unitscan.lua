local unitscan = CreateFrame'Frame'
local forbidden
local found = {}

-- local MSG_PREFIX = 'unitscan_dbg'
local MSG_PREFIX = 'unitscan'

local debug = MSG_PREFIX == 'unitscan_dbg'

unitscan:SetScript('OnUpdate', function() unitscan.UPDATE() end)
unitscan:SetScript('OnEvent', function(_, event, arg1, arg2, arg3, arg4)
  if event == 'ADDON_LOADED' and arg1 == 'unitscan' then
    unitscan.LOAD()
  elseif event == 'ADDON_ACTION_FORBIDDEN' and arg1 == 'unitscan' then
    forbidden = true
  elseif event == 'PLAYER_TARGET_CHANGED' then
    if UnitName'target' and strupper(UnitName'target') ==
      unitscan.uiButton:GetText() and not GetRaidTargetIndex'target' and
      (not IsInRaid() or UnitIsGroupAssistant'player' or
        UnitIsGroupLeader'player') then SetRaidTarget('target', 4) end
  elseif event == 'CHAT_MSG_ADDON' and arg1 == MSG_PREFIX then
    local name, zone = strsplit(',', arg2)

    if arg3 == "RAID" or arg3 == "PARTY" then
      if IsInGuild() then
        ChatThrottleLib:SendAddonMessage("ALERT", MSG_PREFIX, name, "GUILD")
      else
        unitscan.trigger(name, zone)
      end
    elseif arg3 == "GUILD" then -- if (sender ~= nil and sender:find("^" .. UnitName("player"))) then
      unitscan.trigger(name, zone)
    end
  end
end)
unitscan:RegisterEvent 'ADDON_LOADED'
unitscan:RegisterEvent 'ADDON_ACTION_FORBIDDEN'
unitscan:RegisterEvent 'PLAYER_TARGET_CHANGED'
unitscan:RegisterEvent 'CHAT_MSG_ADDON'

local BROWN = {.7, .15, .05}
local YELLOW = {1, 1, .15}
local CHECK_INTERVAL = .1

unitscan_targets = {}

if C_ChatInfo then
  C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
else
  RegisterAddonMessagePrefix(MSG_PREFIX)
end

do
  local last_played
  local last_triggered

  function unitscan.trigger(name, zone)
    if not found[name] or not last_triggered or GetTime() - last_triggered >=
      600 then
      found[name] = zone or true

      unitscan.discovered_unit = name
      unitscan.play_sound()

      last_triggered = GetTime()
    end
  end

  function unitscan.play_sound()
    if not last_played or GetTime() - last_played >= 6 then
      unitscan.flash.animation:Play()
      PlaySoundFile([[Interface\AddOns\unitscan\Event_wardrum_ogre.ogg]],
                    'Master')
      PlaySoundFile([[Interface\AddOns\unitscan\scourge_horn.ogg]], 'Master')
      last_played = GetTime()
    end
  end
end

function unitscan.target(name)
  forbidden = false
  local sound_setting = GetCVar'Sound_EnableAllSound'
  SetCVar('Sound_EnableAllSound', 0)
  TargetUnit(name, true)
  SetCVar('Sound_EnableAllSound', sound_setting)
  if forbidden then
    if not found[name] then
      local zone = GetZoneText()

      found[name] = zone

      unitscan.discovered_unit = name
      unitscan.play_sound()

      if (unitscan.is_worldboss(name)) then
        local msg = name .. ',' .. zone
        if (IsInGroup()) then
          ChatThrottleLib:SendAddonMessage("ALERT", MSG_PREFIX, msg, "RAID")
        else
          ChatThrottleLib:SendAddonMessage("ALERT", MSG_PREFIX, msg, "GUILD")
        end
        -- SendChatMessage(name .. ' spawned in ' .. zone, "GUILD")
      end
    end
  else
    found[name] = nil
  end
end

function unitscan.is_worldboss(target)
  if debug then return true end

  return
    target == "LORD KAZZAK" or target == "AZUREGOS" or target == "LETHON" or
      target == "EMERISS" or target == "TAERAR" or target == "YSONDRE"
end

function unitscan.LOAD()
  UIParent:UnregisterEvent 'ADDON_ACTION_FORBIDDEN'
  do
    local flash = CreateFrame'Frame'
    unitscan.flash = flash
    flash:Show()
    flash:SetAllPoints()
    flash:SetAlpha(0)
    flash:SetFrameStrata 'FULLSCREEN_DIALOG'

    local texture = flash:CreateTexture()
    texture:SetBlendMode 'ADD'
    texture:SetAllPoints()
    texture:SetTexture [[Interface\FullScreenTextures\LowHealth]]

    flash.animation = CreateFrame'Frame'
    flash.animation:Hide()
    flash.animation:SetScript('OnUpdate', function(self)
      local t = GetTime() - self.t0
      if t <= .5 then
        flash:SetAlpha(t * 2)
      elseif t <= 1 then
        flash:SetAlpha(1)
      elseif t <= 1.5 then
        flash:SetAlpha(1 - (t - 1) * 2)
      else
        flash:SetAlpha(0)
        self.loops = self.loops - 1
        if self.loops == 0 then
          self.t0 = nil
          self:Hide()
        else
          self.t0 = GetTime()
        end
      end
    end)
    function flash.animation:Play()
      if self.t0 then
        self.loops = 4
      else
        self.t0 = GetTime()
        self.loops = 3
      end
      self:Show()
    end
  end

  local button = CreateFrame('Button', 'unitscan_button', UIParent,
                             'SecureActionButtonTemplate')
  unitscan.uiButton = button
  button:SetAttribute('type', 'macro')
  button:Hide()
  button:SetPoint('BOTTOM', UIParent, 0, 128)
  button:SetWidth(150)
  button:SetHeight(42)
  button:SetScale(1.25)
  button:SetMovable(true)
  button:SetUserPlaced(true)
  button:SetClampedToScreen(true)
  button:SetScript('OnMouseDown', function(self)
    if IsControlKeyDown() then
      self:RegisterForClicks()
      self:StartMoving()
    end
  end)
  button:SetScript('OnMouseUp', function(self)
    self:StopMovingOrSizing()
    self:RegisterForClicks 'LeftButtonDown'
  end)
  button:SetFrameStrata 'FULLSCREEN_DIALOG'
  button:SetNormalTexture [[Interface\AddOns\unitscan\UI-Achievement-Parchment-Horizontal]]
  button:SetBackdrop{
    tile = true,
    edgeSize = 16,
    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]]
  }
  button:SetBackdropBorderColor(unpack(BROWN))
  button:SetScript('OnEnter', function(self)
    self:SetBackdropBorderColor(unpack(YELLOW))
  end)
  button:SetScript('OnLeave', function(self)
    self:SetBackdropBorderColor(unpack(BROWN))
  end)

  do
    local background = button:GetNormalTexture()
    background:SetDrawLayer 'BACKGROUND'
    background:ClearAllPoints()
    background:SetPoint('BOTTOMLEFT', 3, 3)
    background:SetPoint('TOPRIGHT', -3, -3)
    background:SetTexCoord(0, 1, 0, .25)
  end

  do
    local title_background = button:CreateTexture(nil, 'BORDER')
    title_background:SetTexture [[Interface\AddOns\unitscan\UI-Achievement-Title]]
    title_background:SetPoint('TOPRIGHT', -5, -5)
    title_background:SetPoint('LEFT', 5, 0)
    title_background:SetHeight(18)
    title_background:SetTexCoord(0, .9765625, 0, .3125)
    title_background:SetAlpha(.8)

    local title = button:CreateFontString(nil, 'OVERLAY',
                                          'GameFontHighlightMedium')
    title:SetWordWrap(false)
    title:SetPoint('TOPLEFT', title_background, 0, 0)
    title:SetPoint('RIGHT', title_background)
    button:SetFontString(title)

    local subtitle =
      button:CreateFontString(nil, 'OVERLAY', 'GameFontBlackTiny')
    subtitle:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
    subtitle:SetPoint('RIGHT', title)
    subtitle:SetText 'Unit Found!'

    unitscan.uiZone = subtitle
  end

  do
    local model = CreateFrame('PlayerModel', nil, button)
    button.model = model
    model:SetPoint('BOTTOMLEFT', button, 'TOPLEFT', 0, -4)
    model:SetPoint('RIGHT', 0, 0)
    model:SetHeight(button:GetWidth() * .6)
  end

  do
    local close = CreateFrame('Button', nil, button, 'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT', 0, 0)
    close:SetWidth(32)
    close:SetHeight(32)
    close:SetScale(.8)
    close:SetHitRectInsets(8, 8, 8, 8)
  end

  do
    local glow = button.model:CreateTexture(nil, 'OVERLAY')
    button.glow = glow
    glow:SetPoint('CENTER', button, 'CENTER')
    glow:SetWidth(400 / 300 * button:GetWidth())
    glow:SetHeight(171 / 70 * button:GetHeight())
    glow:SetTexture [[Interface\AddOns\unitscan\UI-Achievement-Alert-Glow]]
    glow:SetBlendMode 'ADD'
    glow:SetTexCoord(0, .78125, 0, .66796875)
    glow:SetAlpha(0)

    glow.animation = CreateFrame'Frame'
    glow.animation:Hide()
    glow.animation:SetScript('OnUpdate', function(self)
      local t = GetTime() - self.t0
      if t <= .2 then
        glow:SetAlpha(t * 5)
      elseif t <= .7 then
        glow:SetAlpha(1 - (t - .2) * 2)
      else
        glow:SetAlpha(0)
        self:Hide()
      end
    end)
    function glow.animation:Play()
      self.t0 = GetTime()
      self:Show()
    end
  end

  do
    local shine = button:CreateTexture(nil, 'ARTWORK')
    button.shine = shine
    shine:SetPoint('TOPLEFT', button, 0, 8)
    shine:SetWidth(67 / 300 * button:GetWidth())
    shine:SetHeight(1.28 * button:GetHeight())
    shine:SetTexture [[Interface\AddOns\unitscan\UI-Achievement-Alert-Glow]]
    shine:SetBlendMode 'ADD'
    shine:SetTexCoord(.78125, .912109375, 0, .28125)
    shine:SetAlpha(0)

    shine.animation = CreateFrame'Frame'
    shine.animation:Hide()
    shine.animation:SetScript('OnUpdate', function(self)
      local t = GetTime() - self.t0
      if t <= .3 then
        shine:SetPoint('TOPLEFT', button, 0, 8)
      elseif t <= .7 then
        shine:SetPoint('TOPLEFT', button, (t - .3) * 2.5 * self.distance, 8)
      end
      if t <= .3 then
        shine:SetAlpha(0)
      elseif t <= .5 then
        shine:SetAlpha(1)
      elseif t <= .7 then
        shine:SetAlpha(1 - (t - .5) * 5)
      else
        shine:SetAlpha(0)
        self:Hide()
      end
    end)
    function shine.animation:Play()
      self.t0 = GetTime()
      self.distance = button:GetWidth() - shine:GetWidth() + 8
      self:Show()
    end
  end
end

function unitscan.set_target(name, zone)
  unitscan.uiButton:SetText(name)
  unitscan.uiButton:SetAttribute('macrotext',
                                 '/cleartarget\n/targetexact ' .. name)
  unitscan.uiButton:Show()
  unitscan.uiButton.glow.animation:Play()
  unitscan.uiButton.shine.animation:Play()
  unitscan.uiZone:SetText(zone or "Unit Found!")
end

do
  unitscan.last_check = GetTime()
  function unitscan.UPDATE()
    if unitscan.discovered_unit and not InCombatLockdown() then
      unitscan.set_target(unitscan.discovered_unit,
                          found[unitscan.discovered_unit])
      unitscan.discovered_unit = nil
    end

    if GetTime() - unitscan.last_check >= CHECK_INTERVAL then
      unitscan.last_check = GetTime()
      for name in pairs(unitscan_targets) do unitscan.target(name) end
    end
  end
end

function unitscan.debug(msg)
  if (DEFAULT_CHAT_FRAME and debug) then
    DEFAULT_CHAT_FRAME:AddMessage(
      LIGHTYELLOW_FONT_COLOR_CODE .. '<unitscan> ' .. msg)
  end
end
function unitscan.print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(
      LIGHTYELLOW_FONT_COLOR_CODE .. '<unitscan> ' .. msg)
  end
end

function unitscan.announce()
  for name, zone in pairs(found) do
    if (unitscan.is_worldboss(name) and zone and zone ~= true) then
      unitscan.debug(name .. ', ' .. zone)
      ChatThrottleLib:SendChatMessage("ALERT", MSG_PREFIX,
                                      "<unitscan> " .. name .. " spawned in " ..
                                        zone, "GUILD")
    end
  end
end

function unitscan.sorted_targets()
  local sorted_targets = {}
  for key in pairs(unitscan_targets) do tinsert(sorted_targets, key) end
  sort(sorted_targets, function(key1, key2) return key1 < key2 end)
  return sorted_targets
end

function unitscan.toggle_target(name)
  local key = strupper(name)
  if unitscan_targets[key] then
    unitscan_targets[key] = nil
    found[key] = nil
    unitscan.print('- ' .. key)
  elseif key ~= '' then
    unitscan_targets[key] = true
    unitscan.print('+ ' .. key)
  end
end

SLASH_UNITSCAN1 = '/unitscan'
function SlashCmdList.UNITSCAN(parameter)
  local _, _, name = strfind(parameter, '^%s*(.-)%s*$')

  if name == '' then
    for _, key in ipairs(unitscan.sorted_targets()) do unitscan.print(key) end
  elseif name == 'announce' then
    unitscan.announce()
  else
    unitscan.toggle_target(name)
  end
end
