pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Glass support: is the refraction shader built, and where on the screen is a surface?
//
// The refraction itself is a fragment shader (shaders/glass.frag). Qt needs it compiled to a .qsb file, which comes from `qsb`
// (package qt6-shadertools): `lovelyrice shaders` (and install.sh) builds shaders/glass.frag.qsb. Without that file glass
// still works, as a blurred, tinted copy of the wallpaper with a bright rim, just without the bending (GlassSurface.qml).
Singleton {
    id: root

    property bool shaderReady: false        // shaders/glass.frag.qsb exists
    readonly property string shaderFile: Quickshell.shellPath("shaders/glass.frag.qsb")

    FileView {
        path: root.shaderFile
        printErrors: false
        watchChanges: true                  // build it while the shell runs and glass picks it up
        onFileChanged: reload()
        onLoaded: root.shaderReady = true
        onLoadFailed: root.shaderReady = false
    }

    // Where the top-left corner of `item` is on the screen. `backdrop` knows where its window sits on the screen.
    // This is plain JS over x / y reads, so a binding that calls it follows the item while it slides or the layout moves.
    function originOf(item, backdrop) {
        let x = backdrop ? backdrop.winX : 0
        let y = backdrop ? backdrop.winY : 0
        let p = item
        while (p) { x += p.x; y += p.y; p = p.parent }
        return Qt.point(x, y)
    }
}
