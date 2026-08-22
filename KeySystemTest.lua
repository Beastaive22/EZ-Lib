-- EZ key system test
-- gate flow before the real UI loads

local EZ = loadstring(game:HttpGet("https://raw.githubusercontent.com/Beastaive22/EZ-Hub/refs/heads/main/Library.lua"))()

local ok = EZ:KeySystem({
    Title = "EZ",
    SubTitle = "premium access required",
    Keys = { "EZ-2026", "let-me-in", "test-key" },
    SaveKey = "EZKeyTest.txt",
    MaxAttempts = 5,
    GetKeyLink = "https://discord.gg/EZ",
    GetKeyText = "Get Key from Discord",
    Callback = function(success)
        if success then print("[EZ] key passed, loading UI...") end
    end,
    OnLockout = function()
        warn("[EZ] too many wrong tries, locked out")
    end,
})

if not ok then return end

local Window = EZ:CreateWindow({
    Title = "EZ",
    SubTitle = "key system passed",
    ToggleKey = Enum.KeyCode.RightShift,
})

local tab = Window:AddTab("Main", "key")
local sec = tab:AddSection("Status")

sec:AddLabel({ Text = "key system worked" })

sec:AddButton({
    Text = "Forget key (re-prompt next run)",
    Callback = function()
        pcall(function() delfile("EZKeyTest.txt") end)
        EZ:Notify({
            Title = "EZ",
            Content = "saved key cleared",
            Type = "info",
            Duration = 3,
        })
    end
})

sec:AddButton({
    Text = "Reload script",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Beastaive22/EZ-Hub/refs/heads/main/KeySystemTest.lua"))()
    end
})

EZ:Notify({
    Title = "EZ",
    Content = "welcome back",
    Type = "success",
    Duration = 4,
})
