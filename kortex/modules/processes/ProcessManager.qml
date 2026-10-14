import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

// Gerenciador de Processos: o que está rodando, agrupado por aplicativo, com CPU e memória.
//   Digite para filtrar · Esc limpa a busca ou fecha · clique no cabeçalho de uma coluna para ordenar
//   Clique num grupo para ver os processos dele · Encerrar pede confirmação e, se o programa não
//   responder em 3 s, aparece Forçar.
// Enquanto o mouse está sobre a lista a ordem fica parada (os números continuam mudando), para a
// linha não fugir do clique.
LazyLoader {
    active: Popups.processesOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-processes"
        panelWidth: Math.min(780, (win.screen?.width ?? 1280) - 80)
        panelHeight: Math.min(640, (win.screen?.height ?? 800) - 100)
        onDismissed: close()

        function close() { Popups.processesOpen = false }

        readonly property string sort: Settings.data.processSort
        readonly property int cpuWidth: 64
        readonly property int memWidth: 84
        readonly property int actionWidth: 160

        property var expanded: ({})       // chave do grupo → aberto
        property string confirmKey: ""    // linha pedindo confirmação de encerrar
        property bool holdOrder: false
        property var _rank: ({})          // chave → posição na última ordenação (para segurar a ordem)
        property var _keys: []            // chaves na ordem do rowModel (espelho, evita rowModel.get)

        readonly property int procCount: Processes.groups.reduce((s, g) => s + g.procs.length, 0)

        onHoldOrderChanged: if (!holdOrder) rebuild()
        onExpandedChanged: rebuild()
        onSortChanged: rebuild()

        Connections {
            target: Processes
            function onGroupsChanged() { win.rebuild() }
            function onEndingChanged() { win.rebuild() }
        }

        function toggleExpanded(key) {
            const e = Object.assign({}, expanded)
            if (e[key]) delete e[key]
            else e[key] = true
            expanded = e
        }

        function setSort(s) { Settings.data.processSort = s }

        function askOrEnd(key, pid) {
            if (confirmKey !== key) {
                confirmKey = key
                resetConfirm.restart()
                return
            }
            confirmKey = ""
            Processes.end(pid)
        }

        function focusApp(pid) {
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "pid:" + pid])
            close()
        }

        function _state(pid, now) {
            if (Processes.ending[pid] === undefined) return ""
            return Processes.stuck(pid, now) ? "stuck" : "ending"
        }

        function _cmp(a, b) {
            if (sort === "name") return a.name.localeCompare(b.name)
            if (sort === "mem") return (b.mem - a.mem) || (b.cpu - a.cpu)
            return (b.cpu - a.cpu) || (b.mem - a.mem)
        }

        function _order(list, prefix) {
            const rank = _rank
            const cmp = (a, b) => win._cmp(a, b)
            if (!holdOrder) return list.slice().sort(cmp)
            // ordem parada: quem já estava fica onde estava; quem chegou vai para o fim
            return list.slice().sort((a, b) => ((rank[prefix + a.key] ?? 1e9) - (rank[prefix + b.key] ?? 1e9)) || cmp(a, b))
        }

        // Linhas da lista: cabeçalhos de seção, grupos e (dos grupos abertos) os processos.
        // Todas com os mesmos campos, porque o ListModel exige.
        function rebuild() {
            const q = search.text.trim().toLowerCase()
            const now = Date.now()
            const rows = []
            const row = o => Object.assign({
                kind: "", key: "", pid: 0, name: "", sub: "", icon: "", isApp: false, essential: false,
                cpu: 0, mem: 0, count: 0, open: false, pids: "", state: "", last: false
            }, o)

            const hit = s => s.toLowerCase().includes(q)
            const procHit = p => hit(p.name) || hit(p.cmd) || String(p.pid) === q

            const sections = [
                { title: "Aplicativos", groups: Processes.groups.filter(g => g.isApp) },
                { title: "Em segundo plano", groups: Processes.groups.filter(g => !g.isApp) }
            ]
            for (const sec of sections) {
                const shown = []
                for (const g of sec.groups) {
                    if (!q) { shown.push({ g: g, procs: g.procs, forced: false }); continue }
                    const groupHit = hit(g.name) || hit(g.title)
                    const procs = g.procs.filter(procHit)
                    if (groupHit) shown.push({ g: g, procs: g.procs, forced: false })
                    else if (procs.length > 0) shown.push({ g: g, procs: procs, forced: true })
                }
                if (shown.length === 0) continue
                rows.push(row({ kind: "header", key: "h" + sec.title, name: sec.title, count: shown.length }))

                const byKey = {}
                for (const s of shown) byKey[s.g.key] = s
                const ordered = _order(shown.map(s => s.g), "g")
                for (const g of ordered) {
                    const s = byKey[g.key]
                    const many = g.procs.length > 1
                    const open = many && (expanded[g.key] === true || s.forced)
                    const state = _state(g.pid, now)
                    rows.push(row({
                        kind: "group", key: "g" + g.key, pid: g.pid, name: g.name, icon: g.icon,
                        isApp: g.isApp, essential: g.essential, cpu: g.cpu, mem: g.mem,
                        count: g.procs.length, open: open, pids: g.procs.map(p => p.pid).join(","),
                        state: state,
                        sub: state === "stuck" ? "Não respondeu. Use Forçar para fechar."
                           : state === "ending" ? "Encerrando…"
                           : g.title !== "" ? g.title
                           : many ? g.procs.length + " processos" : ""
                    }))
                    if (!open) continue
                    const procs = _order(s.procs.map(p => Object.assign({ key: String(p.pid) }, p)), "p")
                    procs.forEach((p, i) => rows.push(row({
                        kind: "proc", key: "p" + p.pid, pid: p.pid, name: p.name, essential: g.essential,
                        cpu: p.cpu, mem: p.mem, count: 1, pids: String(p.pid), state: _state(p.pid, now),
                        sub: "PID " + p.pid, last: i === procs.length - 1
                    })))
                }
            }

            if (!holdOrder) {
                const r = {}
                rows.forEach((x, i) => r[x.key] = i)
                _rank = r
            }
            _sync(rows)
        }

        // Atualiza o rowModel no lugar (mover e alterar em vez de recriar): as linhas não piscam
        // e o mouse continua sobre a mesma linha
        function _sync(rows) {
            const keys = _keys.slice()
            for (let i = 0; i < rows.length; i++) {
                const r = rows[i]
                const j = keys.indexOf(r.key, i)
                if (j < 0) {
                    rowModel.insert(i, r)
                    keys.splice(i, 0, r.key)
                } else {
                    if (j !== i) {
                        rowModel.move(j, i, 1)
                        keys.splice(i, 0, keys.splice(j, 1)[0])
                    }
                    rowModel.set(i, r)
                }
            }
            if (keys.length > rows.length) {
                rowModel.remove(rows.length, keys.length - rows.length)
                keys.length = rows.length
            }
            _keys = keys
        }

        ListModel { id: rowModel }

        Timer {
            id: resetConfirm
            interval: 3000
            onTriggered: win.confirmKey = ""
        }

        Component.onCompleted: {
            rebuild()
            search.focusInput()
        }

        // Título de coluna que ordena a lista; a coluna em uso fica no acento, com a seta
        component SortHeader: MouseArea {
            id: head
            property string text: ""
            property string value: ""
            property bool alignRight: false
            readonly property bool current: win.sort === value

            implicitHeight: 22
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.setSort(value)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: head.alignRight ? parent.right : undefined
                anchors.left: head.alignRight ? undefined : parent.left
                spacing: 3

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: head.text
                    color: head.current ? Theme.accent : head.containsMouse ? Theme.fgBright : Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    font.bold: head.current
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: head.current
                    // nome em ordem alfabética (sobe); CPU e memória do maior para o menor (desce)
                    text: head.value === "name" ? Icons.sortUp : Icons.sortDown
                    color: Theme.accent
                    size: Theme.textSmall + 1
                }
            }
        }

        GradientFrame {
            anchors.fill: parent
            color: Theme.bg
            radius: Theme.radius

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                PopupTitle {
                    text: "Processos"
                    icon: Icons.processes
                    subtitle: (win.procCount > 0 ? win.procCount + " processos  ·  " : "")
                              + "CPU " + SystemStats.pct(SystemStats.cpu)
                              + "  ·  Memória " + SystemStats.sizePair(SystemStats.memUsedGb, SystemStats.memTotalGb)

                    PlainButton {
                        icon: Icons.terminal
                        text: "Monitor do Sistema"
                        onClicked: {
                            win.close()
                            Settings.runInTerminal(["btop"])
                        }
                    }
                    PlainButton {
                        icon: Icons.close
                        implicitWidth: 34
                        onClicked: win.close()
                    }
                }

                Field {
                    id: search
                    icon: Icons.search
                    implicitHeight: 38
                    placeholder: "Buscar por nome, comando ou PID"
                    onTextChanged: win.rebuild()
                    onKeyPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            if (search.text !== "") search.text = ""
                            else win.close()
                            event.accepted = true
                        }
                    }
                }

                // Cabeçalho das colunas: clicar ordena
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 10
                    spacing: 0

                    SortHeader {
                        Layout.fillWidth: true
                        text: "Nome"
                        value: "name"
                    }
                    SortHeader {
                        Layout.preferredWidth: win.cpuWidth
                        text: "CPU"
                        value: "cpu"
                        alignRight: true
                    }
                    SortHeader {
                        Layout.preferredWidth: win.memWidth
                        text: "Memória"
                        value: "mem"
                        alignRight: true
                    }
                    Item { Layout.preferredWidth: win.actionWidth }
                }

                ListView {
                    id: list
                    visible: rowModel.count > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: rowModel
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: false

                    HoverHandler {
                        onHoveredChanged: win.holdOrder = hovered
                    }

                    // Sem animação de entrada/saída: a lista muda a cada 2 s e animar distrai
                    delegate: Item {
                        id: line
                        required property int index
                        required property string kind
                        required property string key
                        required property int pid
                        required property string name
                        required property string sub
                        required property string icon
                        required property bool isApp
                        required property bool essential
                        required property real cpu
                        required property real mem
                        required property int count
                        required property bool open
                        required property string pids
                        required property string state
                        required property bool last

                        readonly property bool isHeader: kind === "header"
                        readonly property bool isGroup: kind === "group"
                        readonly property bool asking: win.confirmKey === key
                        readonly property bool hovered: hover.containsMouse || endBtn.containsMouse || goBtn.containsMouse

                        width: ListView.view.width
                        height: isHeader ? 34 : isGroup ? 48 : 34

                        // ── Cabeçalho de seção ──
                        Text {
                            visible: line.isHeader
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 7
                            text: line.name + "  ·  " + line.count
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.textSmall
                            font.bold: true
                        }

                        // ── Grupo ou processo ──
                        MouseArea {
                            id: hover
                            visible: !line.isHeader
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: line.isGroup && line.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (line.isGroup && line.count > 1) win.toggleExpanded(line.key.slice(1))

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: line.state === "stuck" ? Qt.tint(Theme.bg, Qt.alpha(Theme.red, 0.14))
                                     : line.hovered || line.asking ? Theme.selectionTint : "transparent"
                            }

                            // fio que liga os processos ao grupo aberto
                            Rectangle {
                                visible: line.kind === "proc"
                                x: 25
                                width: 1
                                height: line.last ? parent.height / 2 : parent.height
                                color: Theme.outline
                                opacity: 0.6
                            }
                            Rectangle {
                                visible: line.kind === "proc"
                                x: 25
                                y: parent.height / 2
                                width: 10
                                height: 1
                                color: Theme.outline
                                opacity: 0.6
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: line.isGroup ? 12 : 44
                                anchors.rightMargin: 10
                                spacing: 0

                                // ícone do aplicativo (ou do serviço) com a seta de abrir o grupo
                                Item {
                                    visible: line.isGroup
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    Layout.rightMargin: 12

                                    Image {
                                        anchors.fill: parent
                                        visible: line.isApp
                                        source: line.isApp ? Quickshell.iconPath(line.icon, "application-x-executable") : ""
                                        sourceSize.width: 56
                                        sourceSize.height: 56
                                        asynchronous: true
                                    }
                                    Icon {
                                        anchors.centerIn: parent
                                        visible: !line.isApp
                                        text: line.essential ? Icons.lock : Icons.background
                                        color: Theme.fgDim
                                        size: 22
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 1

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            Layout.preferredWidth: implicitWidth
                                            Layout.minimumWidth: 0
                                            text: line.name
                                            color: line.state !== "" ? Theme.fgDim : line.hovered ? Theme.fgBright : Theme.fg
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textBody
                                            font.bold: line.isGroup && line.isApp
                                            elide: Text.ElideRight
                                        }
                                        Icon {
                                            visible: line.isGroup && line.count > 1
                                            text: line.open ? Icons.up : Icons.down
                                            color: Theme.fgDim
                                            size: Theme.iconSize - 2
                                        }
                                        Text {
                                            visible: line.kind === "proc"
                                            text: line.sub
                                            color: Theme.fgDim
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSmall
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    Text {
                                        visible: line.isGroup && line.sub !== ""
                                        Layout.fillWidth: true
                                        text: line.sub
                                        color: line.state === "stuck" ? Theme.red : Theme.fgDim
                                        font.family: Theme.font
                                        font.pixelSize: Theme.textSmall
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: win.cpuWidth
                                    horizontalAlignment: Text.AlignRight
                                    text: Processes.cpuText(line.cpu)
                                    color: line.cpu >= 0.5 ? Theme.red : line.cpu >= 0.2 ? Theme.yellow : Theme.fg
                                    opacity: line.cpu < 0.001 ? 0.55 : 1
                                    font.family: Theme.font
                                    font.pixelSize: line.isGroup ? Theme.textBody : Theme.textSmall
                                }

                                Text {
                                    Layout.preferredWidth: win.memWidth
                                    horizontalAlignment: Text.AlignRight
                                    text: Processes.memText(line.mem)
                                    color: line.mem >= 4194304 ? Theme.yellow : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: line.isGroup ? Theme.textBody : Theme.textSmall
                                }

                                // Ações: aparecem sob o mouse (ou enquanto pedem confirmação / insistem em Forçar)
                                Item {
                                    Layout.preferredWidth: win.actionWidth
                                    Layout.fillHeight: true

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        MouseArea {
                                            id: goBtn
                                            visible: line.isGroup && line.isApp && line.hovered && !line.asking && line.state === ""
                                            width: 28
                                            height: 28
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.focusApp(line.pid)

                                            GradientBorder {
                                                anchors.fill: parent
                                                radius: Theme.radiusSmall
                                                borderWidth: 1
                                                fill: goBtn.containsMouse ? Theme.bgAlt : "transparent"
                                                color: goBtn.containsMouse ? Theme.accent : Theme.outline
                                            }
                                            Icon {
                                                anchors.centerIn: parent
                                                text: Icons.focusWindow
                                                color: goBtn.containsMouse ? Theme.fgBright : Theme.fg
                                                size: Theme.iconSize - 2
                                            }
                                        }

                                        EndButton {
                                            id: endBtn
                                            visible: !line.essential && line.state !== "ending"
                                                     && (line.state === "stuck" || line.asking || line.hovered)
                                            urgent: line.state === "stuck"
                                            asking: line.asking
                                            text: line.state === "stuck" ? "Forçar" : line.asking ? "Confirmar" : "Encerrar"
                                            onClicked: {
                                                if (line.state === "stuck") Processes.forceEnd(line.pids.split(",").map(Number))
                                                else win.askOrEnd(line.key, line.pid)
                                            }
                                        }

                                        Text {
                                            visible: line.essential && line.isGroup && line.hovered
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Essencial"
                                            color: Theme.fgDim
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSmall
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: rowModel.count === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: !Processes.loaded ? "Lendo os processos…" : "Nenhum processo encontrado."
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textBody
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Encerrar pede ao programa para fechar · se ele não responder, aparece Forçar"
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
