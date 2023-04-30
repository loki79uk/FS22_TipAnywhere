-- ============================================================= --
-- TIP ANYWHERE MOD
-- ============================================================= --
TipAnywhere = {}
addModEventListener(TipAnywhere)

TipAnywhere.CONTROLS = {}
TipAnywhere.tip = true
TipAnywhere.shovel = true
TipAnywhere.workAreas = {
	['BALER'] = true,
	['COMBINECHOPPER'] = false,
	['COMBINESWATH'] = false,
	['CULTIVATOR'] = false,
	['CUTTER'] = false,
	['FORAGEWAGON'] = true,
	['FRUITPREPARER'] = false,
	['MULCHER'] = false,
	['MOWER'] = false,
	['PLOW'] = false,
	['RIDGEMARKER'] = false,
	['ROLLER'] = false,
	['SALTSPREADER'] = false,
	['SOWINGMACHINE'] = false,
	['SPRAYER'] = false,
	['STONEPICKER'] = false,
	['STUMPCUTTER'] = false,
	['TEDDER'] = true,
	['WEEDER'] = false,
	['WINDROWER'] = true,
	['DEFAULT'] = false,
	['AUXILIARY'] = false
}
TipAnywhere.menuItems = {
	[1] = 'BALER',
	[2] = 'FORAGEWAGON',
	[3] = 'TEDDER',
	[4] = 'WINDROWER',
	[5] = 'MOWER'
}

TipAnywhere.OPTION = {
	['default'] = 1,
	['values'] = {false, true},
	['strings'] = {
		g_i18n:getText("ui_off"),
		g_i18n:getText("ui_on")
	}
}

-- HELPER FUNCTIONS
function TipAnywhere.insertMenuItem(id)

	local function tableContainsValue(container, id)
		for k, v in pairs(container) do
			if v == id then
				return true
			end
		end
		return false
	end
	
	if not tableContainsValue(TipAnywhere.menuItems, id) then
		table.insert(TipAnywhere.menuItems, id)
	end
end

function TipAnywhere.setValue(id, value)
	TipAnywhere.workAreas[id] = value
end

function TipAnywhere.getValue(id)
	return TipAnywhere.workAreas[id] or false
end

function TipAnywhere.getStateIndex(id)
	local value = TipAnywhere.getValue(id)
	local values = TipAnywhere.OPTION.values
	for i, v in pairs(values) do
		if value == v then
			return i
		end 
	end
	return TipAnywhere.OPTION.default
end


-- READ/WRITE SETTINGS
function TipAnywhere.writeSettings()

	local key = "TipAnywhere"
	local userSettingsFile = Utils.getFilename("modSettings/TipAnywhere.xml", getUserProfileAppPath())
	
	local xmlFile = createXMLFile("settings", userSettingsFile, key)
	if xmlFile ~= 0 then
	
		local function setXmlValue(id)
			local options = TipAnywhere.OPTION
			if options then
				local xmlValueKey = "TipAnywhere." .. id .. "#value"
				local value = TipAnywhere.getValue(id)
				setXMLBool(xmlFile, xmlValueKey, value)
			end
		end
		
		for _, id in pairs(TipAnywhere.menuItems) do
			setXmlValue(id)
		end

		saveXMLFile(xmlFile)
		delete(xmlFile)
	end
end

function TipAnywhere.readSettings()

	local userSettingsFile = Utils.getFilename("modSettings/TipAnywhere.xml", getUserProfileAppPath())
	
	if not fileExists(userSettingsFile) then
		print("CREATING user settings file: "..userSettingsFile)
		TipAnywhere.writeSettings()
		return
	end
	
	local xmlFile = loadXMLFile("TipAnywhere", userSettingsFile)
	if xmlFile ~= 0 then
	
		local function getXmlValue(id)
			local options = TipAnywhere.OPTION
			if options then
				local xmlSettingKey = "TipAnywhere." .. id
				local value = getXMLBool(xmlFile, xmlSettingKey .. "#value") or false
				TipAnywhere.setValue(id, value)
				
				if g_currentMission:getIsServer() and hasXMLProperty(xmlFile, xmlSettingKey) then
					TipAnywhere.insertMenuItem(id)
					return true
				end
			end
		end
		
		print("TIP ANYWHERE SETTINGS")
		print("  TIP:    " .. tostring(TipAnywhere.tip))
		print("  SHOVEL: " .. tostring(TipAnywhere.shovel))
		for id, _ in pairs(TipAnywhere.workAreas) do
			if getXmlValue(id) then
				print("  ".. id ..":  " .. tostring(TipAnywhere.workAreas[id]))
			end
		end

		delete(xmlFile)
	end
	
end

-- MENU CALLBACK
function TipAnywhere:onMenuOptionChanged(state, menuOption)
	
	local id = menuOption.id
	local value = TipAnywhere.OPTION.values[state]
	
	if value ~= nil then
		--print("SET " .. id .. " = " .. tostring(value))
		TipAnywhere.setValue(id, value)
		ToggleSettingEvent.sendEvent(id, value)
	end

	TipAnywhere.writeSettings()
