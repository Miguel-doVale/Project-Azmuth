// Gerenciador de tarefas na linguagem visual da Central do Omnitrix.
import QtQuick

Item {
    id: panel
    signal openTasks(string page)

    Column {
        anchors.left:parent.left;anchors.right:parent.right
        spacing:18
        Row {
            spacing:12
            Glyph {width:32;height:32;name:"energia";color:Colors.primary;stroke:2}
            Column {
                spacing:4
                Text {text:"SISTEMA";font.family:"Orbitron";font.pixelSize:20;font.weight:Font.Black;color:Colors.primary}
                Text {text:"Diagnóstico do Omnitrix";font.family:"Rajdhani";font.pixelSize:17;color:Qt.alpha(Colors.fg,.75)}
            }
        }
        Rectangle {width:parent.width;height:1;color:Qt.alpha(Colors.primary,.2)}
        Row {
            spacing:36
            Column {
                spacing:8
                UiSection {text:"CPU"}
                Text {text:Math.round(SysStats.cpu)+"%";font.family:"JetBrainsMono Nerd Font";font.pixelSize:30;color:Colors.primary}
            }
            Column {
                spacing:8
                UiSection {text:"MEMÓRIA"}
                Text {text:SysStats.ramUsedGiB.toFixed(1)+" GiB";font.family:"JetBrainsMono Nerd Font";font.pixelSize:30;color:Colors.fg}
            }
            Column {
                spacing:8
                UiSection {text:"TEMPERATURA"}
                Text {text:SysStats.temp?Math.round(SysStats.temp)+" °C":"—";font.family:"JetBrainsMono Nerd Font";font.pixelSize:30;color:Colors.fg}
            }
        }
        Item {width:1;height:8}
        Text {
            width:parent.width;wrapMode:Text.WordWrap
            text:"Veja o consumo dos processos, encerre tarefas e escolha os aplicativos que abrem no login ou nas transformações."
            font.family:"Rajdhani";font.pixelSize:19;color:Colors.fg
        }
        Flow {
            width:parent.width;spacing:12
            UiButton {text:"GERENCIADOR DE TAREFAS";glyph:"codigo";filled:true;height:36;onClicked:panel.openTasks("processes")}
            UiButton {text:"INICIALIZAÇÃO";glyph:"portal";height:36;onClicked:panel.openTasks("startup")}
        }
        Text {
            width:parent.width;wrapMode:Text.WordWrap
            text:"Ctrl + Shift + Esc abre o gerenciador. Os indicadores de CPU e RAM da barra abrem a aba Desempenho."
            font.family:"Rajdhani";font.pixelSize:15;color:Qt.alpha(Colors.fg,.75)
        }
    }
}
