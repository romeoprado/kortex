import QtQuick
import QtQuick.Layouts
import qs.services
import qs.widgets

// Painel Recursos: um bloco por componente (CPU, RAM, GPU, armazenamento) com uso,
// temperatura e consumo, quando a máquina informa. Linhas sem dado somem.
ColumnLayout {
    id: root

    function temp(v) { return v >= 0 ? Math.round(v) + " °C" : "" }

    Layout.fillWidth: true
    spacing: 10

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 10
        rowSpacing: 10
        uniformCellWidths: true

        // ── CPU ─────────────────────────────────────────────────────────
        StatCard {
            icon: Icons.cpu
            title: "CPU"
            subtitle: SystemStats.threads > 0 ? SystemStats.threads + " threads" : ""
            valueText: SystemStats.pct(SystemStats.cpu)
            value: SystemStats.cpu

            StatRow { label: "Temperatura"; value: root.temp(SystemStats.cpuTemp); warn: SystemStats.cpuTemp >= 90 }
            StatRow { label: "Carga"; value: SystemStats.load }
        }

        // ── RAM ─────────────────────────────────────────────────────────
        StatCard {
            icon: Icons.ram
            title: "RAM"
            subtitle: SystemStats.sizeLong(SystemStats.memTotalGb) + " no total"
            valueText: SystemStats.pct(SystemStats.mem)
            value: SystemStats.mem

            StatRow { label: "Temperatura"; value: root.temp(SystemStats.ramTemp); warn: SystemStats.ramTemp >= 85 }
            StatRow { label: "Usado"; value: SystemStats.sizeLong(SystemStats.memUsedGb) }
        }

        // ── GPU ─────────────────────────────────────────────────────────
        StatCard {
            id: gpuCard
            Layout.columnSpan: 2
            visible: g !== null

            readonly property var g: SystemStats.mainGpu
            readonly property var sum: g ? SystemStats.gpuSummary(g) : { text: "", frac: -1, alert: false }
            readonly property bool asleep: g !== null && g.state === "suspended"

            icon: Icons.gpu
            title: "GPU"
            subtitle: g ? g.name.replace(/^NVIDIA\s+/, "") : ""
            valueText: sum.text
            value: sum.frac
            alert: sum.alert

            StatRow { label: "Temperatura"; value: gpuCard.g ? root.temp(gpuCard.g.temp) : ""; warn: gpuCard.g !== null && gpuCard.g.temp >= 85 }
            StatRow {
                label: "Consumo"
                value: gpuCard.g && gpuCard.g.power >= 0 ? gpuCard.g.power.toFixed(1) + " W" : ""
            }
            StatRow {
                label: "Memória de vídeo"
                value: gpuCard.g && gpuCard.g.vramTotal > 0 && !gpuCard.asleep
                       ? SystemStats.sizePair(gpuCard.g.vramUsed, gpuCard.g.vramTotal) + "  ·  " + SystemStats.pct(gpuCard.g.vramUsed / gpuCard.g.vramTotal)
                       : ""
            }
            StatRow { label: "Estado"; value: gpuCard.asleep ? "em repouso (economizando energia)" : "" }
            StatRow {
                label: "Uso"
                value: gpuCard.g && gpuCard.g.util < 0 && !gpuCard.asleep ? "não informado pelo driver" : ""
            }

            // Outras placas (a integrada de um notebook híbrido, por exemplo)
            Repeater {
                model: SystemStats.otherGpus

                StatSection {
                    id: extra
                    required property var modelData
                    readonly property var sum: SystemStats.gpuSummary(modelData)

                    title: modelData.name.replace(/^NVIDIA\s+/, "")
                    valueText: sum.text
                    value: sum.frac
                    alert: sum.alert

                    StatRow { label: "Temperatura"; value: root.temp(modelData.temp) }
                    StatRow { label: "Consumo"; value: modelData.power >= 0 ? modelData.power.toFixed(1) + " W" : "" }
                    StatRow { label: "Uso"; value: modelData.util < 0 ? "não informado pelo driver" : "" }
                }
            }
        }

        // ── Armazenamento ───────────────────────────────────────────────
        StatCard {
            id: diskCard
            Layout.columnSpan: 2
            visible: d !== null

            readonly property var d: SystemStats.disk

            icon: Icons.disk
            title: "Armazenamento"
            subtitle: d ? d.mount + "  ·  " + d.fs + "  ·  " + SystemStats.sizeLong(d.total) : ""
            valueText: d ? SystemStats.pct(d.frac) : ""
            value: d ? d.frac : -1

            StatRow { label: "Temperatura"; value: diskCard.d ? root.temp(diskCard.d.temp) : ""; warn: diskCard.d !== null && diskCard.d.temp >= 70 }
            StatRow { label: "Usado"; value: diskCard.d ? SystemStats.sizeLong(diskCard.d.used) : "" }
            StatRow { label: "Livre"; value: diskCard.d ? SystemStats.sizeLong(diskCard.d.avail) : "" }

            // Demais discos montados
            Repeater {
                model: SystemStats.otherDisks

                StatSection {
                    required property var modelData

                    title: modelData.mount + "  ·  " + modelData.fs + "  ·  " + SystemStats.sizeLong(modelData.total)
                    valueText: SystemStats.pct(modelData.frac)
                    value: modelData.frac

                    StatRow { label: "Temperatura"; value: root.temp(modelData.temp); warn: modelData.temp >= 70 }
                    StatRow { label: "Usado"; value: SystemStats.sizeLong(modelData.used) }
                    StatRow { label: "Livre"; value: SystemStats.sizeLong(modelData.avail) }
                }
            }
        }
    }

    PlainButton {
        Layout.fillWidth: true
        icon: Icons.terminal
        text: "Monitor do Sistema"
        onClicked: {
            Popups.close()
            Settings.runInTerminal(["btop"])
        }
    }
}
