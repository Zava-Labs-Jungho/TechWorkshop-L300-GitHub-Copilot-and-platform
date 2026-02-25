using Microsoft.AspNetCore.Mvc;
using ZavaStorefront.Services;

namespace ZavaStorefront.Controllers;

public class ChatController : Controller
{
    private readonly ILogger<ChatController> _logger;
    private readonly ChatService _chatService;

    public ChatController(ILogger<ChatController> logger, ChatService chatService)
    {
        _logger = logger;
        _chatService = chatService;
    }

    public IActionResult Index()
    {
        _logger.LogInformation("Loading chat page");
        var history = _chatService.GetChatHistory();
        return View(history);
    }

    [HttpPost]
    public async Task<IActionResult> SendMessage([FromBody] SendMessageRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.Message))
        {
            return BadRequest(new { error = "Message cannot be empty." });
        }

        _logger.LogInformation("User sent chat message: {MessageLength} chars", request.Message.Length);

        var response = await _chatService.SendMessageAsync(request.Message);

        return Json(new
        {
            role = response.Role,
            content = response.Content,
            timestamp = response.Timestamp
        });
    }

    [HttpPost]
    public IActionResult ClearHistory()
    {
        _chatService.ClearHistory();
        return RedirectToAction("Index");
    }
}

public class SendMessageRequest
{
    public string Message { get; set; } = string.Empty;
}
