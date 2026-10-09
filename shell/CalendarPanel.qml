// Project Azmuth — aba Calendário da Central: mês com marcas, eventos do dia,
// adicionar/editar/apagar com hora, cor e lembrete (o Context Engine avisa).
import QtQuick

Item {
    id: cp
    property date month: new Date()
    property date day: new Date()
    property string editing: ""       // id do evento em edição ("" = novo)
    readonly property var dayEvents: Events.forDay(day)
    readonly property var colors: ["#4dff8a", "#38bdf8", "#a78bfa", "#f472b6", "#ef4444", "#f59e0b", "#ffd76a", "#2dd4bf"]
    readonly property var reminders: [{ v: -1, t: "SEM" }, { v: 0, t: "NA HORA" }, { v: 10, t: "10 MIN" }, { v: 30, t: "30 MIN" }, { v: 60, t: "1 H" }, { v: 1440, t: "1 DIA" }]
    property color pickColor: colors[1]
    property int pickRemind: 10

    function startNew() { editing = ""; title.text = ""; time.text = ""; pickColor = colors[1]; pickRemind = 10; title.forceActiveFocus() }
    function startEdit(e) { editing = e.id; title.text = e.title; time.text = e.time || ""; pickColor = e.color; pickRemind = e.remind; title.forceActiveFocus() }
    function save() {
        const t = title.text.trim()
        if (!t) return
        const hm = /^([01]?\d|2[0-3]):?([0-5]\d)$/.exec(time.text.trim())
        const data = { title: t, time: hm ? hm[1].padStart(2, "0") + ":" + hm[2] : "", color: String(pickColor), remind: pickRemind, date: Events.key(day) }
        if (editing) Events.update(editing, data); else Events.add(data)
        startNew()
    }

    Row {
        anchors.fill: parent
        spacing: 30

        // ── mês ──
        Column {
            id: cal
            width: 340
            spacing: 10
            Item {
                width: parent.width; height: 34
                Text { anchors.verticalCenter: parent.verticalCenter; text: Qt.locale("pt_BR").toString(cp.month, "MMMM yyyy").toUpperCase(); font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 15; color: Colors.primary }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    UiButton { text: "‹"; width: 30; onClicked: cp.month = new Date(cp.month.getFullYear(), cp.month.getMonth() - 1, 1) }
                    UiButton { text: "HOJE"; onClicked: { cp.month = new Date(); cp.day = new Date() } }
                    UiButton { text: "›"; width: 30; onClicked: cp.month = new Date(cp.month.getFullYear(), cp.month.getMonth() + 1, 1) }
                }
            }
            Grid {
                id: grid
                columns: 7; width: parent.width
                readonly property real cell: width / 7
                readonly property int first: new Date(cp.month.getFullYear(), cp.month.getMonth(), 1).getDay()
                readonly property int days: new Date(cp.month.getFullYear(), cp.month.getMonth() + 1, 0).getDate()
                Repeater {
                    model: ["D", "S", "T", "Q", "Q", "S", "S"]
                    Text { required property string modelData; width: grid.cell; height: 24; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: "Orbitron"; font.pixelSize: 10; color: Qt.alpha(Colors.fg, 0.45) }
                }
                Repeater {
                    model: Math.ceil((grid.first + grid.days) / 7) * 7
                    Item {
                        id: cellI
                        required property int index
                        readonly property int d: index - grid.first + 1
                        readonly property bool valid: d >= 1 && d <= grid.days
                        readonly property date date: new Date(cp.month.getFullYear(), cp.month.getMonth(), Math.max(1, d))
                        readonly property bool isToday: valid && Events.key(date) === Events.key(new Date())
                        readonly property bool isSel: valid && Events.key(date) === Events.key(cp.day)
                        width: grid.cell; height: 46
                        Rectangle {
                            anchors.centerIn: parent; width: 40; height: 40; radius: 20
                            visible: cellI.valid
                            color: cellI.isSel ? Colors.primary : (cm.containsMouse ? Qt.alpha(Colors.primary, 0.12) : "transparent")
                            border.width: cellI.isToday && !cellI.isSel ? 1.5 : 0; border.color: Colors.primary
                        }
                        Text {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: -3
                            visible: cellI.valid
                            text: cellI.d
                            font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16
                            color: cellI.isSel ? Colors.bg : Colors.fg
                        }
                        Row {   // marcas de eventos
                            anchors.horizontalCenter: parent.horizontalCenter; y: 31
                            spacing: 3
                            visible: cellI.valid
                            Repeater {
                                model: cellI.valid ? Events.colorsOn(cellI.date) : []
                                Rectangle { required property var modelData; width: 5; height: 5; radius: 2.5; color: cellI.isSel ? Colors.bg : modelData }
                            }
                        }
                        MouseArea { id: cm; anchors.fill: parent; enabled: cellI.valid; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { cp.day = cellI.date; cp.startNew() } }
                    }
                }
            }
            UiSection { text: "PRÓXIMOS" }
            Repeater {
                model: Events.upcoming(5)
                Item {
                    required property var modelData
                    width: cal.width; height: 26
                    Rectangle { y: 9; width: 8; height: 8; radius: 4; color: parent.modelData.color }
                    Text { x: 16; width: parent.width - 16; elide: Text.ElideRight; text: parent.modelData.date.slice(8) + "/" + parent.modelData.date.slice(5, 7) + (parent.modelData.time ? " " + parent.modelData.time : "") + " · " + parent.modelData.title; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; color: Colors.fg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const p = parent.modelData.date.split("-"); cp.day = new Date(p[0], p[1] - 1, p[2]); cp.month = cp.day; cp.startEdit(parent.modelData) } }
                }
            }
        }

        // ── dia selecionado ──
        Column {
            width: parent.width - cal.width - 30
            spacing: 10
            Text { text: Qt.locale("pt_BR").toString(cp.day, "dddd, d 'de' MMMM").toUpperCase(); font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 15; color: Colors.primary }
            Text { visible: cp.dayEvents.length === 0; text: "Nenhum evento neste dia."; font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.5) }
            Repeater {
                model: cp.dayEvents
                Rectangle {
                    required property var modelData
                    width: parent.width; height: 52; radius: 10
                    color: cp.editing === modelData.id ? Qt.alpha(modelData.color, 0.14) : Qt.alpha(Colors.primary, 0.04)
                    border.width: 1; border.color: Qt.alpha(modelData.color, 0.5)
                    Rectangle { x: 0; y: 10; width: 3; height: 32; radius: 1.5; color: parent.modelData.color }
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; width: 58; text: parent.modelData.time || "dia todo"; font.family: "Orbitron"; font.pixelSize: 12; font.weight: Font.Bold; color: parent.modelData.color }
                    Column {
                        x: 80; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80 - 90
                        Text { width: parent.width; elide: Text.ElideRight; text: parent.parent.modelData.title; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: Colors.fg }
                        Text { text: parent.parent.modelData.remind < 0 ? "sem lembrete" : (parent.parent.modelData.remind === 0 ? "lembrete na hora" : "lembrete " + (cp.reminders.find(r => r.v === parent.parent.modelData.remind) || { t: parent.parent.modelData.remind + " min" }).t.toLowerCase() + " antes"); font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(Colors.fg, 0.5) }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        UiButton { glyph: "codigo"; onClicked: cp.startEdit(parent.parent.modelData) }
                        UiButton { text: "✕"; tint: Colors.danger; onClicked: { Events.remove(parent.parent.modelData.id); if (cp.editing === parent.parent.modelData.id) cp.startNew() } }
                    }
                }
            }

            UiSection { text: cp.editing ? "EDITAR EVENTO" : "NOVO EVENTO" }
            Row {
                width: parent.width; spacing: 10
                Rectangle {
                    width: parent.width - 120; height: 42; radius: 8
                    color: Qt.alpha(Colors.primary, 0.06)
                    border.width: title.activeFocus ? 2 : 1; border.color: Qt.alpha(Colors.primary, title.activeFocus ? 0.9 : 0.35)
                    TextInput {
                        id: title
                        anchors.fill: parent; anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 16; color: Colors.fg
                        selectionColor: Colors.primary
                        Keys.onReturnPressed: cp.save()
                        Text { anchors.verticalCenter: parent.verticalCenter; visible: title.text === ""; text: "Título (ex.: Prova de Engenharia de Software)"; font: title.font; color: Qt.alpha(Colors.fg, 0.35) }
                    }
                }
                Rectangle {
                    width: 110; height: 42; radius: 8
                    color: Qt.alpha(Colors.primary, 0.06)
                    border.width: time.activeFocus ? 2 : 1; border.color: Qt.alpha(Colors.primary, time.activeFocus ? 0.9 : 0.35)
                    TextInput {
                        id: time
                        anchors.fill: parent; anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        maximumLength: 5
                        font.family: "Orbitron"; font.pixelSize: 14; color: Colors.fg
                        selectionColor: Colors.primary
                        Keys.onReturnPressed: cp.save()
                        Text { anchors.centerIn: parent; visible: time.text === ""; text: "HH:MM"; font: time.font; color: Qt.alpha(Colors.fg, 0.35) }
                    }
                }
            }
            Row {
                spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: "COR"; font.family: "Orbitron"; font.pixelSize: 10; color: Qt.alpha(Colors.fg, 0.55); rightPadding: 4 }
                Repeater {
                    model: cp.colors
                    Rectangle {
                        required property string modelData
                        width: 26; height: 26; radius: 13; color: modelData
                        border.width: String(cp.pickColor) === modelData ? 3 : 0; border.color: Colors.fg
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cp.pickColor = parent.modelData }
                    }
                }
            }
            Flow {
                width: parent.width; spacing: 6
                Text { text: "LEMBRETE"; font.family: "Orbitron"; font.pixelSize: 10; color: Qt.alpha(Colors.fg, 0.55); topPadding: 9; rightPadding: 4 }
                Repeater {
                    model: cp.reminders
                    UiButton { required property var modelData; text: modelData.t; filled: cp.pickRemind === modelData.v; onClicked: cp.pickRemind = modelData.v }
                }
            }
            Row {
                spacing: 8
                UiButton { text: cp.editing ? "SALVAR" : "ADICIONAR"; glyph: "tempo"; filled: true; onClicked: cp.save() }
                UiButton { visible: cp.editing !== ""; text: "CANCELAR"; onClicked: cp.startNew() }
            }
        }
    }
}
