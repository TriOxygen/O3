local addon, ns = ...
local O3 = ns.O3

local NOT_CHARGING = 2^32 / 1000

local CooldownButton = O3.UI.IconButton:extend({
	morphedSpells = {
		[108194] = 47476,
		[48743] = 175678,
		[30283] =175707,
		[114189] = 755,
		[119915] = 119898,
		[119915] = 119898,
		[175707] = 6789,
		[113861] = 77801,
		[113858] = 77801,
		[112921] = 1122,
		[140763] = 1122,
		[112927] = 18540,
		[30146] = 112870,
	},
	update = function (self)
		if (not self.actionId) then
			self:setTexture(nil)
			return
		end
		local texture = GetActionTexture(self.actionId)
		local enable = nil
		local charges, maxCharges, start, duration = GetActionCharges(self.actionId)
		if charges > 0 then
			self.count:SetText((charges or '') ..'/'..(maxCharges or ''))
			if start then
				if start == NOT_CHARGING-duration then
					self.dimmed = true
					self.cooldown:SetCooldown(0, 0)
				else
					self.dimmed = false
					if (start+duration ~= self.startDuration) then
						self.cooldown:SetCooldown(start, duration)
					end
				end
				self.startDuration  = start + duration
			end			
		else
			self.count:SetText('')
			start, duration, enable = GetActionCooldown(self.actionId)
			if (start) then
				if start+duration == 0 then
					self.dimmed = true
					self.cooldown:SetCooldown(0, 0)
				elseif duration > 1.5 then
					self.dimmed = false
					if (start+duration ~= self.startDuration) then
						self.cooldown:SetCooldown(start, duration)
					end
				end
				self.startDuration  = start + duration
			end			
		end
		self:setTexture(texture)

		if (self.dimmed) then
			self.icon:SetDesaturated(true)
			self.frame:SetAlpha(0.2)
		else
			self.icon:SetDesaturated(false)
			self.frame:SetAlpha(1)
		end
	end,
	postInit = function (self)
		self.dimmed = true
		self.icon:SetDesaturated(true)
		self.frame:SetAlpha(0.2)
	end,
	onMouseUp = function (self, button)
		if (button == 'RightButton') then
			self:set(nil)
		else	
			self:grab()
		end
	end,
	-- onMouseDown = function (self)
	-- 	self:grab()
	-- end,
	findSpell = function (self, searchId)
		if (self.morphedSpells[searchId]) then
			searchId = self.morphedSpells[searchId]
		end
		for i = 1, 132 do
			local type, id, subType, spellId = GetActionInfo(i)
			if (type == 'spell' and (id == searchId or (self.morphedSpells[id] and self.morphedSpells[id] == searchId)) ) then
				return i
			elseif (type == 'macro') then
				local name, rank, spellId = GetMacroSpell(id)
				if (spellId == searchId or (self.morphedSpells[spellId] and self.morphedSpells[spellId] == searchId)) then
					return i
				end
			end
		end
		return nil
	end,
	createRegions = function (self)
		self.cooldown = CreateFrame("Cooldown", nil, self.frame, 'CooldownFrameTemplate')
		self.cooldown:SetDrawEdge(false)
		self.cooldown:SetDrawSwipe(true)		
		self.cooldown:SetPoint('TOPRIGHT', -1, -1)
		self.cooldown:SetPoint('BOTTOMLEFT', 1, 1)
		self.cooldown:SetScript('OnHide', function (cooldown)
			self.dimmed = true
			self:update()
		end)

		self.count = self:createFontString({
			offset = {2, 2, nil, 2},
			fontFlags = 'OUTLINE',
			-- shadowOffset = {1, -1},
			fontSize = 8,
		})		
	end,
	findItem = function (self, searchId, searchName)
		for i = 1, 132 do
			local type, id, subType, spellId = GetActionInfo(i)
			if (type == 'item' and id == searchId) then
				return i
			elseif (type == 'macro') then
				local name, link = GetMacroItem(id)
				if (name == searchName) then
					return i
				end
			end
		end
		return nil
	end,
	set = function (self, actionId)
		self.handler:save(self.id, actionId)
		self.actionId = actionId
		self.dimmed = true
		self:update()
	end,
	getMacroDetails = function (self, id)
		local name, rank, spellId = GetMacroSpell(id)
		if (name) then
			return 'spell', spellId
		end
		local name, link = GetMacroItem(id)
		if (name) then
			local a, b, color, ltype, itemId, enchantId, gem1, gem2, gem3, gem4, suffix, unique, linkLvl, name, d, e, f =   string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
			return 'item', itemId
		end
		return nil, nil
	end,
	grab = function (self)
		local type, data, subType, subData = GetCursorInfo()
		--print(type, data, subType, subData)
		local actionId, itemId
		local oldId = self.actionId
		if type == 'spell' then
			actionId = self:findSpell(subData)
		elseif type == 'item' then
			local name = GetItemInfo(subType)
			actionId = self:findItem(data, name)
		end
		if (not actionId) then
			return
		end
		self:set(actionId)
		
		if (oldId) then
			local type, id, subType, spellId = GetActionInfo(oldId)
			local pickupId
			if (type == 'spell') then
				pickupId = id
			elseif type == 'item' then
				pickupId = id
			elseif type == 'macro' then
				type, pickupId = self:getMacroDetails(actionId)
			end

			local clearCursor  = true
			if (type) then
				ClearCursor()
				if type == 'item' then
					PickupItem(pickupId)
				elseif type == 'spell' then
					PickupSpell(pickupId)
				end
			end
		end
	end,
})

