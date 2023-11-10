--[[
	By Eric/AetherProgrammer
--]]

--[[ Services ]]--

local players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local data_store_service = game:GetService("DataStoreService")
local run_service = game:GetService("RunService")
local sound_service = game:GetService("SoundService")
local marketplace_service = game:GetService("MarketplaceService")
local server_storage = game:GetService("ServerStorage")

--[[ Variables ]]--

local free_camera = server_storage.Freecam

local saveable_indicator = Instance.new("BoolValue")
saveable_indicator.Name = "Can_Save"

local player_can_save = Instance.new("BoolValue")
player_can_save.Value = false
player_can_save.Name = "Can_Save"

local join_time = Instance.new("NumberValue")
join_time.Name = "Join_Time"

local purchase_granted_enum = Enum.ProductPurchaseDecision.PurchaseGranted

local remotes = replicated_storage.Remotes
local purchase_success = remotes.Purchase_Success
local get_cosmetics = remotes.Get_Cosmetics
local equip_item = remotes.Equip_Item

local radio = server_storage.Tools.Radio

local main_data_store = data_store_service:GetDataStore("MAIN")

local server_shop = replicated_storage.Shop

local player_cosmetics = {}
local equipped_hats = {}

local defaults = {
	["XP"] = 0;
	["Cosmetics"] = {};
}

--[[ Functions ]]--

local function process_receipt(receipt_info)
	local id = receipt_info.ProductId
	local player = players:GetPlayerByUserId(receipt_info.PlayerId)
	for _, item in ipairs(server_shop:GetDescendants()) do
		if item:IsA("NumberValue") and item.Name:match("Donation") then
			if item.Value == id then
				purchase_success:FireClient(player) -- may use later to send a thank you
				return purchase_granted_enum
			end
		elseif item:FindFirstChild("Robux") then
			if item.ID.Value == id then
				local character = player.Character or player.CharacterAdded:Wait()
				local humanoid = character:WaitForChild("Humanoid")
				local humanoid_root_part = character:WaitForChild("HumanoidRootPart")
				if item:IsA("ParticleEmitter") then
					local old_emitter = humanoid_root_part:FindFirstChildWhichIsA("ParticleEmitter")
					if old_emitter then
						old_emitter:Destroy()
					end
					item:Clone().Parent = humanoid_root_part
				else
					local old_hat = equipped_hats[tostring(player.UserId)]
					if old_hat and old_hat.Parent then
						old_hat:Destroy()
					end
					local new_hat = item:Clone()
					equipped_hats[tostring(player.UserId)] = new_hat
					humanoid:AddAccessory(new_hat)
				end
				player_cosmetics[tostring(receipt_info.PlayerId)][tostring(item.ID.Value)] = true
				purchase_success:FireClient(player)
				return purchase_granted_enum
			end
		end
	end
end

local function get_data_to_save(player)
	
	local player_data_folder = replicated_storage:FindFirstChild(player.Name)
	local data_to_save = {}
	
	if player_data_folder then
		
		for _, object in pairs(player_data_folder:GetChildren()) do
			if object:IsA("ValueBase") and object:FindFirstChild("Can_Save") then
				data_to_save[object.Name] = object.Value
			end
		end
		
		data_to_save["Cosmetics"] = player_cosmetics[tostring(player.UserId)]
		
		-- will use a bindable to get cosmetics information
		-- more save data and specific other methods for getting other data to save (if needed) etc
		
		return data_to_save
		
	end
	
end

local function get_data(player_id)
	local success, data = pcall(main_data_store.GetAsync, main_data_store, player_id)		
	if success then
		return data
	else
		return  "ERROR"
	end
end

local function save_data(player, data, LAST)
	local player_data_folder = replicated_storage[player.Name]
	if player:FindFirstChild("Can_Save") and player.Can_Save.Value or (LAST and tick() - player_data_folder.Join_Time.Value >= 15) then
		player.Can_Save.Value = false
		local player_id = tostring(player.UserId)
		local success, message = pcall(main_data_store.SetAsync, main_data_store, player_id, data)
		if not success then
			warn(player_id.."'s data failed to save with error: \n"..message)
		end
		delay(15, function()
			if players:FindFirstChild(player.Name) then
				player.Can_Save.Value = true
			end
		end)
	end
end

local function save_every_players_data(LAST)
	for _, player in pairs(players:GetPlayers()) do
		spawn(function()
			if replicated_storage:FindFirstChild(player.Name) then
				save_data(player, get_data_to_save(player), LAST)
			end
		end)
	end
end

--[[ General ]]--

