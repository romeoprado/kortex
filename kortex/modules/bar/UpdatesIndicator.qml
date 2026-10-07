import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Atualizações pendentes: ícone e quantidade (só com o checkupdates instalado).
// Clique: painel com a lista e o botão de atualizar; clique direito: atualizar no terminal.
BarButton {
    id: root
    required property string screenName

    present: Updates.available
    icon: Icons.updates
    label: Updates.checking && Updates.lastCheck === 0 ? "…" : String(Updates.count)
    color: Updates.count > 0 ? Theme.fg : Theme.fgDim
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) Updates.upgrade()
        else Popups.toggle("updates", screenName)
    }

    BarPopup {
        id: popup
        target: root
        popupId: "updates"
        screenName: root.screenName
        panelWidth: 380
        // ao abrir, confere de novo se a última consulta tem mais de um minuto
        onWantedChanged: if (wanted && Date.now() - Updates.lastCheck > 60 * 1000) Updates.check()

        PopupTitle {
            text: "Atualizações"
            icon: Icons.updates
            subtitle: Updates.checking ? "Verificando…"
                : Updates.count === 0 ? "Sistema em dia"
                : Updates.count + (Updates.count === 1 ? " pacote" : " pacotes")
            PlainButton {
                icon: Icons.refresh
                enabled: !Updates.checking
                onClicked: Updates.check()
            }
        }

        ListView {
            visible: Updates.count > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 320)
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: Updates.packages

            delegate: RowLayout {
                required property var modelData
                width: ListView.view.width
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: modelData.name
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                    elide: Text.ElideRight
                }
                Text {
                    text: modelData.to
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                }
            }
        }

        PlainButton {
            visible: Updates.count > 0
            Layout.fillWidth: true
            icon: Icons.terminal
            text: "Atualizar no Terminal"
            onClicked: {
                Popups.close("updates")
                Updates.upgrade()
            }
        }
    }
}
