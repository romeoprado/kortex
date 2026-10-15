import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

// Gerenciador de Processos: o que está rodando, agrupado por aplicativo, com CPU e memória.
//   Digite para filtrar · ↑/↓ escolhem a linha · Enter abre ou fecha o grupo · Delete encerra
//   (de novo para confirmar) · Esc limpa a busca ou fecha
//   Clique no título de uma coluna para ordenar e no de uma seção para recolhê-la.
// Os botões da linha (ir para a janela, Encerrar) aparecem por cima do fim do nome, na linha
// escolhida: nenhuma coluna fica reservada para eles. Encerrar pede confirmação e, se o programa
// não responder em 3 s, vira Forçar.
// Com o mouse sobre a lista (ou logo depois de usar as setas) a ordem fica parada e só os números
// mudam, para a linha não fugir do clique.
LazyLoader {
    active: Popups.processesOpen

    OverlayPanel {
        id: win

        layerNamespace: "kortex-processes"
        panelWidth: Math.min(720, (win.screen?.width ?? 1280) - 80)
        panelHeight: Math.min(660, (win.screen?.height ?? 800) - 100)
        onDismissed: close()

        function close() { Popups.processesOpen = false }

        readonly property string sort: Settings.data.processSort
        readonly property int cpuWidth: 72
        readonly property int memWidth: 88
        readonly property int iconColumn: 40     // ícone (28) + espaço até o nome
        readonly property int rowPadding: 12

        property var expanded: ({})       // chave do grupo → aberto
        property var collapsed: ({})      // título da seção → recolhida
        property string currentKey: ""    // linha escolhida (mouse ou setas)
        property string confirmKey: ""    // linha pedindo confirmação de encerrar
        property bool keyboardNav: false  // usou as setas há pouco: segura a ordem como o mouse
        readonly property bool holdOrder: listHover.hovered || keyboardNav
        property var _rank: ({})          // chave → posição na última ordenação (para segurar a ordem)
        property var _keys: []            // chaves na ordem do rowModel (espelho, evita rowModel.get)
        property var _kinds: []           // tipo de cada linha, na mesma ordem

        readonly property int procCount: Processes.groups.reduce((s, g) => s + g.procs.length, 0)

        onHoldOrderChanged: if (!holdOrder) rebuild()
        onExpandedChanged: rebuild()
        onCollapsedChanged: rebuild()
        onSortChanged: rebuild()

        Connections {
            target: Processes
            function onGroupsChanged() { win.rebuild() }
            function onEndingChanged() { win.rebuild() }
        }

        function toggleIn(map, key) {
            const m = Object.assign({}, map)
            if (m[key]) delete m[key]
            else m[key] = true
            return m
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

        // ── Teclado ─────────────────────────────────────────────────────
        function _selectable(i) { return _kinds[i] === "group" || _kinds[i] === "proc" }

        function move(step) {
            // sem escolha visível (mouse fora da lista), a primeira seta começa do topo
            const fresh = !keyboardNav && !listHover.hovered
            keyboardNav = true
            navIdle.restart()
            let i = fresh ? -1 : _keys.indexOf(currentKey)
            if (i < 0) i = fresh || step > 0 ? -1 : _keys.length
            if (fresh) step = 1
            for (let j = i + step; j >= 0 && j < _keys.length; j += step) {
                if (_selectable(j)) {
                    currentKey = _keys[j]
                    list.positionViewAtIndex(j, ListView.Contain)
                    return
                }
            }
        }

        function current() {
            const i = _keys.indexOf(currentKey)
            return i >= 0 ? rowModel.get(i) : null
        }

        function activateCurrent() {
            const r = current()
            if (r && r.kind === "group" && r.count > 1) expanded = toggleIn(expanded, r.key.slice(1))
        }

        function endCurrent() {
            const r = current()
            if (!r || r.essential || r.state === "ending") return
            if (r.state === "stuck") Processes.forceEnd(r.pids.split(",").map(Number))
            else askOrEnd(r.key, r.pid)
        }

        // ── Linhas ──────────────────────────────────────────────────────
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
                // buscando, a seção recolhida abre: o resultado não pode ficar escondido
                const closed = collapsed[sec.title] === true && !q
                rows.push(row({ kind: "header", key: "h" + sec.title, name: sec.title, count: shown.length, open: !closed }))
                if (closed) continue

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
                        sub: state === "stuck" ? "Não respondeu"
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
            _kinds = rows.map(x => x.kind)

            // a linha escolhida sumiu (o processo saiu, o grupo fechou): vale a primeira da lista
            if (!rows.some(x => x.key === currentKey && x.kind !== "header")) {
                const first = rows.find(x => x.kind !== "header")
                currentKey = first ? first.key : ""
            }
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

        Timer {
            id: navIdle
            interval: 3000
            onTriggered: win.keyboardNav = false
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

            implicitHeight: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.setSort(value)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: head.alignRight ? parent.right : undefined
                anchors.left: head.alignRight ? undefined : parent.left
                spacing: 3

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: head.current && head.alignRight
                    text: Icons.sortDown
                    color: Theme.accent
                    size: Theme.textSmall + 1
                }
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
                    visible: head.current && !head.alignRight
                    text: Icons.sortUp
                    color: Theme.accent
                    size: Theme.textSmall + 1
                }
            }
        }

        // Medidor compacto do cabeçalho: rótulo, valor e a barra de uso
        component Meter: ColumnLayout {
            id: meter
            property string label: ""
            property string value: ""
            property real frac: 0
            Layout.preferredWidth: 140
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: meter.label
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: meter.value
                    color: Theme.fgBright
                    font.family: Theme.font
                    font.pixelSize: Theme.textSmall
                    font.bold: true
                }
            }
            StatBar {
                Layout.fillWidth: true
                value: meter.frac
                color: Theme.bgDark
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
                    subtitle: win.procCount > 0
                              ? win.procCount + " processos em " + Processes.groups.length + " grupos"
                              : "Lendo os processos…"

                    PlainButton {
                        icon: Icons.close
                        implicitWidth: 34
                        onClicked: win.close()
                    }
                }

                // Busca e o uso total da máquina
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Field {
                        id: search
                        icon: Icons.search
                        implicitHeight: 38
                        placeholder: "Nome, comando ou PID"
                        onTextChanged: win.rebuild()
                        onAccepted: win.activateCurrent()
                        onKeyPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            if (event.key === Qt.Key_Escape) {
                                if (search.text !== "") search.text = ""
                                else win.close()
                            } else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                                win.move(1)
                            } else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                                win.move(-1)
                            } else if (event.key === Qt.Key_Delete && search.input.cursorPosition === search.text.length) {
                                // no fim do texto o Delete não apagaria nada: encerra a linha escolhida
                                win.endCurrent()
                            } else {
                                return
                            }
                            event.accepted = true
                        }
                    }

                    Meter {
                        label: "CPU"
                        value: SystemStats.pct(SystemStats.cpu)
                        frac: SystemStats.cpu
                    }
                    Meter {
                        label: "Memória"
                        value: SystemStats.sizePair(SystemStats.memUsedGb, SystemStats.memTotalGb)
                        frac: SystemStats.mem
                    }
                }

                // A lista, numa área um pouco mais escura: separa os dados dos controles
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusSmall
                    color: Theme.bgDark

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 0

                        // Títulos das colunas: clicar ordena
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: win.rowPadding + win.iconColumn
                            Layout.rightMargin: win.rowPadding
                            Layout.topMargin: 4
                            Layout.bottomMargin: 2
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
                        }

                        ListView {
                            id: list
                            visible: rowModel.count > 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: rowModel
                            boundsBehavior: Flickable.StopAtBounds

                            HoverHandler { id: listHover }

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
                                // a escolha só aparece com o mouse na lista ou depois das setas: ao abrir,
                                // nenhuma linha parece escolhida por acaso
                                readonly property bool current: win.currentKey === key && !isHeader
                                                                && (listHover.hovered || win.keyboardNav)
                                readonly property bool asking: win.confirmKey === key
                                readonly property bool stuck: state === "stuck"
                                // botões por cima do nome: na linha escolhida, pedindo confirmação ou sem resposta
                                readonly property bool showActions: !isHeader && state !== "ending"
                                    && (stuck || asking || current)
                                readonly property color rowColor: stuck ? Qt.tint(Theme.bgDark, Qt.alpha(Theme.red, 0.16))
                                                                : current || asking ? Theme.selectionTint : Theme.bgDark

                                width: ListView.view.width
                                height: isHeader ? 36 : isGroup ? 50 : 34

                                // ── Cabeçalho de seção: clique recolhe ──
                                MouseArea {
                                    id: sectionHit
                                    visible: line.isHeader
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.collapsed = win.toggleIn(win.collapsed, line.name)

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: win.rowPadding
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 6
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: line.name
                                            color: sectionHit.containsMouse ? Theme.fgBright : Theme.accent
                                            font.family: Theme.font
                                            font.pixelSize: Theme.textSmall
                                            font.bold: true
                                        }
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitWidth: countLabel.implicitWidth + 12
                                            implicitHeight: countLabel.implicitHeight + 2
                                            radius: height / 2
                                            color: Theme.bgAlt
                                            Text {
                                                id: countLabel
                                                anchors.centerIn: parent
                                                text: line.count
                                                color: Theme.fg
                                                font.family: Theme.font
                                                font.pixelSize: Theme.textSmall - 1
                                            }
                                        }
                                        Icon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: line.open ? Icons.up : Icons.down
                                            color: Theme.fgDim
                                            size: Theme.iconSize - 2
                                        }
                                    }
                                }

                                // ── Grupo ou processo ──
                                MouseArea {
                                    id: hover
                                    visible: !line.isHeader
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: line.isGroup && line.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onPositionChanged: win.currentKey = line.key
                                    onEntered: win.currentKey = line.key
                                    onClicked: if (line.isGroup && line.count > 1) win.expanded = win.toggleIn(win.expanded, line.key.slice(1))

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: line.rowColor

                                        // marca da linha escolhida, como no lançador
                                        Rectangle {
                                            visible: line.current && !line.stuck
                                            width: 3
                                            height: parent.height - 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            radius: 2
                                            color: Theme.accent
                                        }
                                    }

                                    // fio que liga os processos ao grupo aberto (sob o centro do ícone)
                                    Rectangle {
                                        visible: line.kind === "proc"
                                        x: win.rowPadding + 14
                                        width: 1
                                        height: line.last ? parent.height / 2 : parent.height
                                        color: Theme.outline
                                        opacity: 0.6
                                    }
                                    Rectangle {
                                        visible: line.kind === "proc"
                                        x: win.rowPadding + 14
                                        y: parent.height / 2
                                        width: 14
                                        height: 1
                                        color: Theme.outline
                                        opacity: 0.6
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: win.rowPadding
                                        anchors.rightMargin: win.rowPadding
                                        spacing: 0

                                        // ícone: o do aplicativo ou, no fundo, o de serviço
                                        Item {
                                            Layout.preferredWidth: win.iconColumn
                                            Layout.fillHeight: true

                                            Image {
                                                visible: line.isGroup && line.isApp
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 28
                                                height: 28
                                                source: line.isGroup && line.isApp ? Quickshell.iconPath(line.icon, "application-x-executable") : ""
                                                sourceSize.width: 56
                                                sourceSize.height: 56
                                                asynchronous: true
                                            }
                                            Icon {
                                                visible: line.isGroup && !line.isApp
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: (28 - width) / 2
                                                text: Icons.background
                                                color: Theme.fgDim
                                                size: 22
                                            }
                                        }

                                        // nome e legenda, com os botões por cima do fim quando aparecem
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            ColumnLayout {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6

                                                    Text {
                                                        Layout.preferredWidth: implicitWidth
                                                        Layout.minimumWidth: 0
                                                        text: line.name
                                                        color: line.state !== "" ? Theme.fgDim : line.current ? Theme.fgBright : Theme.fg
                                                        font.family: Theme.font
                                                        font.pixelSize: line.isGroup ? Theme.textBody : Theme.textSmall + 1
                                                        font.bold: line.isGroup && line.isApp
                                                        elide: Text.ElideRight
                                                    }
                                                    // essencial para a sessão: sem Encerrar
                                                    Icon {
                                                        visible: line.isGroup && line.essential
                                                        text: Icons.lock
                                                        color: Theme.fgDim
                                                        size: Theme.textSmall
                                                    }
                                                    Text {
                                                        visible: line.kind === "proc"
                                                        text: line.sub
                                                        color: Theme.fgDim
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.textSmall
                                                    }
                                                    Icon {
                                                        visible: line.isGroup && line.count > 1
                                                        text: line.open ? Icons.up : Icons.down
                                                        color: Theme.fgDim
                                                        size: Theme.iconSize - 2
                                                    }
                                                    Item { Layout.fillWidth: true }
                                                }

                                                Text {
                                                    visible: line.isGroup && line.sub !== ""
                                                    Layout.fillWidth: true
                                                    text: line.sub
                                                    color: line.stuck ? Theme.red : Theme.fgDim
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSmall
                                                    font.bold: line.stuck
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // Botões: um degradê na cor da linha apaga o texto por baixo
                                            Rectangle {
                                                visible: line.showActions
                                                anchors.right: actions.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: 36
                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop { position: 0; color: Qt.alpha(line.rowColor, 0) }
                                                    GradientStop { position: 1; color: line.rowColor }
                                                }
                                            }
                                            Rectangle {
                                                visible: line.showActions
                                                anchors.fill: actions
                                                anchors.leftMargin: -1
                                                color: line.rowColor
                                            }

                                            Row {
                                                id: actions
                                                visible: line.showActions
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                Text {
                                                    visible: line.essential
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Essencial para a sessão"
                                                    color: Theme.fgDim
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.textSmall
                                                }

                                                MouseArea {
                                                    id: goBtn
                                                    visible: line.isGroup && line.isApp && !line.asking && !line.stuck
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
                                                    visible: !line.essential
                                                    urgent: line.stuck
                                                    asking: line.asking
                                                    text: line.stuck ? "Forçar" : line.asking ? "Confirmar" : "Encerrar"
                                                    onClicked: {
                                                        if (line.stuck) Processes.forceEnd(line.pids.split(",").map(Number))
                                                        else win.askOrEnd(line.key, line.pid)
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.preferredWidth: win.cpuWidth
                                            horizontalAlignment: Text.AlignRight
                                            text: Processes.cpuText(line.cpu)
                                            color: line.cpu >= 0.5 ? Theme.red : line.cpu >= 0.2 ? Theme.yellow : Theme.fg
                                            opacity: line.cpu < 0.001 ? 0.45 : 1
                                            font.family: Theme.font
                                            font.pixelSize: line.isGroup ? Theme.textBody : Theme.textSmall
                                            font.bold: line.isGroup && win.sort === "cpu"
                                        }

                                        Text {
                                            Layout.preferredWidth: win.memWidth
                                            horizontalAlignment: Text.AlignRight
                                            text: Processes.memText(line.mem)
                                            color: line.mem >= 4194304 ? Theme.yellow : Theme.fg
                                            font.family: Theme.font
                                            font.pixelSize: line.isGroup ? Theme.textBody : Theme.textSmall
                                            font.bold: line.isGroup && win.sort === "mem"
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
                    }
                }

                // Rodapé: os atalhos e o monitor completo
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        Layout.fillWidth: true
                        text: "↑↓ escolher  ·  Enter abrir  ·  Del encerrar  ·  Esc fechar"
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.textSmall
                        elide: Text.ElideRight
                    }

                    PlainButton {
                        icon: Icons.terminal
                        text: "Monitor do Sistema"
                        onClicked: {
                            win.close()
                            Settings.runInTerminal(["btop"])
                        }
                    }
                }
            }
        }
    }
}
