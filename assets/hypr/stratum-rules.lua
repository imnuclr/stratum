-- Stratum window rules, for Hyprland's Lua config mode.
--
-- Loaded from your config with:
--     dofile(os.getenv("HOME") .. "/.config/hypr/stratum-rules.lua")

-- The image viewer opens as a window of its own, not tiled to fill the screen.
hl.window_rule({
    match  = { class = "com.interversehq.qView" },
    float  = true,
    size   = "(monitor_w*0.6) (monitor_h*0.7)",
    center = true,
})
