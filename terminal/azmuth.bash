# Project Azmuth — integração com o bash (carregado pelo ~/.bashrc).
# Prompt na cor 6 do terminal = cor primária do DNA ativo (o kitty troca ao vivo).

__azmuth_prompt() {
    local s=$?
    local c6='\[\e[36m\]' dim='\[\e[90m\]' red='\[\e[31m\]' r='\[\e[0m\]'
    local mark="${c6}❯${r}"
    (( s != 0 )) && mark="${red}❯${r}"
    local git=""
    if b=$(git symbolic-ref --short HEAD 2>/dev/null); then git=" ${dim}${b}${r}"; fi
    PS1="${c6}⧗${r} ${dim}\u${r} ${c6}\w${r}${git} ${mark} "
}
PROMPT_COMMAND="__azmuth_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# banner do Omnitrix ao abrir o kitty (não em terminais embutidos, ssh etc.)
if [[ $TERM == xterm-kitty && -z $AZMUTH_NO_BANNER && $SHLVL -le 2 ]] && command -v fastfetch >/dev/null; then
    fastfetch
fi
