import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

BarButton {
    id: root
    required property string screenName

    icon: Settings.data.dnd ? Icons.bellOff : Icons.bell
    iconFilled: !Settings.data.dnd && Notifs.count > 0   // sino preenchido quando há notificações
    color: Settings.data.dnd ? Theme.fgDim : (Notifs.count > 0 ? Theme.fgBright : Theme.fg)
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) Settings.data.dnd = !Settings.data.dnd
        else Popups.toggle("notifications", screenName)
    }

    BarPopup {
        id: popup
        target: root
        popupId: "notifications"
        screenName: root.screenName
        panelWidth: 380

        PopupTitle {
            text: "Notificações"
            icon: Settings.data.dnd ? Icons.bellOff : Icons.bell
            subtitle: Settings.data.dnd ? "Não Perturbe ativado"
                : Notifs.count > 0 ? Notifs.count + (Notifs.count === 1 ? " notificação" : " notificações")
                : ""
            Text {
                text: "Não Perturbe"
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
            Toggle {
                checked: Settings.data.dnd
                onToggled: value => Settings.data.dnd = value
            }
        }

        Text {
            visible: Notifs.count === 0
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            horizontalAlignment: Text.AlignHCenter
            text: "Sem notificações."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        ListView {
            visible: Notifs.count > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 440)
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.list

            delegate: NotificationCard {
                required property var modelData
                notif: modelData
                width: ListView.view.width
            }
        }

        PlainButton {
            visible: Notifs.count > 0
            Layout.fillWidth: true
            icon: Icons.trash
            text: "Limpar"
            onClicked: Notifs.clearAll()
        }
    }
}
