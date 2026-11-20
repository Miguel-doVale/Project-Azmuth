// Project Azmuth — o ShaderEffect das cenas ASCII (shaders/cellfx.frag), com TODOS os uniformes e texturas
// declarados num lugar só: AsciiScene (efeitos de célula, planetas, mapa, glitch do carrossel) e a camada
// da frente da LiveDesktop usam este arquivo, para que acrescentar um uniforme não quebre um deles em silêncio.
import QtQuick

ShaderEffect {
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/cellfx.frag.qsb")

    // texturas (todas precisam existir: quem não usa aponta para o atlas)
    property var baseTex
    property var maskTex
    property var atlasTex
    property var mapTex

    // uniformes (a ordem e os nomes seguem o bloco `buf` do shader)
    property vector2d grid: Qt.vector2d(1, 1)
    property vector4d region: Qt.vector4d(0, 0, 1, 1)
    property int mode: 0
    property real t: 0
    property real tick: 0
    property vector4d p0
    property vector4d p1
    property vector4d p2
    property vector4d b0
    property vector4d b1
    property vector4d b2
    property vector4d b3
    property vector4d b4
    property vector4d b5
    property vector4d col1
    property vector4d col2
}
