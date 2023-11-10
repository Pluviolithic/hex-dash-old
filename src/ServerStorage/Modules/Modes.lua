--[[
	By Eric/AetherProgrammer
--]]

--[[ Services ]]--

local tween_service = game:GetService("TweenService")
local players = game:GetService("Players")
local replicated_storage = game:GetService("ReplicatedStorage")
local server_storage = game:GetService("ServerStorage")
local team_service = game:GetService("Teams")

--[[ Variables ]]--

local miscellaneous = replicated_storage.Miscellaneous
local status = miscellaneous.Status
local teams_folder = replicated_storage.Teams
local modes = {}

--[[ Functions ]]--

local function shuffle(t)
	for n = #t, 1, -1 do
		local k = math.random(n)
		t[n], t[k] = t[k], t[n]
	end
	return t
end

modes["Classic"] = function(map)
	local tween_info = TweenInfo.new(0.5)
	for _, folder in ipairs(map:GetChildren()) do
		if folder.Name ~= "Terrain" then
			for _, obj in ipairs(folder:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name ~= "Spawn" and obj.Name ~= "Barrier" and obj.Name ~= "Void"  then
					local touched = false
					local tween = tween_service:Create(
						obj,
						tween_info,
						{
							Transparency = 1;
						}
					)
					obj.Touched:Connect(function(hit)
						if players:GetPlayerFromCharacter(hit:FindFirstAncestorWhichIsA("Model")) and status.Value == "Round in progress..." and not touched then
							touched = true
							tween:Play()
							tween.Completed:Wait()
							tween:Destroy()
							obj:Destroy()
						end
					end)
				end
			end
		else
			for _, hex_model in ipairs(folder:GetDescendants()) do
				if hex_model:IsA("Model") and hex_model.Name:match("Hex Terrain") then
					local hex_model_children = hex_model:GetChildren()
					local touched = false
					local tweens = {}
					for _, obj in ipairs(hex_model_children) do
						table.insert(tweens, tween_service:Create(
							obj,
							tween_info,
							{
								Transparency = 1
							}
						))
						obj.Touched:Connect(function(hit)
							if players:GetPlayerFromCharacter(hit:FindFirstAncestorWhichIsA("Model")) and status.Value == "Round in progress..." and not touched then
								touched = true
								for _, tween in ipairs(tweens) do
									tween:Play()
								end
								tweens[#tweens].Completed:Wait()
								for i, obj in ipairs(hex_model_children) do
									tweens[i]:Destroy()
									obj:Destroy()
								end
							end	
						end)
					end
				end
			end
		end
	end
	map.Parent = workspace
end

modes["Flash Fade"] = function(map)
	local map_parts = {}
	local tween_info = TweenInfo.new(0.75)
	for _, folder in ipairs(map:GetChildren()) do
		if folder.Name ~= "Terrain" then
			for _, obj in ipairs(folder:GetDescendants()) do
				if obj:IsA("BasePart") and obj.Name ~= "Spawn" and obj.Name ~= "Barrier" and obj.Name ~= "Void"  then
					table.insert(map_parts, obj)
				end
			end
		else
			for _, hex_model in ipairs(folder:GetDescendants()) do
				if hex_model:IsA("Model") and hex_model.Name:match("Hex Terrain") then
					table.insert(map_parts, hex_model)
				end
			end
		end
	end
	shuffle(map_parts)
	spawn(function()
		repeat
			status:GetPropertyChangedSignal("Value"):Wait()
		until status.Value == "Round in progress..." or status.Value == "Not enough non-afk players. Please ask a friend to join."
		if status.Value == "Not enough non-afk players. Please ask a friend to join." then
			return
		end
		local end_one = math.ceil(#map_parts/3)
		local end_two = math.ceil(2*#map_parts/3)
		spawn(function()
			for i = 1, end_one do
				map_parts[i]:Destroy()
				wait()
			end
		end)
		spawn(function()
			for i = (end_one + 1), end_two do
				map_parts[i]:Destroy()
				wait()
			end
		end)
		spawn(function()
			for i = (end_two + 1), #map_parts do
				map_parts[i]:Destroy()
				wait()
			end
		end)
	end)
	map.Parent = workspace
end

modes["Super Speed"] = function(map)
	modes["Classic"](map)
end

modes["Colour Battle"] = function(map)
	local red_team = teams_folder.RED:Clone()
	local blue_team = teams_folder.BLUE:Clone()
	red_team.Parent = team_service
	blue_team.Parent = team_service
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name ~= "Barrier" and obj.Name ~= "Void" and obj.Name ~= "Spawn" then
			local debounce = true
			obj.Touched:Connect(function(hit)
				local player = players:GetPlayerFromCharacter(hit:FindFirstAncestorWhichIsA("Model"))
				if player and status.Value:match("%d+:%d+") and status.Value ~= "00:00" and obj.BrickColor ~= player.TeamColor and (player.Team == red_team or player.Team == blue_team)  then
					if debounce then
						debounce = false
						if obj.BrickColor ==  BrickColor.new("Really red") then
							local other_team_score = miscellaneous["RED"]
							other_team_score.Value = other_team_score.Value - 1
						elseif obj.BrickColor == BrickColor.new("Bright blue") then
							local other_team_score = miscellaneous["BLUE"]
							other_team_score.Value = other_team_score.Value - 1				
						end
						obj.BrickColor = player.TeamColor
						local score_counter = miscellaneous[player.Team.Name]
						score_counter.Value = score_counter.Value + 1
					end
					wait(1)
					debounce = true
				end
			end)
		end
	end
	map.Parent = workspace
end

return modes