players.PlayerAdded:Connect(function(player)
	
	if not player.PlayerGui:FindFirstChild("Freecam") then
		free_camera:Clone().Parent = player.PlayerGui
	end
	
	local player_id = tostring(player.UserId)
	
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	
	local leaderstat_wins = Instance.new("IntValue")
	leaderstat_wins.Name = "Wins"
	
	local player_data_folder = Instance.new("Folder")
	player_data_folder.Name = player.Name
	
	local current_song = Instance.new("StringValue")
	current_song.Name = "Current_Song"
	
	local radio_is_enabled = Instance.new("BoolValue")
	radio_is_enabled.Name = "Boom_Box_Is_Active"
	
	local other_radios_enabled = Instance.new("BoolValue") -- will use later when I have a ui for it
	other_radios_enabled.Name = "Other_Radios_Enabled"
	other_radios_enabled.Value = true
	
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	saveable_indicator:Clone().Parent = wins
	
	local afk = Instance.new("BoolValue")
	afk.Name = "AFK"
	afk.Value = true
	
	local join_time = Instance.new("NumberValue")
	join_time.Name = "Join_Time"
	
	leaderstat_wins.Parent = leaderstats
	leaderstats.Parent = player
	
	current_song.Parent = player_data_folder
	radio_is_enabled.Parent = player_data_folder
	other_radios_enabled.Parent = player_data_folder
	wins.Parent = player_data_folder
	afk.Parent = player_data_folder
	join_time.Parent = player_data_folder
	player_data_folder.Parent = replicated_storage
	
	player_can_save:Clone().Parent = player
	join_time:Clone().Parent = player
	
	player.Join_Time.Value = tick()
	
	wins:GetPropertyChangedSignal("Value"):Connect(function()
		leaderstat_wins.Value = wins.Value
	end)
	
	wait(5)
	
	if not players:FindFirstChild(player.Name) then
		return
	end
	
	local saved_data = get_data(player_id)
	
	if saved_data == "ERROR" then
		player:Kick("Your data failed to load. Please join another server and try again.")
		return
	elseif type(saved_data) ~= "table" then
		saved_data = defaults
	end
	
	for key, value in pairs(defaults) do -- this in case new data is added after save data is already in existence
		if saved_data[key] == nil then
			saved_data[key] = value
		end
	end
	
	for key, value in pairs(saved_data) do
		if player_data_folder:FindFirstChild(key) then
			player_data_folder[key].Value = value
		end
	end
	
	player_cosmetics[tostring(player.UserId)] = saved_data.Cosmetics
	
	player.Can_Save.Value = true
	afk.Value = false
	
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		if radio_is_enabled.Value then
			humanoid:AddAccessory(radio:Clone())
		end
	end)
	
end)

players.PlayerRemoving:Connect(function(player)
	local player_data_folder = replicated_storage:FindFirstChild(player.Name)
	if player_data_folder then
		save_data(player, get_data_to_save(player), true)
		player_data_folder:Destroy()
	end
	player_cosmetics[tostring(player.UserId)] = nil
	equipped_hats[tostring(player.UserId)] = nil
end)

get_cosmetics.OnServerInvoke = function(player)
	return player_cosmetics[tostring(player.UserId)]
end

equip_item.OnServerEvent:Connect(function(player, item)
	if item:FindFirstAncestor("Shop") then
		local wins = replicated_storage[player.Name].Wins.Value
		if item:IsA("ParticleEmitter") then
			if item:FindFirstChild("Wins") then
				if wins >= item.Wins.Value then
					local character = player.Character or player.CharacterAdded:Wait()
					local humanoid_root_part = character:WaitForChild("HumanoidRootPart")
					local old_trail = humanoid_root_part:FindFirstChildWhichIsA("ParticleEmitter")
					if old_trail then
						old_trail:Destroy()
					end
					item:Clone().Parent = humanoid_root_part
				end
			elseif player_cosmetics[tostring(player.UserId)][tostring(item.ID.Value)] then
				local character = player.Character or player.CharacterAdded:Wait()
				local humanoid_root_part = character:WaitForChild("HumanoidRootPart")
				local old_trail = humanoid_root_part:FindFirstChildWhichIsA("ParticleEmitter")
				if old_trail then
					old_trail:Destroy()
				end
				item:Clone().Parent = humanoid_root_part
			end
		else
			if item:FindFirstChild("Wins") then
				if wins >= item.Wins.Value then
					local character = player.Character or player.CharacterAdded:Wait()
					local humanoid = character:WaitForChild("Humanoid")
					local old_hat = equipped_hats[tostring(player.UserId)]
					if old_hat and old_hat.Parent then
						old_hat:Destroy()
					end
					local new_hat = item:Clone()
					humanoid:AddAccessory(new_hat)
					equipped_hats[tostring(player.UserId)] = new_hat
				end
			elseif player_cosmetics[tostring(player.UserId)][tostring(item.ID.Value)] then
				local character = player.Character or player.CharacterAdded:Wait()
				local humanoid = character:WaitForChild("Humanoid")
				local old_hat = equipped_hats[tostring(player.UserId)]
				if old_hat and old_hat.Parent then
					old_hat:Destroy()
				end
				local new_hat = item:Clone()
				humanoid:AddAccessory(new_hat)
				equipped_hats[tostring(player.UserId)] = new_hat
			end
		end
	end
	purchase_success:FireClient(player)
end)

marketplace_service.ProcessReceipt = process_receipt
sound_service.RespectFilteringEnabled = true

if not run_service:IsStudio() then
	game:BindToClose(function()
		save_every_players_data(true)
	end)
end

while true do
	wait(60)
	save_every_players_data()
end