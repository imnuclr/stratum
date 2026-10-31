pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Where the weather is for. Search for a town, or click on the map; or let it
 * be guessed from your internet address, which is quick but often the wrong
 * town and tells a third party where you are.
 */
SettingsPage {
    id: page

    icon: "cloud-sun"
    title: "Weather"
    detail: "Where the forecast is for, and how it is shown."

    // Town search results from open-meteo's geocoder, as { name, area, lat, lon }.
    property var results: []
    property string query: ""

    Component.onCompleted: {
        if (Weather.located)
            map.show(Weather.latitude, Weather.longitude, 6);
    }

    Timer {
        id: searchLater

        interval: 350
        onTriggered: {
            if (page.query.trim().length < 2) {
                page.results = [];
                return;
            }
            geocode.command = ["curl", "-s", "--max-time", "8",
                `https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&format=json&name=${encodeURIComponent(page.query.trim())}`];
            geocode.running = true;
        }
    }

    Process {
        id: geocode

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.results = (JSON.parse(text).results ?? []).map(r => ({
                        name: r.name,
                        area: [r.admin1, r.country].filter(s => s).join(", "),
                        lat: r.latitude,
                        lon: r.longitude
                    }));
                } catch (e) {
                    page.results = [];
                }
            }
        }
    }

    // A clicked point gets a name from OpenStreetMap, best effort.
    property real pendingLat: NaN
    property real pendingLon: NaN

    Process {
        id: reverse

        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                try {
                    const a = JSON.parse(text).address ?? {};
                    name = a.city || a.town || a.village || a.municipality || a.county || a.state || "";
                } catch (e) {}
                Weather.choose(page.pendingLat, page.pendingLon,
                    name || `${page.pendingLat.toFixed(2)}, ${page.pendingLon.toFixed(2)}`);
            }
        }
    }

    function pick(lat, lon) {
        page.pendingLat = lat;
        page.pendingLon = lon;
        // Shown at once; named when the answer comes.
        Weather.choose(lat, lon, `${lat.toFixed(2)}, ${lon.toFixed(2)}`);
        reverse.command = ["curl", "-s", "--max-time", "8", "-A", "Stratum shell weather picker",
            `https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10&lat=${lat}&lon=${lon}`];
        reverse.running = true;
    }

    SettingCard {
        title: "location"

        SettingRow {
            title: Weather.place.length > 0 ? Weather.place : (Weather.located ? `${Weather.latitude.toFixed(2)}, ${Weather.longitude.toFixed(2)}` : "Unknown")
            detail: Weather.source === "chosen" ? "Chosen by you."
                : Weather.source === "from your IP" ? "Guessed from your internet address, which can be the wrong town. Pick on the map to be exact."
                : "Not known yet."

            LinkButton {
                visible: Weather.source === "chosen"
                text: "guess from IP instead"
                onClicked: Weather.forget()
            }
        }

        // Search by name.
        Item {
            width: parent.width
            height: 56

            TextField {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                radius: 17
                placeholder: "Search for a town or city…"
                onTextChanged: {
                    page.query = text;
                    searchLater.restart();
                }
            }
        }

        Repeater {
            model: page.results

            ChoiceRow {
                required property var modelData

                icon: "cloud-sun"
                title: modelData.name
                sub: modelData.area
                chosen: Math.abs(modelData.lat - Weather.latitude) < 0.01 && Math.abs(modelData.lon - Weather.longitude) < 0.01
                onClicked: {
                    Weather.choose(modelData.lat, modelData.lon, modelData.name);
                    map.show(modelData.lat, modelData.lon, 14);
                    page.results = [];
                }
            }
        }
    }

    // Or point at it.
    Column {
        spacing: Theme.space(2)

        SectionLabel {
            leftPadding: Theme.space(1)
            text: "or click on the map"
        }

        WorldMap {
            id: map

            width: parent.width
            height: 380
            pinLat: Weather.located ? Weather.latitude : NaN
            pinLon: Weather.located ? Weather.longitude : NaN
            onPicked: (lat, lon) => page.pick(lat, lon)
        }

        Text {
            leftPadding: Theme.space(1)
            text: "Drag to move, scroll to zoom. Map: Natural Earth. Names: OpenStreetMap."
            color: Theme.fgFaint
            font.family: Theme.fontUi
            font.pixelSize: 11
            renderType: Text.NativeRendering
        }
    }

    SettingCard {
        title: "showing"

        SettingRow {
            title: "Weather"
            detail: "Off stops every weather request."

            Switch {
                checked: Config.get("weather.enabled", true)
                onToggled: value => Config.set("weather.enabled", value)
            }
        }

        SettingRow {
            title: "Units"

            Segmented {
                model: ["°C", "°F"]
                current: Weather.metric ? 0 : 1
                onPicked: index => Config.set("weather.units", index === 0 ? "metric" : "imperial")
            }
        }
    }
}
