# Como ajudar a traduzir

1. Abra o arquivo CSV da tabela em `projects/<jogo>/<idioma>/` (Excel, LibreOffice ou Google Planilhas; codificação UTF-8).
   `DialogueTable_*.csv` é a maior (diálogos).
2. Preencha **somente** a coluna `translation`. Linha vazia = continua em inglês no jogo.
3. Regras:
   - Mantenha idênticos: `<color=...>`, `<blink>`, `<shake ...>`, `{0}`, `{1}` e `\n` (barra + n). Não troque por quebra de linha real.
   - Não use aspas curvas nem caracteres fora da fonte do jogo (rode `check --font`).
   - Falas curtas: o balão do jogo é pequeno. Evite textos muito mais longos que o inglês.
   - Consistência: Chroma City, Neon Shine, E.V.E, Zênite Cromático, Dia da Noite Polar (veja o glossário abaixo).
4. Rode `python unity_loc_tool.py check projects/<jogo>/<idioma>` antes de enviar. O CI faz a mesma checagem.
5. Abra um Pull Request. Uma tabela ou um trecho de linhas por PR facilita a revisão.

## Glossário (D1AL-ogue pt-BR)
Chroma City · Neon Shine · E.V.E(s) · Oficiais de Estabilidade · Zênite Cromático · Dia da Noite Polar ·
LDS (Síndrome de Deficiência de Luz) · Unidade de Energia / Lógica / Neural · Unidade Sináptica · Gerente (o Chris).
