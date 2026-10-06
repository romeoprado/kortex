import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

BarButton {
    id: root
    required property string screenName

    readonly property int minTemp: 2500
    readonly property int maxTemp: 6500

    // Monitor desta barra e a seleção ainda não aplicada (resolução, taxa, escala)
    readonly property var mon: Monitors.byName(screenName)
    readonly property var resolutions: mon ? mon.resolutions : []
    readonly property var currentRes: resolutions.find(r => r.key === selRes) ?? null
    property string selRes: ""
    property real selRate: 0
    property real selScale: 1
    property bool edited: false
    readonly property bool changed: mon !== null && (selRes !== mon.width + "x" + mon.height
        || Math.abs(selRate - mon.refresh) > 0.005 || Math.abs(selScale - mon.scale) > 0.005)

    function closestRate(rates, target) {
        return rates.reduce((best, r) => Math.abs(r - target) < Math.abs(best - target) ? r : best, rates[0])
    }

    function syncSelection() {
        edited = false
        if (!mon) return
        selRes = mon.width + "x" + mon.height
        const res = resolutions.find(r => r.key === selRes)
        selRate = res && res.rates.length ? closestRate(res.rates, mon.refresh) : mon.refresh
        selScale = mon.scale
    }

    function pickResolution(key) {
        const res = resolutions.find(r => r.key === key)
        if (!res) return
        selRes = key
        // mantém a taxa se o novo modo a tem; senão, a mais próxima
        if (!res.rates.some(r => Math.abs(r - selRate) < 0.005)) selRate = closestRate(res.rates, selRate)
        edited = true
    }

    function applySelection() {
        const res = currentRes
        if (!mon || !res || !changed) return
        Popups.close("display")
        Monitors.apply(mon.name, res.w, res.h, selRate, selScale)
    }

    Connections {
        target: Monitors
        function onMonitorsChanged() { if (!root.edited) root.syncSelection() }
        function onPendingChanged() { if (!Monitors.pending) root.syncSelection() }
    }

    icon: Icons.display
    color: Settings.data.nightLight ? Theme.yellow : Theme.fg
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) Settings.data.nightLight = !Settings.data.nightLight
        else Popups.toggle("display", screenName)
    }
    onWheel: wheel => {
        if (Brightness.available) Brightness.setValue(Brightness.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }

    BarPopup {
        id: popup
        target: root
        popupId: "display"
        screenName: root.screenName
        panelWidth: 330
        onWantedChanged: if (wanted) {
            Brightness.refresh()
            Monitors.refresh()
            root.syncSelection()
        }

        PopupTitle {
            text: "Tela"
            icon: Icons.display
        }

        SliderBar {
            visible: Brightness.available
            icon: Icons.sun
            value: Brightness.value
            onMoved: v => Brightness.setValue(v)
        }

        Text {
            visible: !Brightness.available
            Layout.fillWidth: true
            text: "Controle de brilho indisponível."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.muted }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Luz Noturna"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.textBody
            }
            Toggle {
                checked: Settings.data.nightLight
                onToggled: value => Settings.data.nightLight = value
            }
        }

        SliderBar {
            id: tempSlider
            visible: Settings.data.nightLight
            icon: Icons.moon
            property real preview: (root.maxTemp - Settings.data.nightLightTemp) / (root.maxTemp - root.minTemp)
            value: preview
            valueText: Math.round(root.maxTemp - value * (root.maxTemp - root.minTemp)) + "K"
            onMoved: v => preview = v
            onCommitted: v => Settings.data.nightLightTemp = Math.round((root.maxTemp - v * (root.maxTemp - root.minTemp)) / 100) * 100
        }

        Text {
            visible: Brightness.nightLightMissing
            Layout.fillWidth: true
            text: "Instale o hyprsunset para usar a luz noturna."
            color: Theme.red
            font.family: Theme.font
            font.pixelSize: Theme.textSmall
            wrapMode: Text.Wrap
        }

        Rectangle { visible: root.mon !== null; Layout.fillWidth: true; implicitHeight: 1; color: Theme.muted }

        ColumnLayout {
            visible: root.mon !== null
            Layout.fillWidth: true
            spacing: 8

            component SectionLabel: Text {
                Layout.fillWidth: true
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.textBody
            }

            Text {
                Layout.fillWidth: true
                text: root.mon ? root.mon.name + (root.mon.description ? " · " + root.mon.description : "") : ""
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.textSmall
                elide: Text.ElideRight
            }

            SectionLabel { text: "Resolução" }
            Chips {
                model: root.resolutions.map(r => ({ label: r.w + "×" + r.h, value: r.key }))
                current: root.selRes
                onPicked: key => root.pickResolution(key)
            }

            SectionLabel { text: "Taxa de Atualização" }
            Chips {
                model: root.currentRes ? root.currentRes.rates.map(r => ({ label: Monitors.fmtLabel(r) + " Hz", value: r })) : []
                current: root.selRate
                onPicked: rate => { root.selRate = rate; root.edited = true }
            }

            SectionLabel { text: "Escala" }
            Chips {
                model: Monitors.scales.map(s => ({ label: Monitors.fmtLabel(s) + "×", value: s }))
                current: root.selScale
                onPicked: scale => { root.selScale = scale; root.edited = true }
            }

            Text {
                visible: root.currentRes !== null
                Layout.fillWidth: true
                text: root.currentRes
                    ? "Área de Trabalho: " + Math.round(root.currentRes.w / root.selScale) + "×" + Math.round(root.currentRes.h / root.selScale)
                    : ""
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.textSmall
            }

            PlainButton {
                Layout.fillWidth: true
                highlighted: true
                enabled: root.changed
                icon: Icons.display
                text: "Aplicar"
                onClicked: root.applySelection()
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.muted }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            PlainButton {
                Layout.fillWidth: true
                icon: Icons.brush
                text: "Temas"
                onClicked: Popups.openPicker("themes")
            }
            PlainButton {
                Layout.fillWidth: true
                icon: Icons.image
                text: "Papéis de Parede"
                onClicked: Popups.openPicker("wallpapers")
            }
        }
    }
}
