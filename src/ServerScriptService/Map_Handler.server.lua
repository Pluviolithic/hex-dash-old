--[[
	By Eric/AetherProgrammer
--]]

--[[ Services ]]--

local server_storage = game:GetService("ServerStorage")
local tween_service = game:GetService("TweenService")
local replicated_storage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local team_service = game:GetService("Teams")
local lighting_service = game:GetService("Lighting")

--[[ Variables ]]--

local maps = server_storage.Maps:GetChildren()
local temp_maps = table.pack(table.unpack(maps))

local tools = server_storage.Tools
local c4_remote = tools.C4
local c4 = tools.C4_Bomb

local remotes = replicated_storage.Remotes
local place_c4 = remotes.Place_C4

local miscellaneous = replicated_storage.Miscellaneous
local status = miscellaneous.Status
local red_score = miscellaneous.RED
local blue_score = miscellaneous.BLUE
local neutral_team = team_service.Neutral

local materials = Enum.Material
local dead_state = Enum.HumanoidStateType.Dead

local y_offset_vector = Vector3.new(0, 7, 0)
local tween_info = TweenInfo.new(0.5)
local getn = table.getn
local ran_obj = Random.new()

local modules = server_storage.Modules
local modes = require(modules.Modes)
local mode_display = miscellaneous.Mode
local current_mode_counter = 1

local keys = {
	["X"] = 0;
	["Y"] = 0;
	["Z"] = 0;
}
local mode_names = {
	"Classic";
	"Flash Fade";
	"Super Speed";
	"Colour Battle";
	"Explosive";
}

local neon_material = Enum.Material.Neon
local region_size = Vector3.new(1, 1, 1)*25

local default_explosion = Instance.new("Explosion")
default_explosion.BlastRadius = 30
default_explosion.BlastPressure = 0
default_explosion.ExplosionType = Enum.ExplosionType.NoCraters

--[[ Functions ]]--

local function shuffle(t)
	for n = #t, 1, -1 do
		local k = ran_obj:NextInteger(1, n)
		t[n], t[k] = t[k], t[n]
	end
	return t
end

local function copy_table(t)
	local new_t = {}
	for i, v in pairs(t) do
		new_t[i] = v
	end
	return new_t
end

local function filter_position(position)
	if type(position) ~= "table" then
		return Vector3.new()
	end
	local new_position = {}
	for key in pairs(keys) do
		new_position[key] = type(position[key]) == "number" and position[key] or 0
	end
	return Vector3.new(new_position.X, new_position.Y, new_position.Z)
end

local function init_c4(position, ignore_list)
	local bomb = c4:Clone()
	local bomb_material = bomb.Material
	local explosion = default_explosion:Clone()
	local region = Region3.new((position - region_size/2), (position + region_size/2))
	local parts_to_destroy = workspace:FindPartsInRegion3WithIgnoreList(region, ignore_list, math.huge)
	bomb.Position = position
	bomb.Parent = workspace
	for i = 1, 3 do
		wait(0.5)
		bomb.Material = bomb_material
		wait(0.5)
		bomb.Material = neon_material
	end
	explosion.Position = bomb.Position
	explosion.Parent = workspace
	wait()
	bomb:Destroy()
	for _, part in ipairs(parts_to_destroy) do
		part:Destroy()
	end
end

local function display_clock_time(counter)
	local seconds = counter%60
	status.Value = "0"..math.floor(counter/60)..":"..(seconds < 10 and "0"..seconds or seconds)
end

local function choose_map()
	if getn(maps) == getn(temp_maps) then
		temp_maps = shuffle(temp_maps)
		return table.remove(temp_maps):Clone()
	else
		local chosen_map = table.remove(temp_maps)
		if #temp_maps == 0 then
			temp_maps = {table.unpack(maps)}
		end
		return chosen_map:Clone()
	end
end

local function choose_mode()
	if current_mode_counter == 1 then
		shuffle(mode_names)
	end
	local new_mode = mode_names[current_mode_counter]
	current_mode_counter = current_mode_counter + 1
	if current_mode_counter > #mode_names then
		current_mode_counter = 1
	end
	return new_mode
end

local function get_participating_players()
	local participating_players = {}
	for _, player in ipairs(players:GetPlayers()) do
		local player_data_folder = replicated_storage:FindFirstChild(player.Name)
		if player_data_folder and not player_data_folder.AFK.Value then
			table.insert(participating_players, player)
		end
	end
	return participating_players
end

local function get_dictionary_length(t)
	local counter = 0
	for _ in pairs(t) do
		counter = counter + 1
	end
	return counter
end

local function give_win(player)
	local player_data_folder = replicated_storage:FindFirstChild(player.Name)
	if player_data_folder then
		player_data_folder.Wins.Value = player_data_folder.Wins.Value + 1
		player.Team = neutral_team
		player:LoadCharacter()
	end
end

