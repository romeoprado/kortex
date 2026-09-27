pragma Singleton

import QtQuick
import Quickshell

// Manter Acordado: enquanto ligado, o computador não bloqueia, não apaga a tela e não suspende por
// inatividade. Usa o protocolo idle-inhibit do Wayland (o IdleInhibitor fica na barra, ver Bar.qml),
// que o hypridle respeita. Fechar a tampa ou suspender pelo menu continua funcionando. Não é salvo:
// volta a desligado quando o shell reinicia.
Singleton {
    id: root

    property bool active: false

    function toggle() {
        active = !active
        Notifs.flash("keepAwake", Icons.keepAwake,
                     active ? "Manter Acordado ativado" : "Manter Acordado desativado",
                     active ? "O computador não vai bloquear nem suspender por inatividade."
                            : "Bloqueio e suspensão por inatividade voltam ao normal.")
    }
}
