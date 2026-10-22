import QtQuick
import QtQuick.Effects

// A rounded piece of glass. Fill the bar (or a pill) with it; `backdrop` is the bar window's GlassBackdrop.
//
//   shader built (shaders/glass.frag.qsb)   blur + the rim bends what is behind it + color fringe + lit rim
//   no shader                               blurred, tinted copy of the wallpaper with a lit rim (no bending)
//   no backdrop yet / it failed             a plain translucent surface with a lit rim
//
// The look comes from /settings -> Style: glassBlur, glassRefraction, glassLight, glassTint, glassFringe.
Item {
    id: root
    property var backdrop: null
    property real radius: Theme.barRadius
    property color tintColor: Theme.bg

    readonly property real shortSide: Math.max(1, Math.min(width, height))
    readonly property real bevel: Math.max(6, shortSide * 0.42)
    readonly property point origin: Glass.originOf(root, root.backdrop)       // follows the item while it slides
    readonly property bool useShader: shaderLoader.status === Loader.Ready && shaderLoader.item !== null
                                      && shaderLoader.item.status !== ShaderEffect.Error
    readonly property bool haveBackdrop: backdrop !== null && backdrop !== undefined

    // ---- the real thing ----
    Loader {
        id: shaderLoader
        anchors.fill: parent
        active: Glass.shaderReady && root.haveBackdrop && root.width > 0 && root.height > 0
        sourceComponent: ShaderEffect {
            id: fx
            property var source: root.backdrop.texture
            property size size: Qt.size(root.width, root.height)
            property point origin: root.origin
            property size screenSize: Qt.size(root.backdrop.sw, root.backdrop.sh)
            property real radius: root.radius
            property real bevel: root.bevel
            property real refraction: Settings.glassRefraction / 100 * root.bevel * 1.7
            property real blurLod: Settings.glassBlur / 100 * 4.2
            property vector4d tint: Qt.vector4d(root.tintColor.r, root.tintColor.g, root.tintColor.b, Settings.glassTint / 100 * 0.75)
            property real light: Settings.glassLight / 100
            property real fringe: Settings.glassFringe ? 1 : 0
            property real saturation: 1.25
            fragmentShader: Qt.resolvedUrl("shaders/glass.frag.qsb")
            blending: true
        }
    }

    // ---- without the shader: a blurred copy of the wallpaper behind this surface ----
    Loader {
        anchors.fill: parent
        active: !root.useShader && root.haveBackdrop && root.width > 0 && root.height > 0
        sourceComponent: Item {
            Item {
                id: mask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle { anchors.fill: parent; radius: root.radius }
            }
            MultiEffect {
                anchors.fill: parent
                source: ShaderEffectSource {
                    sourceItem: root.backdrop.wallItem
                    sourceRect: Qt.rect(root.origin.x, root.origin.y, root.width, root.height)
                    hideSource: true
                }
                blurEnabled: true
                blurMax: 56
                blur: Settings.glassBlur / 100
                saturation: 0.25
                maskEnabled: true
                maskSource: mask
            }
            Rectangle {     // the theme tint
                anchors.fill: parent
                radius: root.radius
                color: Qt.alpha(root.tintColor, Settings.glassTint / 100 * 0.75)
            }
        }
    }

    // ---- nothing to sample: a plain translucent surface ----
    Rectangle {
        anchors.fill: parent
        visible: !root.haveBackdrop
        radius: root.radius
        color: Qt.alpha(root.tintColor, 0.55)
    }

    // ---- the lit rim, for the two paths where the shader is not drawing it ----
    Item {
        anchors.fill: parent
        visible: !root.useShader
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10 + 0.40 * Settings.glassLight / 100)
        }
        Rectangle {     // light caught along the top edge
            x: root.radius * 0.5; y: 1
            width: Math.max(0, parent.width - root.radius); height: 1
            color: Qt.rgba(1, 1, 1, 0.55 * Settings.glassLight / 100)
        }
    }
}
