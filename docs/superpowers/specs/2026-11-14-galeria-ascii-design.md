# Galeria de fundos ASCII vivo — design

Data: 2026-11-14 · Status: aprovado pelo Miguel em 2026-11-15
Referências: `docs/design/prototipo-wallpaper.html` (rodada 2: pôster, ASCII/DedSec, quadrinho) e o teste
"Flash em ASCII vivo" (rascunho fora do repo, aprovado: "ficou foda").

## 1. Intenção

O fundo atual (imagem procedural + circuitos da área de trabalho viva) é "vazio, sem graça". O Miguel não
quer personagem/paisagem estático comum: o gosto dele (Pinterest) é **arte gráfica com personalidade** —
DedSec/ASCII, quadrinho, pôster, terminal. O que acertou: **ASCII vivo** (imagem convertida em caracteres,
com animações temáticas) e o **quadrinho** (linhas de ação + retícula).

Ele quer uma **galeria** de fundos para trocar quando quiser, com cenas de tudo que gosta (Azmuth, código,
aliens do Ben 10, DedSec, Lanterna Verde, Invencível, Marvel, DC, Wally West, paisagens…). **O Claude
produz e cura as cenas; o Miguel escolhe o que entra e liga/desliga os efeitos de cada uma.**

**Sucesso** = a área de trabalho deixa de ser vazia; cada cena parece feita para o Azmuth; trocar de fundo e
ajustar efeitos é um clique; nada pesa no PC.

### Antiobjetivos
- O Miguel ter que preparar imagem, converter ou ajustar arquivo (ele não quer ser o produtor).
- Imagens de terceiros no repositório público do GitHub.
- Fundo que compete com as janelas a ponto de atrapalhar o uso (os efeitos têm de poder ser desligados).
- Esconder o Omnitrix central: ele continua vivo no meio, por cima de qualquer cena.

### Fora do escopo (próximo projeto)
**Fundo-história do Ben** (ideia do Miguel): no Neutral o fundo é o Ben em ASCII; ativar o Omnitrix faz a
cena dar zoom no pulso, o disco girar escolhendo o alien e, ao transformar, rodar a transformação estilo
Força Alienígena até virar o alien. Depende desta galeria (formato de cena, renderizador) — vai para
`docs/IDEIAS-LORE.md`.

## 2. Como funciona

### 2.1 Cena
Uma cena é uma pasta com:
- `scene.json` — título, autor/fonte (crédito), a grade ASCII (brilho 0–1 e cor RGB por célula), a
  **caixa do personagem** (onde ele está na tela) e os **efeitos que a cena oferece** com o estado padrão.
- `preview.png` — miniatura para a galeria.

Tipos de cena: **ASCII de imagem** (a maioria) e **procedurais** feitas em código (o quadrinho; depois
outras, como o pôster). As procedurais seguem a cor do DNA.

### 2.2 Onde ficam
- Cenas de imagens de terceiros: **só no PC do Miguel**, `~/.local/share/azmuth/scenes/<id>/` (fora do git).
- No repositório: o conversor (`tools/ascii_scene.py`), o renderizador e as cenas procedurais.

### 2.3 Produção (Claude)
1. Escolher imagens no Pinterest do Miguel (salvos e pastas: Invincible, Cartoon, Wally West…; feed).
2. Mostrar a leva para ele aprovar (6–8 por vez).
3. Converter com `tools/ascii_scene.py`: 100 linhas de caracteres (≈307 colunas em 16:9), contraste +
   vinheta, **posição/tamanho do personagem escolhidos por cena** (não "full esquerda": de lado, grande
   atrás do Omnitrix como emblema, etc.), e a lista de efeitos que fazem sentido para ela.
4. Gravar em `~/.local/share/azmuth/scenes/`.
Sem remoção de fundo por IA (o Miguel gostou do chão do Flash); ajustes de contraste por cena quando
precisar.

