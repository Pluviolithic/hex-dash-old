--[[
	By Eric/AetherProgrammer
--]]

--[[ Services ]]--

local replicated_storage = game:GetService("ReplicatedStorage")
local server_storage = game:GetService("ServerStorage")
local marketplace_service = game:GetService("MarketplaceService")

--[[ Variables ]]--

local remotes = replicated_storage.Remotes
local switch_afk = remotes.Switch_AFK
local play_song = remotes.Play_Song
local main_song_id = replicated_storage.Miscellaneous.Song_Id
local song_ids = {
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

local radio = server_storage.Tools.Radio

--[[ Functions ]]--

local function shuffle(t)
	for n = #t, 1, -1 do
		local k = math.random(n)
		t[n], t[k] = t[k], t[n]
	end
	return t
end

--[[ General ]]--

switch_afk.OnServerEvent:Connect(function(player)
	local player_data_folder = replicated_storage:FindFirstChild(player.Name)
	if player_data_folder then
		player_data_folder.AFK.Value = not player_data_folder.AFK.Value
	end
end)

play_song.OnServerInvoke = function(player, song_id)
	
	local player_data_folder = replicated_storage[player.Name]
	local current_song = player_data_folder.Current_Song
	local boom_box_is_active = player_data_folder.Boom_Box_Is_Active
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	
	if (marketplace_service:UserOwnsGamePassAsync(player.UserId, 8593567) or allowed_users[player.UserId]) and type(song_id) == "string" and tonumber(song_id) then
		
		local success, info_type = pcall(marketplace_service.GetProductInfo, marketplace_service, tonumber(song_id))
		
		if success and info_type.AssetTypeId == 3 then
			boom_box_is_active.Value = true
			current_song.Value = "rbxassetid://"..song_id
			if not character:FindFirstChild("Radio", true) then
				humanoid:AddAccessory(radio:Clone())
			end
			return "Song turned on successfully!"
		else
			return "Not a valid song ID."
		end
		
	elseif type(song_id) == "boolean" and not song_id then
		local old_radio = character:FindFirstChild("Radio", true)
		if old_radio then
			old_radio:Destroy()
		end
		boom_box_is_active.Value = false
		current_song.Value = ""
		return "Song turned off successfully!"
	end
	
end

while true do
	local song_ids = shuffle(song_ids)
	for _, song_id in ipairs(song_ids) do
		local sound = Instance.new("Sound")
		print(song_id)
		sound.SoundId = "rbxassetid://"..song_id
		sound.Parent = server_storage
		if not sound.IsLoaded then
			sound.Loaded:Wait()
		end
		local song_length = sound.TimeLength
		main_song_id.Value = song_id
		sound:Destroy()
		wait(song_length)
	end
end