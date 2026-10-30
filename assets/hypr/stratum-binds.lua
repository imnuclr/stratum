-- Stratum keybinds, for Hyprland's Lua config mode.
--
-- Add this to the end of your user config (hypr-user.lua, or whichever file your
-- setup loads last):
--     dofile(os.getenv("HOME") .. "/.config/hypr/stratum-binds.lua")
--
-- Loading it last matters. Hyprland keeps *both* bindings when a key is bound
-- twice and fires both, so anything bound earlier has to be dropped first rather
-- than simply overridden. hl.unbind only matches unmodified keys, so a combo
-- already taken by another config cannot be reclaimed this way — pick a free one.

local locked = { locked = true }
local repeating = { locked = true, repeating = true }

if type(hl.unbind) == "function" then
    for _, key in ipairs({
        "XF86AudioPlay", "XF86AudioPause", "XF86AudioNext", "XF86AudioPrev",
        "XF86AudioRaiseVolume", "XF86AudioLowerVolume", "XF86AudioMute",
        "XF86AudioMicMute", "XF86MonBrightnessUp", "XF86MonBrightnessDown",
        "Print",
    }) do
        pcall(hl.unbind, key)
    end
end

hl.bind("XF86AudioPlay", hl.dsp.global("stratum:mediaToggle"), locked)
hl.bind("XF86AudioPause", hl.dsp.global("stratum:mediaToggle"), locked)
hl.bind("XF86AudioNext", hl.dsp.global("stratum:mediaNext"), locked)
hl.bind("XF86AudioPrev", hl.dsp.global("stratum:mediaPrev"), locked)

hl.bind("XF86AudioRaiseVolume", hl.dsp.global("stratum:volumeUp"), repeating)
hl.bind("XF86AudioLowerVolume", hl.dsp.global("stratum:volumeDown"), repeating)
hl.bind("XF86AudioMute", hl.dsp.global("stratum:volumeMute"), locked)
hl.bind("XF86AudioMicMute", hl.dsp.global("stratum:micMute"), locked)

hl.bind("XF86MonBrightnessUp", hl.dsp.global("stratum:brightnessUp"), repeating)
hl.bind("XF86MonBrightnessDown", hl.dsp.global("stratum:brightnessDown"), repeating)

-- Shift + Print emits SysRq rather than Print, so the third one uses Ctrl.
hl.bind("Print", hl.dsp.global("stratum:screenshotRegion"), locked)
hl.bind("SUPER + Print", hl.dsp.global("stratum:screenshot"), locked)
hl.bind("CTRL + Print", hl.dsp.global("stratum:screenshotEdit"), locked)

-- Lock the session. Not "locked": it should not fire while already locked.
hl.bind("SUPER + L", hl.dsp.global("stratum:lock"))
