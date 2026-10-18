import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

// Lançador de aplicativos estilo Rofi.
//   Digite para filtrar · ↑/↓ ou Ctrl+J/K navegam · Enter abre · Esc fecha
//   Ctrl+D marca/desmarca o favorito · Ctrl+F lista só os favoritos
//   Comece com ">" para executar um comando do shell.
//
// Abre em cascata: o painel cresce e surge, a busca desce, as primeiras linhas entram uma depois da
// outra com um quique leve e a dica aparece por último. Só na abertura; as buscas trocam a lista na
// hora. O Hyprland só esmaece a camada (HyprSync). Ideia da abertura do lançador do
// dhrruvsharma/shell (GPLv3).
LazyLoader {
    active: Popups.launcherOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-launcher"
        panelWidth: 372
        panelHeight: 480
        onDismissed: close()

        property var results: []
        readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)
        readonly property var favs: {
            const m = {}
            for (const id of (Settings.data.favoriteApps || [])) m[id] = true
            return m
        }
        readonly property bool hasFavorites: apps.some(a => favs[a.id] === true)

        function close() { Popups.launcherOpen = false }

        // as linhas criadas enquanto isto vale entram em cascata
        property bool opening: Motion.enabled
        Timer { running: win.opening; interval: Motion.ms(700); onTriggered: win.opening = false }

        // Entrada fixa que abre as Configurações do Kortex
        readonly property var settingsEntry: ({
            isSettings: true,
            name: "Configurações do Kortex",
            comment: "Aparência, barra, aplicativos padrão e sessão"
        })
        readonly property var settingsWords: [
            "configurações", "configuracoes", "configuração", "configurar", "settings", "ajustes", "preferências",
            "preferencias", "opções", "opcoes", "aparência", "aparencia", "kortex", "barra", "fonte", "fontes",
            "cantos", "bordas", "transparência", "transparencia", "áreas", "areas", "trabalho", "sessão", "sessao"
        ]
        // Começo de alguma palavra (3+ letras), ou parte do nome da entrada
        function matchesSettings(q) {
            return q.length >= 3 && (settingsWords.some(w => w.startsWith(q)) || settingsEntry.name.toLowerCase().includes(q))
        }

        function openSettings() {
            close()
            Popups.openSettings()
        }

        function score(a, q) {
            const name = (a.name || "").toLowerCase()
            if (name === q) return 1000
            if (name.startsWith(q)) return 800 - name.length
            if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 600
            if (name.includes(q)) return 500
            const extra = [a.genericName || "", (a.keywords || []).join(" "), a.comment || "", a.id || ""]
                .join(" ").toLowerCase()
            if (extra.includes(q)) return 300
            let i = 0
            for (const c of name) if (c === q[i]) i++
            return i === q.length ? 100 : -1
        }

        // keep: mantém o item selecionado (ao marcar um favorito) em vez de voltar ao topo
        function update(keep) {
            const raw = search.text
            const q = raw.trim().toLowerCase()
            const usage = Settings.data.appUsage || {}
            const pool = Settings.data.launcherFavoritesOnly ? apps.filter(a => favs[a.id] === true) : apps
            if (q.startsWith(">")) {
                const cmd = raw.trim().slice(1).trim()
                results = cmd ? [{ isCommand: true, name: cmd, comment: "Executar no shell" }] : []
            } else if (!q) {
                results = pool.slice().sort((a, b) =>
                    ((usage[b.id] || 0) - (usage[a.id] || 0)) || a.name.localeCompare(b.name))
            } else {
                results = pool
                    .map(a => ({ a: a, s: score(a, q) }))
                    .filter(x => x.s >= 0)
                    .map(x => ({ a: x.a, s: x.s + Math.min(usage[x.a.id] || 0, 40) }))
                    .sort((x, y) => (y.s - x.s) || x.a.name.localeCompare(y.a.name))
                    .map(x => x.a)
                // As configurações do Kortex aparecem na busca ("config", "kortex", "ajustes", "fonte"…)
                if (matchesSettings(q)) results = [settingsEntry].concat(results)
            }
            if (keep) {
                list.currentIndex = Math.max(0, Math.min(list.currentIndex, results.length - 1))
            } else {
                list.currentIndex = 0
                list.positionViewAtBeginning()
            }
        }

        function toggleFavorite(item) {
            if (!item || item.isCommand) return
            const ids = Settings.data.favoriteApps || []
            Settings.data.favoriteApps = ids.includes(item.id) ? ids.filter(i => i !== item.id) : ids.concat([item.id])
            // no modo "só favoritos" o app desmarcado sai da lista
            if (Settings.data.launcherFavoritesOnly) update(true)
        }

        function setFavoritesOnly(on) {
            Settings.data.launcherFavoritesOnly = on
            update()
        }

        function launch(item) {
            if (!item) return
            if (item.isSettings) {
                openSettings()
                return
            }
            if (item.isCommand) {
                Quickshell.execDetached(["sh", "-c", item.name])
            } else {
                const u = Object.assign({}, Settings.data.appUsage || {})
                u[item.id] = (u[item.id] || 0) + 1
                Settings.data.appUsage = u
                item.execute()
            }
            close()
        }

        Component.onCompleted: {
            update()
            search.focusInput()
        }

        GradientFrame {
            id: frame
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius
            opacity: Motion.enabled ? 0 : 1

            ParallelAnimation {
                running: Motion.enabled
                NumberAnimation { target: frame; property: "opacity"; from: 0; to: 1; duration: Motion.ms(200); easing.type: Easing.OutQuad }
                NumberAnimation {
                    target: frame; property: "scale"; from: Motion.pick(0.97, 0.94, 0.9); to: 1; duration: Motion.ms(320)
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.curveOut
                }
                SequentialAnimation {
                    PauseAnimation { duration: Motion.ms(50) }
                    ParallelAnimation {
                        NumberAnimation { target: searchRow; property: "opacity"; from: 0; to: 1; duration: Motion.ms(300); easing.type: Easing.OutCubic }
                        NumberAnimation { target: searchShift; property: "y"; from: -12; to: 0; duration: Motion.ms(380); easing.type: Easing.OutCubic }
                    }
                }
                SequentialAnimation {
                    PauseAnimation { duration: Motion.ms(440) }
                    NumberAnimation { target: hint; property: "opacity"; from: 0; to: 1; duration: Motion.ms(260); easing.type: Easing.OutCubic }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    id: searchRow
                    Layout.fillWidth: true
                    spacing: 8
                    opacity: Motion.enabled ? 0 : 1
                    transform: Translate { id: searchShift }

                    Field {
                        id: search
                        icon: Icons.search
                        implicitHeight: 40
                        placeholder: "Buscar  (> comando)"
                        onTextChanged: win.update()
                        onAccepted: win.launch(win.results[list.currentIndex])

                        onKeyPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            if (event.key === Qt.Key_Escape) {
                                win.close()
                            } else if (ctrl && event.key === Qt.Key_F) {
                                win.setFavoritesOnly(!Settings.data.launcherFavoritesOnly)
                            } else if (ctrl && event.key === Qt.Key_D) {
                                win.toggleFavorite(win.results[list.currentIndex])
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                                list.incrementCurrentIndex()
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                                list.decrementCurrentIndex()
                            } else if (event.key === Qt.Key_PageDown) {
                                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 8)
                            } else if (event.key === Qt.Key_PageUp) {
                                list.currentIndex = Math.max(0, list.currentIndex - 8)
                            } else {
                                event.accepted = false
                                return
                            }
                            event.accepted = true
                        }
                    }

                    PlainButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        highlighted: Settings.data.launcherFavoritesOnly
                        icon: Settings.data.launcherFavoritesOnly ? Icons.star : Icons.starOff
                        onClicked: win.setFavoritesOnly(!Settings.data.launcherFavoritesOnly)
                    }

                    PlainButton {
                        implicitWidth: 40
                        implicitHeight: 40
                        icon: Icons.sliders
                        onClicked: win.openSettings()
                    }
                }

                ListView {
                    id: list
                    visible: win.results.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: win.results
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationWraps: true

                    delegate: MouseArea {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool selected: ListView.isCurrentItem

                        width: ListView.view.width
                        height: 46
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: list.currentIndex = index
                        onClicked: win.launch(modelData)
                        transform: Translate { id: rowShift }
                        Component.onCompleted: {
                            if (!win.opening || index > 11) return
                            opacity = 0
                            rowIn.start()
                        }

                        SequentialAnimation {
                            id: rowIn
                            PauseAnimation { duration: Motion.ms(110 + row.index * 28) }
                            ParallelAnimation {
                                NumberAnimation { target: row; property: "opacity"; to: 1; duration: Motion.ms(240); easing.type: Easing.OutCubic }
                                NumberAnimation { target: rowShift; property: "y"; from: 10; to: 0; duration: Motion.ms(320); easing.type: Easing.OutCubic }
                                NumberAnimation {
                                    target: row; property: "scale"; from: Motion.pick(0.98, 0.95, 0.9); to: 1; duration: Motion.ms(320)
                                    easing.type: Easing.OutBack; easing.overshoot: Motion.pick(0.3, 0.6, 1.2)
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: row.selected ? Theme.selectionTint : "transparent"

                            Rectangle {
                                visible: row.selected
                                width: 3
                                height: parent.height - 14
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 2
                                color: Theme.accent
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28

                                Image {
                                    anchors.fill: parent
                                    visible: !row.modelData.isCommand && !row.modelData.isSettings
                                    source: (row.modelData.isCommand || row.modelData.isSettings) ? "" : Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                                    sourceSize.width: 56
                                    sourceSize.height: 56
                                    asynchronous: true
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    visible: row.modelData.isCommand === true || row.modelData.isSettings === true
                                    text: row.modelData.isSettings ? Icons.sliders : Icons.terminal
                                    color: Theme.accent
                                    size: 22
                                }
                            }

                            // Só o nome (a descrição do .desktop continua valendo na busca)
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                color: row.selected ? Theme.fgBright : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.textBody
                                font.bold: row.selected
                                elide: Text.ElideRight
                            }

                            // Estrela: marca/desmarca o favorito. Aparece na linha selecionada ou sob o mouse e, na
                            // lista de todos os apps, nas favoritas (na lista só de favoritos todas seriam estrelas)
                            MouseArea {
                                id: star
                                readonly property bool fav: win.favs[row.modelData.id] === true
                                visible: !row.modelData.isCommand && !row.modelData.isSettings
                                         && ((fav && !Settings.data.launcherFavoritesOnly) || row.selected || row.containsMouse)
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 28
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.toggleFavorite(row.modelData)

                                Icon {
                                    anchors.centerIn: parent
                                    text: Icons.star
                                    filled: star.fav
                                    color: star.fav || star.containsMouse ? Theme.accent : Theme.fgDim
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: win.results.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                    text: !Settings.data.launcherFavoritesOnly ? "Nada encontrado. Use > para executar como comando."
                        : win.hasFavorites ? "Nenhum favorito encontrado."
                        : "Nenhum favorito ainda. Clique na estrela ao lado da busca (ou Ctrl+F) para ver todos os aplicativos e marque os seus."
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                }

                Text {
                    id: hint
                    Layout.fillWidth: true
                    opacity: Motion.enabled ? 0 : 1
                    horizontalAlignment: Text.AlignHCenter
                    text: (Settings.data.launcherFavoritesOnly ? "Ctrl+F todos os apps" : "Ctrl+F só favoritos") + " · Ctrl+D marcar"
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
