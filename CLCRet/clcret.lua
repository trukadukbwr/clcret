-- Default layout
local defaults = {
    -- Other existing default properties
    procFlipbook = false,
    -- Continuing with remaining defaults
}

function CreateButton(...)
    -- Existing button creation logic
    local procFlipbookTexture = button:CreateTexture(nil, "OVERLAY")
    -- Additional setup for procFlipbookTexture
end

function UpdateButtonLayout(button)
    -- Existing layout update logic
    if button.layout.procFlipbook then
        procFlipbookTexture:Show()
    else
        procFlipbookTexture:Hide()
    end
end