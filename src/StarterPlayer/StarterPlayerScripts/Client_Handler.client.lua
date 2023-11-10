--[[
	By Eric/AetherProgrammer
--]]

--[[ Services ]]--

local replicated_storage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local marketplace_service = game:GetService("MarketplaceService")
local tween_service = game:GetService("TweenService")

--[[ Variables ]]--

local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid_root_part = character:WaitForChild("HumanoidRootPart")

local player_data_folder = replicated_storage:WaitForChild(player.Name)
local wins = player_data_folder:WaitForChild("Wins")
local is_afk = player_data_folder:WaitForChild("AFK")
local other_radios_enabled = player_data_folder:WaitForChild("Other_Radios_Enabled")
local my_radio_is_enabled = player_data_folder:WaitForChild("Boom_Box_Is_Active")

local remotes = replicated_storage:WaitForChild("Remotes")
local switch_afk = remotes.Switch_AFK
local purchase_success = remotes.Purchase_Success
local get_cosmetics = remotes.Get_Cosmetics
local equip_item = remotes.Equip_Item
local play_song = remotes.Play_Song

local miscellaneous = replicated_storage:WaitForChild("Miscellaneous")
local status = miscellaneous.Status
local main_song_id = miscellaneous.Song_Id
local last_area_song_id = main_song_id.Value

local player_gui = player:WaitForChild("PlayerGui")
local main_display = player_gui:WaitForChild("Main_Display")

local open_shop_button = main_display.Shop_Button
local wins_display = main_display.Wins_Display
local status_display = main_display.Status_Display

local afk_button = main_display.AFK_Button
local afk_text = afk_button.AFK_Text

local music_switch = main_display.Music
local game_songs = workspace:WaitForChild("Game_Songs")
local area_music_is_enabled = true
local tween_info = TweenInfo.new(2)
local on_properties = {
	["Volume"] = 0.8
}
local off_properties = {
	["Volume"] = 0
}
local volume_tween_objects = {}
local song_changed_connections = {}
local last_song_ids = {}

local main_song_ids = {
	1846272493;
	292744729;
	588190964;
	452176144;
	610800425;
	1447404216;
	154315237;
}
local allowed_users = {
	[450516853] = true;
	[436631753] = true;
	[220051208] = true;
}

local open_uis = {}
local shop_ui
local boombox_ui

--[[ Functions ]]--

local function update_afk_ui()
	if is_afk.Value then
		afk_text.Text = "AFK"
	else
		afk_text.Text = "Playing"
	end
end

local function update_status()
	status_display.Text = status.Value
end

local function update_wins()
	wins_display.Text = "Wins: "..wins.Value
end

local function close_open_uis()
	for ui in pairs(open_uis) do
		ui.Close()
	end
end

local function tween_volume_on(song_obj)
	return tween_service:Create(
		song_obj,
		tween_info,
		on_properties
	)
end

local function tween_volume_off(song_obj)
	return tween_service:Create(
		song_obj,
		tween_info,
		off_properties
	)
end

local function handle_music_volume(player, can_always_play)
	
	local player_data_folder = replicated_storage:WaitForChild(player.Name)
	local boom_box_is_active = player_data_folder:WaitForChild("Boom_Box_Is_Active")
	local current_song = player_data_folder:WaitForChild("Current_Song")
	
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid_root_part = character:WaitForChild("HumanoidRootPart")
	
	if boom_box_is_active.Value then
		
		local song_id = current_song.Value
		local song_obj = Instance.new("Sound")
		
		song_obj.Name = song_id
		song_obj.SoundId = song_id
		song_obj.Volume = 0
		song_obj:Play()
		
		local tween_obj = tween_volume_on(song_obj)
		
		volume_tween_objects[player.Name.."_On"] = tween_volume_on(song_obj)
		volume_tween_objects[player.Name.."_Off"] = tween_volume_off(song_obj)
		last_song_ids[player.Name] = song_id
		
		song_obj.Parent = game_songs
		
		if other_radios_enabled.Value or can_always_play then
			tween_obj:Play()	
		end
		
	end
	
	song_changed_connections[player.Name] = current_song:GetPropertyChangedSignal("Value"):Connect(function()
		
		local last_song_id = last_song_ids[player.Name]
		if last_song_id then
			local last_song = game_songs:FindFirstChild(last_song_id)
			if last_song then
				last_song:Destroy()
				last_song_ids[player.Name] = nil
			end
		end
		
		if boom_box_is_active.Value then
			
			local song_id = current_song.Value
			local song_obj = Instance.new("Sound")
			
			song_obj.Name = song_id
			song_obj.SoundId = song_id
			song_obj.Volume = 0
			song_obj.Looped = true
			song_obj:Play()
			
			volume_tween_objects[player.Name.."_On"] = tween_volume_on(song_obj)
			volume_tween_objects[player.Name.."_Off"] = tween_volume_off(song_obj)
			last_song_ids[player.Name] = song_id
			
			song_obj.Parent = game_songs
		
		end
		
	end)
	