local function run_round()
	local participating_players = get_participating_players()
	if getn(participating_players) < 2 then
		status.Value = "Not enough non-afk players. Please ask a friend to join."
		return false
	end
	status.Value = "Loading in map..."
	local map = choose_map()
	local spawns = shuffle(map.Spawns:GetChildren())
	local current_thread = coroutine.running()
	local connections = {}
	local mode = choose_mode()
	mode_display.Value = mode
	if modes[mode] then
		modes[mode](map)
	else
		map.Parent = workspace
	end
	if map.Name == "Enchanted Woods" then
		lighting_service.ClockTime = 0.116
	end
	wait(3)
	for i = 3, 1, -1 do
		status.Value = "Chosen map is "..map.Name..". Gamemode: "..mode..". Teleporting players in "..i.."..."
		wait(2)
	end
	local red_team = team_service:FindFirstChild("RED")
	local blue_team = team_service:FindFirstChild("BLUE")
	local participating_players = get_participating_players()
	if getn(participating_players) < 2 then
		status.Value = "Not enough non-afk players. Please ask a friend to join."
		map:Destroy()
		lighting_service.ClockTime = 14
		if red_team and blue_team then
			red_team:Destroy()
			blue_team:Destroy()
		end
		return false
	end
	local live_players = {}
	local last_assigned = red_team
	for i, player in ipairs(shuffle(participating_players)) do
		local spawn_point = spawns[i]
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid_root_part = character:WaitForChild("HumanoidRootPart")
		local humanoid = character:WaitForChild("Humanoid")
		humanoid_root_part.CFrame = CFrame.new(spawn_point.Position + y_offset_vector)
		if mode_display.Value == "Super Speed" and humanoid then
			humanoid.WalkSpeed = 75
		end
		if mode == "Colour Battle" then
			last_assigned = last_assigned == red_team and blue_team or red_team 
			player.Team = last_assigned
			live_players[player] = last_assigned
		 	local death_connection; death_connection = humanoid.Died:Connect(function()
				print("EVENT")
				local team = player.Team
				player.Team = neutral_team
				live_players[player] = nil
				if getn(team:GetPlayers()) < 1 then
					status.Value = (team == red_team and "Blue" or "Red").." team has won by default!"
				end
				death_connection:Disconnect()
			end)
			local leaving_connection; leaving_connection = players.PlayerRemoving:Connect(function(leaving_player)
				if player == leaving_player then
					local team = player.Team
					player.Team = neutral_team
					live_players[player] = nil
					if getn(team:GetPlayers()) < 1 then
						status.Value = (team == red_team and "Blue" or "Red").." team has won by default!"
					end
					leaving_connection:Disconnect()
				end
			end)
			table.insert(connections, death_connection)
			table.insert(connections, leaving_connection)
		else
			if mode == "Explosive" then
				live_players[player] = 0
				c4_remote:Clone().Parent = player.Backpack
			else
				live_players[player] = true
			end
		 	local death_connection; death_connection = humanoid.Died:Connect(function()
				live_players[player] = nil
				if get_dictionary_length(live_players) < 2 then
					status.Value = next(live_players).Name.." has won the round!"
					give_win(next(live_players))
					coroutine.resume(current_thread)
				end
				death_connection:Disconnect()
			end)
			local leaving_connection; leaving_connection = players.PlayerRemoving:Connect(function(leaving_player)
				if player == leaving_player then
					live_players[player] = nil
					if get_dictionary_length(live_players) < 2 then
						status.Value = next(live_players).Name.." has won the round!"
						give_win(next(live_players))
						coroutine.resume(current_thread)
					end
					leaving_connection:Disconnect()
				end
			end)
			table.insert(connections, death_connection)
			table.insert(connections, leaving_connection)
		end
	end	
	wait(1)
	for i = 3, 1, -1 do
		status.Value = "Round starting in "..i.."..."
		wait(1)
	end
	if not status.Value:match("team has won by default!") then
		status.Value = "Round in progress..."
	end
	if mode == "Colour Battle" then
		local counter = 120
		if not status.Value:match("team has won by default!") then
			display_clock_time(counter)
		end
		wait(1)
		while status.Value:match(":") and counter > 0 do
			counter = counter - 1
			display_clock_time(counter)
			wait(1)
		end
		if status.Value:match("team has won by default!") then
			if status.Value:match("Red") then
				for _, player in ipairs(team_service.RED:GetPlayers()) do
					give_win(player)
					live_players[player] = nil
				end
			else
				for _, player in ipairs(team_service.BLUE:GetPlayers()) do
					give_win(player)
					live_players[player] = nil
				end
			end
		else
			if red_score.Value > blue_score.Value then
				status.Value = "Red team has won by a margin of "..(red_score.Value - blue_score.Value).."!"
				for _, player in ipairs(team_service.RED:GetPlayers()) do
					give_win(player)
					live_players[player] = nil
				end
			elseif red_score.Value < blue_score.Value then
				status.Value = "Blue team has won by a margin of "..(blue_score.Value - red_score.Value).."!"
				for _, player in ipairs(team_service.BLUE:GetPlayers()) do
					give_win(player)
					live_players[player] = nil
				end
			else
				status.Value = "There has been a tie!"
			end
		end
		for player in pairs(live_players) do
			player.Team = neutral_team
			player:LoadCharacter()
		end
		map:Destroy()
		for _, connection in ipairs(connections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end
		wait(3)
		red_score.Value = 0
		blue_score.Value = 0
		red_team:Destroy()
		blue_team:Destroy()
	else
		if mode == "Explosive" then
			local ignore_list = {workspace.Lobby}
			for _, obj in ipairs(map["Kill Zone"]:GetChildren()) do
				table.insert(ignore_list, obj)
			end
			for player in pairs(live_players) do
				table.insert(ignore_list, player.Character)
			end
			table.insert(connections, place_c4.OnServerEvent:Connect(function(player, position)
				if status.Value =="Round in progress..." and live_players[player] and (tick() - live_players[player]) >= 5  then
					live_players[player] = tick()
					local position = filter_position(position)
					local humanoid_root_part = player.Character.HumanoidRootPart
					if (position - humanoid_root_part.Position).Magnitude <= 160 then
						init_c4(position, ignore_list)
					end
				end
			end))
		end
		coroutine.yield(current_thread)
		map:Destroy()
		for _, connection in ipairs(connections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end
		wait(3)
	end
	return true
end

while true do
	if run_round() then
		lighting_service.ClockTime = 14
		for i = 15, 1, -1 do
			status.Value = "Intermission...("..i..")"
			wait(1)
		end
	else
		wait(1)
	end
end