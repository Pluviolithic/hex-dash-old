--[[
	By Eric/AetherProgrammer
--]]

--[[ Services ]]--

local replicated_storage = game:GetService("ReplicatedStorage")
local user_input_service = game:GetService("UserInputService")
local players = game:GetService("Players")

--[[ Variables ]]--

local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid_root_part = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

local tool = script.Parent
local cooled_down = true
local c4_enabled = false

local status = replicated_storage.Miscellaneous.Status
local place_c4 = replicated_storage.Remotes.Place_C4

--[[ Functions ]]--

local function handle_input_position(position)
	if status.Value == "Round in progress..." then
		local unit_ray = camera:ViewportPointToRay(position.X, position.Y)
		local ray = Ray.new(unit_ray.Origin, unit_ray.Direction*200)
		local part, position = workspace:FindPartOnRayWithIgnoreList(ray, {character})
		if part and (humanoid_root_part.Position - position).Magnitude <= 150 then
			cooled_down = false
			place_c4:FireServer({
				["X"] = position.X;
				["Y"] = position.Y;
				["Z"] = position.Z;
			})
			wait(5)
			cooled_down = true
		end
	end
end

--[[ General ]]--

tool.Equipped:Connect(function()
	c4_enabled = true
end)

tool.Unequipped:Connect(function()
	c4_enabled = false
end)

if user_input_service.TouchEnabled and not user_input_service.KeyboardEnabled and not user_input_service.MouseEnabled then
	user_input_service.TouchTapInWorld:Connect(function(position, processed_by_ui)
		if c4_enabled then
			if cooled_down then
				if not processed_by_ui then
					handle_input_position(position)
				end
			end
		end
	end)
else
	local mouse = player:GetMouse()
	local left_click_enum = Enum.UserInputType.MouseButton1
	user_input_service.InputBegan:Connect(function(input_object, game_processed_event)
		if c4_enabled then
			if cooled_down then
				if input_object.UserInputType == left_click_enum and not game_processed_event then
					local position = user_input_service:GetMouseLocation()
					handle_input_position(position)
				end
			end
		end
	end)
end