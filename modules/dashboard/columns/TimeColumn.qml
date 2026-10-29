import QtQuick
import qs.components
import qs.services
import qs.theme

Column {
    spacing: Theme.space(2)

    DotText {
        text: Time.format("HH:mm")
        size: 52
    }

    SectionLabel {
        dim: true
        text: `${Time.format("d MMMM")} · week ${Time.weekNumber()}`
    }

    DotBar {
        count: 30
        value: Time.dayProgress
    }
}
