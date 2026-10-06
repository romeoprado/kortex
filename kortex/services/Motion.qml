pragma Singleton

import QtQuick
import Quickshell

// Animações do Kortex (Configurações › Animações). Um só lugar para o que o Hyprland anima
// (HyprSync aplica `hyprlandCommands`) e para o que o Qt anima (painéis da barra e avisos).
//
// Curvas (Bézier; as molas do Hyprland só existem na configuração em Lua):
//  kortexOut  desaceleração forte: o que entra chega depressa e assenta devagar
//  kortexIn   aceleração: o que sai parte devagar e some depressa
//  kortexStd  padrão, para o que muda de lugar (mover/redimensionar, áreas de trabalho)
//  kortexBack o que surge passa um pouco do tamanho final e volta (mola); a força vem da intensidade
Singleton {
    id: root

    readonly property bool enabled: Settings.data.animations
    readonly property string intensity: Settings.data.animIntensity     // subtle | elegant | intense
    readonly property string speed: Settings.data.animSpeed             // slow | normal | fast
    readonly property string windowStyle: Settings.data.animWindows      // popin | slide | gnomed
    readonly property string workspaceStyle: Settings.data.animWorkspaces   // horizontal | vertical | fade

    // multiplica todas as durações (Hyprland e Qt)
    readonly property real factor: speed === "slow" ? 1.4 : speed === "fast" ? 0.7 : 1

    readonly property int level: intensity === "subtle" ? 0 : intensity === "intense" ? 2 : 1
    function pick(subtle, elegant, intense) { return [subtle, elegant, intense][level] }

    // curvas em formato Qt (easing.bezierCurve), iguais às do Hyprland
    readonly property var curveOut: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveIn: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var curveStd: [0.2, 0, 0, 1, 1, 1]

    // duração em ms de uma animação do Qt (base = velocidade normal)
    function ms(base) { return Math.round(base * factor) }

    // Painéis da barra: crescem desta escala e deslocam-se tantos px a partir da barra
    readonly property real popupScale: pick(0.96, 0.92, 0.86)
    readonly property int popupShift: pick(6, 10, 16)
    // Avisos: entram deslizando tantos px da direita, crescendo desta escala
    readonly property int toastShift: pick(32, 56, 96)
    readonly property real toastScale: pick(0.97, 0.94, 0.9)

    function _speed(base) { return (base * factor).toFixed(2) }

    readonly property var hyprlandCommands: {
        if (!enabled) return ["keyword animations:enabled 0"]

        const back = pick("0.05,0.7,0.1,1", "0.34,1.3,0.64,1", "0.34,1.56,0.64,1")
        const winIn = windowStyle === "slide" ? "slide"
                    : windowStyle === "gnomed" ? "gnomed"
                    : "popin " + pick(92, 80, 70) + "%"
        const winOut = windowStyle === "slide" ? "slide"
                     : windowStyle === "gnomed" ? "gnomed"
                     : "popin " + pick(95, 90, 80) + "%"
        const ws = workspaceStyle === "fade" ? "fade"
                 : workspaceStyle === "vertical" ? pick("slidefadevert 8%", "slidefadevert 20%", "slidevert")
                 : pick("slidefade 8%", "slidefade 20%", "slide")
        const special = workspaceStyle === "fade" ? "fade" : pick("slidefadevert 15%", "slidefadevert 25%", "slidevert")

        return [
            "keyword animations:enabled 1",
            "keyword bezier kortexOut,0.05,0.7,0.1,1",
            "keyword bezier kortexIn,0.3,0,0.8,0.15",
            "keyword bezier kortexStd,0.2,0,0,1",
            "keyword bezier kortexBack," + back,
            // janelas: abrem com a mola e fecham mais depressa
            "keyword animation windowsIn,1," + _speed(pick(3.5, 4.5, 5)) + ",kortexBack," + winIn,
            "keyword animation windowsOut,1," + _speed(pick(1.8, 2.2, 2.5)) + ",kortexIn," + winOut,
            "keyword animation windowsMove,1," + _speed(4) + "," + (level === 2 ? "kortexBack" : "kortexStd"),
            "keyword animation fadeIn,1," + _speed(2.5) + ",kortexOut",
            "keyword animation fadeOut,1," + _speed(2.2) + ",kortexIn",
            "keyword animation fadeSwitch,1," + _speed(3) + ",kortexStd",
            "keyword animation fadeDim,1," + _speed(3) + ",kortexStd",
            "keyword animation border,1," + _speed(4) + ",kortexStd",
            "keyword animation workspaces,1," + _speed(pick(3.5, 4.5, 5)) + ",kortexStd," + ws,
            "keyword animation specialWorkspace,1," + _speed(4) + ",kortexOut," + special,
            // camadas de qualquer programa esmaecem; as do Kortex têm regras próprias (HyprSync)
            "keyword animation layersIn,1," + _speed(3.5) + ",kortexBack,fade",
            "keyword animation layersOut,1," + _speed(2) + ",kortexIn,fade",
            "keyword animation fadeLayersIn,1," + _speed(2.5) + ",kortexOut",
            "keyword animation fadeLayersOut,1," + _speed(1.8) + ",kortexIn",
            // popups: menus de qualquer programa e os painéis da barra (que ainda se movem pelo Qt)
            "keyword animation fadePopupsIn,1," + _speed(2) + ",kortexOut",
            "keyword animation fadePopupsOut,1," + _speed(1.5) + ",kortexIn"
        ]
    }
}
