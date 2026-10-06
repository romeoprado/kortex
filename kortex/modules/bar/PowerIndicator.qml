import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.widgets

BarButton {
    id: root
    required property string screenName
    property string confirming: ""

    icon: Icons.session
    active: popup.visible
    onClicked: Popups.toggle("power", screenName)

    // Todas as ações; Configurações escolhe quais aparecem e se as destrutivas pedem confirmação
    readonly property var allActions: [
        { id: "lock",     icon: Icons.lock,   text: "Bloquear",  destructive: false },
        { id: "suspend",  icon: Icons.moon,   text: "Suspender", destructive: false },
        { id: "logout",   icon: Icons.logout, text: "Sair",      destructive: true },
        { id: "reboot",   icon: Icons.reboot,   text: "Reiniciar", destructive: true },
        { id: "firmware", icon: Icons.firmware, text: "UEFI",      destructive: true },
        { id: "shutdown", icon: Icons.power,    text: "Desligar",  destructive: true }
    ]
    readonly property var actions: allActions
        .filter(a => Settings.powerActionEnabled(a.id))
        .map(a => Object.assign({ confirm: a.destructive && Settings.data.powerConfirm }, a))

    // Ação sob o mouse (id), para a etiqueta com o nome aparecer embaixo do botão
    property string hovered: ""
    readonly property string confirmText: "Clique novamente para confirmar."
    // Etiqueta: sob o botão da ação que pede confirmação ou, senão, da que está sob o mouse
    readonly property int tagIndex: actions.findIndex(a => a.id === (confirming !== "" ? confirming : hovered))
    FontMetrics { id: tagMetrics; font.family: Theme.font; font.pixelSize: Theme.textSmall }
    FontMetrics { id: tagBoldMetrics; font.family: Theme.font; font.pixelSize: Theme.textSmall; font.bold: true }
    readonly property real longestLabel: {
        void tagMetrics.font, tagBoldMetrics.font   // refaz a conta quando a fonte muda
        return Math.max(0, ...actions.map(a => a.confirm ? tagBoldMetrics.advanceWidth(confirmText)
                                                         : tagMetrics.advanceWidth(a.text))) + 20   // folga da etiqueta
    }

    function run(a) {
        if (a.confirm && confirming !== a.id) {
            confirming = a.id
            resetConfirm.restart()
            return
        }
        confirming = ""
        Popups.close()
        switch (a.id) {
        case "lock": Settings.shell(Settings.data.lockCommand); break
        case "suspend": Quickshell.execDetached(["systemctl", "suspend"]); break
        case "logout": Hyprland.dispatch("exit"); break
        case "reboot": Quickshell.execDetached(["systemctl", "reboot"]); break
        case "firmware": Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]); break
        case "shutdown": Quickshell.execDetached(["systemctl", "poweroff"]); break
        }
    }

    Timer {
        id: resetConfirm
        interval: 3000
        onTriggered: root.confirming = ""
    }

    BarPopup {
        id: popup
        target: root
        popupId: "power"
        screenName: root.screenName
        // Justo ao conteúdo: a linha de botões ou, se for mais larga, a maior frase possível embaixo
        panelWidth: Math.ceil(Math.max(root.actions.length * 52 - 8, root.longestLabel, 200)) + padding * 2
        onWantedChanged: root.confirming = ""

        PopupTitle { text: "Sessão"; icon: Icons.session }

        Text {
            visible: root.actions.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            horizontalAlignment: Text.AlignHCenter
            text: "Nenhuma ação habilitada. Escolha em Configurações › Sessão."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.textBody
        }

        // Um botão só com ícone por ação; embaixo, o nome da ação sob o mouse ou o pedido de confirmação
        RowLayout {
            visible: root.actions.length > 0
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.actions

                TileButton {
                    required property var modelData

                    icon: modelData.icon
                    danger: modelData.destructive
                    asking: root.confirming === modelData.id
                    countdown: resetConfirm.interval
                    onClicked: root.run(modelData)
                    onContainsMouseChanged: {
                        if (containsMouse) root.hovered = modelData.id
                        else if (root.hovered === modelData.id) root.hovered = ""
                    }
                }
            }
        }

        // Etiqueta sob o botão: o nome da ação ou, em vermelho, o pedido de confirmação
        ButtonTag {
            visible: root.actions.length > 0
            Layout.fillWidth: true
            readonly property bool asking: root.confirming !== ""
            index: root.tagIndex
            text: asking ? root.confirmText : root.tagIndex >= 0 ? root.actions[root.tagIndex].text : ""
            fill: asking ? Theme.red : Theme.bgAlt
            textColor: asking ? Theme.redText : Theme.fg
            bold: asking
        }
    }
}
