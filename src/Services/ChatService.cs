using Azure;
using Azure.AI.Inference;
using Newtonsoft.Json;
using ZavaStorefront.Models;

namespace ZavaStorefront.Services;

public class ChatService
{
    private readonly ChatCompletionsClient _client;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<ChatService> _logger;
    private const string SessionKey = "ChatHistory";
    private const string SystemPrompt = "You are a helpful shopping assistant for the Zava Storefront. You help customers with product questions, recommendations, and general inquiries. Keep responses concise and friendly.";

    public ChatService(
        ChatCompletionsClient client,
        IHttpContextAccessor httpContextAccessor,
        ILogger<ChatService> logger)
    {
        _client = client;
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;
    }

    public List<ChatMessage> GetChatHistory()
    {
        var session = _httpContextAccessor.HttpContext?.Session;
        var json = session?.GetString(SessionKey);
        if (string.IsNullOrEmpty(json))
        {
            return new List<ChatMessage>();
        }
        return JsonConvert.DeserializeObject<List<ChatMessage>>(json) ?? new List<ChatMessage>();
    }

    public async Task<ChatMessage> SendMessageAsync(string userMessage)
    {
        var history = GetChatHistory();

        // Add user message to history
        var userChatMessage = new ChatMessage
        {
            Role = "user",
            Content = userMessage,
            Timestamp = DateTime.UtcNow
        };
        history.Add(userChatMessage);

        // Build the messages list for the API call
        var requestMessages = new List<ChatRequestMessage>
        {
            new ChatRequestSystemMessage(SystemPrompt)
        };

        foreach (var msg in history)
        {
            if (msg.Role == "user")
            {
                requestMessages.Add(new ChatRequestUserMessage(msg.Content));
            }
            else if (msg.Role == "assistant")
            {
                requestMessages.Add(new ChatRequestAssistantMessage(msg.Content));
            }
        }

        try
        {
            _logger.LogInformation("Sending chat request to Phi-4 endpoint with {MessageCount} messages", requestMessages.Count);

            var requestOptions = new ChatCompletionsOptions(requestMessages);
            var response = await _client.CompleteAsync(requestOptions);

            var assistantContent = response.Value.Content;

            var assistantMessage = new ChatMessage
            {
                Role = "assistant",
                Content = assistantContent,
                Timestamp = DateTime.UtcNow
            };
            history.Add(assistantMessage);

            SaveChatHistory(history);

            _logger.LogInformation("Received response from Phi-4 endpoint");
            return assistantMessage;
        }
        catch (RequestFailedException ex)
        {
            _logger.LogError(ex, "Azure AI Inference request failed with status {Status}", ex.Status);

            var errorMessage = new ChatMessage
            {
                Role = "assistant",
                Content = "Sorry, I'm having trouble connecting right now. Please try again later.",
                Timestamp = DateTime.UtcNow
            };
            history.Add(errorMessage);
            SaveChatHistory(history);
            return errorMessage;
        }
    }

    public void ClearHistory()
    {
        var session = _httpContextAccessor.HttpContext?.Session;
        session?.Remove(SessionKey);
        _logger.LogInformation("Chat history cleared");
    }

    private void SaveChatHistory(List<ChatMessage> history)
    {
        var session = _httpContextAccessor.HttpContext?.Session;
        var json = JsonConvert.SerializeObject(history);
        session?.SetString(SessionKey, json);
    }
}
