import QtQuick 2.15

// Tela de login do Kortex. As cores vêm de theme.conf / theme.conf.user, que o shell reescreve
// a cada troca de tema (scripts/sddm-colors.sh); os valores de cfg() abaixo são o Morello.
// O visual acompanha a tela de bloqueio (hyprlock): relógio, campo de senha com contorno em degradê.
Rectangle {
    id: root
    width: 1280
    height: 800
    color: bg

    function cfg(key, fallback) {
        const v = config[key]
        return (v !== undefined && String(v) !== "") ? String(v) : fallback
    }

    readonly property color bg: cfg("bg", "#222222")
    readonly property color bgAlt: cfg("bgAlt", "#343434")
    readonly property color fg: cfg("fg", "#ffffff")
    readonly property color fgBright: cfg("fgBright", "#ffffff")
    readonly property color fgDim: cfg("fgDim", "#9c9c9c")
    readonly property color accent: cfg("accent", "#686868")
    readonly property color accent2: cfg("accent2", "#393939")
    readonly property color red: cfg("red", "#7c7c7c")
    readonly property color yellow: cfg("yellow", "#a0a0a0")
    readonly property string family: cfg("font", "JetBrainsMono Nerd Font")

    // O greeter não conhece a escala do monitor: dimensiona tudo pela altura da tela (900 = 1×).
    readonly property real u: Math.max(0.7, height / 900)

    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property string userName: userModel.lastUser
    property string sessionName: ""
    property bool busy: false
    property bool failed: false
    property date now: new Date()

    readonly property bool capsLock: typeof keyboard !== "undefined" && keyboard.capsLock
    readonly property int layoutCount: (typeof keyboard !== "undefined" && keyboard.layouts) ? keyboard.layouts.length : 0

    function login() {
        if (busy || userName === "") return
        busy = true
        failed = false
        sddm.login(userName, password.text, sessionIndex)
    }

    function cycleUser() {
        if (users.count > 1) userIndex = (userIndex + 1) % users.count
        password.text = ""
        failed = false
        password.forceActiveFocus()
    }

    function cycleSession() {
        if (sessions.count > 1) sessionIndex = (sessionIndex + 1) % sessions.count
        password.forceActiveFocus()
    }

    function cycleLayout() {
        if (layoutCount > 1) keyboard.currentLayout = (keyboard.currentLayout + 1) % layoutCount
        password.forceActiveFocus()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Rede de segurança: se o SDDM nunca responder, o campo de senha não fica travado para sempre.
    Timer {
        interval: 20000
        running: root.busy
        onTriggered: {
            root.busy = false
            password.forceActiveFocus()
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.failed = true
            password.text = ""
            shake.restart()
            password.forceActiveFocus()
        }
    }

    // Os modelos do SDDM só entregam os papéis dentro de um delegate: cada item avisa quando é o atual.
    Repeater {
        id: users
        model: userModel
        delegate: Item {
            readonly property bool current: index === root.userIndex
            onCurrentChanged: if (current) root.userName = model.name
            Component.onCompleted: if (current) root.userName = model.name
        }
    }
    Repeater {
        id: sessions
        model: sessionModel
        delegate: Item {
            readonly property bool current: index === root.sessionIndex
            onCurrentChanged: if (current) root.sessionName = model.name
            Component.onCompleted: if (current) root.sessionName = model.name
        }
    }
    Repeater {
        id: realNames
        model: userModel
        delegate: Item {
            visible: false
            readonly property string label: model.realName !== "" ? model.realName : model.name
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: password.forceActiveFocus()
    }

    Column {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -60 * root.u
        spacing: 6 * root.u
        transform: Translate { id: shiftX }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale().toString(root.now, Qt.locale().timeFormat(Locale.ShortFormat))
            color: root.fgBright
            font.family: root.family
            font.pixelSize: 96 * root.u
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale().toString(root.now, Qt.locale().dateFormat(Locale.LongFormat))
            color: root.fgDim
            font.family: root.family
            font.pixelSize: 17 * root.u
        }
        Item { width: 1; height: 34 * root.u }

        // Nome do usuário; com mais de um, um clique passa para o próximo.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: nameText.width + 8 * root.u
            height: nameText.height + 6 * root.u
            Text {
                id: nameText
                anchors.centerIn: parent
                text: {
                    const item = realNames.itemAt(root.userIndex)
                    return item ? item.label : root.userName
                }
                color: root.fg
                font.family: root.family
                font.pixelSize: 20 * root.u
            }
            MouseArea {
                anchors.fill: parent
                enabled: users.count > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.cycleUser()
            }
        }
        Item { width: 1; height: 4 * root.u }

        // Contorno em degradê (accent → accent2), como no campo de senha do hyprlock.
        Rectangle {
            id: ring
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340 * root.u
            height: 52 * root.u
            radius: 9 * root.u
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.failed ? root.red : root.busy ? root.yellow : root.accent }
                GradientStop { position: 1.0; color: root.failed ? root.red : root.busy ? root.yellow : root.accent2 }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2 * root.u
                radius: 7 * root.u
                color: root.bgAlt

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 16 * root.u
                    anchors.rightMargin: 16 * root.u
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.fgBright
                    selectionColor: root.accent
                    selectedTextColor: root.bg
                    font.family: root.family
                    font.pixelSize: 18 * root.u
                    clip: true
                    focus: true
                    enabled: !root.busy
                    onAccepted: root.login()
                    onTextChanged: if (text.length > 0) root.failed = false
                    Keys.onEscapePressed: text = ""
                    Component.onCompleted: forceActiveFocus()
                }

                Text {
                    anchors.centerIn: parent
                    visible: password.text.length === 0
                    text: root.busy ? "Entrando…" : "Senha…"
                    color: root.busy ? root.yellow : root.fgDim
                    font.family: root.family
                    font.pixelSize: 18 * root.u
                }
            }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: shiftX; property: "x"; to: -14 * root.u; duration: 50 }
                NumberAnimation { target: shiftX; property: "x"; to: 14 * root.u; duration: 90 }
                NumberAnimation { target: shiftX; property: "x"; to: -8 * root.u; duration: 80 }
                NumberAnimation { target: shiftX; property: "x"; to: 0; duration: 60 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 26 * root.u
            verticalAlignment: Text.AlignVCenter
            text: root.failed ? "Senha incorreta" : root.capsLock ? "Caps Lock ativado" : ""
            color: root.failed ? root.red : root.yellow
            font.family: root.family
            font.pixelSize: 14 * root.u
        }
    }

    // Rodapé: máquina, teclado e sessão à esquerda; energia à direita.
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 32 * root.u
        spacing: 26 * root.u

        Text {
            text: sddm.hostName
            color: root.fgDim
            font.family: root.family
            font.pixelSize: 14 * root.u
        }

        Text {
            visible: root.layoutCount > 0
            text: root.layoutCount > 0 ? "  " + String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : ""
            color: root.layoutCount > 1 ? root.fg : root.fgDim
            font.family: root.family
            font.pixelSize: 14 * root.u
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6 * root.u
                enabled: root.layoutCount > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.cycleLayout()
            }
        }

        Text {
            visible: root.sessionName !== ""
            text: "  " + root.sessionName
            color: sessions.count > 1 ? root.fg : root.fgDim
            font.family: root.family
            font.pixelSize: 14 * root.u
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6 * root.u
                enabled: sessions.count > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.cycleSession()
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24 * root.u
        spacing: 10 * root.u

        Repeater {
            model: [
                { icon: "", text: "Suspender", ok: sddm.canSuspend, run: function () { sddm.suspend() } },
                { icon: "", text: "Reiniciar", ok: sddm.canReboot, run: function () { sddm.reboot() } },
                { icon: "", text: "Desligar", ok: sddm.canPowerOff, run: function () { sddm.powerOff() } }
            ]
            delegate: Rectangle {
                visible: modelData.ok
                width: 84 * root.u
                height: 64 * root.u
                radius: 8 * root.u
                color: hover.containsMouse ? root.bgAlt : "transparent"
                border.width: hover.containsMouse ? 1 : 0
                border.color: root.accent2

                Column {
                    anchors.centerIn: parent
                    spacing: 5 * root.u
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        color: hover.containsMouse ? root.accent : root.fg
                        font.family: root.family
                        font.pixelSize: 22 * root.u
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.text
                        color: root.fgDim
                        font.family: root.family
                        font.pixelSize: 12 * root.u
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.run()
                }
            }
        }
    }
}
