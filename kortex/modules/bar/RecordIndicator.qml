import QtQuick
import qs.services
import qs.widgets

// Gravação de tela em andamento: ponto vermelho e o tempo gravado. Clique para parar (o mesmo que
// repetir SHIFT+Print); depois abre a janela de salvar. Só aparece enquanto grava e fica fora da
// ordem dos itens (não se arrasta).
BarButton {
    visible: ScreenRecord.recording
    icon: Icons.recording
    iconFilled: true
    color: Theme.red
    label: ScreenRecord.stopping ? "Parando…" : ScreenRecord.clock(ScreenRecord.elapsed)
    tabular: true
    onClicked: ScreenRecord.stop()
}