end

local function initialize_shop()
	local shop = player_gui:WaitForChild("Shop_UI")
	local self = {}
	
	local server_shop = replicated_storage:WaitForChild("Shop")
	
	local background = shop.Background
	local item_scrolling_frame = background.Items
	local template = item_scrolling_frame.Template:Clone()
	
	local function clear_shop()
		for _, item in ipairs(item_scrolling_frame:GetChildren()) do
			if not item:IsA("UIGridLayout") then
				item:Destroy()
			end
		end
	end
	
	local function get_items(category)
		local items = server_shop:FindFirstChild(category):GetChildren()
		table.sort(items, function(a, b)
			local price_a = a:FindFirstChild("Wins") and a.Wins.Value or a:FindFirstChild("Robux") and a.Robux.Value or a.Donation.Value
			local price_b = b:FindFirstChild("Wins") and b.Wins.Value or b:FindFirstChild("Robux") and b.Robux.Value or b.Donation.Value
			return price_a < price_b
		end)
		return items
	end
	
	local function display_items(category)
		clear_shop()
		local purchased_cosmetics = get_cosmetics:InvokeServer()
		local items = get_items(category)
		for _, item in ipairs(items) do
			local new_template = template:Clone()
			if item:IsA("ParticleEmitter") then
				new_template.ImageLabel.Image = item.Texture
			elseif not item:IsA("NumberValue") then
				new_template.ImageLabel.Image = item.Image_ID.Value
			end
			if item:FindFirstChild("Wins") then
				if wins.Value < item.Wins.Value then
					new_template.TextLabel.Text = "Wins: "..item.Wins.Value
				end
			elseif item:FindFirstChild("Robux") then
				if not purchased_cosmetics[tostring(item.ID.Value)] then
					new_template.TextLabel.Text = "Robux: "..item.Robux.Value
				end
			else
				new_template.TextLabel.Text = "Robux: "..item.Donation.Value
			end
			new_template.Activated:Connect(function()
				if item:FindFirstChild("Wins") then
					if wins.Value >= item.Wins.Value then
						equip_item:FireServer(item)
					end
				elseif item:FindFirstChild("Robux") then
					if purchased_cosmetics[tostring(item.ID.Value)] then
						equip_item:FireServer(item)
					else
						marketplace_service:PromptProductPurchase(player, item.ID.Value)
					end
				else
					marketplace_service:PromptProductPurchase(player, item.Value)
				end
			end)
			new_template.Parent = item_scrolling_frame
		end
	end
	
	self.Open = function()
		if shop.Enabled then
			self.Close()
		else
			close_open_uis()
			shop.Enabled = true
			open_uis[self] = true
			display_items("Hats")
		end
	end
	self.Close = function()
		clear_shop()
		shop.Enabled = false
		open_uis[self] = nil
	end
	
	open_shop_button.Activated:Connect(self.Open)
	
	background.Hats.Activated:Connect(function()
		display_items("Hats")
	end)
	--[[
	background.Particles.Activated:Connect(function()
		display_items("Particles")
	end)
	--]]
	background.Donations.Activated:Connect(function()
		display_items("Donations")
	end)
	
	purchase_success.OnClientEvent:Connect(self.Close)
	clear_shop()
	
	return self
end

local function initialize_boombox()
	local boombox = player_gui:WaitForChild("Boombox")
	local self = {}
	
	local background = boombox.Background
	local song_id = background.SongID
	
	self.Open = function()
		if boombox.Enabled then
			self.Close()
		else
			close_open_uis()
			if marketplace_service:UserOwnsGamePassAsync(player.UserId, 8593567) or allowed_users[player.UserId] then
				boombox.Enabled = true
				open_uis[self] = true
			else
				marketplace_service:PromptGamePassPurchase(player, 8593567)
			end
		end
	end
	
	self.Close = function()
		song_id.Text = ""
		boombox.Enabled = false
		open_uis[self] = nil
	end
	
	background.Close.Activated:Connect(self.Close)
	main_display.Boombox_Button.Activated:Connect(self.Open)
	
	background.Play.Activated:Connect(function()
		song_id.Text = song_id.Text:gsub("%D", "")
		if #song_id.Text > 0 then
			song_id.Text = play_song:InvokeServer(song_id.Text)
		end
	end)
	
	background.Stop.Activated:Connect(function()
		song_id.Text = play_song:InvokeServer(false)
	end)
	
	return self
end

--[[ General ]]--

