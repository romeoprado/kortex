pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Servidor de notificações (substitui mako/dunst/swaync)
Singleton {
    id: root

    property var toasts: []
    property var times: ({})
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length

    // Os avisos do Kortex chegam ao Repeater como CÓPIA (objeto JS, não QObject): compara pela chave
    function removeToast(n) {
        toasts = toasts.filter(t => t !== n && !(n && n.kortexKey && t.kortexKey === n.kortexKey))
    }

    // Aviso do próprio Kortex (não vem de um app): só o aviso flutuante, sem entrar no histórico, e
    // aparece mesmo com o Não Perturbe. Some em 2,5 s; um novo aviso com a mesma chave substitui o anterior.
    function flash(key, icon, summary, body) {
        const n = { kortexKey: key, kortexIcon: icon, id: "kortex-" + key + "-" + Date.now(), appName: "Kortex",
                    summary: summary, body: body || "", image: "", appIcon: "",
                    urgency: NotificationUrgency.Normal, expireTimeout: 2500, actions: [] }
        const t = Object.assign({}, times)
        t[n.id] = Date.now()
        times = t
        toasts = [n].concat(toasts.filter(x => x.kortexKey !== key)).slice(0, 5)
    }

    // Ação de uma notificação: o invoke() do Quickshell já fecha (e destrói) a que não é residente, e
    // o cartão que chamou pode ser destruído junto — por isso a ordem fica aqui, fora do cartão
    function invoke(n, action) {
        const resident = n.resident
        action.invoke()
        if (resident) n.dismiss()
    }

    function clearAll() {
        const all = server.trackedNotifications.values.slice()
        for (const n of all) n.dismiss()
        toasts = []
    }

    function timeOf(n) {
        const t = n ? times[n.id] : undefined
        if (!t) return ""
        const mins = Math.floor((Date.now() - t) / 60000)
        if (mins < 1) return "agora"
        if (mins < 60) return mins + " min"
        return new Date(t).toLocaleTimeString(Qt.locale(), "HH:mm")
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true
            const t = Object.assign({}, root.times)
            t[n.id] = Date.now()
            root.times = t
            n.closed.connect(() => root.removeToast(n))
            if (!Settings.data.dnd || n.urgency === NotificationUrgency.Critical)
                root.toasts = [n].concat(root.toasts.filter(x => x !== n)).slice(0, 5)
        }
    }
}
