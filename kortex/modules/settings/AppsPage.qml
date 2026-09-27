import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Configurações › Aplicativos: terminal, explorador de arquivos e navegador padrão
SettingsPage {
    id: page

    // Lista de aplicativos de um tipo, com o escolhido em destaque
    component AppGroup: ColumnLayout {
        id: group

        property string title: ""
        property var entries: []       // [{ key, id, name, icon, command }]
        property string currentKey: ""
        property string autoText: ""   // com texto, oferece "voltar ao automático"
        property string note: ""
        property bool warn: false
        signal chosen(var entry)       // entry nulo = automático

        Layout.fillWidth: true
        spacing: 8

        SettingRow {
            title: group.title
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            AppChip {
                visible: group.autoText !== ""
                text: group.autoText
                highlighted: group.currentKey === ""
                onClicked: group.chosen(null)
            }

            Repeater {
                model: group.entries

                AppChip {
                    required property var modelData
                    text: modelData.name
                    icon: modelData.icon
                    highlighted: group.currentKey === modelData.key
                    onClicked: group.chosen(modelData)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: group.note !== ""
            text: group.note
            color: group.warn ? Theme.yellow : Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
        }
    }

    readonly property var fileManagers: Apps.fileManagers.map(e => Object.assign({ key: e.id }, e))
    readonly property var browsers: Apps.browsers.map(e => Object.assign({ key: e.id }, e))
    readonly property string fileKey: Apps.currentFileManager()
    readonly property string browserKey: Apps.currentBrowser()

    Component.onCompleted: Apps.refresh()

    SettingsSection { text: "Aplicativos padrão" }

    AppGroup {
        title: "Terminal"
        autoText: "Automático"
        entries: Apps.terminals.map(e => Object.assign({ key: Apps.commandName(e) }, e))
        currentKey: Settings.data.terminal
        onChosen: entry => Apps.setTerminal(entry)
    }

    AppGroup {
        title: "Explorador de Arquivos"
        entries: page.fileManagers
        currentKey: page.fileKey
        note: page.fileKey !== "" && !page.fileManagers.some(e => e.key === page.fileKey)
            ? "O padrão do sistema para pastas é \"" + page.fileKey + "\", que não é um explorador de arquivos. Escolha um acima para corrigir."
            : ""
        warn: true
        onChosen: entry => Apps.setFileManager(entry)
    }

    AppGroup {
        title: "Navegador"
        entries: page.browsers
        currentKey: page.browserKey
        note: page.browsers.length === 0 ? "Nenhum navegador instalado foi encontrado." : ""
        onChosen: entry => Apps.setBrowser(entry)
    }
}
