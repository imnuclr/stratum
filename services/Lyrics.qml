pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

/*
 * The words of whatever is playing, timed to it.
 *
 * Word by word where the source knows them that finely, which is the whole
 * point: a line that lights up all at once tells you which line, and a line that
 * lights up a word at a time tells you where in it you are. Spicy Lyrics is the
 * one public source that carries word timings — its community syncs are made by
 * hand for exactly this — so it is asked first, and LRCLIB answers when it
 * cannot.
 *
 * A source that only timed the *line* gets no words at all, and the line lights
 * up whole. Spreading its words across the line's span was tried first — by
 * letter, then by syllable — and both are wrong in the same way: the sweep is a
 * claim about where in the line the voice is, and a guess dressed as that claim
 * reads as the lyrics being out of time rather than as an estimate. A line
 * lighting up whole claims only what the source actually knows. `exact` says
 * which of the two you are looking at.
 *
 * Spicy Lyrics wants a key, which is free but has to be asked for, and is a
 * secret: it belongs in a file of its own (~/.config/stratum/spicylyrics.key)
 * rather than in shell.json, which is the file people paste into issues and
 * commit to dotfile repos. The config key is read too, for anyone who would
 * rather keep everything in one place.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.get("lyrics.enabled", true)

    /*
     * Shifts every time by this many milliseconds. MPRIS position is a reading
     * taken over a bus, and the player has usually moved on a little by the time
     * it arrives; the right value is whatever makes the words land with the
     * voice on this machine.
     */
    readonly property int offsetMs: Config.get("lyrics.offsetMs", 0)

    readonly property string keyPath: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/stratum/spicylyrics.key`

    property string fileKey: ""
    readonly property string key: root.fileKey.length > 0 ? root.fileKey : Config.get("lyrics.key", "")
    readonly property bool haveKey: root.key.length > 0

    FileView {
        id: keyFile

        path: root.keyPath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.fileKey = text().trim()
        // No file is the ordinary case, not a fault: LRCLIB needs no key.
        onLoadFailed: root.fileKey = ""
    }

    function saveKey(value) {
        root.fileKey = (value ?? "").trim();
        keyFile.setText(root.fileKey + "\n");
    }

    /*
     * Which track the shell is looking at.
     *
     * Spotify puts its own id in the MPRIS track id and again in the track URL,
     * and the Spicy Lyrics API takes exactly that, so a Spotify stream needs no
     * matching by title at all. Anything else is looked up by what it says it
     * is.
     */
    readonly property var meta: Media.active?.metadata ?? ({})

    function spotifyIdIn(text) {
        const hit = /(?:spotify[:/]track[:/]|\/com\/spotify\/track\/)([A-Za-z0-9]{22})/.exec(text ?? "");
        return hit ? hit[1] : "";
    }

    readonly property string trackId: {
        void root.meta;
        return root.spotifyIdIn(root.meta["mpris:trackid"] ?? "")
            || root.spotifyIdIn(root.meta["xesam:url"] ?? "");
    }

    // What identifies this track to the cache, and to LRCLIB when there is no id.
    readonly property string trackKey: root.trackId.length > 0
        ? `spotify:${root.trackId}`
        : (Media.title.length > 0 ? `${Media.artist}\u0000${Media.title}\u0000${Math.round(Media.length)}` : "")

    /*
     * "", "loading", "ready", "none" or "error". `none` is a track that was
     * looked up and has no lyrics anywhere — a different thing from one that has
     * not been looked up, and the only one of the two worth saying out loud.
     */
    property string status: ""
    property string error: ""
    // "spicy_lyrics", "apple_music", "spotify", "lrclib" — whoever answered.
    property string provider: ""
    // "word" when the source timed every word, "line" when the words below are
    // this service's own guess at where they fall.
    property string granularity: ""
    readonly property bool exact: root.granularity === "word"
    readonly property bool any: root.lines.length > 0

    /*
     * The lyrics themselves.
     *
     * [{ start, end, text, words: [{ text, start, end, joinNext }], opposite }]
     *
     * Times are seconds from the start of the track, matching MPRIS. `joinNext`
     * marks a syllable that runs into the one after it with no space, so the
     * renderer knows not to put a gap there — a syllable sync splits "even" into
     * "e" and "ven", and they have to be drawn as one word.
     *
     * `words` is empty when the source only timed the line. That is the signal
     * to light the line whole rather than sweep it: there is nothing to sweep
     * with.
     */
    property var lines: []

    // What has been fetched this session, by trackKey. A miss is cached too: a
    // track with no lyrics must not be asked for again every time it is paused.
    property var cache: ({})
    readonly property int cacheMax: 60

    function remember(trackKey, entry) {
        const next = Object.assign({}, root.cache);
        const keys = Object.keys(next);
        if (keys.length >= root.cacheMax)
            delete next[keys[0]];
        next[trackKey] = entry;
        root.cache = next;
    }

    function adopt(entry) {
        root.lines = entry.lines ?? [];
        root.provider = entry.provider ?? "";
        root.granularity = entry.granularity ?? "";
        root.status = root.lines.length > 0 ? "ready" : "none";
        root.error = entry.error ?? "";
    }

    function clear() {
        root.lines = [];
        root.provider = "";
        root.granularity = "";
        root.status = "";
        root.error = "";
    }

    /* ---------------------------------------------------------------- clock */

    /*
     * Where in the track we are, to the frame.
     *
     * MPRIS answers with a number that was true a moment ago — it has crossed a
     * bus to get here — so the reading is an anchor and the time between
     * readings is counted locally off the system clock.
     *
     * The rule for what to do with a new reading is the part that matters. The
     * obvious one, averaging each reading into the anchor, holds the clock
     * permanently *behind* by about the round trip: every reading is stale by
     * however long it took to arrive, so averaging them converges on the mean
     * staleness rather than on the truth. Measured against Spotify's own
     * position that was a steady 110ms late, which is a syllable.
     *
     * A reading is a *lower bound*: the track was at least there when it was
     * taken, and is further on now. So a reading ahead of the local clock is
     * news and is taken immediately, while one behind it is simply an older
     * sample and is ignored. The clock then converges on the quickest reading
     * rather than the average one, which is as close to the truth as this side
     * of the bus can get. Only a reading a long way behind is believed, because
     * that is a seek or a stall rather than latency.
     */
    property real anchorAt: 0
    property real anchorPos: 0
    property real position: 0
    // The last value MPRIS gave, so the same number arriving twice can be told
    // apart from a fresh one. Quickshell emits positionChanged both when a
    // re-read is asked for and when the answer lands, and the first of those
    // carries the old value.
    property real lastReading: -1

    readonly property bool running: Media.playing && root.watchers > 0

    function anchor(seconds) {
        root.anchorPos = seconds;
        root.anchorAt = Date.now();
        root.position = seconds;
    }

    function resync(hard) {
        const reading = Media.position;
        if (!(reading >= 0))
            return;

        if (hard || !root.running) {
            root.lastReading = reading;
            root.anchor(reading);
            return;
        }

        // The same number again: the signal fired before the value was fetched.
        if (Math.abs(reading - root.lastReading) < 0.001)
            return;
        root.lastReading = reading;

        const drift = reading - root.position;
        // Ahead of us, or a long way behind (a seek): believe it.
        if (drift > 0.015 || drift < -1.2)
            root.anchor(reading);
        // Otherwise it is an older sample than the clock we already have.
    }

    /*
     * Asked for more often than the rest of the shell needs, and only while the
     * words are on screen. More samples is more chances at a quick one, and with
     * the rule above a quick one is what sets the clock.
     */
    Timer {
        running: root.running
        repeat: true
        interval: 400
        onTriggered: Media.active?.positionChanged()
    }

    // What the lyrics are timed against: the clock, shifted by the offset.
    readonly property real at: root.position + root.offsetMs / 1000

    Timer {
        running: root.watchers > 0
        repeat: true
        interval: 33
        onTriggered: {
            if (!Media.playing) {
                root.position = root.anchorPos;
                return;
            }
            root.position = root.anchorPos + (Date.now() - root.anchorAt) / 1000;
        }
    }

    Connections {
        target: Media

        function onPositionChanged() {
            root.resync(false);
        }

        function onPlayingChanged() {
            root.resync(true);
        }
    }

    /*
     * Nothing is fetched, and no clock runs, unless something is showing the
     * words. The widget and the full view each take one of these.
     */
    property int watchers: 0

    function watch() {
        root.watchers++;
        if (root.watchers === 1) {
            Media.watch();
            root.resync(true);
            root.refresh(false);
        }
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
        if (root.watchers === 0)
            Media.unwatch();
    }

    /* --------------------------------------------------------------- lookup */

    /*
     * Every line sounding right now, not just one.
     *
     * Songs overlap their lines constantly: a backing vocal runs under the lead,
     * one singer comes in over the last word of the other, a chorus answers a
     * call. The lookup used to walk the list and return the *first* line whose
     * span held the clock, which meant the second of any overlapping pair was
     * never current — it would wait for the first to end, by which time it had
     * often ended too, so it never appeared at all. Whole lines of a duet were
     * simply missing.
     *
     * A set, then, and every member of it lights. Walking the whole list rather
     * than stopping at the first miss, because lines that overlap are not in a
     * single order: one can start before the one listed ahead of it has
     * finished, and a backing vocal starts inside its lead.
     */
    property var active: []
    // The one the view follows: the lead that started earliest among those
    // sounding. A backing vocal never takes it — it belongs to the line it sits
    // under, and scrolling to it would pull the lead off the anchor.
    property int lineIndex: -1

    function activeAt(seconds) {
        const lines = root.lines;
        const out = [];
        for (let i = 0; i < lines.length; i++) {
            if (seconds >= lines[i].start && seconds < lines[i].end)
                out.push(i);
        }
        return out;
    }

    function isActive(index) {
        return root.active.indexOf(index) >= 0;
    }

    function leadOf(indices) {
        for (const i of indices) {
            if (!root.lines[i]?.background)
                return i;
        }
        return indices.length > 0 ? indices[0] : -1;
    }

    /*
     * The line to show, which is not quite the line being sung: in the gap
     * between two lines the one just finished stays up until the next is close
     * enough to take over. A panel that empties between every line flickers.
     */
    property int shownIndex: -1

    onAtChanged: {
        if (root.lines.length === 0) {
            if (root.active.length > 0)
                root.active = [];
            if (root.lineIndex !== -1)
                root.lineIndex = -1;
            if (root.shownIndex !== -1)
                root.shownIndex = -1;
            return;
        }
        const now = root.at;
        const sounding = root.activeAt(now);
        // Only republished when it actually changes: this runs thirty times a
        // second and every write wakes everything bound to it.
        if (sounding.length !== root.active.length
            || sounding.some((v, i) => v !== root.active[i]))
            root.active = sounding;

        const found = root.leadOf(sounding);
        if (found !== root.lineIndex)
            root.lineIndex = found;

        if (found >= 0) {
            if (root.shownIndex !== found)
                root.shownIndex = found;
            return;
        }
        // In a gap: hold the line just finished until the next one starts.
        let next = -1;
        for (let i = 0; i < root.lines.length; i++) {
            if (root.lines[i].start > now) {
                next = i;
                break;
            }
        }
        const held = next < 0 ? root.lines.length - 1 : next - 1;
        if (root.shownIndex !== held)
            root.shownIndex = held;
    }

    readonly property var current: root.shownIndex >= 0 && root.shownIndex < root.lines.length
        ? root.lines[root.shownIndex] : null

    /*
     * A second line sounding alongside the one being followed — the other half
     * of a duet, or a backing vocal — or -1. Somewhere that can only show two
     * lines shows this one in the second place instead of what is coming next,
     * because a line being sung now matters more than one that is not.
     */
    readonly property int partnerIndex: {
        for (const i of root.active) {
            if (i !== root.shownIndex)
                return i;
        }
        return -1;
    }
    readonly property var partner: root.partnerIndex >= 0 ? root.lines[root.partnerIndex] : null

    readonly property var next: root.shownIndex + 1 < root.lines.length
        ? root.lines[root.shownIndex + 1] : null
    // True while nothing at all is sounding: what a lyrics view draws as an
    // interlude rather than as a held line.
    readonly property bool resting: root.active.length === 0

    // How long until the next line starts, for the countdown an interlude shows.
    readonly property real restingFor: {
        if (!root.resting)
            return 0;
        for (const line of root.lines) {
            if (line.start > root.at)
                return line.start - root.at;
        }
        return 0;
    }

    /* -------------------------------------------------------------- parsing */

    /*
     * Words evenly through a span, for the placeholder below and nothing else.
     *
     * This used to stand in for word timings a source had not given, spreading a
     * line's words across it by length and then by syllable count. Both guesses
     * were close enough to look deliberate and wrong often enough to read as the
     * lyrics being out of time — which is worse than not sweeping at all,
     * because a sweep is a statement about where the voice is and this had no
     * way of knowing. A line-timed source now lights its lines whole.
     *
     * The placeholder keeps it because there the words *are* the timing: it is
     * four made-up lines with made-up words in them, and there is no truth for
     * the spacing to be wrong about.
     */
    function spreadWords(text, start, end) {
        const parts = (text ?? "").split(/(\s+)/).filter(p => p.trim().length > 0);
        if (parts.length === 0)
            return [];
        const span = Math.max(0.2, end - start);
        let total = 0;
        for (const p of parts)
            total += Math.max(2, p.length);
        let t = start;
        const words = [];
        for (const p of parts) {
            const share = span * Math.max(2, p.length) / total;
            words.push({ text: p, start: t, end: t + share, joinNext: false });
            t += share;
        }
        return words;
    }

    /*
     * One timed part — a lead or a backing vocal — as a line.
     *
     * `IsPartOfWord` describes the gap *after* a syllable, not before it: it is
     * set on the piece that runs into the next one. "e"(true) + "ven"(false) is
     * "even"; "Sto"(true) + "len"(false) is "Stolen". Reading it as "continues
     * the piece before me" shifts every space in the line one syllable along,
     * which is how "been haunting me inside" came out as "beenhaun ting mein
     * side" — every gap in the wrong place.
     */
    function fromSyllables(part, opposite, background) {
        if (!part || !Array.isArray(part.Syllables))
            return null;
        const words = [];
        for (const s of part.Syllables) {
            const piece = s?.Text ?? "";
            if (piece.trim().length === 0)
                continue;
            words.push({
                text: piece,
                start: s.StartTime,
                end: s.EndTime,
                joinNext: s?.IsPartOfWord === true
            });
        }
        if (words.length === 0)
            return null;
        let text = "";
        for (let i = 0; i < words.length; i++)
            text += words[i].text + (i < words.length - 1 && !words[i].joinNext ? " " : "");
        return {
            start: part.StartTime,
            end: part.EndTime,
            text: text.trim(),
            words: words,
            opposite: opposite === true,
            background: background === true
        };
    }

    function parseSpicy(body) {
        const kind = body?.Type ?? "";
        const content = body?.Content ?? [];
        const lines = [];

        if (kind === "Syllable") {
            for (const item of content) {
                const lead = root.fromSyllables(item?.Lead, item?.OppositeAligned === true, false);
                if (!lead)
                    continue;
                lines.push(lead);
                /*
                 * Backing vocals, which the shell had been throwing away.
                 *
                 * They are a second voice over the top of the lead and they have
                 * their own timings, so they are kept as lines of their own,
                 * sitting after the line they answer. Nothing special is needed
                 * to sound them at the same time as it: they overlap it, and
                 * overlapping lines all light together.
                 */
                for (const bg of item?.Background ?? []) {
                    const voice = root.fromSyllables(bg, item?.OppositeAligned === true, true);
                    if (voice)
                        lines.push(voice);
                }
            }
            return lines.length > 0 ? { lines: lines, granularity: "word" } : null;
        }

        if (kind === "Line") {
            for (const item of content) {
                const text = item?.Text ?? "";
                if (text.trim().length === 0)
                    continue;
                lines.push({
                    start: item.StartTime,
                    end: item.EndTime,
                    text: text,
                    // The source timed the line and not its words: no sweep.
                    words: [],
                    opposite: item?.OppositeAligned === true
                });
            }
            return lines.length > 0 ? { lines: lines, granularity: "line" } : null;
        }

        // Static: words with no timing at all. Kept, because being able to read
        // the words of a song the clock knows nothing about is still worth
        // something, but marked so nothing tries to sweep them.
        const statics = [];
        for (const item of content) {
            const text = item?.Text ?? "";
            if (text.trim().length === 0)
                continue;
            statics.push({ start: -1, end: -1, text: text, words: [], opposite: false });
        }
        return statics.length > 0 ? { lines: statics, granularity: "static" } : null;
    }

    // LRC: lines of "[mm:ss.xx] words", sometimes several stamps for one line.
    function parseLrc(text) {
        const out = [];
        for (const raw of (text ?? "").split("\n")) {
            const words = raw.replace(/^(\[\d+:\d+(?:[.:]\d+)?\])+/, "").trim();
            const stamps = raw.match(/\[(\d+):(\d+)(?:[.:](\d+))?\]/g) ?? [];
            for (const stamp of stamps) {
                const hit = /\[(\d+):(\d+)(?:[.:](\d+))?\]/.exec(stamp);
                if (!hit)
                    continue;
                const fraction = hit[3] ? Number(`0.${hit[3]}`) : 0;
                out.push({ at: Number(hit[1]) * 60 + Number(hit[2]) + fraction, text: words });
            }
        }
        out.sort((a, b) => a.at - b.at);

        const lines = [];
        for (let i = 0; i < out.length; i++) {
            // A stamp with no words is where the singing stops, so it ends the
            // line before it and is not a line of its own.
            if (out[i].text.length === 0)
                continue;
            const start = out[i].at;
            const end = i + 1 < out.length
                ? out[i + 1].at
                : (Media.length > 0 ? Math.max(start + 2, Media.length) : start + 4);
            lines.push({
                start: start,
                end: end,
                text: out[i].text,
                // LRC is a list of line starts. Nothing here knows where in a
                // line the voice is, so nothing pretends to.
                words: [],
                opposite: false
            });
        }
        return lines;
    }

    /* -------------------------------------------------------------- fetching */

    /*
     * Which request the answers coming back belong to. A track changed while a
     * fetch was in flight used to show the previous track's words, because
     * nothing checked that the answer was still wanted.
     */
    property int generation: 0
    property string wantKey: ""

    onTrackKeyChanged: {
        root.lastReading = -1;
        root.resync(true);
        root.refresh(false);
    }
    onEnabledChanged: root.refresh(false)
    onHaveKeyChanged: {
        // A key arriving is worth asking again with: the track showing is
        // probably one LRCLIB answered, and Spicy may know it word by word.
        if (root.haveKey && root.granularity === "line")
            root.refresh(true);
    }

    function refresh(force) {
        if (!root.enabled || root.trackKey.length === 0) {
            root.wantKey = "";
            root.clear();
            return;
        }
        // A different track: what is held belongs to the last one and must go
        // whether or not anything is watching, or the words of the song before
        // are still on screen when a view is next opened.
        if (root.wantKey !== root.trackKey) {
            root.clear();
            if (root.watchers === 0) {
                // Asked for as soon as something wants to read them.
                root.wantKey = "";
                return;
            }
        } else if (root.watchers === 0 || !force) {
            return;
        }

        root.wantKey = root.trackKey;
        root.generation++;

        const known = root.cache[root.trackKey];
        if (known && !force) {
            root.adopt(known);
            return;
        }

        root.lines = [];
        root.provider = "";
        root.granularity = "";
        root.error = "";
        root.status = "loading";

        if (root.haveKey && root.trackId.length > 0)
            root.askSpicy(root.generation, root.trackId);
        else
            root.askLrclib(root.generation);
    }

    function finish(generation, trackKey, entry) {
        if (generation !== root.generation)
            return;
        root.remember(trackKey, entry);
        root.adopt(entry);
    }

    function askSpicy(generation, id) {
        spicy.wanted = generation;
        spicy.trackKey = root.trackKey;
        /*
         * The key goes in a header file read by curl rather than on the command
         * line, where it would be visible to every process on the machine in
         * /proc. Written through a here-doc on stdin so it never touches disk
         * either.
         */
        spicy.command = ["sh", "-c",
            'printf "Authorization: Bearer %s\\n" "$1" > "$2"; '
            + 'curl -sS --max-time 12 -H @"$2" -w "\\n%{http_code}" "https://api.spicylyrics.org/v1/lyrics/$3"; '
            + 'rc=$?; rm -f "$2"; exit $rc',
            "sh", root.key, `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/stratum-lyrics-auth`, id];
        spicy.running = true;
    }

    function askLrclib(generation) {
        if (Media.title.length === 0) {
            root.finish(generation, root.wantKey, { lines: [], provider: "", granularity: "" });
            return;
        }
        lrclib.wanted = generation;
        lrclib.trackKey = root.trackKey;
        lrclib.command = ["sh", "-c",
            'curl -sS --max-time 12 -G "https://lrclib.net/api/get" '
            + '--data-urlencode "artist_name=$1" --data-urlencode "track_name=$2" '
            + '--data-urlencode "album_name=$3" --data-urlencode "duration=$4" '
            + '-H "User-Agent: stratum-shell (https://github.com/imnuclr/stratum)" '
            + '-w "\\n%{http_code}"',
            "sh", Media.artist, Media.title, Media.album, String(Math.round(Media.length))];
        lrclib.running = true;
    }

    // The body and the status code, which curl was asked to append on its own
    // line so one read gives both.
    function split(text) {
        const trimmed = (text ?? "").replace(/\s+$/, "");
        const cut = trimmed.lastIndexOf("\n");
        if (cut < 0)
            return { body: "", code: Number(trimmed) || 0 };
        return { body: trimmed.slice(0, cut), code: Number(trimmed.slice(cut + 1)) || 0 };
    }

    Process {
        id: spicy

        property int wanted: 0
        property string trackKey: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (spicy.wanted !== root.generation)
                    return;
                const answer = root.split(text);

                if (answer.code === 401 || answer.code === 403) {
                    root.error = "the Spicy Lyrics key was refused";
                    Diag.log("lyrics", `spicy refused the key (${answer.code})`);
                    root.askLrclib(spicy.wanted);
                    return;
                }
                if (answer.code !== 200) {
                    Diag.log("lyrics", `spicy said ${answer.code}, trying lrclib`);
                    root.askLrclib(spicy.wanted);
                    return;
                }

                let parsed = null;
                try {
                    parsed = root.parseSpicy(JSON.parse(answer.body)?.Body);
                } catch (e) {
                    Diag.log("lyrics", `spicy sent something unreadable: ${e.message}`);
                }

                if (!parsed) {
                    root.askLrclib(spicy.wanted);
                    return;
                }

                let provider = "spicy_lyrics";
                try {
                    provider = JSON.parse(answer.body)?.Body?.source ?? "spicy_lyrics";
                } catch (e) {
                    // Keep the default.
                }
                Diag.log("lyrics", `spicy: ${parsed.lines.length} lines, ${parsed.granularity}, from ${provider}`);
                root.finish(spicy.wanted, spicy.trackKey, {
                    lines: parsed.lines,
                    granularity: parsed.granularity,
                    provider: provider
                });
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    Diag.log("lyrics", `spicy: ${text.trim()}`);
            }
        }
    }

    Process {
        id: lrclib

        property int wanted: 0
        property string trackKey: ""

        stdout: StdioCollector {
            onStreamFinished: {
                if (lrclib.wanted !== root.generation)
                    return;
                const answer = root.split(text);
                if (answer.code !== 200) {
                    Diag.log("lyrics", `lrclib said ${answer.code}`);
                    root.finish(lrclib.wanted, lrclib.trackKey, {
                        lines: [], provider: "", granularity: "", error: root.error
                    });
                    return;
                }

                let data = null;
                try {
                    data = JSON.parse(answer.body);
                } catch (e) {
                    data = null;
                }

                const synced = data?.syncedLyrics ?? "";
                if (synced.length > 0) {
                    const lines = root.parseLrc(synced);
                    Diag.log("lyrics", `lrclib: ${lines.length} lines, timed by line`);
                    root.finish(lrclib.wanted, lrclib.trackKey, {
                        lines: lines, granularity: "line", provider: "lrclib", error: root.error
                    });
                    return;
                }

                const plain = data?.plainLyrics ?? "";
                if (plain.length > 0) {
                    const statics = plain.split("\n")
                        .filter(l => l.trim().length > 0)
                        .map(l => ({ start: -1, end: -1, text: l, words: [], opposite: false }));
                    root.finish(lrclib.wanted, lrclib.trackKey, {
                        lines: statics, granularity: "static", provider: "lrclib", error: root.error
                    });
                    return;
                }

                root.finish(lrclib.wanted, lrclib.trackKey, {
                    lines: [], provider: "", granularity: "", error: root.error
                });
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    Diag.log("lyrics", `lrclib: ${text.trim()}`);
            }
        }
    }

    /*
     * A few lines of nothing in particular, timed from wherever the track is
     * now, so the view can be looked at without waiting for a song both sources
     * happen to know. Also the quickest way to tell whether the words are
     * landing early or late before settling on an offset.
     *
     * `kind` picks which of the two a source can give: "word" sweeps, as a
     * syllable sync does, and "line" lights each line whole, as everything else
     * does. Worth being able to see on demand, because which one a track gets is
     * not a setting — it is whatever the sources happen to hold for it.
     *
     * The swept placeholder spaces its own words out, which everywhere else is
     * exactly what the shell refuses to do. It is allowed here because these
     * words *are* the timing: there is no recording for the spacing to disagree
     * with.
     *
     * Replaced by the real thing as soon as the track changes.
     */
    function sample(kind) {
        const base = Math.max(0, root.at);
        const swept = kind !== "line";
        /*
         * The last two of the swept script overlap, and one of them is a backing
         * vocal, because that is the case worth being able to look at: lines
         * that sound together used to be dropped, and a placeholder that only
         * ever shows one line at a time cannot show that they no longer are.
         */
        const script = swept
            ? [["This is what a word-timed lyric looks like", 0, 3.0, false],
               ["each word lights as it is sung", 3.2, 6.0, false],
               ["and lines that sound together light together", 6.4, 11.0, false],
               ["like this one, over the end of it", 9.4, 12.4, true]]
            : [["This is what a line-timed lyric looks like", 0, 3.0, false],
               ["the whole line lights at once", 3.2, 6.0, false],
               ["because the source timed the line", 6.4, 9.2, false],
               ["and guessing the words would only look wrong", 9.6, 12.4, false]];
        const lines = [];
        for (const [text, from, to, background] of script) {
            lines.push({
                start: base + from,
                end: base + to,
                text: text,
                words: swept ? root.spreadWords(text, base + from, base + to) : [],
                opposite: false,
                background: background
            });
        }
        root.wantKey = "sample";
        root.lines = lines;
        root.granularity = swept ? "word" : "line";
        root.provider = "sample";
        root.status = "ready";
        root.error = "";
    }

    // What the shell can say about itself, for `stratum ipc lyrics status`.
    function report() {
        return [
            `enabled:  ${root.enabled}`,
            `key:      ${root.haveKey ? `yes (${root.fileKey.length > 0 ? root.keyPath : "shell.json"})` : "no — word timing needs one, see Settings → Lyrics"}`,
            `track:    ${Media.artist} — ${Media.title}`,
            `id:       ${root.trackId || "(not a Spotify stream)"}`,
            `status:   ${root.status}${root.error.length > 0 ? ` (${root.error})` : ""}`,
            `source:   ${root.provider || "(none)"}`,
            `timing:   ${root.granularity || "(none)"}${root.granularity === "line" ? " — each line lights whole; this source did not time the words" : ""}`,
            `lines:    ${root.lines.length}`,
            `showing:  ${root.watchers === 0 ? "nothing is — the clock and the lookup only run while a view is up" : `${root.watchers} view${root.watchers === 1 ? "" : "s"}`}`,
            `at:       ${root.at.toFixed(2)}s, line ${root.lineIndex}`
                + `${root.active.length > 1 ? ` (+${root.active.length - 1} sounding with it)` : ""}`
        ].join("\n");
    }
}
