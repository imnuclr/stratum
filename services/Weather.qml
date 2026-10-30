pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * Current conditions from open-meteo, which needs no API key.
 *
 * Location comes from config when set. If it isn't, the service asks ip-api.com,
 * which means one outbound request that reveals this machine's IP to a third
 * party — so it is opt-out by setting weather.latitude and weather.longitude,
 * and nothing is requested at all when weather.enabled is false.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.get("weather.enabled", true)
    readonly property bool metric: Config.get("weather.units", "metric") === "metric"

    property real latitude: Config.get("weather.latitude", null) ?? NaN
    property real longitude: Config.get("weather.longitude", null) ?? NaN
    property string place: Config.get("weather.place", "")

    readonly property bool located: !isNaN(latitude) && !isNaN(longitude)

    // Tomorrow onward: { day, code, max, min }. Index 0 of the API's daily
    // arrays is today, which the current conditions already cover.
    property var daily: []
    // Today's range, which `daily` (tomorrow onward) does not carry.
    property real todayMax: NaN
    property real todayMin: NaN
    property string sunrise: ""
    property string sunset: ""

    property real temperature: NaN
    property real apparent: NaN
    property real humidity: NaN
    property real windSpeed: NaN
    property int code: -1
    property bool day: true
    property string error: ""

    readonly property bool ready: !isNaN(temperature)
    readonly property string unit: metric ? "C" : "F"

    // open-meteo WMO weather codes, grouped to the handful worth distinguishing.
    readonly property string condition: {
        if (code < 0)
            return "";
        if (code === 0)
            return "clear";
        if (code <= 2)
            return "partly cloudy";
        if (code === 3)
            return "overcast";
        if (code <= 48)
            return "fog";
        if (code <= 57)
            return "drizzle";
        if (code <= 67)
            return "rain";
        if (code <= 77)
            return "snow";
        if (code <= 82)
            return "showers";
        if (code <= 86)
            return "snow showers";
        return "thunderstorm";
    }

    function refresh() {
        if (!enabled)
            return;
        if (!located) {
            locate.running = true;
            return;
        }
        const units = metric ? "celsius" : "fahrenheit";
        // m/s rather than km/h: the strip shows wind beside "feels like" in the
        // space of a few characters.
        const wind = metric ? "ms" : "mph";
        fetch.command = ["curl", "-s", "--max-time", "10",
            `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}` +
            `&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day` +
            `&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&forecast_days=5` +
            `&temperature_unit=${units}&wind_speed_unit=${wind}&timezone=auto`];
        fetch.running = true;
    }

    onLocatedChanged: {
        if (located)
            root.refresh();
    }

    Component.onCompleted: refresh()

    // Conditions do not change minute to minute, and this is a third-party
    // request; fifteen minutes is frequent enough.
    Timer {
        running: root.enabled
        repeat: true
        interval: 900000
        onTriggered: root.refresh()
    }

    Process {
        id: locate

        command: ["curl", "-s", "--max-time", "10", "http://ip-api.com/json?fields=status,city,lat,lon"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.status !== "success") {
                        root.error = "location lookup failed";
                        return;
                    }
                    root.latitude = d.lat;
                    root.longitude = d.lon;
                    if (!root.place)
                        root.place = d.city ?? "";
                    root.error = "";
                } catch (e) {
                    root.error = "location lookup unreadable";
                }
            }
        }
    }

    Process {
        id: fetch

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text)?.current;
                    if (!c) {
                        root.error = "no current conditions";
                        return;
                    }
                    root.temperature = c.temperature_2m;
                    root.apparent = c.apparent_temperature;
                    root.humidity = c.relative_humidity_2m;
                    root.windSpeed = c.wind_speed_10m;
                    root.code = c.weather_code ?? -1;
                    root.day = c.is_day === 1;

                    const d = JSON.parse(text)?.daily;
                    if (d?.time) {
                        // Local date strings, so the time is taken off the end
                        // rather than parsed as UTC and shifted.
                        root.sunrise = (d.sunrise?.[0] ?? "").slice(11);
                        root.sunset = (d.sunset?.[0] ?? "").slice(11);
                        root.todayMax = d.temperature_2m_max?.[0] ?? NaN;
                        root.todayMin = d.temperature_2m_min?.[0] ?? NaN;

                        const names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
                        const days = [];
                        for (let i = 1; i < d.time.length; i++) {
                            days.push({
                                day: names[new Date(`${d.time[i]}T00:00`).getDay()],
                                code: d.weather_code?.[i] ?? -1,
                                max: d.temperature_2m_max?.[i] ?? NaN,
                                min: d.temperature_2m_min?.[i] ?? NaN
                            });
                        }
                        root.daily = days;
                    }

                    root.error = "";
                } catch (e) {
                    root.error = "forecast unreadable";
                }
            }
        }
    }
}
