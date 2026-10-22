import QtQuick

// Stacks its children along the bar: top to bottom on a left/right bar, left to right on a top/bottom bar.
// Children are centered across the bar. Hidden children take no room.
// "Which way the bar runs" is asked of the bar this sits in (a split layout has one of each).
Grid {
    id: stack
    readonly property bool horizontal: Bar.horizontalFor(stack)
    columns: horizontal ? 64 : 1             // rows follow from the number of children
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
}