local CooldownPanel = O3.UI.Panel:extend({
	buttonSize = 36,
	spacing = 1,
	parentFrame = UIParent,
	offset = {nil, nil, nil, 42},
	buttons = {},
	events = {
		ACTIONBAR_UPDATE_COOLDOWN = true,
		ACTIONBAR_UPDATE_USABLE = true,
		ACTIONBAR_UPDATE_STATE = true,
		SPELL_UPDATE_CHARGES = true,
		SPELL_UPDATE_COOLDOWN = true,
		ACTIONBAR_SLOT_CHANGED = true,
		PLAYER_SPECIALIZATION_CHANGED = true,
		SPELLS_CHANGED = true,
	},
	postInit = function (self)
		self:setSize(12*self.buttonSize+11*self.spacing, 2*self.buttonSize+1*self.spacing)
		for event, foo in pairs(self.events) do
			self.handler:registerEvent(event, self)
		end
		self:reset()
	end,
	ACTIONBAR_UPDATE_COOLDOWN = function (self)
		for i = 1,24 do 
			local button = self.buttons[i]
			button:update()
		end
	end,
	ACTIONBAR_UPDATE_USABLE = function (self)
		for i = 1,24 do 
			local button = self.buttons[i]
			button:update()
		end
	end,
	ACTIONBAR_UPDATE_STATE = function (self)
		for i = 1,24 do 
			local button = self.buttons[i]
			button:update()
		end
	end,
	SPELL_UPDATE_CHARGES = function (self)
		for i = 1,24 do 
			local button = self.buttons[i]
			button:update()
		end
	end,
	ACTIONBAR_SLOT_CHANGED = function (self)
		for i = 1,24 do 
			local button = self.buttons[i]
			button:update()
		end
	end,	
	SPELL_UPDATE_COOLDOWN = function (self)
		for i = 1,24 do 
			local button = self.buttons[i]
			button:update()
		end
	end,	
	PLAYER_SPECIALIZATION_CHANGED = function (self)
		self:reset()
	end,
	SPELLS_CHANGED = function (self)
		self:reset()
	end,
	reset = function (self)
		self.spec = GetSpecialization() or 1
		self.settings.cooldowns[self.spec] = self.settings.cooldowns[self.spec] or {}
		local config = self.settings.cooldowns[self.spec]

		for i = 1,24 do
			local button = self.buttons[i]
			if (config[i]) then
				button.actionId = config[i]
			else
				button.actionId = nil
			end
			button:update()
		end
	end,
	save = function (self, id, actionId)
		self.spec = GetSpecialization() or 1
		self.settings.cooldowns[self.spec] = self.settings.cooldowns[self.spec] or {}
		self.settings.cooldowns[self.spec][id] = actionId
	end,	
	createRegions = function (self)
		for i = 1, 24 do
			local button = CooldownButton:instance({
				id = i,
				handler = self,
				parentFrame = self.frame,
				width = self.buttonSize,
				height = self.buttonSize,
			})
			if (i == 1 ) then
				button:point('TOPLEFT', 0, 0)
			elseif (i % 12 == 1) then
				button:point('TOPLEFT', self.buttons[i-12].frame, 'BOTTOMLEFT', 0, -self.spacing)
			else
				button:point('TOPLEFT', self.buttons[i-1].frame, 'TOPRIGHT', self.spacing, 0)
			end
			self.buttons[i] = button
			if (not self.settings.enableMouse) then
				button.frame:EnableMouse(false)
			end
		end
	end,
	enableMouse = function (self, enable)
		for i = 1, 24 do
			local button = self.buttons[i]
			button.frame:EnableMouse(enable)
		end
	end,
})

