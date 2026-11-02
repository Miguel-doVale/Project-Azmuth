import QtQuick
import "components"

Canvas {
    id: chart
    property var points: []
    property color tint: Colors.primary
    property real ceiling: 100
    property bool grid: true
    onPointsChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCeilingChanged: requestPaint()
    onPaint: {
        const c=getContext("2d")
        c.reset()
        if (grid) {
            c.strokeStyle=Qt.alpha(Colors.fg,.09);c.lineWidth=1
            for(let i=1;i<4;i++) {
                const y=Math.round(height*i/4)+.5
                c.beginPath();c.moveTo(0,y);c.lineTo(width,y);c.stroke()
            }
        }
        if(!points.length)return
        const step=width/59, n=points.length
        function py(v) {return height-3-Math.max(0,Math.min(1,v/Math.max(1,ceiling)))*(height-7)}
        c.beginPath()
        for(let i=0;i<n;i++) {
            const x=width-(n-1-i)*step,y=py(points[i])
            if(!i)c.moveTo(x,y);else c.lineTo(x,y)
        }
        c.strokeStyle=tint;c.lineWidth=2;c.lineJoin="round";c.stroke()
        c.lineTo(width,height);c.lineTo(width-(n-1)*step,height);c.closePath()
        c.fillStyle=Qt.alpha(tint,.12);c.fill()
        c.beginPath();c.arc(width-3,py(points[n-1]),3,0,Math.PI*2);c.fillStyle=tint;c.fill()
    }
}
