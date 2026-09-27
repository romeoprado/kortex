import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Layout de teclado ativo. Clique: troca rápida e atalhos das configurações;
// clique do meio: próximo layout; clique direito: janela de teclado e idioma.
BarButton {
    id: root
    required property string screenName

    icon: Icons.keyboard
    label: Keyboard.shortName
    active: popup.visible
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) Keyboard.next()
        else if (mouse.button === Qt.RightButton) Popups.openLanguage("keyboard")
        else Popups.toggle("keyboard", screenName)
    }

    BarPopup {
        id: popup
        target: root
        popupId: "keyboard"
        screenName: root.screenName
        panelWidth: 360
        onWantedChanged: if (wanted) {
            Keyboard.refresh()
            Language.refresh()
        }

        PopupTitle { text: "Teclado"; icon: Icons.keyboard }

        Repeater {
            model: Keyboard.layouts

            PlainButton {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: 36
                alignLeft: true
                icon: Icons.keyboard
                text: Keyboard.labelOf(modelData) + "  " + Keyboard.nameOf(modelData)
                highlighted: index === Keyboard.activeIndex
                onClicked: Keyboard.switchTo(index)
            }
        }

        Text {
            visible: Keyboard.layouts.length < 2
            Layout.fillWidth: true
            text: "Somente um layout ativo."
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.muted }

        Text {
            Layout.fillWidth: true
            text: "Idioma do Sistema: " + Language.currentName
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            PlainButton {
                Layout.fillWidth: true
                icon: Icons.keyboard
                text: "Teclado"
                onClicked: Popups.openLanguage("keyboard")
            }
            PlainButton {
                Layout.fillWidth: true
                icon: Icons.globe
                text: "Idioma"
                onClicked: Popups.openLanguage("language")
            }
        }
    }
}