### 2.4 Efeitos (biblioteca)
Cada efeito é desenhado em caracteres por cima da cena, a ~10 quadros/s (ritmo "terminal" do teste):
- **raios** — galhos `/ \ - *` estalando em volta do personagem (Flash);
- **rastro** — traços `- =` saindo para trás do corpo (velocidade);
- **glitch** — faixas horizontais deslocadas de vez em quando;
- **vento** — ondulação horizontal numa região (capa, cabelo);
- **faíscas** — pontos subindo/espalhando;
- **aura** — contorno pulsando na cor do efeito (energia: Lanterna, Omnitrix);
- **estrelas** — pontos piscando no fundo (cenas no espaço); **cometas** — riscos atravessando o céu;
- **chuva** / **neve** — riscos ou flocos caindo por cima (Heatblast na chuva, Big Chill na nevasca);
- **pulso** — só as células de uma cor brilham e apagam (lava, olhos, circuitos, capa);
- **redemoinho** — os caracteres de uma região elíptica giram (portal, galáxia);
- **planeta** — esfera ASCII gerada, com luz, faixas ou continentes girando, atmosfera e anel opcional;
- **órbita** — partículas em elipse, metade passando na frente do Omnitrix;
- **vulto** — o rosto treme e some por instantes; **varredura** — faixa de scanner descendo;
- **bolhas** (presas numa área), **letreiro** (frase do pôster nítida por cima da arte).

### 2.4.1 Composição (rodada de prévia, 2026-11-15)
- Toda cena ocupa a **tela inteira**. O Omnitrix real tem raio = 27% da altura, no centro. O personagem fica fora dele.
- Para completar a tela, a conversão usa: o fundo desfocado da própria imagem (ou de um pedaço dela),
  a continuação espelhada da arte (com a cor do protagonista trocada nas cópias), ou várias camadas
  (ex.: Flash à direita e Zoom à esquerda).
- Cada cena pode começar em **branco + cor do DNA** em vez das cores da foto.
- Os pôsteres I–X podem virar uma **cena carrossel** (troca a cada ~9 s, com glitch).
- Prévia viva (fora do repo): `~/.local/share/azmuth/scenes/galeria.html`.
Modo de cor por cena: **cores da foto** ou **branco + cor do DNA**. A cor dos efeitos: a da cena (ex.:
amarelo no Flash) ou a do DNA.

### 2.5 Galeria (Miguel)
Na Central → Área de trabalho, seção **FUNDO**: grade de miniaturas; clicar aplica. A cena ativa mostra
chaves para os efeitos que ela oferece e para o modo de cor. Inclui as opções "circuitos (atual)" e
"quadrinho". Preferências em `settings.json → desktop.scene` (`id`, `effects`, `color`).

### 2.6 Renderização
Na área de trabalho viva (`shell/LiveDesktop.qml`, camada Bottom): a cena substitui os circuitos; o
Omnitrix central continua igual, por cima. A camada base de caracteres é desenhada uma vez e guardada; só
os efeitos são redesenhados a ~10 quadros/s. "Área de trabalho viva" desligada → cena parada (sem efeitos).

### 2.7 Quadrinho como transformação
> **Removido em 2026-11-20:** implementado e testado; o Miguel não gostou e pediu para tirar. A transformação
> segue com a onda de luz (agora sem travar). Mantido abaixo só como registro.

Ao transformar (hoje: onda de luz `hud flash`), a tela vira por ~1 s um quadro de quadrinho: linhas de ação
saindo do Omnitrix, retícula, moldura de nanquim e uma onomatopeia ("FLASH!"/variações), na cor do novo
DNA; depois o fundo volta já na cor nova. Chave na Central para quem preferir o flash antigo.

## 3. Abordagens consideradas
- **Conversor de imagem → ASCII vivo, curadoria do Claude (escolhida).** Escala para qualquer tema; o
  Miguel só escolhe. Variação recusada: o Miguel mesmo jogar imagens ("não confio em mim mesmo").
- Cenas desenhadas à mão em código, uma a uma: lento e ruim para personagens conhecidos.
- Wallpapers ASCII estáticos (imagem parada no hyprpaper): perde a animação, que é a graça.
- Remoção de fundo por IA local (~200 MB): adiada; o resultado sem ela agradou.

## 4. Decisões do Claude (o Miguel pode mudar)
- Cenas fora do git; repositório só com ferramenta, renderizador e cenas procedurais.
- 100 linhas de caracteres, ~10 quadros/s nos efeitos.
- Leva inicial: 6–8 cenas aprovadas + quadrinho + circuitos.
- Efeito de transformação em quadrinho ligado por padrão, com chave para voltar ao flash antigo.
- Uma cena para todos os DNAs (a cor acompanha o DNA no modo "branco + cor do DNA"); cena por DNA
  pode vir depois, junto com o fundo-história do Ben.

## 5. Testes
- Python: conversor (dimensões da grade, caixa do personagem, recorte por posição, `scene.json` válido),
  leitura/validação de `desktop.scene` no settings.
- Shell: log sem erros; prints no workspace 9 de cada cena da leva, com e sem efeitos, nas cores Neutral e
  Massa Cinzenta; medir CPU da shell com a cena ativa (meta: não subir mais que alguns % em repouso).