end


local inGameMenu = g_gui.screenControllers[InGameMenu]
local settingsGame = inGameMenu.pageSettingsGame
function TipAnywhere.addMenuOption(id, original)
	
	local original = original or settingsGame.checkDirt
	local callback = "onMenuOptionChanged"

	local options = TipAnywhere.OPTION.strings

	local menuOption = original:clone(settingsGame.boxLayout)
	menuOption.target = TipAnywhere
	menuOption.id = id
	
	menuOption:setCallback("onClickCallback", callback)
	menuOption:setDisabled(false)

	local setting = menuOption.elements[4]
	local toolTip = menuOption.elements[6]

	setting:setText(g_i18n:getText("setting_tipanywhere_" .. id))
	toolTip:setText(g_i18n:getText("tooltip_tipanywhere_" .. id))
	menuOption:setTexts({unpack(options)})
	menuOption:setState(TipAnywhere.getStateIndex(id))
	
	TipAnywhere.CONTROLS[id] = menuOption

	return menuOption
end

local title = TextElement.new()
title:applyProfile("settingsMenuSubtitle", true)
title:setText(g_i18n:getText("menu_TipAnywhere_TITLE"))
settingsGame.boxLayout:addElement(title)

for _, id in pairs(TipAnywhere.menuItems) do
	TipAnywhere.addMenuOption(id)
end
settingsGame.boxLayout:invalidateLayout()



function TipAnywhere:shovelGetCanShovelAtPosition(superFunc, shovelNode)
	if shovelNode == nil then
		return false
	end
	return TipAnywhere.shovel
end

function TipAnywhere:dischargeableGetCanDischargeToLand(superFunc, dischargeNode)
	if dischargeNode == nil then
		return false
	end
	return TipAnywhere.tip
end

function TipAnywhere:WorkAreaGetIsAccessibleAtWorldPosition(superFunc, farmId, x, z, workAreaType)
	local workAreaName = g_workAreaTypeManager:getWorkAreaTypeNameByIndex(workAreaType)
	-- print("workAreaName: " .. workAreaName)
	if TipAnywhere.workAreas[workAreaName] then
		return true
	end
	
	return superFunc(self, farmId, x, z, workAreaType) 
end

MissionManager.getIsMissionWorkAllowed = Utils.overwrittenFunction(MissionManager.getIsMissionWorkAllowed,
function(self, superFunc, farmId, x, z, workAreaType)
	local mission = self:getMissionAtWorldPosition(x, z)
	if mission ~= nil and mission.farmId == farmId then
		local workAreaName = g_workAreaTypeManager:getWorkAreaTypeNameByIndex(workAreaType)
		if TipAnywhere.workAreas[workAreaName] then
			return true
		end
	end
	
	return superFunc(self, farmId, x, z, workAreaType)
	
end)

function TipAnywhere.registerTipAnywhereFunctions()
	for vehicleName, vehicleType in pairs(g_vehicleTypeManager.types) do
		if SpecializationUtil.hasSpecialization(Shovel, vehicleType.specializations) then
			SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanShovelAtPosition", TipAnywhere.shovelGetCanShovelAtPosition)
			-- print("Shovel Anywhere added to " .. vehicleName)
		end
		if SpecializationUtil.hasSpecialization(Dischargeable, vehicleType.specializations) then
			SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanDischargeToLand", TipAnywhere.dischargeableGetCanDischargeToLand)
			-- print("Tip Anywhere added to " .. vehicleName)
		end
		if SpecializationUtil.hasSpecialization(WorkArea, vehicleType.specializations) then
			SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsAccessibleAtWorldPosition", TipAnywhere.WorkAreaGetIsAccessibleAtWorldPosition)
			-- print("Work Anywhere ADDED to " .. vehicleName)
		end
	end
end

function TipAnywhere:loadMap(name)
	--print("Loaded Mod: 'TIP ANYWHERE'")
	TipAnywhere.readSettings()
	TipAnywhere.registerTipAnywhereFunctions()
end

InGameMenuGameSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGameSettingsFrame.onFrameOpen, function()
	
	local isAdmin = g_currentMission:getIsServer() or g_currentMission.isMasterUser
	
	for _, id in pairs(TipAnywhere.menuItems) do
	
		local menuOption = TipAnywhere.CONTROLS[id]
		menuOption:setState(TipAnywhere.getStateIndex(id))
	
		menuOption:setDisabled(not isAdmin)

	end
end)

source(g_currentModDirectory .. 'ToggleSettingEvent.lua')

-- SEND SETTINGS TO CLIENT:
FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState,
function(self, connection, user, farm)

	for _, id in pairs(TipAnywhere.menuItems) do
	
		local value = TipAnywhere.getValue(id)
		if value ~= nil then
			ToggleSettingEvent.sendEvent(id, value)
		end
		
	end
	
end)
