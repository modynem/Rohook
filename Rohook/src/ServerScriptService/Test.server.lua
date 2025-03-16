local Rohook = require(game.ReplicatedStorage.Rohook)
local webhook = Rohook.new(
	"https://discord.com/api/webhooks/1350763069768466505/GAUeuBR97Il3P9AwLcyaejR_MhkYlTLsjmV5Nqn7HoLUa3qRNKCm21OXFbAQyluCn4X3",
	{rateLimitWarning = true, batchProcessing = true}
)

webhook:saveTemplate("welcome", {
	content = "Welcome, {username}!",
	embeds = {
		{title = "Hello {username}", description = "Joined on {date}"}
	}
})

task.wait(2)

webhook:useTemplate("welcome", {
	username = "Ahmed",
	date = os.date("%Y-%m-%d")
}, function(response)
	print("Sent:", response.Success, response.MessageId)
end)