local Log = {
   data = {},
   dialogue_option_count = 0,
   expect_solo = false,
}
function Log:addDialogueEntry(text)
   if self.expect_solo then
      self.expect_solo = false
      self:appendToLast(text)
      return
   end
   self:addEntry(text)
end
function Log:addEntry(text)
   self.data[#self.data + 1] = text
   self.expect_solo = false
end
function Log:appendToLast(text)
   local count = #self.data
   self.data[count] = self.data[count] .. "\n" .. text
end
function Log:clear()
   self.data = {}
end
function Log:getCombined()
   local tbl  = self.data
   local size = #tbl
   if size == 0 then
      return ""
   end
   local entry = tbl[1]
   for i = 2, size do
      entry = entry .. "\n\n" .. tbl[i]
   end
   return entry
end
function Log:onDialogueOptionUpdate(count)
   self.dialogue_option_count = count
end
function Log:onExitDialogue()
   self.dialogue_option_count = 0
   self.expect_solo = false
end
function Log:onSelectDialogueOption(index)
   if index == 1 and self.dialogue_option_count == 1 then
      self.expect_solo = true
   else
      self.expect_solo = false
   end
end

--[[

TODO:

Store the time of each event. If the same character has multiple consecutive subtitles 
spaced five seconds apart or less, group them.

Note when we loot a quest item.

Investigate whether we can log when we complete an objective by killing an enemy, or 
else log quest objectives as they appear. Might be useful anyway so we can easily grab 
quest stages (could even set up a second log for those in specific).

]]--

local function _join(tbl, delim) -- table.join is nil UGH
   local size = #tbl
   if size == 0 then
      return ""
   end
   local entry = tbl[1]
   for i = 2, size do
      entry = entry .. delim .. tbl[i]
   end
   return entry
end

local function _fmtDialogue(text)
   local entry = ":''"
   local quote = false
   do
      local begin = text[1]
      quote = not (begin == "\"" or begin == "<")
   end
   if quote then
      entry = entry .. "\""
   end
   entry = entry .. string.gsub(text, "\n\n", "<br/> ")
   if quote then
      entry = entry .. "\""
   end
   entry = entry .. "''"
   return entry
end
local function _fmtDialogueResponse(type, text)
   local out = ":'''"
   if type == CHATTER_TALK_CHOICE_MONEY
   or type == CHATTER_TALK_CHOICE_PAY_BOUNTY then
      out = out .. "[Pay] "
   elseif type == CHATTER_TALK_CHOICE_CLEMENCY_COOLDOWN
   or     type == CHATTER_TALK_CHOICE_CLEMENCY_DISABLED
   or     type == CHATTER_TALK_CHOICE_USE_CLEMENCY then -- Clemency
      out = out .. "[Clemency] "
   elseif type == CHATTER_TALK_CHOICE_INTIMIDATE_DISABLED then
      out = out .. "[Intimidate] "
      --
      -- NOTE: There isn't a value for inaccessible intimidate/persuade options; the labels for those 
      -- must just be embedded into the option text itself
      --
   elseif type == CHATTER_TALK_CHOICE_PERSUADE_DISABLED then
      out = out .. "[Persuade] "
   elseif type == CHATTER_TALK_CHOICE_SHADOWY_CONNECTIONS_UNAVAILABLE
   or     type == CHATTER_START_USE_SHADOWY_CONNECTIONS then -- Shadowy Connections
      out = out .. "[Shadowy Connections] "
   end
   out = out .. text .. "'''"
   return out
end

local _is_chattering = false

local function OnChatterBegin(eventCode, optionCount)
   Log:onDialogueOptionUpdate(optionCount)
   _is_chattering = true
   local entry = "Start of conversation with " .. GetUnitName("interact") .. ":\n\n"
   entry = entry .. _fmtDialogue(GetChatterGreeting())
   for i = 1, optionCount do
      local optionString, optionType, optionalArg, isImportant, chosenBefore = GetChatterOption(i)
      --
      entry = entry .. "\n" .. _fmtDialogueResponse(optionType, optionString)
      if isImportant then
         entry = entry .. " <!-- red -->"
      end
   end
   local backToTOC, farewell, isImportant = GetChatterFarewell()
   if backToTOC ~= "" then
      entry = entry .. "\n" .. _fmtDialogueResponse(nil, backToTOC) .. " <!-- back to TOC -->"
   end
   if farewell ~= "" then
      entry = entry .. "\n" .. _fmtDialogueResponse(nil, farewell) .. " <!-- farewell -->"
   end
   Log:addEntry(entry)
end
local function OnBeforeChatterChoice(index)
   Log:onSelectDialogueOption(index)
   if Log.expect_solo then
      return
   end
   local optionString, optionType, optionalArg, isImportant, chosenBefore = GetChatterOption(index)
   local entry = "Player selected: \"" .. optionString .. "\""
   Log:addEntry(entry)
end
local function OnChatterEnd()
   Log:onExitDialogue()
   if not _is_chattering then -- looting can trigger this, it seems
      return
   end
   _is_chattering = false
   Log:addEntry("[Conversation End]")
end
local function OnConversationUpdated(eventCode, bodyText, optionCount)
   local entry = _fmtDialogue(bodyText)
   for i = 1, optionCount do
      local optionString, optionType, optionalArg, isImportant, chosenBefore = GetChatterOption(i)
      --
      entry = entry .. "\n" .. _fmtDialogueResponse(optionType, optionString)
      if isImportant then
         entry = entry .. " <!-- red -->"
      end
   end
   local backToTOC, farewell, isImportant = GetChatterFarewell()
   if backToTOC ~= "" then
      optionCount = optionCount + 1
      entry = entry .. "\n" .. _fmtDialogueResponse(nil, backToTOC) .. " <!-- back to TOC -->"
   end
   if farewell ~= "" then
      optionCount = optionCount + 1
      entry = entry .. "\n" .. _fmtDialogueResponse(nil, farewell) .. " <!-- farewell -->"
   end
   Log:onDialogueOptionUpdate(optionCount)
   Log:addDialogueEntry(entry)
end
local function OnQuestOffered()
   local dialogue, response = GetOfferedQuestInfo()
   local _, farewell = GetChatterFarewell()
   local entry = _fmtDialogue(dialogue)
   entry = entry .. "\n" .. _fmtDialogueResponse(nil, response) .. " <!-- begin quest -->"
   if farewell ~= "" then
      entry = entry .. "\n" .. _fmtDialogueResponse(nil, farewell) .. " <!-- decline quest -->"
      Log:onDialogueOptionUpdate(2)
   else
      Log:onDialogueOptionUpdate(1)
   end
   Log:addDialogueEntry(entry)
end
local function OnQuestComplete(eventCode, journalQuestIndex)
   local _, endDialogue, confirmComplete, declineComplete = GetJournalQuestEnding(journalQuestIndex)
   local entry = "[Conversation: Quest Complete]\n"
   entry = entry .. _fmtDialogue(endDialogue)
   if confirmComplete == "" then
      confirmComplete = GetString(SI_DEFAULT_QUEST_COMPLETE_CONFIRM_TEXT)
   end
   entry = entry .. "\n" .. _fmtDialogueResponse(nil, confirmComplete)
   if declineComplete ~= "" then
      entry = entry .. "\n" .. _fmtDialogueResponse(nil, declineComplete) .. " <!-- special-case decline -->"
      Log:onDialogueOptionUpdate(2)
   else
      Log:onDialogueOptionUpdate(1)
   end
   Log:addDialogueEntry(entry)
end
local function OnSubtitle(eventCode, type, speaker, message)
   Log:addEntry("Ambient dialogue:\n\n:'''" .. zo_strformat("<<t:1>>", speaker) .. ":''' ''\"" .. message .. "\"''")
end

local menu = {
   name        = "CobbDialogueLogger",
   displayName = "Cobb Dialogue Logger",
   type        = "panel",
}
local options = {
   {
      type        = "editbox",
      name        = "",
      getFunc     =
         function()
            return Log:getCombined()
         end,
      setFunc     = function() end,
      isMultiline = true,
      isExtraWide = true,
      width       = "full",
      reference   = "CobbDialogueLogger_Readout" -- we need to be able to refer to this to clear it, because LAM doesn't call getFunc unless the textbox is empty
   },
   {
      type  = "button",
      name  = "Update Display",
      width = "half",
      func  =
         function()
            CobbDialogueLogger_Readout:UpdateValue()
         end,
   },
   {
      type  = "button",
      name  = "Clear Log",
      width = "half",
      func  =
         function()
            Log:clear()
            CobbDialogueLogger_Readout:UpdateValue()
         end,
   }
}
local function registerLAMOptions()
   local LAM = LibStub:GetLibrary("LibAddonMenu-2.0")
   LAM:RegisterAddonPanel("CobbDialogueLoggerOptionsMenu", menu)
   LAM:RegisterOptionControls("CobbDialogueLoggerOptionsMenu", options)
end

local function OnAddonLoaded(eventCode, addonName)
   if addonName ~= "CobbDialogueLogger" then
      return
   end
   --
   EVENT_MANAGER:RegisterForEvent("CobbDialogueLogger", EVENT_CHATTER_BEGIN, OnChatterBegin)
   EVENT_MANAGER:RegisterForEvent("CobbDialogueLogger", EVENT_CHATTER_END, OnChatterEnd)
   EVENT_MANAGER:RegisterForEvent("CobbDialogueLogger", EVENT_CONVERSATION_UPDATED, OnConversationUpdated)
   EVENT_MANAGER:RegisterForEvent("CobbDialogueLogger", EVENT_QUEST_OFFERED, OnQuestOffered)
   EVENT_MANAGER:RegisterForEvent("CobbDialogueLogger", EVENT_QUEST_COMPLETE_DIALOG, OnQuestComplete)
   EVENT_MANAGER:RegisterForEvent("CobbDialogueLogger", EVENT_SHOW_SUBTITLE, OnSubtitle)
   --
   do
      local _api = SelectChatterOption
      SelectChatterOption = function(index)
         OnBeforeChatterChoice(index)
         return _api(index)
      end
   end
   --
   registerLAMOptions()
   CALLBACK_MANAGER:RegisterCallback("LAM-RefreshPanel", function(panel)
      if CobbDialogueLogger_Readout then
         CobbDialogueLogger_Readout:SetHeight(360)
         CobbDialogueLogger_Readout.container:SetHeight(360)
         --
         CobbDialogueLogger_Readout.UpdateValue = function(self)
            --
            -- LibAddonMenu only calls getFunc once; force it to always call getFunc
            --
            self.editbox:SetText(self.data.getFunc())
         end
         --
         CobbDialogueLogger_Readout.editbox:SetMaxInputChars(99999999) -- default length is too short
      end
   end)
   --
   SLASH_COMMANDS["/logdialogue"] = function(text)
      Log:addEntry(text)
   end
end
EVENT_MANAGER:RegisterForEvent("CobbDialogueLogger", EVENT_ADD_ON_LOADED, OnAddonLoaded)