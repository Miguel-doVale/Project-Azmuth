// THESIS: diagnóstico do Omnitrix com processos, desempenho e inicialização acessíveis.
// OWN-WORLD: paleta do DNA, superfícies escuras, Orbitron nos títulos, Rajdhani no trabalho.
// STORY: localizar consumo, inspecionar uma identidade de processo e escolher uma ação.
// FIRST VIEWPORT: núcleo à esquerda, tabela ao centro, detalhes ao selecionar; dados reais.
// FORM: extensão da Central, com a organização familiar de um gerenciador de tarefas.
import QtQuick
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    id: app
    readonly property string az: Quickshell.env("HOME")+"/.local/bin/azmuth"
    readonly property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME")
    property int tab: 0
    property bool frozen: false
    property bool mineOnly: true
    property bool loading: true
    property string query: ""
    property string startupQuery: ""
    property string sortKey: "cpu"
    property bool descending: true
    property string selectedKey: ""
    property var packet: ({system:{cpu:0,memory:{percent:0,total:0,used:0},cores:[],disks:[],network:[],process_count:0,threads:0},processes:[]})
    readonly property var system: packet.system
    readonly property var selected: packet.processes.find(p=>p.key===selectedKey) || null
    property var cpuHistory: []
    property var ramHistory: []
    property var diskHistory: []
    property var netHistory: []
    property var visited: [true,false,false]
    property var inspected: []
    readonly property int protocols: visited.filter(Boolean).length
    property string notice: ""
    property bool noticeError: false
    property var pending: null
    property var startupRows: []
    property var startupComponents: []
    property bool startupLoading: false
    readonly property var filteredStartup: {
        const q=startupQuery.trim().toLowerCase()
        return startupRows.filter(r=>!q||(r.name+" "+r.source+" "+r.command).toLowerCase().includes(q))
    }
    property var applications: []
    property bool catalogOpen: false
    property bool catalogLoading: false
    property bool refreshStartup: false
    readonly property string pressure: system.cpu>=85 || system.memory.percent>=90 ? "PRESSÃO ALTA" : (system.cpu>=55 ? "EM ATIVIDADE" : "ESTÁVEL")
    readonly property color pressureColor: system.cpu>=85 || system.memory.percent>=90 ? Colors.warn : Colors.primary
    readonly property var tabs: [
        {name:"Processos",glyph:"codigo",caption:"Assinaturas em execução"},
        {name:"Desempenho",glyph:"energia",caption:"Telemetria do sistema"},
        {name:"Inicialização",glyph:"portal",caption:"Login e transformações"}
    ]

    function bytes(value) {
        if(value>=1073741824)return (value/1073741824).toFixed(1)+" GiB"
        if(value>=1048576)return (value/1048576).toFixed(1)+" MiB"
        if(value>=1024)return (value/1024).toFixed(0)+" KiB"
        return Math.round(value)+" B"
    }
    function duration(value) {
        const s=Math.floor(value||0),h=Math.floor(s/3600),m=Math.floor(s%3600/60)
        return h ? h+"h "+m+"min" : m+"min "+(s%60)+"s"
    }
    function sum(rows,key) { return (rows||[]).reduce((a,b)=>a+(b[key]||0),0) }
    function history(old,value) { return old.concat([value]).slice(-60) }
    function announce(text,error) { notice=text; noticeError=error===true; noticeTimer.restart() }
    function showTab(value) {
        const index=typeof value==="number"?value:["processes","performance","startup"].indexOf(value)
        tab=index>=0?index:0
        const next=visited.slice();next[tab]=true;visited=next
        pending=null
        if(tab===2)readStartup()
    }
    function ingest(line) {
        try {
            const data=JSON.parse(line)
            if(!data.ok){announce(data.error,true);return}
            packet=data;loading=!data.sampled
            if(data.sampled) {
                cpuHistory=history(cpuHistory,system.cpu)
                ramHistory=history(ramHistory,system.memory.percent)
                diskHistory=history(diskHistory,sum(system.disks,"read")+sum(system.disks,"write"))
                netHistory=history(netHistory,sum(system.network,"read")+sum(system.network,"write"))
            }
            rebuild()
        } catch(e) { announce("Não foi possível ler as métricas. Tente atualizar.",true) }
    }
    function rebuild() {
        const q=query.trim().toLowerCase()
        let rows=packet.processes.filter(p=>(!mineOnly||!currentUser||p.user===currentUser)
                                           &&(!q||(p.name+" "+p.pid+" "+p.user+" "+p.command).toLowerCase().includes(q)))
        rows.sort((a,b)=>{
            let n=sortKey==="name"?a.name.localeCompare(b.name):(a[sortKey]-b[sortKey])
            if(!n)n=a.pid-b.pid
            return descending?-n:n
        })
        for(let i=0;i<rows.length;i++) {
            const p=rows[i]
            const value={processKey:p.key,pid:p.pid,processName:p.name,cpu:p.cpu,rss:p.rss,status:p.status,processState:p.state,user:p.user,canSignal:p.can_signal}
            if(i<processModel.count)processModel.set(i,value);else processModel.append(value)
        }
        if(processModel.count>rows.length)processModel.remove(rows.length,processModel.count-rows.length)
    }
    function sort(key) {
        if(sortKey===key)descending=!descending;else {sortKey=key;descending=key!=="name"&&key!=="pid"}
        rebuild()
    }
    function choose(key) {
        selectedKey=key;pending=null
        if(selected && !inspected.includes(selected.name))inspected=inspected.concat([selected.name])
    }
    function askAction(action) {
        if(!selected||!selected.can_signal||actionProc.running)return
        const p=selected
        if(action==="cont"){invoke(["--signal",String(p.pid),String(p.start),action],false);return}
        pending={pid:p.pid,start:p.start,name:p.name,action:action,key:p.key}
    }
    function confirmAction() {
        if(!pending)return
        const target=pending
        pending=null
        invoke(["--signal",String(target.pid),String(target.start),target.action],false)
    }
    function invoke(args,refresh) {
        if(actionProc.running)return
        refreshStartup=refresh===true
        actionProc.command=[az,"tasks"].concat(args);actionProc.running=true
    }
    function readStartup() {
        if(startupProc.running)return
        startupLoading=true;startupProc.running=true
    }
    function openCatalog() {
        catalogOpen=true
        if(!applications.length){catalogLoading=true;catalogProc.running=true}
    }
    onSelectedKeyChanged:omniMeter.scan()
    onFrozenChanged: reader.running=!frozen
    onMineOnlyChanged:rebuild()
    onQueryChanged:rebuild()

    Timer { id:noticeTimer;interval:6500;onTriggered:app.notice="" }
    Timer { id:retry;interval:2000;onTriggered:if(!app.frozen)reader.running=true }

    FileView {
        path:Quickshell.env("HOME")+"/.local/state/azmuth/theme.json"
        watchChanges:true
        onFileChanged:reload()
        onLoaded:{
            try {const t=JSON.parse(text());Colors.primary=t.primary;Colors.bg=t.background;Colors.fg=t.foreground}catch(e){}
        }
    }
    FileView {
        path:Quickshell.env("HOME")+"/.local/state/azmuth/tasks-request.json"
        watchChanges:true
        onFileChanged:reload()
        onLoaded:{try{app.showTab(JSON.parse(text()).tab)}catch(e){}}
    }
    Process {
        id:reader
        command:[app.az,"tasks","--watch"]
        stdout:SplitParser { onRead:data=>app.ingest(data) }
        onExited:(exitCode,exitStatus)=>{
            if(!app.frozen){app.announce("O leitor parou. Tentando reconectar…",true);retry.restart()}
        }
    }
    Process {
        id:startupProc
        command:[app.az,"tasks","--startup-list"]
        stdout:StdioCollector {
            onStreamFinished:{
                app.startupLoading=false
                try {const r=JSON.parse(text);if(r.ok){app.startupRows=r.entries;app.startupComponents=r.components}else app.announce(r.error,true)}
                catch(e){app.announce("Não foi possível ler a inicialização.",true)}
            }
        }
    }
    Process {
        id:catalogProc
        command:[app.az,"tasks","--catalog"]
        stdout:StdioCollector {
            onStreamFinished:{
                app.catalogLoading=false
                try{const r=JSON.parse(text);if(r.ok)app.applications=r.apps;else app.announce(r.error,true)}
                catch(e){app.announce("Não foi possível listar os aplicativos.",true)}
            }
        }
    }
    Process {
        id:actionProc
        stdout:StdioCollector {
            onStreamFinished:{
                try {
                    const r=JSON.parse(text)
                    app.announce(r.ok?r.message:r.error,!r.ok)
                    if(r.ok&&app.refreshStartup){app.catalogOpen=false;startupRefresh.restart()}
                }catch(e){app.announce("A ação não retornou uma resposta válida.",true)}
            }
        }
    }
    Timer { id:startupRefresh;interval:100;onTriggered:app.readStartup() }
    Component.onCompleted:reader.running=true

    component Body: Text { font.family:"Rajdhani";font.pixelSize:17;color:Colors.fg }
    component Label: Text { font.family:"Orbitron";font.pixelSize:10;font.weight:Font.Bold;color:Qt.alpha(Colors.fg,.73) }
    component Data: Text { font.family:"JetBrainsMono Nerd Font";font.pixelSize:13;color:Colors.fg }
    component Rule: Rectangle { height:1;color:Qt.alpha(Colors.fg,.1) }

    FloatingWindow {
        id:window
        title:"Azmuth · Gerenciador de tarefas"
        visible:true
        implicitWidth:1280;implicitHeight:780
        minimumSize:Qt.size(960,620)
        color:Colors.bg
        onClosed:Qt.quit()

        Rectangle {
            id:surface
            anchors.fill:parent
            color:Colors.bg
            focus:true
            Keys.onPressed:event=>{
                if(event.key===Qt.Key_Escape){
                    if(app.catalogOpen)app.catalogOpen=false
                    else if(app.pending)app.pending=null
                    else if(app.selectedKey)app.selectedKey=""
                    else Qt.quit()
                    event.accepted=true
                }
                if((event.modifiers&Qt.ControlModifier)&&event.key===Qt.Key_F){
                    if(app.tab===0)processSearch.activate()
                    else if(app.tab===2)startupSearch.activate()
                    event.accepted=true
                }
                if((event.modifiers&Qt.ControlModifier)&&event.key===Qt.Key_R){
                    if(app.tab===2)app.readStartup();else app.frozen=!app.frozen
                    event.accepted=true
                }
            }

            Rectangle { x:0;y:0;width:198;height:parent.height;color:Qt.alpha(Colors.primary,.035) }
            Rule { x:198;y:0;width:1;height:parent.height;color:Qt.alpha(Colors.primary,.16) }
            Rectangle { x:0;y:0;width:parent.width;height:3;color:Colors.primary }

            Row {
                x:24;y:22;spacing:10
                Glyph { width:25;height:25;name:"nucleo";color:Colors.primary;stroke:1.8 }
                Column { spacing:2
                    Text { text:"AZMUTH";font.family:"Orbitron";font.pixelSize:15;font.weight:Font.Black;color:Colors.primary }
                    Body { text:"Diagnóstico";font.pixelSize:14;color:Qt.alpha(Colors.fg,.7) }
                }
            }
            CoreMeter {
                id:omniMeter
                x:19;y:104
                cpu:app.tab===0&&app.selected?app.selected.cpu:app.system.cpu
                ram:app.tab===0&&app.selected?100*app.selected.rss/Math.max(1,app.system.memory.total):app.system.memory.percent
                label:app.tab===0&&app.selected?"ALVO · CPU":"CPU"
                live:!app.frozen
            }
            Text {
                x:18;y:300;width:162;horizontalAlignment:Text.AlignHCenter
                text:app.loading?"INICIANDO SCAN":(app.frozen?"LEITURA PAUSADA":app.pressure)
                font.family:"Orbitron";font.pixelSize:9;font.weight:Font.Bold;color:app.frozen?Colors.warn:app.pressureColor
            }
            Body {
                x:16;y:324;width:166;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight
                text:app.tab===0&&app.selected?app.selected.name:"Selecione uma assinatura"
                font.pixelSize:13;color:Qt.alpha(Colors.fg,.72)
            }
            Column {
                x:14;y:350;width:170;spacing:7
                Repeater {
                    model:app.tabs
                    Rectangle {
                        required property var modelData
                        required property int index
                        width:170;height:50;radius:8
                        color:app.tab===index?Qt.alpha(Colors.primary,.15):(navMouse.containsMouse?Qt.alpha(Colors.primary,.07):"transparent")
                        border.width:app.tab===index?1:0;border.color:Qt.alpha(Colors.primary,.4)
                        activeFocusOnTab:true
                        Keys.onReturnPressed:app.showTab(index)
                        Keys.onSpacePressed:app.showTab(index)
                        Glyph { x:12;anchors.verticalCenter:parent.verticalCenter;width:21;height:21;name:parent.modelData.glyph;color:app.tab===parent.index?Colors.primary:Qt.alpha(Colors.fg,.7) }
                        Body { x:43;anchors.verticalCenter:parent.verticalCenter;text:parent.modelData.name;font.weight:Font.DemiBold;color:app.tab===parent.index?Colors.primary:Colors.fg }
                        MouseArea { id:navMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:app.showTab(parent.index) }
                    }
                }
            }
            Column {
                x:24;anchors.bottom:parent.bottom;anchors.bottomMargin:26;width:152;spacing:8
                Label { text:app.protocols===3?"SISTEMA MAPEADO":"PROTOCOLO DE SCAN";font.pixelSize:8;color:Colors.primary }
                Row {
                    spacing:8
                    Repeater { model:app.visited;Glyph { required property bool modelData;required property int index;width:25;height:25;name:app.tabs[index].glyph;color:modelData?Colors.primary:Qt.alpha(Colors.fg,.2);stroke:1.6 } }
                }
                Body { visible:surface.height>=700;width:parent.width;text:app.protocols+"/3 áreas exploradas";font.pixelSize:14;color:Qt.alpha(Colors.fg,.72) }
                Body { visible:surface.height>=700;width:parent.width;text:app.inspected.length+" assinaturas analisadas";font.pixelSize:14;color:Qt.alpha(Colors.fg,.72) }
            }

            Item {
                id:main
                x:222;y:24;width:surface.width-x-24;height:surface.height-48

                Row {
                    x:0;y:0;spacing:12
                    Glyph { width:30;height:30;name:app.tabs[app.tab].glyph;color:Colors.primary;stroke:2;anchors.verticalCenter:parent.verticalCenter }
                    Column {
                        spacing:2
                        Text { text:app.tabs[app.tab].name.toUpperCase();font.family:"Orbitron";font.pixelSize:19;font.weight:Font.Black;color:Colors.fg }
                        Body { text:app.tabs[app.tab].caption;font.pixelSize:15;color:Qt.alpha(Colors.fg,.7) }
                    }
                }
                Row {
                    anchors.right:parent.right;y:3;spacing:8
                    TaskButton { visible:app.tab!==2;text:app.frozen?"Retomar leitura":"Pausar leitura";glyph:app.frozen?"energia":"tempo";onClicked:app.frozen=!app.frozen }
                    TaskButton { visible:app.tab===2;text:"Adicionar app";glyph:"portal";filled:true;enabled:!actionProc.running;onClicked:app.openCatalog() }
                    TaskButton { text:"×";width:34;onClicked:Qt.quit() }
                }
                Rule { y:65;width:parent.width;color:Qt.alpha(Colors.primary,.2) }

                Item {
                    id:processPage
                    visible:app.tab===0
                    y:86;width:parent.width;height:parent.height-y-42
                    Row {
                        id:totals
                        spacing:30
                        Column {spacing:2;Label{text:"CPU"}Data{text:app.loading?"…":Math.round(app.system.cpu)+"%";color:Colors.primary;font.pixelSize:22} }
                        Column {spacing:2;Label{text:"MEMÓRIA"}Data{text:app.loading?"…":app.bytes(app.system.memory.used);font.pixelSize:22} }
                        Column {spacing:2;Label{text:"PROCESSOS"}Data{text:app.system.process_count;font.pixelSize:22} }
                        Column {spacing:2;Label{text:"THREADS"}Data{text:app.system.threads;font.pixelSize:22} }
                    }
                    Row {
                        y:68;width:parent.width;spacing:12
                        SearchField { id:processSearch;width:parent.width-202;placeholder:"Buscar nome, PID ou comando · Ctrl+F";onEdited:v=>app.query=v }
                        TaskButton { width:190;height:38;text:app.mineOnly?"Meus processos":"Todos os usuários";glyph:"visao";onClicked:app.mineOnly=!app.mineOnly }
                    }
                    Item {
                        id:table
                        y:122;width:parent.width-(app.selected?Math.min(284,parent.width*.32)+18:0);height:parent.height-y
                        readonly property real nameWidth:width*.43
                        readonly property real pidWidth:width*.12
                        readonly property real cpuWidth:width*.17
                        readonly property real ramWidth:width*.28
                        Rectangle {
                            width:parent.width;height:34;radius:5;color:Qt.alpha(Colors.primary,.075)
                            Repeater {
                                model:[{key:"name",text:"PROCESSO",x:12,w:table.nameWidth-12},
                                       {key:"pid",text:"PID",x:table.nameWidth,w:table.pidWidth},
                                       {key:"cpu",text:"CPU",x:table.nameWidth+table.pidWidth,w:table.cpuWidth},
                                       {key:"rss",text:"RAM · RSS",x:table.nameWidth+table.pidWidth+table.cpuWidth,w:table.ramWidth}]
                                Item {
                                    required property var modelData
                                    x:modelData.x;width:modelData.w;height:34
                                    Label { anchors.verticalCenter:parent.verticalCenter;text:parent.modelData.text+(app.sortKey===parent.modelData.key?(app.descending?" ↓":" ↑"):"");font.pixelSize:9;color:app.sortKey===parent.modelData.key?Colors.primary:Qt.alpha(Colors.fg,.75) }
                                    MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:app.sort(parent.modelData.key) }
                                }
                            }
                        }
                        ListView {
                            id:processList
                            y:42;width:parent.width;height:parent.height-y;clip:true
                            model:ListModel { id:processModel }
                            boundsBehavior:Flickable.StopAtBounds
                            spacing:2
                            delegate:Rectangle {
                                id:row
                                required property string processKey
                                required property string processName
                                required property int pid
                                required property real cpu
                                required property real rss
                                required property string status
                                required property string processState
                                required property string user
                                required property bool canSignal
                                width:processList.width;height:51;radius:5
                                color:app.selectedKey===processKey?Qt.alpha(Colors.primary,.16):(rowMouse.containsMouse?Qt.alpha(Colors.fg,.045):"transparent")
                                border.width:app.selectedKey===processKey?1:0;border.color:Qt.alpha(Colors.primary,.4)
                                Glyph { x:10;anchors.verticalCenter:parent.verticalCenter;width:19;height:19;name:!row.canSignal?"chave":row.processState==="T"?"tempo":"codigo";color:!row.canSignal?Qt.alpha(Colors.fg,.4):Colors.primary;stroke:1.5 }
                                Column {
                                    x:38;width:table.nameWidth-x-8;anchors.verticalCenter:parent.verticalCenter;spacing:1
                                    Body { width:parent.width;text:row.processName;font.weight:Font.DemiBold;elide:Text.ElideRight;font.pixelSize:17 }
                                    Body { width:parent.width;text:row.status+" · "+row.user;font.pixelSize:12;color:Qt.alpha(Colors.fg,.66);elide:Text.ElideRight }
                                }
                                Data { x:table.nameWidth;anchors.verticalCenter:parent.verticalCenter;text:row.pid;font.pixelSize:11;color:Qt.alpha(Colors.fg,.8) }
                                Item {
                                    x:table.nameWidth+table.pidWidth;width:table.cpuWidth-8;height:parent.height
                                    Rectangle { x:0;y:14;width:Math.max(0,Math.min(parent.width,row.cpu/100*parent.width));height:24;radius:3;color:Qt.alpha(row.cpu>30?Colors.warn:Colors.primary,.12) }
                                    Data { y:18;text:row.cpu.toFixed(1)+"%";font.pixelSize:11;color:row.cpu>30?Colors.warn:Colors.fg }
                                }
                                Data { x:table.nameWidth+table.pidWidth+table.cpuWidth;anchors.verticalCenter:parent.verticalCenter;text:app.bytes(row.rss);font.pixelSize:11 }
                                MouseArea { id:rowMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:app.choose(row.processKey) }
                            }
                        }
                        Column {
                            visible:processModel.count===0;anchors.centerIn:parent;spacing:10
                            Glyph { anchors.horizontalCenter:parent.horizontalCenter;width:40;height:40;name:"visao";color:Qt.alpha(Colors.primary,.65) }
                            Body { text:app.loading?"Coletando assinaturas…":"Nenhum processo corresponde à busca.";color:Qt.alpha(Colors.fg,.75) }
                        }
                    }
                    Rectangle {
                        id:details
                        visible:app.selected!==null
                        anchors.right:parent.right;y:122;width:Math.min(284,parent.width*.32);height:parent.height-y
                        radius:8;color:Qt.alpha(Colors.primary,.035);border.width:1;border.color:Qt.alpha(Colors.primary,.17)
                        Flickable {
                            id:detailsScroll
                            anchors.fill:parent;anchors.margins:16;contentHeight:detailContent.implicitHeight;clip:true;boundsBehavior:Flickable.StopAtBounds
                            Column {
                                id:detailContent
                                width:parent.width;spacing:12
                                Row { spacing:8;Glyph {width:22;height:22;name:"visao";color:Colors.primary}Label {text:"ASSINATURA";anchors.verticalCenter:parent.verticalCenter;color:Colors.primary} }
                                Body { width:parent.width;text:app.selected?app.selected.name:"";font.pixelSize:25;font.weight:Font.Bold;wrapMode:Text.WrapAnywhere }
                                Body {text:app.selected?"PID "+app.selected.pid+" · "+app.selected.user:"";font.pixelSize:14;color:Qt.alpha(Colors.fg,.75)}
                                Rule {width:parent.width}
                                Repeater {
                                    model:app.selected?[["Estado",app.selected.status],["CPU",app.selected.cpu.toFixed(1)+"%"],["Memória RSS",app.bytes(app.selected.rss)],["Threads",String(app.selected.threads)],["Em execução",app.duration(app.selected.age)],["Prioridade nice",String(app.selected.nice)],["Processo pai",String(app.selected.ppid)]]:[]
                                    Row {required property var modelData;width:detailContent.width
                                        Body {width:parent.width*.52;text:parent.modelData[0];font.pixelSize:14;color:Qt.alpha(Colors.fg,.72)}
                                        Data {width:parent.width*.48;text:parent.modelData[1];font.pixelSize:11;elide:Text.ElideRight}
                                    }
                                }
                                Label {text:"COMANDO"}
                                Body { width:parent.width;text:app.selected?app.selected.command:"";font.pixelSize:13;wrapMode:Text.WrapAnywhere;color:Qt.alpha(Colors.fg,.8);maximumLineCount:7;elide:Text.ElideRight }
                                Body { visible:app.selected&&!app.selected.can_signal;width:parent.width;text:app.selected?app.selected.reason:"";font.pixelSize:14;wrapMode:Text.WordWrap;color:Colors.warn }
                                Column {
                                    width:parent.width;spacing:8
                                    enabled:app.selected&&app.selected.can_signal&&!actionProc.running&&!app.pending
                                    TaskButton {width:parent.width;text:"Encerrar tarefa";glyph:"fantasma";tint:Colors.danger;onClicked:app.askAction("term")}
                                    TaskButton {width:parent.width;text:app.selected&&app.selected.state==="T"?"Retomar processo":"Pausar processo";glyph:"tempo";onClicked:app.askAction(app.selected.state==="T"?"cont":"stop")}
                                    TaskButton {width:parent.width;text:"Forçar encerramento";tint:Colors.danger;onClicked:app.askAction("kill")}
                                }

                            }
                        }
                        Rectangle {
                            visible:app.pending!==null;z:2;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:16;height:confirmation.implicitHeight+24;radius:6;color:Colors.bg;border.width:1;border.color:Qt.alpha(Colors.danger,.7)
                            MouseArea {anchors.fill:parent}
                            Column {
                                id:confirmation;x:12;y:12;width:parent.width-24;spacing:10
                                Body { width:parent.width;text:app.pending?(app.pending.action==="stop"?"Pausar ":"Encerrar ")+app.pending.name+"?":"";font.weight:Font.Bold;wrapMode:Text.WordWrap }
                                Body { width:parent.width;text:app.pending&&app.pending.action==="stop"?"Ele fica parado até você retomar.":"O aplicativo pode ter trabalho não salvo.";font.pixelSize:14;wrapMode:Text.WordWrap;color:Qt.alpha(Colors.fg,.78) }
                                TaskButton {width:parent.width;text:"Confirmar";filled:true;tint:Colors.danger;onClicked:app.confirmAction()}
                                TaskButton {width:parent.width;text:"Cancelar";onClicked:app.pending=null}
                            }
                        }
                    }
                }

                Flickable {
                    id:performancePage
                    visible:app.tab===1
                    y:86;width:parent.width;height:parent.height-y-42
                    contentHeight:performanceContent.implicitHeight
                    clip:true;boundsBehavior:Flickable.StopAtBounds
                    Column {
                        id:performanceContent;width:parent.width;spacing:22
                        Row {
                            width:parent.width;spacing:24
                            Column {
                                width:parent.width*.60;spacing:8
                                Item {width:parent.width;height:32;Label{text:"PROCESSADOR"}Data{anchors.right:parent.right;text:Math.round(app.system.cpu)+"%";color:Colors.primary;font.pixelSize:26}}
                                Body { width:parent.width;text:app.system.cpu_model||"Coletando…";font.pixelSize:15;elide:Text.ElideRight;color:Qt.alpha(Colors.fg,.78) }
                                SparkChart {width:parent.width;height:194;points:app.cpuHistory}
                                Item {width:parent.width;height:18;Body{text:"Histórico · até 90 s";font.pixelSize:13;color:Qt.alpha(Colors.fg,.7)}Body{anchors.right:parent.right;text:app.system.temperature?Math.round(app.system.temperature)+" °C":"";font.pixelSize:13;color:Colors.primary}}
                            }
                            Column {
                                width:parent.width*.40-24;spacing:8
                                Item {width:parent.width;height:32;Label{text:"MEMÓRIA"}Data{anchors.right:parent.right;text:Math.round(app.system.memory.percent)+"%";color:Colors.warn;font.pixelSize:26}}
                                Body {width:parent.width;text:app.bytes(app.system.memory.used)+" / "+app.bytes(app.system.memory.total);font.pixelSize:15;color:Qt.alpha(Colors.fg,.78)}
                                SparkChart {width:parent.width;height:194;points:app.ramHistory;tint:Colors.warn}
                                Body {text:"Swap: "+app.bytes(app.system.memory.swap_used||0)+" / "+app.bytes(app.system.memory.swap_total||0);font.pixelSize:13;color:Qt.alpha(Colors.fg,.72)}
                            }
                        }
                        Column {
                            width:parent.width;spacing:10
                            Label {text:"NÚCLEOS LÓGICOS · "+(app.system.core_count||0)}
                            Grid {
                                width:parent.width;columns:Math.min(8,app.system.core_count||1);spacing:7
                                Repeater {
                                    model:app.system.cores||[]
                                    Rectangle {
                                        required property real modelData
                                        required property int index
                                        width:(performanceContent.width-(parent.columns-1)*7)/parent.columns;height:54;radius:5;color:Qt.alpha(Colors.primary,.04)
                                        Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:parent.height*Math.max(0,Math.min(1,parent.modelData/100));color:Qt.alpha(Colors.primary,.13)}
                                        Body{x:8;y:5;text:"CPU "+parent.index;font.pixelSize:12;color:Qt.alpha(Colors.fg,.72)}
                                        Data{x:8;y:27;text:Math.round(parent.modelData)+"%";font.pixelSize:12}
                                    }
                                }
                            }
                        }
                        Rule {width:parent.width}
                        Row {
                            width:parent.width;spacing:24
                            Column {
                                width:(parent.width-24)/2;spacing:8
                                Label {text:"DISCO"}
                                Body {text:"Leitura "+app.bytes(app.sum(app.system.disks,"read"))+"/s";font.pixelSize:18}
                                Body {text:"Gravação "+app.bytes(app.sum(app.system.disks,"write"))+"/s";font.pixelSize:15;color:Qt.alpha(Colors.fg,.75)}
                                SparkChart {width:parent.width;height:86;points:app.diskHistory;ceiling:Math.max(1048576,...app.diskHistory)}
                                Body {text:(app.system.disks||[]).map(d=>d.name).join(" · ")||"Sem dispositivo detectado";font.pixelSize:13;color:Qt.alpha(Colors.fg,.72)}
                            }
                            Column {
                                width:(parent.width-24)/2;spacing:8
                                Label {text:"REDE"}
                                Body {text:"Recebendo "+app.bytes(app.sum(app.system.network,"read"))+"/s";font.pixelSize:18}
                                Body {text:"Enviando "+app.bytes(app.sum(app.system.network,"write"))+"/s";font.pixelSize:15;color:Qt.alpha(Colors.fg,.75)}
                                SparkChart {width:parent.width;height:86;points:app.netHistory;ceiling:Math.max(1048576,...app.netHistory);tint:Colors.warn}
                                Body {text:(app.system.network||[]).map(d=>d.name).join(" · ")||"Sem interface detectada";font.pixelSize:13;color:Qt.alpha(Colors.fg,.72)}
                            }
                        }
                        Body {text:"Sistema ativo há "+app.duration(app.system.uptime)+" · "+app.system.process_count+" processos";font.pixelSize:14;color:Qt.alpha(Colors.fg,.72)}
                    }
                }

                Item {
                    id:startupPage
                    visible:app.tab===2
                    y:86;width:parent.width;height:parent.height-y-42
                    Body {width:parent.width;text:"Escolha o que abre no login e ao transformar um DNA.";font.pixelSize:18}
                    SearchField {id:startupSearch;y:35;width:parent.width;placeholder:"Buscar aplicativo ou DNA";onEdited:v=>app.startupQuery=v}
                    Flickable {
                        y:90;width:parent.width;height:parent.height-y
                        contentHeight:startupContent.implicitHeight+8;clip:true;boundsBehavior:Flickable.StopAtBounds
                        Column {
                            id:startupContent;width:parent.width;spacing:8
                            Repeater {
                                model:app.filteredStartup
                                Rectangle {
                                    required property var modelData
                                    width:startupContent.width;height:72;radius:7;color:Qt.alpha(Colors.primary,.035);border.width:1;border.color:Qt.alpha(Colors.primary,.12)
                                    AppIcon {
                                        x:14;y:19;width:32;height:32
                                        iconName:parent.modelData.icon
                                        fallback:parent.modelData.kind==="dna"?"mente":"portal"
                                    }
                                    Column {
                                        x:60;anchors.verticalCenter:parent.verticalCenter;width:parent.width-196;spacing:2
                                        Body {width:parent.width;text:parent.parent.modelData.name;font.weight:Font.Bold;font.pixelSize:19;elide:Text.ElideRight}
                                        Body {width:parent.width;text:parent.parent.modelData.source+" · "+(parent.parent.modelData.enabled?"Ativado":"Desativado");font.pixelSize:14;color:parent.parent.modelData.enabled?Colors.primary:Qt.alpha(Colors.fg,.7);elide:Text.ElideRight}
                                        Body {width:parent.width;text:parent.parent.modelData.command;font.pixelSize:12;color:Qt.alpha(Colors.fg,.65);elide:Text.ElideRight}
                                    }
                                    TaskButton {
                                        visible:parent.modelData.removable
                                        anchors.right:toggle.left;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter
                                        width:28;height:28;text:"×";tint:Colors.danger;enabled:!actionProc.running
                                        onClicked:app.invoke(["--startup-remove",parent.modelData.id],true)
                                    }
                                    TaskSwitch {
                                        id:toggle;anchors.right:parent.right;anchors.rightMargin:16;anchors.verticalCenter:parent.verticalCenter
                                        checked:parent.modelData.enabled;label:"Inicialização de "+parent.modelData.name;enabled:!actionProc.running
                                        onToggled:v=>app.invoke(["--startup-toggle",parent.modelData.id,JSON.stringify(v)],true)
                                    }
                                }
                            }
                            Body {visible:app.startupLoading;text:"Lendo inicialização…";font.pixelSize:16;color:Qt.alpha(Colors.fg,.72)}
                            Body {visible:!app.startupLoading&&app.filteredStartup.length===0;width:parent.width;wrapMode:Text.WordWrap;text:app.startupQuery.trim()?"Nenhum aplicativo corresponde à busca.":"Nenhum aplicativo configurado. Use Adicionar app para escolher o que abre no login.";font.pixelSize:16;color:Qt.alpha(Colors.fg,.75)}
                            Item {width:1;height:14}
                            Label {text:"COMPONENTES DA RICE"}
                            Body {width:parent.width;text:"Definidos pela sessão para manter o Omnitrix funcionando.";font.pixelSize:14;color:Qt.alpha(Colors.fg,.7)}
                            Repeater {
                                model:app.startupComponents
                                Item {
                                    required property var modelData
                                    width:startupContent.width;height:53
                                    Glyph{x:4;anchors.verticalCenter:parent.verticalCenter;width:20;height:20;name:"chave";color:Qt.alpha(Colors.fg,.6);stroke:1.5}
                                    Column {x:38;width:parent.width-45;anchors.verticalCenter:parent.verticalCenter;spacing:1
                                        Body{width:parent.width;text:parent.parent.modelData.name;font.pixelSize:16;elide:Text.ElideRight}
                                        Body{width:parent.width;text:parent.parent.modelData.description;font.pixelSize:13;color:Qt.alpha(Colors.fg,.7);elide:Text.ElideRight}
                                    }
                                }
                            }
                            Body {width:parent.width;wrapMode:Text.WordWrap;text:"Mudanças no login valem na próxima sessão. Nos DNAs, valem na próxima transformação.";font.pixelSize:14;color:Qt.alpha(Colors.fg,.7)}
                        }
                    }
                }

                Rule {anchors.bottom:parent.bottom;anchors.bottomMargin:30;width:parent.width}
                Body {
                    anchors.bottom:parent.bottom;anchors.bottomMargin:3;width:parent.width
                    text:app.notice||(app.tab===0?processModel.count+" processos visíveis · CPU sobre o total da máquina · RAM residente":(app.tab===1?"Métricas reais · atualização a cada 1,5 s":"Adicionar à inicialização não abre o aplicativo agora."))
                    font.pixelSize:14;color:app.noticeError&&app.notice?Colors.danger:(app.notice?Colors.primary:Qt.alpha(Colors.fg,.72));elide:Text.ElideRight
                }
            }

            Item {
                anchors.fill:parent;visible:app.catalogOpen;z:100
                Rectangle {anchors.fill:parent;color:"#bc000000"}
                MouseArea {anchors.fill:parent;onClicked:app.catalogOpen=false}
                Rectangle {
                    id:catalogPanel
                    anchors.centerIn:parent;width:Math.min(640,surface.width-80);height:Math.min(610,surface.height-80)
                    radius:10;color:Colors.bg;border.width:1;border.color:Qt.alpha(Colors.primary,.65)
                    MouseArea {anchors.fill:parent}
                    Label {x:24;y:22;text:"ADICIONAR À INICIALIZAÇÃO";font.pixelSize:13;color:Colors.primary}
                    Body {x:24;y:48;text:"Escolha um aplicativo instalado para abrir no login.";font.pixelSize:16;color:Qt.alpha(Colors.fg,.75)}
                    SearchField {id:catalogSearch;x:24;y:83;width:parent.width-48;placeholder:"Buscar aplicativo"}
                    ListView {
                        id:catalogList
                        x:24;y:137;width:parent.width-48;height:parent.height-y-65;clip:true;spacing:5;boundsBehavior:Flickable.StopAtBounds
                        model:app.applications.filter(a=>!catalogSearch.text||a.name.toLowerCase().includes(catalogSearch.text.toLowerCase()))
                        delegate:Rectangle {
                            required property var modelData
                            width:catalogList.width;height:54;radius:6;color:Qt.alpha(Colors.primary,.035)
                            AppIcon {x:10;y:12;width:30;height:30;iconName:parent.modelData.icon}
                            Body {x:52;anchors.verticalCenter:parent.verticalCenter;width:parent.width-174;text:parent.modelData.name;font.pixelSize:18;elide:Text.ElideRight}
                            TaskButton {anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;text:"Adicionar";enabled:!actionProc.running;onClicked:app.invoke(["--startup-add",parent.modelData.id],true)}
                        }
                    }
                    Body {visible:!app.catalogLoading&&catalogList.count===0;anchors.centerIn:parent;text:"Nenhum aplicativo corresponde à busca.";color:Qt.alpha(Colors.fg,.75)}
                    Body {visible:app.catalogLoading;anchors.centerIn:parent;text:"Lendo aplicativos instalados…";color:Qt.alpha(Colors.fg,.7)}
                    TaskButton {anchors.bottom:parent.bottom;anchors.bottomMargin:16;anchors.right:parent.right;anchors.rightMargin:24;text:"Concluir";onClicked:app.catalogOpen=false}
                }
            }
        }
    }
    IpcHandler {
        target:"manager"
        function show(tab:string):void { window.visible=true;window.minimized=false;app.showTab(tab) }
        function tab(index:int):void { app.showTab(index) }
        function search(query:string):void { processSearch.text=query;app.query=query }
        function select(pid:int):void {const p=app.packet.processes.find(p=>p.pid===pid);if(p){app.showTab(0);app.choose(p.key)}}
        function request(action:string):void { app.askAction(action) }
        function confirm():void { app.confirmAction() }
        function catalog():void { app.showTab(2);app.openCatalog() }
        function close():void { Qt.quit() }
    }
}
