import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.services

// Cartão usado tanto nos avisos flutuantes quanto no histórico
Rectangle {
    id: root

    required property var notif
    property bool toast: false
    signal expired()

    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical
    readonly property string image: {
        const n = root.notif
        if (!n) return ""
        if (n.image) return n.image
        const i = n.appIcon || ""
        if (!i) return ""
        if (i.startsWith("/")) return Theme.url(i)
        if (/^(file|image):/.test(i)) return i
        return Quickshell.iconPath(i, true)
    }

    // altura em pixels físicos inteiros: com escala fracionária os cartões empilhados ficariam
    // em posições fracionárias e a borda sairia borrada
    readonly property real dpr: QsWindow.window ? QsWindow.window.devicePixelRatio : 1
    implicitHeight: Math.ceil((body.implicitHeight + 24) * dpr - 0.000001) / dpr
    radius: Theme.radius
    color: "transparent"

    // Aviso flutuante: borda no acento do tema, ou em vermelho se for crítico (o histórico tem 1 px cinza)
    GradientBorder {
        anchors.fill: parent
        radius: root.radius
        fill: root.toast ? Theme.bg : Theme.bgAlt
        borderWidth: root.toast ? Theme.border : 1
        scaled: root.toast
        color: root.toast ? (root.critical ? Theme.red : Theme.borderColor) : Theme.muted
    }

    // Fecha: aviso do Kortex (Notifs.flash) só sai da tela; notificação de app é descartada
    function close() {
        const n = root.notif
        if (!n) return
        if (n.kortexKey) Notifs.removeToast(n)
        else n.dismiss()
    }

    function actionsOf(n) {
        const out = []
        const a = n ? n.actions : []
        for (let i = 0; i < a.length; i++) out.push(a[i])
        return out
    }

    Timer {
        running: root.toast && !root.critical && !hover.containsMouse
        interval: (root.notif && root.notif.expireTimeout > 0) ? root.notif.expireTimeout : Math.max(2, Settings.data.toastSeconds) * 1000
        onTriggered: root.expired()
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            const n = root.notif
            if (!n) return
            const def = mouse.button === Qt.LeftButton ? root.actionsOf(n).find(a => a.identifier === "default") : null
            if (def) Notifs.invoke(n, def)
            else root.close()
        }
    }

    RowLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12

        // Avisos do próprio Kortex (Notifs.flash) trazem um ícone do Google no lugar da imagem
        Icon {
            Layout.preferredWidth: 40
            Layout.alignment: Qt.AlignTop
            visible: text !== ""
            text: root.notif?.kortexIcon ?? ""
            color: Theme.accent
            size: Theme.iconSize + 12
        }

        Image {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignTop
            visible: root.image !== "" && status !== Image.Error
            source: root.image
            sourceSize.width: 80
            sourceSize.height: 80
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: root.notif?.appName || "Notificação"
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: Notifs.timeOf(root.notif)
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                }
                Icon {
                    text: Icons.close
                    color: closeArea.containsMouse ? Theme.red : Theme.fgDim
                    size: Theme.fontSize + 2
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notif?.summary ?? ""
                visible: text !== ""
                color: Theme.fgBright
                font.family: Theme.font
                font.pixelSize: Theme.textBody
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                // sem <img>: a marcação aceita imagens de endereços da internet, e um aviso não deve
                // fazer o Kortex baixar nada
                text: (root.notif?.body ?? "").replace(/<img\b[^>]*>/gi, "")
                visible: text !== ""
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.textBody
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: children.length > 1
                Repeater {
                    model: root.actionsOf(root.notif).filter(a => a.identifier !== "default")
                    PlainButton {
                        required property var modelData
                        implicitHeight: 26
                        text: modelData.text
                        onClicked: Notifs.invoke(root.notif, modelData)
                    }
                }
            }
        }
    }
}
