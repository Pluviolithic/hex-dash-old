game:GetService("Chat"):RegisterChatCallback(
	Enum.ChatCallbackType.OnCreatingChatWindow,
	function()
		return {BubbleChatEnabled = true}
	end
)

local replicated_first = game:GetService("ReplicatedFirst")
local players = game:GetService("Players")
local tween_service = game:GetService("TweenService")
local content_provider = game:GetService("ContentProvider")

local player = players.LocalPlayer
local loading_screen = replicated_first:WaitForChild("Loading")
local loading_text = loading_screen.Loading_Text
local tween_info = TweenInfo.new(0.5)

loading_screen.Parent = player:WaitForChild("PlayerGui")
replicated_first:RemoveDefaultLoadingScreen()

wait(7)

repeat
	wait(0.5)
until content_provider.RequestQueueSize < 10

local tween_a = tween_service:Create(
	loading_text,
	tween_info,
	{
		BackgroundTransparency = 1
	}
)

local tween_b = tween_service:Create(
	loading_text,
	tween_info,
	{
		TextTransparency = 1
	}
)

tween_a:Play()
tween_b:Play()

tween_b.Completed:Wait()
loading_screen:Destroy()
script:Destroy()