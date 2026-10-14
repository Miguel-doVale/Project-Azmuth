// Personalização de pastas do Azmuth. Instância própria: não reinicia a shell.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "components"
import "components/Galvan.js" as Galvan

ShellRoot {
    id: app
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"
    property string target: ""
    property string folderName: ""
    property string folderColor: "#38bdf8"
    property var markers: []
    property int selected: -1
    property string error: ""
    property string colorTarget: "folder"
    property string baseImage: ""
    property string glyphHint: "Clique numa runa para adicionar um marcador."
    readonly property var marker: selected >= 0 && selected < markers.length ? markers[selected] : null
    readonly property var colors: ["#4dff8a", "#38bdf8", "#a78bfa", "#f472b6", "#ff7b7b", "#ffd76a", "#2dd4bf", "#f8fafc"]

    function setStyle(style) { folderColor = style.color; markers = style.markers || []; selected = markers.length ? 0 : -1; error = ""; redraw.restart() }
    function loadFolder(path) { target = path; error = ""; loadProc.command = [az, "files", "--style-load", path]; loadProc.running = true }
    function updateMarker(patch) {
        if (!marker) return
        const next = markers.slice()
        next[selected] = Object.assign({}, next[selected], patch)
        markers = next
    }
    function add(kind, value) {
        const n = markers.length
        const next = { uid: "m" + Date.now().toString(36) + Math.random().toString(36).slice(2,5),
                       kind: kind, value: value, color: String(Colors.fg),
                       x: .28 + (n % 3) * .22, y: .77 - (Math.floor(n / 3) % 3) * .2,
                       size: .17, badge: true }
        markers = markers.concat([next]); selected = markers.length - 1
    }
    function removeMarker(i) { markers = markers.filter((m,j) => j !== i); selected = Math.min(i, markers.length - 1) }
    function reorder(d) {
        if (!marker || selected + d < 0 || selected + d >= markers.length) return
        const next = markers.slice(), to = selected + d, tmp = next[to]
        next[to] = next[selected]; next[selected] = tmp
        markers = next; selected = to
    }
    function chooseColor(c) {
        c = String(c)
        if (!/^#[0-9a-fA-F]{6}$/.test(c)) { error = "Use #RRGGBB para escolher a cor."; return }
        error = ""
        if (colorTarget === "folder") { folderColor = c; redraw.restart() }
        else updateMarker({ color: c })
    }
    function pickColor(which) {
        colorTarget = which
        picker.setColor(which === "folder" ? folderColor : (marker ? marker.color : Colors.fg))
        picker.visible = true
    }
    function save() {
        if (!target || saveProc.running) return
        error = ""
        saveProc.command = [az, "files", "--style-save", target, JSON.stringify({ color: folderColor, markers: markers })]
        saveProc.running = true
    }
    function resetFolder() {
        if (!target || saveProc.running) return
        saveProc.command = [az, "files", "--style-reset", target]; saveProc.running = true
    }

    FileView {
        id: requestFile
        path: Quickshell.env("HOME") + "/.local/state/azmuth/folder-editor-request.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { const req = JSON.parse(text()); app.loadFolder(req.path) } catch (e) { app.error = "Não foi possível abrir a pasta." }
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/azmuth/theme.json"
        onLoaded: {
            try { const t = JSON.parse(text()); Colors.primary=t.primary; Colors.bg=t.background; Colors.fg=t.foreground } catch(e) {}
        }
    }
    Process {
        id: loadProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(this.text)
                    if (!r.ok) { app.error = r.error; return }
                    app.target = r.path; app.folderName = r.name; app.setStyle(r.style)
                } catch(e) { app.error = "Não foi possível ler a personalização." }
            }
        }
    }
    Timer {
        id: redraw
        interval: 100
        onTriggered: {
            if (previewProc.running) { redraw.restart(); return }
            previewProc.command = [app.az, "files", "--style-preview", JSON.stringify({ color: app.folderColor, markers: [] })]
            previewProc.running = true
        }
    }
    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r=JSON.parse(this.text); if(r.ok) app.baseImage="data:image/svg+xml;base64,"+r.svg; else app.error=r.error } catch(e) {}
            }
        }
    }
    Process {
        id: saveProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r=JSON.parse(this.text); if(r.ok) Qt.quit(); else app.error=r.error } catch(e) { app.error="Não foi possível salvar." }
            }
        }
    }

    component ColorInput: Rectangle {
        id: ci
        property string value: "#38bdf8"
        signal edited(string value)
        signal pick
        onValueChanged: if (hex) hex.text = value
        width: parent ? parent.width : 200; height: 38; radius: 6
        color: Qt.alpha(Colors.primary,.05); border.width: 1; border.color: Qt.alpha(Colors.primary,.35)
        Rectangle {
            x: 10; y: 8; width: 22; height: 22; radius: 4
            color: ci.value; border.width: 1; border.color: Qt.alpha(Colors.fg,.4)
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ci.pick() }
        }
        TextInput {
            id: hex
            x: 44; width: parent.width-84; height: parent.height
            verticalAlignment: TextInput.AlignVCenter; clip: true
            text: ci.value; maximumLength: 7
            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.fg
            onAccepted: ci.edited(text)
            onEditingFinished: { if(/^#[0-9a-fA-F]{6}$/.test(text)) ci.edited(text) }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "…"; font.pixelSize: 23; color: Colors.primary; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ci.pick() } }
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "azmuth-folder-editor"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle { anchors.fill: parent; color:"#000000"; opacity:.7 }
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(1040, win.width-48); height: Math.min(710, win.height-100)
            radius: 12; color: Colors.bg; border.width: 1.5; border.color: Qt.alpha(Colors.primary,.75)
            focus: true
            Keys.onEscapePressed: { if (picker.visible) picker.visible = false; else Qt.quit() }
            Column {
                x: 24; y: 20; width: parent.width-48
                spacing: 4
                Row {
                    spacing: 10
                    Glyph { width: 26; height: 26; name:"dados"; color:Colors.primary }
                    Text { text:"PERSONALIZAR PASTA"; font.family:"Orbitron"; font.weight:Font.Black; font.pixelSize:18; font.letterSpacing:2; color:Colors.primary }
                }
                Text { width: parent.width; elide:Text.ElideMiddle; text:app.target; font.family:"Rajdhani"; font.pixelSize:16; color:Qt.alpha(Colors.fg,.65) }
            }
            UiButton { anchors.top:parent.top; anchors.topMargin:20; anchors.right:parent.right; anchors.rightMargin:24; text:"✕"; width:32; onClicked:Qt.quit() }

            Item {
                id: left
                x: 24; y: 92; width: 330; height: panel.height-160
                Rectangle { anchors.fill:parent; radius:8; color:Qt.alpha(Colors.primary,.035); border.width:1; border.color:Qt.alpha(Colors.primary,.15) }
                Item {
                    id: art
                    width: 300; height: 300; anchors.horizontalCenter:parent.horizontalCenter; y:8
                    Image { anchors.fill:parent; source:app.baseImage; sourceSize:Qt.size(600,600); smooth:true }
                    Repeater {
                        model: app.markers
                        Item {
                            id: mark
                            required property var modelData
                            required property int index
                            width: modelData.size * art.width; height: width
                            x: modelData.x * art.width - width/2; y: modelData.y * art.height - height/2
                            Rectangle { anchors.fill:parent; radius:width*.16; visible:mark.modelData.badge; color:"#091017"; border.width:1.5; border.color:mark.modelData.color }
                            Glyph { visible:mark.modelData.kind==="glyph"; anchors.centerIn:parent; width:parent.width*.66; height:width; name:mark.modelData.kind==="glyph"?mark.modelData.value:"nucleo"; color:mark.modelData.color; stroke:1.7*parent.width*.66/24 }
                            Text { visible:mark.modelData.kind==="text"; anchors.centerIn:parent; text:mark.modelData.value; font.family:"JetBrainsMono Nerd Font"; font.weight:Font.Bold; font.pixelSize:mark.width*Math.min(.6,1.10/Math.max(1,text.length)); color:mark.modelData.color }
                            Rectangle { anchors.fill:parent; anchors.margins:-4; visible:app.selected===mark.index; radius:6; color:"transparent"; border.width:1; border.color:Colors.primary }
                            MouseArea {
                                anchors.fill:parent; hoverEnabled:true
                                cursorShape:pressed?Qt.ClosedHandCursor:Qt.OpenHandCursor
                                drag.target:mark; drag.minimumX:0; drag.maximumX:art.width-mark.width; drag.minimumY:0; drag.maximumY:art.height-mark.height
                                onPressed:app.selected=mark.index
                                onReleased:app.updateMarker({x:(mark.x+mark.width/2)/art.width,y:(mark.y+mark.height/2)/art.height})
                            }
                        }
                    }
                }
                Column {
                    x: 18; y: 310; width:parent.width-36; spacing:10
                    Text { width:parent.width; horizontalAlignment:Text.AlignHCenter; elide:Text.ElideRight; text:app.folderName; font.family:"Rajdhani"; font.weight:Font.Bold; font.pixelSize:22; color:Colors.fg }
                    Text { width:parent.width; wrapMode:Text.WordWrap; text:"Arraste os marcadores sobre a pasta. A ordem da lista define qual fica por cima."; font.family:"Rajdhani"; font.pixelSize:15; color:Qt.alpha(Colors.fg,.65) }
                    UiSection { text:"COR DA PASTA" }
                    ColorInput { value:app.folderColor; onEdited:c=>{app.colorTarget="folder";app.chooseColor(c)}; onPick:app.pickColor("folder") }
                    Row {
                        spacing:10
                        Repeater {
                            model:app.colors
                            Rectangle { required property string modelData; width:25; height:25; radius:5; color:modelData; border.width:app.folderColor===modelData?2:0; border.color:Colors.fg; MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{app.folderColor=parent.modelData;redraw.restart()} } }
                        }
                    }
                }
            }

            Flickable {
                x:374; y:88; width:panel.width-x-24; height:panel.height-156
                contentHeight:controls.implicitHeight+12; clip:true; boundsBehavior:Flickable.StopAtBounds
                Column {
                    id:controls
                    width:parent.width; spacing:9
                    UiSection { text:"ADICIONAR RUNAS GALVAN" }
                    Flow {
                        width:parent.width; spacing:7
                        Repeater {
                            model:Galvan.glyphs
                            Rectangle {
                                required property var modelData
                                width:42;height:42;radius:7
                                color:gm.containsMouse?Qt.alpha(Colors.primary,.18):Qt.alpha(Colors.primary,.05)
                                border.width:1;border.color:Qt.alpha(Colors.primary,.3)
                                Glyph { anchors.centerIn:parent;width:25;height:25;name:parent.modelData.id;color:Colors.primary;stroke:1.8 }
                                MouseArea { id:gm;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onEntered:app.glyphHint=parent.modelData.meaning;onExited:app.glyphHint="Clique numa runa para adicionar um marcador.";onClicked:app.add("glyph",parent.modelData.id) }
                                Text { anchors.centerIn:parent; visible:false }
                            }
                        }
                    }
                    Text { width:parent.width; height:20; elide:Text.ElideRight; text:app.glyphHint; font.family:"Rajdhani"; font.pixelSize:14; color:Qt.alpha(Colors.fg,.65) }
                    Row {
                        spacing:10
                        Rectangle {
                            width:180;height:38;radius:6;color:Qt.alpha(Colors.primary,.05);border.width:1;border.color:Qt.alpha(Colors.primary,.3)
                            TextInput { id:letters;anchors.fill:parent;anchors.margins:10;clip:true;verticalAlignment:TextInput.AlignVCenter;font.family:"Rajdhani";font.pixelSize:16;color:Colors.fg;onAccepted:{if(text.trim()){app.add("text",text.trim());text=""}} Text { visible:!letters.text;anchors.verticalCenter:parent.verticalCenter;text:"Letra, número ou texto";font:letters.font;color:Qt.alpha(Colors.fg,.4) } }
                        }
                        UiButton { height:38;text:"ADICIONAR";glyph:"codigo";onClicked:{if(letters.text.trim()){app.add("text",letters.text.trim());letters.text=""}} }
                    }

                    UiSection { text:"MARCADORES · "+app.markers.length }
                    Text { visible:app.markers.length===0;text:"Escolha uma runa ou adicione um texto acima.";font.family:"Rajdhani";font.pixelSize:15;color:Qt.alpha(Colors.fg,.55) }
                    Repeater {
                        model:app.markers
                        Rectangle {
                            required property var modelData
                            required property int index
                            width:controls.width;height:38;radius:6
                            color:app.selected===index?Qt.alpha(Colors.primary,.12):"transparent"
                            border.width:app.selected===index?1:0;border.color:Qt.alpha(Colors.primary,.6)
                            MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:app.selected=parent.index }
                            Glyph { visible:parent.modelData.kind==="glyph";x:10;anchors.verticalCenter:parent.verticalCenter;width:22;height:22;name:parent.modelData.kind==="glyph"?parent.modelData.value:"nucleo";color:parent.modelData.color }
                            Text { x:42;anchors.verticalCenter:parent.verticalCenter;width:parent.width-150;elide:Text.ElideRight;text:parent.modelData.kind==="glyph"?Galvan.byId(parent.modelData.value).meaning:parent.modelData.value;font.family:"Rajdhani";font.weight:Font.DemiBold;font.pixelSize:16;color:Colors.fg }
                            Row {
                                anchors.right:parent.right;anchors.rightMargin:6;anchors.verticalCenter:parent.verticalCenter;spacing:5
                                UiButton { width:28;text:"↓";onClicked:{app.selected=parent.parent.index;app.reorder(-1)} }
                                UiButton { width:28;text:"↑";onClicked:{app.selected=parent.parent.index;app.reorder(1)} }
                                UiButton { width:28;text:"✕";tint:Colors.danger;onClicked:app.removeMarker(parent.parent.index) }
                            }
                        }
                    }
                    Column {
                        visible:app.marker!==null
                        width:parent.width;spacing:8
                        UiSection { text:"EDITAR MARCADOR" }
                        ColorInput { value:app.marker?app.marker.color:"#d6ffe0";onEdited:c=>{app.colorTarget="marker";app.chooseColor(c)};onPick:app.pickColor("marker") }
                        Row { spacing:10;Text { text:"TAMANHO";font.family:"Orbitron";font.pixelSize:10;color:Colors.fg;anchors.verticalCenter:parent.verticalCenter } UiSlider { width:200;maximum:.45;value:app.marker?app.marker.size:.17;onMoved:v=>app.updateMarker({size:Math.max(.06,v)}) } }
                        UiToggle { label:"Fundo do marcador";hint:"Desligue para deixar só o símbolo sobre a cor";checked:app.marker?app.marker.badge:true;onToggled:v=>app.updateMarker({badge:v}) }
                    }
                }
            }
            Text { x:24;y:panel.height-58;width:panel.width-430;wrapMode:Text.WordWrap;text:app.error;font.family:"Rajdhani";font.pixelSize:15;color:Colors.danger }
            Row {
                anchors.bottom:parent.bottom;anchors.bottomMargin:18;anchors.right:parent.right;anchors.rightMargin:24
                spacing:10
                UiButton { text:"RESTAURAR ÍCONE";tint:Colors.warn;enabled:!saveProc.running;onClicked:app.resetFolder() }
                UiButton { text:"CANCELAR";onClicked:Qt.quit() }
                UiButton { text:saveProc.running?"SALVANDO…":"APLICAR";glyph:"dados";filled:true;enabled:!saveProc.running&&app.target!=="";onClicked:app.save() }
            }
        }
        Item {
            id: picker
            anchors.fill: parent
            visible: false
            z: 10
            property real hue: 0
            property real saturation: 1
            property real brightness: 1
            readonly property color selectedColor: Qt.hsva(hue, saturation, brightness, 1)
            onVisibleChanged: if (visible) forceActiveFocus()
            Keys.onEscapePressed: visible = false

            function setColor(value) {
                const c = String(value)
                if (!/^#[0-9a-fA-F]{6}$/.test(c)) return
                const r = parseInt(c.slice(1,3),16)/255, g = parseInt(c.slice(3,5),16)/255, b = parseInt(c.slice(5,7),16)/255
                const hi = Math.max(r,g,b), lo = Math.min(r,g,b), d = hi-lo
                brightness = hi
                saturation = hi ? d/hi : 0
                if (d) {
                    const h = hi===r ? (g-b)/d : hi===g ? (b-r)/d+2 : (r-g)/d+4
                    hue = ((h/6)%1+1)%1
                }
            }
            Rectangle { anchors.fill:parent; color:"#b3000000" }
            MouseArea { anchors.fill:parent; onClicked:picker.visible=false }
            Rectangle {
                width: 420; height: 448
                anchors.centerIn: parent
                radius: 10; color: Colors.bg
                border.width: 1.5; border.color: Colors.primary
                MouseArea { anchors.fill:parent }
                Text {
                    x:24; y:22; text:app.colorTarget==="folder"?"COR DA PASTA":"COR DO MARCADOR"
                    font.family:"Orbitron"; font.pixelSize:14; font.weight:Font.Bold; color:Colors.primary
                }
                Rectangle {
                    id: sv
                    x:24; y:62; width:parent.width-48; height:206
                    color:Qt.hsva(picker.hue,1,1,1)
                    Rectangle {
                        anchors.fill:parent
                        gradient:Gradient {
                            orientation:Gradient.Horizontal
                            GradientStop { position:0; color:"white" }
                            GradientStop { position:1; color:"#00ffffff" }
                        }
                    }
                    Rectangle {
                        anchors.fill:parent
                        gradient:Gradient {
                            GradientStop { position:0; color:"#00000000" }
                            GradientStop { position:1; color:"black" }
                        }
                    }
                    Rectangle {
                        x:picker.saturation*sv.width-width/2; y:(1-picker.brightness)*sv.height-height/2
                        width:14; height:14; radius:7; color:"transparent"; border.width:2; border.color:"white"
                        Rectangle { anchors.fill:parent; anchors.margins:-1; radius:8; color:"transparent"; border.width:1; border.color:"#55000000" }
                    }
                    MouseArea {
                        anchors.fill:parent; cursorShape:Qt.CrossCursor
                        function choose(mx,my) { picker.saturation=Math.max(0,Math.min(1,mx/width)); picker.brightness=1-Math.max(0,Math.min(1,my/height)) }
                        onPressed:m=>choose(m.x,m.y)
                        onPositionChanged:m=>{ if(pressed) choose(m.x,m.y) }
                    }
                }
                Rectangle {
                    id: hueBar
                    x:24; y:286; width:parent.width-48; height:20; radius:4
                    gradient:Gradient {
                        orientation:Gradient.Horizontal
                        GradientStop { position:0; color:"#ff0000" }
                        GradientStop { position:1/6; color:"#ffff00" }
                        GradientStop { position:2/6; color:"#00ff00" }
                        GradientStop { position:3/6; color:"#00ffff" }
                        GradientStop { position:4/6; color:"#0000ff" }
                        GradientStop { position:5/6; color:"#ff00ff" }
                        GradientStop { position:1; color:"#ff0000" }
                    }
                    Rectangle { x:picker.hue*hueBar.width-width/2; y:-3; width:10; height:26; radius:3; color:"transparent"; border.width:2; border.color:"white" }
                    MouseArea {
                        anchors.fill:parent; anchors.margins:-4; cursorShape:Qt.PointingHandCursor
                        function choose(mx) { picker.hue=Math.max(0,Math.min(1,(mx-4)/hueBar.width)) }
                        onPressed:m=>choose(m.x)
                        onPositionChanged:m=>{ if(pressed) choose(m.x) }
                    }
                }
                Row {
                    x:24; y:326; spacing:12
                    Rectangle { width:38; height:38; radius:6; color:picker.selectedColor; border.width:1; border.color:Qt.alpha(Colors.fg,.4) }
                    Rectangle {
                        width:200; height:38; radius:6; color:Qt.alpha(Colors.primary,.05); border.width:1; border.color:Qt.alpha(Colors.primary,.35)
                        TextInput {
                            id:pickerHex
                            anchors.fill:parent; anchors.margins:10; verticalAlignment:TextInput.AlignVCenter; clip:true
                            text:String(picker.selectedColor); maximumLength:7
                            font.family:"JetBrainsMono Nerd Font"; font.pixelSize:14; color:Colors.fg
                            onAccepted:picker.setColor(text)
                            onEditingFinished:picker.setColor(text)
                        }
                    }
                    Text { height:38; verticalAlignment:Text.AlignVCenter; text:"HEX"; font.family:"Rajdhani"; font.pixelSize:15; color:Qt.alpha(Colors.fg,.6) }
                }
                Row {
                    anchors.right:parent.right; anchors.rightMargin:24; anchors.bottom:parent.bottom; anchors.bottomMargin:22
                    spacing:10
                    UiButton { text:"CANCELAR"; onClicked:picker.visible=false }
                    UiButton { text:"USAR COR"; filled:true; onClicked:{picker.setColor(pickerHex.text);app.chooseColor(picker.selectedColor);picker.visible=false} }
                }
            }
        }
    }
    IpcHandler {
        target:"editor"
        function close():void { Qt.quit() }
        function apply():void { app.save() }
        function picker():void { app.pickColor("folder") }
    }
}
