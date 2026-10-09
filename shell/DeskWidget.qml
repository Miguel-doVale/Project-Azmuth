// Project Azmuth — um widget da área de trabalho (catálogo em DeskLayout.qml).
// Só exibe; a edição (arrastar/escala/remover) é feita pelo DesktopEditor.

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

Item {
    id: dw
    property string type: "relogio"
    property string src: ""          // widget "imagem": caminho do arquivo
    property var theme: ({})
    readonly property color primary: Colors.primary
    readonly property color fg: Colors.fg
    readonly property color bg: Colors.bg

    implicitWidth: loader.item ? loader.item.implicitWidth : 100
    implicitHeight: loader.item ? loader.item.implicitHeight : 100

    Loader {
        id: loader
        sourceComponent: ({ relogio: clockC, aneis: ringsC, energia: energyC, dna: dnaC, musica: musicC, calendario: calC, sistema: sysC, imagem: imageC })[dw.type] || clockC
    }

    component Card: Rectangle {
        radius: 12
        color: Qt.alpha(dw.bg, 0.72)
        border.width: 1; border.color: Qt.alpha(dw.primary, 0.4)
    }
    component Gauge: Item {
        id: g
        property real value: 0
        property string label: ""
        property string unit: "%"
        property color tint: value >= 90 ? Colors.danger : (value >= 75 ? Colors.warn : dw.primary)
        property real shown: value
        Behavior on shown { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
        implicitWidth: 76; implicitHeight: 92
        Shape {
            width: 76; height: 76
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: Qt.alpha(dw.primary, 0.16); strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 38; centerY: 38; radiusX: 33; radiusY: 33; startAngle: 135; sweepAngle: 270 } }
            ShapePath { strokeColor: g.tint; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 38; centerY: 38; radiusX: 33; radiusY: 33; startAngle: 135; sweepAngle: Math.max(1, 270 * Math.min(100, g.shown) / 100) } }
        }
        Text { width: 76; y: 26; horizontalAlignment: Text.AlignHCenter; text: Math.round(g.value) + g.unit; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 15; color: dw.fg }
        Text { width: 76; y: 72; horizontalAlignment: Text.AlignHCenter; text: g.label; font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2; color: Qt.alpha(dw.fg, 0.6) }
    }

    // ── relógio ──
    Component {
        id: clockC
        Column {
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.now = new Date() }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(parent.now, "HH:mm")
                font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 68; font.letterSpacing: 4
                color: dw.primary
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: dw.primary; shadowBlur: 1.0; shadowOpacity: 0.6; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale("pt_BR").toString(parent.now, "dddd · d 'de' MMMM").toUpperCase()
                font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; font.letterSpacing: 3
                color: Qt.alpha(dw.fg, 0.85)
            }
        }
    }

    // ── anéis do sistema ──
    Component {
        id: ringsC
        Row {
            spacing: 34
            Gauge { label: "CPU"; value: SysStats.cpu }
            Gauge { label: "RAM"; value: SysStats.ram }
            Gauge { label: "TEMP"; value: SysStats.temp; unit: "°" }
            Gauge { visible: Energy.enabled; label: Energy.locked ? "RECARGA" : "OMNITRIX"; value: Energy.percent; tint: Energy.locked ? Colors.danger : dw.primary }
        }
    }

    // ── energia (anel grande) ──
    Component {
        id: energyC
        Item {
            id: ec
            implicitWidth: 170; implicitHeight: 170
            readonly property color c: Energy.locked ? Colors.danger : dw.primary
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: Qt.alpha(ec.c, 0.15); strokeWidth: 10; fillColor: "transparent"
                    PathAngleArc { centerX: 85; centerY: 85; radiusX: 75; radiusY: 75; startAngle: 0; sweepAngle: 360 } }
                ShapePath { strokeColor: ec.c; strokeWidth: 10; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 85; centerY: 85; radiusX: 75; radiusY: 75; startAngle: -90; sweepAngle: 360 * Math.max(0.003, Energy.level) } }
            }
            Column {
                anchors.centerIn: parent
                Glyph { anchors.horizontalCenter: parent.horizontalCenter; width: 26; height: 26; name: "energia"; color: ec.c; stroke: 2 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Energy.percent + "%"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 30; color: ec.c }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Energy.draining ? "resta " + Energy.mmss(Energy.secondsLeft) : Energy.locked ? "recarga " + Energy.mmss(Energy.secondsToMin)
                          : Energy.charging ? "cheia em " + Energy.mmss(Energy.secondsToFull) : "carregada"
                    font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 14; color: Qt.alpha(dw.fg, 0.75)
                }
            }
        }
    }

    // ── DNA ativo ──
    Component {
        id: dnaC
        Card {
            implicitWidth: 340; implicitHeight: 112
            Rectangle {
                id: badge
                x: 16; anchors.verticalCenter: parent.verticalCenter
                width: 76; height: 76; radius: 38
                color: "#0c0f11"; border.width: 3; border.color: dw.primary
                Image {
                    anchors.centerIn: parent; width: 66; height: 66
                    visible: !!dw.theme.art
                    source: dw.theme.art ? "file://" + dw.theme.art : ""
                    sourceSize: Qt.size(132, 132)
                }
                Glyph { visible: !dw.theme.art; anchors.centerIn: parent; width: 38; height: 38; name: "tempo"; color: dw.primary; stroke: 2.4 }
            }
            Column {
                anchors.left: badge.right; anchors.leftMargin: 16; anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text { text: "DNA ATIVO"; font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2; color: Qt.alpha(dw.fg, 0.55) }
                Text { text: (dw.theme.name || "").toUpperCase(); font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 20; color: dw.primary }
                Rectangle {
                    width: parent.width; height: 5; radius: 2.5; color: Qt.alpha(dw.primary, 0.15); visible: Energy.enabled
                    Rectangle { width: parent.width * Energy.level; height: parent.height; radius: 2.5; color: Energy.locked ? Colors.danger : dw.primary }
                }
                Text { text: Energy.enabled ? "energia " + Energy.percent + "%" : ""; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 13; color: Qt.alpha(dw.fg, 0.7) }
            }
        }
    }

    // ── música ──
    Component {
        id: musicC
        Card {
            id: mc
            implicitWidth: 360; implicitHeight: 112
            readonly property var p: { const ps = Mpris.players.values; return ps.find(x => x.isPlaying) || ps[0] || null }
            ClippingRectangle {
                id: cover
                x: 14; anchors.verticalCenter: parent.verticalCenter
                width: 84; height: 84; radius: 8
                color: Qt.alpha(dw.primary, 0.12)
                Image { anchors.fill: parent; source: mc.p ? mc.p.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                Glyph { anchors.centerIn: parent; visible: !mc.p || !mc.p.trackArtUrl; width: 34; height: 34; name: "som"; color: dw.primary; stroke: 2 }
            }
            Column {
                anchors.left: cover.right; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text { width: parent.width; elide: Text.ElideRight; text: mc.p ? (mc.p.trackTitle || mc.p.identity) : "Nada tocando"; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: dw.fg }
                Text { width: parent.width; elide: Text.ElideRight; text: mc.p ? (mc.p.trackArtist || "") : ""; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(dw.fg, 0.6) }
                Row {
                    spacing: 3; height: 18
                    Repeater {
                        model: 16
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 4; radius: 2; color: dw.primary
                            property real level: 0.15
                            height: 3 + level * 15
                            Behavior on height { NumberAnimation { duration: 140 } }
                            Timer {
                                interval: 140 + (parent.index % 5) * 20; repeat: true
                                running: mc.p !== null && mc.p.isPlaying
                                onTriggered: parent.level = Math.random()
                                onRunningChanged: if (!running) parent.level = 0.15
                            }
                        }
                    }
                }
            }
        }
    }

    // ── calendário ──
    Component {
        id: calC
        Card {
            id: cal
            implicitWidth: 300; implicitHeight: calCol.implicitHeight + 24
            readonly property date today: new Date()
            Column {
                id: calCol
                x: 14; y: 12; width: parent.width - 28
                spacing: 6
                Text { text: Qt.locale("pt_BR").toString(cal.today, "MMMM yyyy").toUpperCase(); font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 12; color: dw.primary }
                Grid {
                    id: calGrid
                    columns: 7; width: parent.width
                    readonly property real cell: width / 7
                    readonly property date t: cal.today
                    readonly property int first: new Date(t.getFullYear(), t.getMonth(), 1).getDay()
                    readonly property int days: new Date(t.getFullYear(), t.getMonth() + 1, 0).getDate()
                    Repeater {
                        model: ["D", "S", "T", "Q", "Q", "S", "S"]
                        Text { required property string modelData; width: parent.cell; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: "Orbitron"; font.pixelSize: 9; color: Qt.alpha(dw.fg, 0.45) }
                    }
                    Repeater {
                        model: Math.ceil((parent.first + parent.days) / 7) * 7
                        Item {
                            required property int index
                            readonly property int day: index - parent.first + 1
                            readonly property bool isToday: day === parent.t.getDate()
                            width: parent.cell; height: 24
                            Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11; color: dw.primary; visible: parent.isToday }
                            Text { anchors.centerIn: parent; text: parent.day >= 1 && parent.day <= parent.parent.days ? parent.day : ""; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 13; color: parent.isToday ? dw.bg : dw.fg }
                            Rectangle {   // tem evento
                                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                                width: 4; height: 4; radius: 2
                                visible: parent.day >= 1 && parent.day <= parent.parent.days && Events.hasDay(new Date(parent.parent.t.getFullYear(), parent.parent.t.getMonth(), parent.day))
                                color: parent.isToday ? dw.fg : dw.primary
                            }
                        }
                    }
                }
                Repeater {   // próximos eventos
                    model: Events.upcoming(3)
                    Item {
                        required property var modelData
                        width: calCol.width; height: 20
                        Rectangle { y: 7; width: 6; height: 6; radius: 3; color: parent.modelData.color }
                        Text {
                            x: 14; width: parent.width - 14; elide: Text.ElideRight
                            text: parent.modelData.date.slice(8) + "/" + parent.modelData.date.slice(5, 7) + (parent.modelData.time ? " " + parent.modelData.time : "") + " · " + parent.modelData.title
                            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 13; color: dw.fg
                        }
                    }
                }
            }
        }
    }

    // ── imagem ──
    Component {
        id: imageC
        Item {
            readonly property real ratio: img.implicitWidth > 0 ? img.implicitHeight / img.implicitWidth : 0.75
            implicitWidth: 300; implicitHeight: Math.round(300 * ratio)
            ClippingRectangle {
                anchors.fill: parent
                radius: 14
                color: Qt.alpha(dw.primary, 0.08)
                Image {
                    id: img
                    anchors.fill: parent
                    source: dw.src ? "file://" + dw.src : ""
                    sourceSize.width: 600
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Rectangle { anchors.fill: parent; radius: 14; color: "transparent"; border.width: 2; border.color: Qt.alpha(dw.primary, 0.6) }
        }
    }

    // ── barras do sistema ──
    Component {
        id: sysC
        Card {
            implicitWidth: 300; implicitHeight: 130
            Column {
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 10
                Repeater {
                    model: [
                        { k: "CPU", v: SysStats.cpu, t: Math.round(SysStats.cpu) + "%" },
                        { k: "RAM", v: SysStats.ram, t: SysStats.ramUsedGiB.toFixed(1) + " / " + SysStats.ramTotalGiB.toFixed(0) + " GiB" },
                        { k: "TEMP", v: SysStats.temp, t: Math.round(SysStats.temp) + "°C" }
                    ]
                    Item {
                        required property var modelData
                        width: parent.width; height: 24
                        Text { text: parent.modelData.k; font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2; color: Qt.alpha(dw.fg, 0.55) }
                        Text { anchors.right: parent.right; text: parent.modelData.t; font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; color: dw.fg }
                        Rectangle {
                            y: 16; width: parent.width; height: 6; radius: 3; color: Qt.alpha(dw.primary, 0.15)
                            Rectangle { height: parent.height; radius: 3; width: parent.width * Math.min(1, parent.parent.modelData.v / 100); color: parent.parent.modelData.v >= 85 ? Colors.danger : dw.primary; Behavior on width { NumberAnimation { duration: 600 } } }
                        }
                    }
                }
            }
        }
    }
}
