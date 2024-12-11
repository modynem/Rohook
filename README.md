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
local webhook = require('lua-discord-webhook')

local url = "https://discord.com/api/webhooks/your_webhook_url"
webhook.sendMessage(url, "Hello, Discord!")
```

### Sending an Embed
```lua
local embed = {
    title = "Lua Discord Webhook",
    description = "An awesome Lua library for Discord webhooks!",
    color = 0x7289DA  -- Discord's blurple color
}

webhook.sendEmbed(url, embed)
```

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests to improve the library.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