O3:module({
	name = 'CooldownBar',
	readable = 'Cooldown bar',
	autoRegister = false,
	config = {
		enabled = true,
		buttonSize = 32,
		spacing = 4,
		columns = 12,
		rows = 2,
		font = O3.Media:font('Normal'),
		fontSize = 10,
		enableMouse = false,
	},
	exportList = {},
	settings = {
		cooldowns = {},
	},
	buttons = {
	},
	events = {
		PLAYER_ENTERING_WORLD = true,
	},
	defaultCds = {
		MONK = {
			[1] = {},
			[2] = {},
			[3] = {115072, 115098, 115399, 113656, 109132, 101545, 115078, 116705, 122470, 122783, 115203, 137562, 115288, 115078, 117368, 119381, 101643, 119996, 115080, 115176, -10, -15, -6, -14},
		},
		DEATHKNIGHT = {
			[1] = {57330, 114866, 43265, 77575, 47568, 49028, 49576, 108194, 48792, 48707, 49222, 108200, 47528, 55233, 48982, 77606, 42650, 111673, 46584, 61999, -6, -15, -10, -13},
			[2] = {57330, 123693, 43265, 77575, 51271, 47568, 49576, 108194, 48792, 48707, nil, 108201, 47528, 130735, 77606, nil, 42650, 111673, 46584, 61999, -6, -15, -10, -13},
		},
		SHAMAN = {
			[1] = {8050, 114049, 79206, 73680, 61882, 8143, 2062, 120668, 8177, 108269, 108271, 30823, 32182, 57994, 51490, 73920, 5394, 108280, 2894, 108287, -6, -15, -10, -13},
			[3] = {16188, 114049, 8042, 73920, 51514, 73680, 2894, 108271, 98008, 120668, 8177, 108269, 32182, 51505, 57994, 2062, 8143, 108280, 16190, 5394, -6, -15, -10, -13},
		},
		ROGUE = {
			[3] = {51713, 121471, 14183, 73981, 408, 14185, 1856, 2983, 5277, 31224, 76577, nil, 1766, 1776, 36554, 1725, 51722, 2094, 114018, 114842, -6, -15, -10, -13},
			[2] = {13750, 121471, 51690, 73981, 408, 14185, 1856, 2983, 5277, 31224, 76577, nil, 1766, 1776, 36554, 1725, 51722, 2094, 114018, 114842,  -6, -15, -10, -13},
		},
		WARLOCK = {
			[2] = {103958, 105174, 104316, 113861, 108359, 109151, 30283, 29858, 111771, 108416, 104773, 59752, 89766, 119915, 114189, 20707, 698, 29893, 112870, 48018, 48020, 112921, 112927, nil},
			[3] = {17962, nil, 80240, 113858, 108359, 114635, 6789, 29858, 111771, 108416, 104773, 59752, nil, 119898, nil, 20707, 698, 29893, 120451, 48018, 48020, 140763, 112927, 108482},
		}

	},
	addOptions = function (self)
		self:addOption('_0', {
			type = 'Title',
			label = 'Interaction',
		})
		self:addOption('enableMouse', {
			type = 'Toggle',
			label = 'Toggle mouse',
			setter = 'enableMouse',
		})
		self:addOption('reset', {
			type = 'Button',
			label = 'Load default cooldowns for your spec',
			onClick = function (option)
				self:loadDefaultCooldowns()
			end,
		})
		self:addOption('export', {
			type = 'Button',
			label = 'Export current spec',
			onClick = function (option)
				O3.Copy(self:exportSpec())
			end,
		})
	end,
	getInventoryId = function (self, searchItemId)
		for slot = 1, 19 do
			local itemId = GetInventoryItemID('player', slot)
			if (itemId == searchItemId) then
				return -1*slot
			end
		end
		return nil
	end,
	enableMouse = function (self)
		self.cooldownPanel:enableMouse(self.settings.enableMouse)
	end,
	findInventoryItemByName = function (self, searchName)
		for slot = 1, 19 do
			local itemLink = GetInventoryItemLink('player', slot)
			if itemLink then
				local name = GetItemInfo(itemLink)
				if (name == searchName) then
					return -1*slot
				end
			end
		end
		return nil
	end,
	getMacroId = function (self, id)
		local name, rank, spellId = GetMacroSpell(id)
		if (name) then
			return spellId
		end
		local name, link = GetMacroItem(id)
		if (name) then
			return self:findInventoryItemByName(name)
		end
	end,
	exportSpec = function (self)
		local spec = GetSpecialization() or 1
		local _, class = UnitClass('player')
		table.wipe(self.exportList)
		
		for i = 1, 24 do
			local button = self.cooldownPanel.buttons[i]
			local actionId = button.actionId
			if actionId then
				local type, id, subType, spellID = GetActionInfo(actionId)
				if (type == 'spell') then
					table.insert(self.exportList, id)
				elseif (type == 'macro') then
					table.insert(self.exportList, self:getMacroId(id))
				elseif (type == 'item') then
					table.insert(self.exportList, self:getInventoryId(id))
				end
			else
				table.insert(self.exportList, 'nil')
			end
		end
		return class..'['..spec..'] = {'..table.concat(self.exportList, ', ')..'}'
	end,
	loadDefaultCooldowns = function (self)
		local spec = GetSpecialization() or 1
		local _, class = UnitClass('player')
		if (self.defaultCds[class] and self.defaultCds[class][spec]) then
			local spells = self.defaultCds[class][spec]
			for i = 1, #spells do
				local spellId = spells[i]
				local foundActionId
				if (spellId and spellId < 0) then
					local slot = spellId * -1
					local itemId = GetInventoryItemLink("player", slot)
					local itemLink = GetInventoryItemLink("player", slot)
					local itemName = GetItemInfo(itemLink)
					foundActionId = CooldownButton:findItem(itemId, itemName)
				elseif (spellId and spellId > 0) then
					foundActionId = CooldownButton:findSpell(spellId)
				end
				
				self.cooldownPanel.buttons[i]:set(foundActionId)
			end
		end

	end,
	-- PLAYER_SPECIALIZATION_CHANGED = function (self)
	-- 	self:reset()
	-- end,
	-- SPELLS_CHANGED = function (self)
	-- 	self:reset()
	-- end,
	-- findSpell = function (self, id)
	-- 	local found, foundId = false, 0
	-- 	local foundRow
	-- 	local _, class = UnitClass('player')
	-- 	if (not self.classInfo[class]) then
	-- 		return found, foundId
	-- 	end
	-- 	for i = 1, #self.classInfo[class] do
	-- 		for j = 1, #self.classInfo[class][i] do
	-- 			local spellId = self.classInfo[class][i][j]
	-- 			if (spellId == id) then
	-- 				foundRow = i
	-- 			end
	-- 		end
	-- 	end
	-- 	if (foundRow) then
	-- 		for j = 1, #self.classInfo[class][foundRow] do
	-- 			local spellId = self.classInfo[class][foundRow][j]
	-- 			if (IsPlayerSpell(spellId)) then
	-- 				foundId = spellId
	-- 				found = true
	-- 				break
	-- 			end
	-- 		end
	-- 	end
	-- 	return found, foundId
	-- end,

	-- enableMouse = function (self)
	-- 	for i = 1, 24 do
	-- 		self.buttons[i]:EnableMouse(self.settings.enableMouse or false)
	-- 	end
	-- end,
	PLAYER_ENTERING_WORLD = function (self)
		self:unregisterEvent('PLAYER_ENTERING_WORLD')
		self.cooldownPanel = CooldownPanel:instance({
			handler = self,
			frame = self.frame,
			settings = self.settings,
		})
		-- self:registerEvent('ACTIVE_TALENT_GROUP_CHANGED')
	end,

})