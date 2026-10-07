import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.services

// Contorno de cor sólida (o acento do tema, por padrão), desenhado como um anel: o interior fica
// transparente, a menos que `fill` seja dado, e a espessura acompanha o raio dos cantos. Serve para
// molduras de painéis e para qualquer caixa com borda (campos, botões, cartões). O contorno e o
// preenchimento saem do mesmo desenho, então não sobra franja do fundo por fora da borda.
// (O nome vem de quando a borda era em degradê.)
Item {
    id: root

    property real radius: Theme.radius
    property real borderWidth: Theme.border
    property color color: Theme.accent
    property color fill: "transparent"
    // false: `borderWidth` em pixels da TELA (1 é sempre 1 pixel; caixas finas: campos, botões,
    // cartões). true: em pixels LÓGICOS, como o Hyprland conta a borda das janelas (a 1.6, 2 viram
    // 3 pixels); é o caso das molduras da barra, dos painéis e dos avisos, para ficarem iguais às janelas.
    property bool scaled: false

    // Tudo em pixels FÍSICOS inteiros: a espessura vira um número inteiro de pixels da tela (sem
    // `scaled`, a 1.6, 1 px lógico daria 1,6 px físico e, caindo entre pixels, um cheio e dois
    // esmaecidos; com `scaled`, 2 × 1.6 = 3,2 vira 3, como no Hyprland). As bordas do anel também são
    // levadas à grade de pixels DA JANELA: a origem vem da soma de x/y de todos os ancestrais (a
    // leitura na expressão registra a dependência, então o anel se realinha quando algo se move).
    // Ficam aqui, no objeto raiz, porque os elementos do caminho só enxergam as propriedades dele.
    // A escala real vem da janela (1.6); o Screen do Qt a arredonda (2). Antes de a janela existir
    // (popups ainda fechados) vale o do Screen, que é trocado assim que ela aparece.
    readonly property real dpr: QsWindow.window ? QsWindow.window.devicePixelRatio
        : Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property point origin: {
        let ox = 0, oy = 0
        for (let p = root; p; p = p.parent) { ox += p.x; oy += p.y }
        return Qt.point(ox, oy)
    }
    readonly property real snapX: Math.round(origin.x * dpr) / dpr - origin.x     // deslocamento dentro do item
    readonly property real snapY: Math.round(origin.y * dpr) / dpr - origin.y
    readonly property real w: Math.round((origin.x + width) * dpr) / dpr - origin.x - snapX
    readonly property real h: Math.round((origin.y + height) * dpr) / dpr - origin.y - snapY
    readonly property real r: Math.max(0, Math.min(radius, w / 2, h / 2))
    readonly property real b: borderWidth > 0
        ? Math.min(Math.max(1, Math.round(scaled ? borderWidth * dpr : borderWidth)) / dpr, w / 2, h / 2)
        : 0
    readonly property real ri: Math.max(0, r - b)   // raio do contorno interno

    Shape {
        x: root.snapX
        y: root.snapY
        width: root.w
        height: root.h
        preferredRendererType: Shape.CurveRenderer   // bordas suaves, sem multisampling

        // preenchimento: o retângulo arredondado inteiro (por baixo do contorno)
        ShapePath {
            strokeWidth: -1
            fillColor: root.fill

            startX: r; startY: 0
            PathLine { x: w - r; y: 0 }
            PathArc { x: w; y: r; radiusX: r; radiusY: r }
            PathLine { x: w; y: h - r }
            PathArc { x: w - r; y: h; radiusX: r; radiusY: r }
            PathLine { x: r; y: h }
            PathArc { x: 0; y: h - r; radiusX: r; radiusY: r }
            PathLine { x: 0; y: r }
            PathArc { x: r; y: 0; radiusX: r; radiusY: r }
        }

        // Sem borda (0 px) o anel não é pintado: com os dois contornos iguais ele seria vazio, mas a
        // suavização das curvas deixaria uma franja na cor da borda nos arcos dos cantos.
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            fillColor: root.b > 0 ? root.color : "transparent"

            // contorno externo
            startX: r; startY: 0
            PathLine { x: w - r; y: 0 }
            PathArc { x: w; y: r; radiusX: r; radiusY: r }
            PathLine { x: w; y: h - r }
            PathArc { x: w - r; y: h; radiusX: r; radiusY: r }
            PathLine { x: r; y: h }
            PathArc { x: 0; y: h - r; radiusX: r; radiusY: r }
            PathLine { x: 0; y: r }
            PathArc { x: r; y: 0; radiusX: r; radiusY: r }

            // contorno interno, recuado pela espessura da borda
            PathMove { x: b + ri; y: b }
            PathLine { x: w - b - ri; y: b }
            PathArc { x: w - b; y: b + ri; radiusX: ri; radiusY: ri }
            PathLine { x: w - b; y: h - b - ri }
            PathArc { x: w - b - ri; y: h - b; radiusX: ri; radiusY: ri }
            PathLine { x: b + ri; y: h - b }
            PathArc { x: b; y: h - b - ri; radiusX: ri; radiusY: ri }
            PathLine { x: b; y: b + ri }
            PathArc { x: b + ri; y: b; radiusX: ri; radiusY: ri }
        }
    }
}