for _, id in ipairs(main_song_ids) do
	local new_sound = Instance.new("Sound")
	new_sound.Volume = 0
	new_sound.Name = "rbxassetid://_"..id
	new_sound.SoundId = "rbxassetid://"..id
	new_sound.Looped = true
	new_sound.Parent = game_songs
	volume_tween_objects[new_sound.Name.."_On"] = tween_volume_on(new_sound)
	volume_tween_objects[new_sound.Name.."_Off"] = tween_volume_off(new_sound)
	new_sound:Play()
end

main_song_id:GetPropertyChangedSignal("Value"):Connect(function()
	volume_tween_objects["rbxassetid://_"..last_area_song_id.."_Off"]:Play()
	last_area_song_id = main_song_id.Value
end)

music_switch.Activated:Connect(function()
	if area_music_is_enabled then
		area_music_is_enabled = false
		music_switch.Text = "Music: Off"
	else
		area_music_is_enabled = true
		music_switch.Text = "Music: On"
	end
end)

update_status()
status:GetPropertyChangedSignal("Value"):Connect(update_status)

update_wins()
wins:GetPropertyChangedSignal("Value"):Connect(update_wins)

update_afk_ui()
is_afk:GetPropertyChangedSignal("Value"):Connect(update_afk_ui)

afk_button.Activated:Connect(function()
	switch_afk:FireServer()
end)

players.PlayerAdded:Connect(handle_music_volume)

players.PlayerRemoving:Connect(function(player)
	local on_tween_obj = volume_tween_objects[player.Name.."_On"]
	local off_tween_obj = volume_tween_objects[player.Name.."_Off"]
	local last_song_id = last_song_ids[player.Name]
	local song_obj = last_song_id and game_songs:FindFirstChild(last_song_id)
	if on_tween_obj then
		on_tween_obj:Destroy()
		volume_tween_objects[player.Name.."_On"] = nil
	end
	if off_tween_obj then
		if song_obj and song_obj.Volume > 0 then
			off_tween_obj:Play()
			off_tween_obj.Completed:Wait()
		end
		off_tween_obj:Destroy()
		volume_tween_objects[player.Name.."_Off"] = nil
	end
	if song_obj then
		song_obj:Destroy()
	end
	last_song_ids[player.Name] = nil
end)

for _, other_player in ipairs(players:GetPlayers()) do
	if other_player == player then
		handle_music_volume(other_player, true)
	else
		handle_music_volume(other_player, false)
	end
end

other_radios_enabled:GetPropertyChangedSignal("Value"):Connect(function()
	if not other_radios_enabled.Value then
		for player_name, song_id in pairs(last_song_ids) do	
			local song_obj = game_songs:FindFirstChild(song_id)
			if song_obj and song_obj.Volume > 0 then
				local tween_obj = volume_tween_objects[player_name.."_Off"]
				if tween_obj then
					tween_obj:Play()
				end
			end
		end
	end
end)

shop_ui = initialize_shop()
boombox_ui = initialize_boombox()

while true do
	if humanoid_root_part then
		local found_a_player_playing_music_in_range = false
		for _, other_player in ipairs(players:GetPlayers()) do
			local other_player_data_folder = replicated_storage:WaitForChild(other_player.Name)
			local other_players_boom_box_is_active = other_player_data_folder:WaitForChild("Boom_Box_Is_Active")
			local other_players_current_song = other_player_data_folder:WaitForChild("Current_Song")
			local other_character = other_player.Character or other_player.CharacterAdded:Wait()
			local other_humanoid_root_part = other_character:FindFirstChild("HumanoidRootPart")
			if other_humanoid_root_part and other_players_boom_box_is_active.Value and (other_player == player or other_radios_enabled.Value) then
				local song_obj = game_songs:FindFirstChild(other_players_current_song.Value)
				if song_obj then
					if (player:DistanceFromCharacter(other_humanoid_root_part.Position) <= 50) or player == other_player then
						found_a_player_playing_music_in_range = true
						if song_obj.Volume < 1 then
							local tween_obj = volume_tween_objects[other_player.Name.."_On"]
							if tween_obj then
								tween_obj:Play()
							end
						end	
					elseif song_obj.Volume > 0 then
						local tween_obj = volume_tween_objects[other_player.Name.."_Off"]
						if tween_obj then
							tween_obj:Play()
						end
					end
				end
			end
		end
		if found_a_player_playing_music_in_range or not area_music_is_enabled then
			local off_tween_obj = volume_tween_objects["rbxassetid://_"..main_song_id.Value.."_Off"]
			if off_tween_obj then
				off_tween_obj:Play()
			end	
		elseif area_music_is_enabled then
			local on_tween_obj = volume_tween_objects["rbxassetid://_"..main_song_id.Value.."_On"]
			if on_tween_obj then
				on_tween_obj:Play()
			end				
		end
	end
	wait(0.4)
end