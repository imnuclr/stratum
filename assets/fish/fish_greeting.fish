# Stratum's terminal greeting: the dot-matrix STRATUM mark from fastfetch, and
# nothing else. Its colours come from the shell (Settings → Appearance → Apps).
function fish_greeting
    command -q fastfetch; and fastfetch
end
