import QtQuick
import Quickshell
import qs.services
import qs.widgets

BarButton {
    id: root
    required property string screenName

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1) }
    function bare(s) { return s.replace(/\.$/, "") }   // "sáb." → "sáb"

    readonly property string time: clock.date.toLocaleTimeString(Qt.locale(), Settings.data.use24h ? "HH:mm" : "h:mm AP")
    readonly property string weekday: cap(clock.date.toLocaleDateString(Qt.locale(), "dddd"))
    readonly property string shortDate: cap(bare(clock.date.toLocaleDateString(Qt.locale(), "ddd")))
        + " " + clock.date.getDate() + " " + bare(clock.date.toLocaleDateString(Qt.locale(), "MMM"))

    readonly property string numericDate: clock.date.toLocaleDateString(Qt.locale(), Locale.ShortFormat)

    // Formatos do rótulo. O clique do meio passa para o próximo e a escolha fica em
    // Settings.data.clockFormat (vale para a barra de todos os monitores).
    readonly property var labels: [
        weekday + " " + time,       // Sábado 11:46
        shortDate + " " + time,     // Sáb 19 set 11:46
        numericDate + " " + time,   // 19/09/2026 11:46
        shortDate,                  // Sáb 19 set
        time                        // 11:46
    ]
    readonly property int formatIndex: ((Settings.data.clockFormat % labels.length) + labels.length) % labels.length

    label: labels[formatIndex]
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) Settings.data.clockFormat = (formatIndex + 1) % labels.length
        else Popups.toggle("calendar", screenName)
    }

    BarPopup {
        id: popup
        target: root
        popupId: "calendar"
        screenName: root.screenName
        panelWidth: 413   // 516 × 0,8 (ver Calendar.size)
        onWantedChanged: if (wanted) calendar.reset()

        Calendar { id: calendar }
    }
}
