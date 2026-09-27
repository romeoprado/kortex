import QtQuick
import qs.services
import qs.widgets

// Clique: lançador de aplicativos · Botão direito: temas e papéis de parede
BarButton {
    icon: Icons.arch
    // O logo do Arch é da Nerd Font. Na variante Propo o glifo declara a própria largura; na normal
    // (monoespaçada) declara a de uma letra e o desenho transborda para a direita, fora do centro.
    iconFamily: Theme.firstInstalled(["JetBrainsMono Nerd Font Propo"], Theme.font)
    iconScale: 1.15
    active: Popups.launcherOpen
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) Popups.openPicker("themes")
        else Popups.toggleLauncher()
    }
}
