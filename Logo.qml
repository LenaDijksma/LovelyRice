import QtQuick
import QtQuick.Shapes

// The LovelyRice cat. Same paths as assets/logo.svg, filled from the theme: face = accent, heart nose = accent2.
// The colors animate with the theme because they are bound to Theme, so there is no image to regenerate.
Item {
    id: root
    property real size: Math.round(Theme.cell * 0.8)
    property color face: Theme.accent
    property color heart: Theme.accent2

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 64; height: 64
        scale: root.size / 64
        transformOrigin: Item.TopLeft
        layer.enabled: true         // drawn at 64x64 and scaled down: smooth edges without MSAA
        layer.smooth: true
        layer.mipmap: true

        ShapePath {
            fillColor: root.face
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathSvg {
                path: "M9 7 L23 17 Q32 14.5 41 17 L55 7 Q57.5 18 56.5 31 Q55 52.5 32 54 Q9 52.5 7.5 31 Q6.5 18 9 7 Z "
                    + "M12.5 13.5 L18.8 17.8 L11.8 21.3 Z M51.5 13.5 L45.2 17.8 L52.2 21.3 Z "
                    + "M19.1 33 a3.4 4 0 1 0 6.8 0 a3.4 4 0 1 0 -6.8 0 Z M38.1 33 a3.4 4 0 1 0 6.8 0 a3.4 4 0 1 0 -6.8 0 Z"
            }
        }
        ShapePath {
            fillColor: root.heart
            strokeColor: "transparent"
            PathSvg {
                path: "M32 46.5 C26.5 42.8 27.2 38.6 29.9 38.6 C31.2 38.6 32 39.4 32 40.4 C32 39.4 32.8 38.6 34.1 38.6 C36.8 38.6 37.5 42.8 32 46.5 Z"
            }
        }
    }
}
