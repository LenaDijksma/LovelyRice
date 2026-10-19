import QtQuick
import QtQuick.Shapes

// The LovelyRice cat: an onigiri with ears and a curled tail. Same paths as assets/logo.svg, filled from the theme:
// body, ears and tail = accent, nori tab = accent2, eyes are cut out so the bar shows through.
// The colors animate with the theme because they are bound to Theme, so there is no image to regenerate.
Item {
    id: root
    property real size: Math.round(Theme.cell * 0.8)
    property color face: Theme.accent
    property color nori: Theme.accent2

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 64; height: 64
        scale: root.size / 64
        transformOrigin: Item.TopLeft
        layer.enabled: true         // drawn at 64x64 and scaled down: smooth edges without MSAA
        layer.smooth: true
        layer.mipmap: true

        ShapePath {                // tail
            fillColor: "transparent"
            strokeColor: root.face
            strokeWidth: 3.1
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M49.7 53.9 C62.1 56.7 63.2 43.2 55.9 43.2 C51.4 43.2 53.1 37.5 59.3 36.4" }
        }
        ShapePath {                // ears
            fillColor: root.face
            strokeColor: root.face
            strokeWidth: 1
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M12.6 20.2 L11.9 8.2 L18.7 12.1 Z " + 
                    "M43.9 20.2 L44.6 8.2 L37.8 12.1 Z"
            }
        }
        ShapePath {                // body with the two eye holes
            fillColor: root.face
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathSvg {
                path: "M28.3 10.5 C35.3 10.5 39.5 16.1 46.6 30.2 L53.6 45.7 C56.5 52.2 52.2 55.6 46.6 55.6 L9.9 55.6 C4.3 55.6 0.1 52.2 2.9 45.7 L9.9 30.2 C17 16.1 21.2 10.5 28.3 10.5 Z " + 
                    "M19.8 32.4 L20.7 32.4 A1.4 1.4 0 0 1 22.1 33.9 L22.1 37.8 A1.4 1.4 0 0 1 20.7 39.2 L19.8 39.2 A1.4 1.4 0 0 1 18.4 37.8 L18.4 33.9 A1.4 1.4 0 0 1 19.8 32.4 Z " + 
                    "M35.9 32.4 L36.7 32.4 A1.4 1.4 0 0 1 38.1 33.9 L38.1 37.8 A1.4 1.4 0 0 1 36.7 39.2 L35.9 39.2 A1.4 1.4 0 0 1 34.5 37.8 L34.5 33.9 A1.4 1.4 0 0 1 35.9 32.4 Z"
            }
        }
        ShapePath {                // nori tab
            fillColor: root.nori
            strokeColor: "transparent"
            PathSvg { path: "M16.4 45.4 L40.1 45.4 A1.1 1.1 0 0 1 41.2 46.5 L41.2 53.9 A1.1 1.1 0 0 1 40.1 55 L16.4 55 A1.1 1.1 0 0 1 15.3 53.9 L15.3 46.5 A1.1 1.1 0 0 1 16.4 45.4 Z" }
        }
    }
}
