pragma Singleton
// Project Azmuth — cores do DNA ativo para os componentes de interface (Ui*.qml).
// A shell atualiza a partir do theme.json a cada transformação.
import QtQuick
import Quickshell

Singleton {
    property color primary: "#38bdf8"
    property color bg: "#0b0f19"
    property color fg: "#cdd6f4"
    readonly property color danger: "#ff5a5a"
    readonly property color warn: "#ffd76a"
    // modo do core (cânone): "scan" = amarelo (coleta), "recalibrate" = azul (atualização)
    property string mode: ""
    property bool lifeform: false
    readonly property color modeColor: mode === "scan" ? "#ffd76a" : (mode === "recalibrate" ? "#3b82f6" : primary)
    readonly property string modeLabel: mode === "scan" ? "SCAN DE DNA" : (mode === "recalibrate" ? "RECALIBRANDO" : "")
}
