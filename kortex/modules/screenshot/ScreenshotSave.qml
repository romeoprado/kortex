import QtQuick
import Quickshell
import qs.services

// Janela de salvar a captura (SaveWindow.qml): prévia, nome, formato (PNG ou JPEG) e pasta. Abre
// sozinha quando há uma captura pendente (Screenshot.pending). A pasta e o formato usados ficam
// salvos para a próxima.
LazyLoader {
    active: Screenshot.pending !== ""

    SaveWindow {
        tool: Screenshot
        layerNamespace: "kortex-screenshot-save"
        titleIcon: Icons.screenshot
        title: "Salvar Captura"
        subtitle: Screenshot.pixelWidth + " × " + Screenshot.pixelHeight + " px"
        previewSource: Screenshot.pending !== "" ? "file://" + Screenshot.pending : ""
        previewWidth: Screenshot.pixelWidth
        formats: [{ label: "PNG", value: "png" }, { label: "JPEG", value: "jpeg" }]
        format: Settings.data.screenshotFormat === "jpeg" ? "jpeg" : "png"
    }
}
