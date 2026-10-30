import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Hours over minutes. A vertical bar is too narrow for "16:54" at a size worth
 * reading, so the pair stacks and drops the colon — the stack itself separates
 * them.
 */
Column {
    id: root

    spacing: -2

    DotText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Time.hour2
        size: 26
    }

    DotText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Time.format("mm")
        size: 26
    }

    SectionLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        topPadding: Theme.space(1)
        text: Time.format("ddd d")
    }
}
