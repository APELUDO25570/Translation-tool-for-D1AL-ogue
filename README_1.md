#unity-loc-tool

Ferramenta (Python 3.8+, sem dependências) para traduzir **jogos Unity que usam Unity Localization + Addressables**.

Testado com D1AL-ogue (Unity 6000.0.61f1). Funciona com bundles LZ4, LZMA ou sem compressão.

Fluxo de 4 etapas

```
python unity_loc_tool.py extract "<pacote de textos em inglês americano>" -o projects/MyGame/pt-BR

(traduz os arquivos CSV)
python unity_loc_tool.py check projects/MyGame/pt-BR [--font font.ttf]
python unity_loc_tool.py build "<pacote>" projects/MyGame/pt-BR -o output --catalog ".../aa/catalog.bin"
python unity_loc_tool.py install output --game "C:\...\MyGame" # cria um backup (.bak)
python unity_loc_tool.py restore --game "C:\...\MyGame" # desfaz as alterações
```

- `extract` pode ser executado novamente após uma atualização do jogo: ele mantém o que já foi traduzido, adiciona novos textos e informa sobre os removidos.

- - `check` verifica se `<tags>`, `{0}`, `\n` e quebras de linha correspondem ao original e se a **fonte do jogo** possui os caracteres usados (`--font`, requer `pip install fonttools`). Retorna um erro se houver algum problema (útil para CI).

- `build` ignora (e avisa sobre) traduções com problemas de formatação, para não quebrar o jogo.

- `--catalog` redefine o CRC do pacote em `catalog.bin` (Addressables rejeita pacotes modificados). Sem isso, o jogo pode não abrir ou pode exibir menus quebrados.

## Para tradutores
Consulte [CONTRIBUTING.md](CONTRIBUTING.md). Nenhuma instalação é necessária: edite os arquivos CSV e abra um Pull Request.

## Limitações conhecidas
- Edita apenas **StringTables** da Unity Localization. Textos fixos na interface (ex.: "Ponto de Reparo", barra de atalhos, datas) estão localizados em outros recursos e ainda não foram incluídos.

O pacote gerado não está compactado (é maior, mas válido).

Tabelas com metadados por entrada são ignoradas. Catálogos JSON (Addressables antigos) ainda não possuem ajuste automático de CRC.

Testado apenas no Windows/Unity 6; versões anteriores do SerializedFile (< v17) não são suportadas.

Não distribuímos arquivos do jogo. Use cópias que você possui. 