# Rohook - Discord Webhook Library for Lua (Version 2)

Rohook is the second version of a lightweight Lua library designed for seamless Discord webhook integration, originally developed by Ahmed Sayed (Discord: ahmedsayed0 / Roblox: ModyNegm00). It builds upon the foundation of version 1, introducing advanced features such as message editing, deletion, scheduling, template management, priority queuing, rate limiting, and an EmbedBuilder for creating rich embeds.

## Features

- **Simple API**: Interact with Discord webhooks effortlessly.
- **Embed Support**: Send rich embeds with custom fields and colors using the EmbedBuilder.
- **Message Management**: Edit or delete previously sent messages.
- **Scheduling**: Schedule messages to be sent at a later time or repeatedly.
- **Templates**: Save and reuse message templates with variable substitution.
- **Priority Queuing**: Prioritize important messages for faster delivery.
- **Rate Limiting**: Automatically handle rate limits with retries.
- **Lightweight**: Minimal dependencies, optimized for Lua environments.
- **Asynchronous Support**: Compatible with coroutine-based workflows.
- **Customizable Requests**: Tailor headers and payloads to suit your needs.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/modynem/Rohook.git
   ```
2. Include the library in your Lua project:
   ```lua
   local Rohook = require 'path.to.Rohook'
   ```

**Roblox Marketplace Source**:  
Get Rohook directly from the Roblox Marketplace!  
[![Get Rohook on Roblox Marketplace](https://img.shields.io/badge/Roblox%20Marketplace-Get%20Rohook-brightgreen)](https://create.roblox.com/store/asset/91889747323310/Rohook)  
*(Note: Replace the URL with the actual Roblox Marketplace link when available.)*

## Usage

### Sending a Simple Message

Create a webhook instance and send a basic message. Optional settings like rate limit warnings and batch processing can be enabled during initialization.

```lua
local Rohook = require(path.to.Rohook)
local webhook = Rohook.new(
    "https://discord.com/api/webhooks/123/token",
    {rateLimitWarning = true, batchProcessing = true}
)
webhook:SendMessage("Hello, Roblox!")
```

### Sending an Embed

Use the `EmbedBuilder` to construct a rich embed and send it with custom options, such as overriding the username and avatar.

```lua
local embed = Rohook.CreateEmbedBuilder()
    :SetTitle("Test")
    :SetDescription("hello everybody!")
    :SetColor(0x7289DA) -- Hex equivalent of Color3.fromRGB(114, 137, 218)
    :SetTimestamp() -- Sets current UTC time
    :AddField("Credit", "@ahmedsayed0", true)
    :Build()

webhook:SendMessage({
    username = "Ahmed Sayed",
    avatar_url = "https://i.postimg.cc/5Nkf0Zng/7-C51-A09-F-212-B-4751-BC5-C-943-C26-AFEC48.jpg",
    embeds = {embed}
}, function(response)
    if not response.Success then
        warn("Failed to send embed:", response.Message)
    end
end)
```

## Additional Features

Rohook version 2 introduces several advanced capabilities:

- **Message Editing and Deletion**: Modify or remove sent messages.
- **Scheduling**: Send messages at specified times or intervals.
- **Templates**: Store and reuse message structures with placeholders.
- **Priority Queuing**: Ensure critical messages are sent first.
- **Rate Limiting Handling**: Automatically retry requests when rate limits are encountered.
- **Statistics and Health Checks**: Track message stats and verify webhook health.

For detailed usage instructions on these features, refer to the library's source code or additional documentation within the repository.

## Version History

| Version | Release Date | Changes |
|---------|--------------|---------|
| 1.0     | [Initial Release Date] | Initial release with basic webhook support, simple messages, and embed functionality. |
| 2.0     | March 16, 2025 | Renamed to "Rohook". Added message editing/deletion, scheduling, templates, priority queuing, rate limiting, and improved EmbedBuilder. Updated API for instance-based usage. |

*(Update the initial release date for v1.0 as needed.)*

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests to enhance the library.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
