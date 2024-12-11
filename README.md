# Lua Discord Webhook Library

A lightweight Lua library for easy Discord webhook integration, supporting messages, embeds, and customizable requests.

## Features

- **Simple API**: Easily interact with Discord webhooks.
- **Embed Support**: Send rich embeds with custom fields and colors.
- **Lightweight**: Minimal dependencies, optimized for Lua environments.
- **Asynchronous Support**: Works seamlessly with coroutine-based workflows.
- **Customizable Requests**: Tailor headers and payloads to fit your needs.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/lua-discord-webhook.git
   ```
2. Include the library in your Lua project:
   ```lua
   require 'lua-discord-webhook'
   ```

## Usage

### Sending a Simple Message
```lua
local Webhook = require(game:GetService("ReplicatedStorage").Webhook)
local webhookUrl = "DISCORD_WEBHOOK_URL"

Webhook:SendMessage(webhookUrl, "hi there it's me ahmed!")
```

### Sending an Embed
```lua
local embed = Webhook.CreateEmbedBuilder()
		:SetTitle("Test")
		:SetDescription("hello everybody!")
		:SetColor(Color3.fromRGB(114, 137, 218))
		:SetTimestamp(DateTime.now())
		:AddField("Credit", "@ahmedsayed0", true)
		:Build()

	Webhook:SendMessage(webhookUrl, {
		username = "Ahmed Sayed",
		avatar_url = "https://i.postimg.cc/5Nkf0Zng/7-C51-A09-F-212-B-4751-BC5-C-943-C26-AFEC48.jpg",
		embeds = {embed}
	}, function(response)
		if not response.Success then
			warn("Failed to send monitoring update:", response.Message)
		end
	end)
```

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests to improve the library.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
