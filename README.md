# Polityka Prywatności — HERBORG

Statyczna strona z polityką prywatności sklepu HERBORG sp. z o.o., przygotowana
na potrzeby weryfikacji aplikacji w Facebook App Review.

Publikacja: <https://ogloszenia-byte.github.io/privacy-policy-herborg/>

```
index.html                  cała strona (HTML + CSS inline, bez zależności)
.claude/settings.json       deklaracja zestawu pluginów Claude Code
.claude/setup-plugins.sh    instalator tego zestawu
```

---

## Zestaw pluginów Claude Code

### Szybki start

```sh
./.claude/setup-plugins.sh          # dla wszystkich projektów (domyślnie)
./.claude/setup-plugins.sh project  # tylko dla tego repozytorium
./.claude/setup-plugins.sh local    # tylko dla tego repo, poza gitem
```

Skrypt jest idempotentny — można go uruchamiać wielokrotnie. Pierwsze
uruchomienie na czystej maszynie zajmuje ok. 13 s (klonowanie marketplace'ów),
kolejne ok. 5 s. Pluginy ładują się przy starcie sesji, więc **po instalacji
trzeba zrestartować Claude Code**.

### Dlaczego potrzebny jest skrypt, a nie sam plik konfiguracyjny

Sam `.claude/settings.json` **nie zainstaluje pluginów** i nigdy tego nie zrobi.
Claude Code celowo odmawia instalowania czegokolwiek, co jest zadeklarowane
wyłącznie przez plik śledzony przez gita. Widać to wprost w logu:

```
Skipped auto-recording superpowers@superpowers-marketplace
  — enabled only by repo-authored settings
installPluginsForHeadless: no marketplaces declared
Found 0 plugins (0 enabled, 0 disabled)
```

Wewnętrznie decyduje o tym flaga `fromOwnConfig`, prawdziwa tylko dla ustawień
użytkownika albo dla **nieśledzonego** przez gita `settings.local.json`. To nie
jest błąd, tylko granica bezpieczeństwa: *repozytorium nie ma prawa instalować
oprogramowania na cudzej maszynie*. Gdyby było inaczej, każde sklonowane repo
mogłoby po cichu doinstalować sobie kod.

Dlatego ten projekt **nie** zawiera hooka `SessionStart`, który obchodziłby tę
granicę. Instalację uruchamia świadomie człowiek — repozytorium nie robi tego
za niego.

Rola `.claude/settings.json` jest więc węższa, ale realna: rejestruje
marketplace'y, deklaruje zamiar i sprawia, że CLI samo podpowiada brakującą
komendę.

### Wybór zasięgu

| Zasięg | Gdzie zapisuje | Zakres działania | Uwagi |
| --- | --- | --- | --- |
| `user` *(domyślny)* | `~/.claude/settings.json` | każdy projekt | jedyny, który sam się odtwarza po skasowaniu `~/.claude/plugins` |
| `project` | `.claude/settings.json` | tylko to repo | zgodny z podpowiedzią samego CLI |
| `local` | `.claude/settings.local.json` | tylko to repo | poza gitem; nie odtwarza się po skasowaniu cache'u |

Instalacja `user` nie nadpisuje istniejących ustawień — sprawdzone: `theme`,
`env` i cudze wpisy `enabledPlugins` przetrwały instalację bez zmian.

### Co się instaluje i ile to kosztuje

Koszt tokenowy dotyczy **każdej sesji**, niezależnie od tego, czy plugin zostanie
użyty. Liczby pochodzą z `claude plugin details`.

| Plugin | Tokeny/sesję | Hooki | Dysk |
| --- | ---: | ---: | ---: |
| `pr-review-toolkit@claude-code-plugins` | ~2 877 | 0 | 88 KB |
| `claude-mem@thedotmack` | ~1 755 | 6 | 474 MB |
| `superpowers@superpowers-marketplace` | ~688 | 1 | 3,2 MB |
| `frontend-design@claude-code-plugins` | ~78 | 0 | 44 KB |
| `code-review@claude-code-plugins` | ~20 | 0 | 40 KB |
| `security-guidance@claude-code-plugins` | ~0 | 4 | 660 KB |
| **razem** | **~5 418** | **11** | **~776 MB** |

### Na co warto zwrócić uwagę

Zestaw jest kompletny zgodnie z zamówieniem, ale trzy pozycje mają koszty, które
lepiej znać przed podjęciem decyzji:

- **`claude-mem`** to 474 MB plus klon marketplace'u (274 MB) — ok. 96% całego
  zajętego miejsca. Uruchamia demona, hookuje `PostToolUse` z matcherem `*`
  (kod przy każdym wywołaniu narzędzia) i trzyma dane w globalnym magazynie
  `~/.claude-mem`, wspólnym dla wszystkich projektów. To narzędzie osobiste —
  zasięg `project` niewiele przy nim daje.
- **`security-guidance`** instaluje przy starcie sesji środowisko `pip`
  i uruchamia wywołanie modelu przy każdym zakończeniu tury, na Twoim rozliczeniu.
- **`code-review`** dubluje wbudowane w CLI polecenia `/code-review`
  i `/security-review`, które są dostępne bez żadnego pluginu.

Żeby pominąć któryś z nich, zakomentuj odpowiednią linię w liście `PLUGINS`
w `.claude/setup-plugins.sh`.

`enabledPlugins` w pliku projektu **wymusza włączenie** tych pluginów także
u osoby, która wyłączyła je u siebie. Aby się wypisać, ustaw `false`
w `.claude/settings.local.json` — ten plik jest w `.gitignore` i ma tam zostać.

### Windows

Skrypt wymaga powłoki POSIX (Git Bash, WSL). W PowerShell te same komendy
działają bezpośrednio — kolejność jest istotna, marketplace'y muszą być
zarejestrowane przed pluginami:

```powershell
claude plugin marketplace add anthropics/claude-code
claude plugin marketplace add obra/superpowers-marketplace
claude plugin marketplace add thedotmack/claude-mem

claude plugin install superpowers@superpowers-marketplace
claude plugin install frontend-design@claude-code-plugins
claude plugin install code-review@claude-code-plugins
claude plugin install pr-review-toolkit@claude-code-plugins
claude plugin install security-guidance@claude-code-plugins
claude plugin install claude-mem@thedotmack
```

Każdy plugin musi mieć **osobne wywołanie**. Podanie kilku naraz instaluje tylko
pierwszy i mimo to kończy się kodem 0 — składnia CLI to `<plugin>`,
w liczbie pojedynczej.

### Weryfikacja i usuwanie

```sh
claude plugin list                  # powinno pokazać 6 pozycji "√ enabled"
claude plugin marketplace list      # powinno pokazać 3 marketplace'y
claude plugin uninstall <nazwa>     # usunięcie pojedynczego pluginu
```
