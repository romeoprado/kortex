import QtQuick
import Quickshell
import qs.services

// Janela de salvar a gravação (SaveWindow.qml): um quadro do vídeo com a duração, nome, formato
// (MP4 ou MKV) e pasta. Abre sozinha quando a gravação para (ScreenRecord.pending). A pasta e o
// formato usados ficam salvos para a próxima.
LazyLoader {
    active: ScreenRecord.pending !== ""

    SaveWindow {
        tool: ScreenRecord
        layerNamespace: "kortex-record-save"
        titleIcon: Icons.record
        title: "Salvar Gravação"
        subtitle: ScreenRecord.pixelWidth + " × " + ScreenRecord.pixelHeight + " px"
        previewSource: ScreenRecord.preview !== "" ? "file://" + ScreenRecord.preview : ""
        previewWidth: ScreenRecord.pixelWidth
        previewBadge: ScreenRecord.clock(ScreenRecord.duration)
        formats: [{ label: "MP4", value: "mp4" }, { label: "MKV", value: "mkv" }]
        format: Settings.data.recordFormat === "mkv" ? "mkv" : "mp4"
    }
}
