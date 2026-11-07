# unity-loc-tool

Ferramenta (Python 3.8+, sem dependências) para traduzir jogos **Unity que usam Unity Localization + Addressables**.
Testada com D1AL-ogue (Unity 6000.0.61f1). Funciona com bundles LZ4, LZMA ou sem compressão.

## Fluxo em 4 passos

```
python unity_loc_tool.py extract  "<bundle de textos en-US>" -o projects/MeuJogo/pt-BR
   (traduza os CSVs)
python unity_loc_tool.py check    projects/MeuJogo/pt-BR [--font fonte.ttf]
python unity_loc_tool.py build    "<bundle>" projects/MeuJogo/pt-BR -o saida --catalog ".../aa/catalog.bin"
python unity_loc_tool.py install  saida --game "C:\...\MeuJogo"      # faz backup (.bak)
python unity_loc_tool.py restore  --game "C:\...\MeuJogo"            # desfaz
```

- `extract` pode ser rodado de novo depois de uma atualização do jogo: mantém o que já foi traduzido, acrescenta textos novos e informa os removidos.
- `check` confere se `<tags>`, `{0}`, `\n` e quebras de linha batem com o original e se a **fonte do jogo** tem os caracteres usados (`--font`, requer `pip install fonttools`). Retorna erro se houver problema (bom para CI).
- `build` ignora (e avisa sobre) traduções com problema de formatação, para não quebrar o jogo.
- `--catalog` zera o CRC do bundle no `catalog.bin` (o Addressables recusa bundles modificados). Sem isso o jogo pode não abrir ou mostrar menus quebrados.

## Para tradutores
Veja [CONTRIBUTING.md](CONTRIBUTING.md). Não precisa instalar nada: edite os CSVs e abra um Pull Request.

## Limitações conhecidas
- Só edita **StringTables** do Unity Localization. Textos fixos na interface (ex.: "Repair Point", barra de atalhos, datas) ficam em outros assets e não são cobertos ainda.
- O bundle gerado é sem compressão (maior, mas válido). 
- Tabelas com metadados por entrada são puladas. Catálogos JSON (Addressables antigos) ainda não têm ajuste automático de CRC.
- Testado só em Windows/Unity 6; versões antigas do SerializedFile (< v17) não são suportadas.
- Não distribuímos arquivos do jogo. Use cópias que você mesmo possui.
