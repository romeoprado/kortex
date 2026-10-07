import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.services
import qs.widgets

// Bandeja: os ícones que os programas põem na barra (Discord, Steam, Nextcloud…). Só aparece com
// algum programa na bandeja. Clique: abre o programa (ou o menu, se ele só tiver menu); clique
// direito: menu do programa; clique do meio: ação secundária; roda: o que o programa definir.
// O item inteiro se arrasta pelas pontas (o espaço entre a borda e os ícones).
BarButton {
    id: root
    required property string screenName

    readonly property var items: SystemTray.items.values
    present: items.length > 0
    implicitWidth: icons.implicitWidth + 16
    // o clique nas pontas não faz nada (os ícones recebem os próprios cliques)

    Row {
        id: icons
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.items

            MouseArea {
                id: entry
                required property SystemTrayItem modelData
                width: Theme.iconSize + 6
                height: root.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                function showMenu() {
                    if (!modelData.hasMenu) return
                    const p = entry.mapToItem(null, 0, Theme.barBottom ? 0 : entry.height)
                    modelData.display(QsWindow.window, Math.round(p.x), Math.round(p.y))
                }
                onPressed: Popups.dismiss()
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) showMenu()
                    else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
                    else if (modelData.onlyMenu) showMenu()
                    else modelData.activate()
                }
                onWheel: wheel => modelData.scroll(wheel.angleDelta.y / 120, false)

                // fundo suave sob o mouse, como nos botões dos painéis
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: width
                    radius: Theme.radiusSmall
                    color: Qt.alpha(Theme.accent, 0.25)
                    visible: entry.containsMouse
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Theme.iconSize
                    source: {
                        // alguns programas mandam "nome?path=/pasta": o ícone está nessa pasta
                        const icon = entry.modelData.icon
                        if (!icon.includes("?path=")) return icon
                        const [name, path] = icon.split("?path=")
                        return "file://" + path + "/" + name.slice(name.lastIndexOf("/") + 1)
                    }
                }
            }
        }
    }
}
