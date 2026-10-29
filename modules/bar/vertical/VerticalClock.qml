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
        text: Time.format("HH")
        size: 26
    }

    DotText {
        text: Time.format("mm")
        size: 26
    }

    SectionLabel {
        topPadding: Theme.space(1)
        text: Time.format("ddd d")
    }
}
