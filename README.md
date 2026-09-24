# marlabs-code-review-marketplace

Marketplace (Agent Plugins 1.0) do plugin **marlabs-code-review**: 2 agents + 9 skills de Code Review.

## Estrutura

```text
.
├── .github/plugin/marketplace.json          # catálogo do marketplace
├── .gitattributes                           # preserva os bytes do pacote (sem conversão de fim de linha)
├── install.ps1                              # instalação no projeto (Windows PowerShell)
├── install.sh                               # instalação no projeto (bash: Linux, macOS, Git Bash)
├── SHA256SUMS                               # hashes dos arquivos originais do POC
└── plugins/marlabs-code-review/
    ├── plugin.json                          # manifesto Agent Plugins 1.0
    ├── README.md
    ├── com.github.copilot/agents/           # 2 agents (Copilot)
    ├── skills/                              # 9 skills (portáveis)
    └── code-review/                         # CHANGELOG e modelo de decisões
```

## Antes de publicar

Substitua `code-review` pelo repositório onde este conteúdo for publicado, neste README e no valor padrão de `Repo`/`REPO` em `install.ps1` e `install.sh`, e crie a tag `v1.0.0`.

## Instalação no projeto (recomendada)

Os scripts copiam o pacote para a pasta `.github/` do projeto, nos mesmos caminhos usados pelo POC (`.github/agents`, `.github/skills`, `.github/code-review`). Assim os agents encontram o Core e as skills, e as regras ficam versionadas no Git do projeto, mantendo a leitura das regras pela `BASE_BRANCH`.

Execute na raiz do projeto (qualquer pasta dentro de um repositório git).

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/code-review/v1.0.0/install.ps1 | iex
```

Linux, macOS ou Git Bash:

```bash
curl -fsSL https://raw.githubusercontent.com/code-review/v1.0.0/install.sh | bash
```

Repositório privado (usa as credenciais git da máquina): clone o marketplace e execute o script do clone.

```bash
git clone --branch v1.0.0 https://github.com/code-review.git marlabs-code-review-marketplace
```

```powershell
.\marlabs-code-review-marketplace\install.ps1 -Target C:\caminho\do\projeto
```

```bash
bash marlabs-code-review-marketplace/install.sh --target /caminho/do/projeto
```

Opções:

| PowerShell | bash | Efeito |
|---|---|---|
| `-Target <pasta>` | `--target <pasta>` | Projeto de destino (padrão: pasta atual) |
| `-Repo code-review` | `--repo code-review` | Baixa o pacote desse repositório (também aceita URL git) |
| `-Ref v1.0.0` | `--ref v1.0.0` | Tag ou branch a instalar |
| `-Source <pasta>` | `--source <pasta>` | Usa um pacote local (pasta raiz deste repositório) |
| `-Yes` | `--yes` | Confirma a substituição de arquivos existentes sem perguntar |
| `-DryRun` | `--dry-run` | Mostra o plano sem alterar nada |

Com parâmetros no PowerShell remoto:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/code-review/v1.0.0/install.ps1))) -Ref v1.0.0 -DryRun
```

O que os scripts garantem:

- conferem o `SHA256SUMS` do pacote antes de copiar e os arquivos instalados depois de copiar;
- nunca sobrescrevem `.github/code-review/review-decisions.md` (decisões do time);
- mostram a versão instalada e a nova, e pedem confirmação antes de substituir arquivos existentes (sem terminal interativo, exigem `-Yes`/`--yes`);
- não alteram nada fora de `.github/agents`, `.github/skills` e `.github/code-review`, e não removem arquivos que não pertencem ao pacote;
- não fazem commit: ao final mostram os comandos para revisar e comitar.

Atualização para uma nova versão: execute o script com a nova tag, revise o diff e comite em um PR. Nesse PR, as regras aplicadas na revisão ainda são as da `BASE_BRANCH`; a nova versão passa a valer após o merge.

No Windows PowerShell 5.1, caminhos com mais de 260 caracteres não são suportados: use uma pasta com caminho mais curto.

## Instalação como plugin

Atenção: os agents leem o Core em `.github/skills/code-review-core/SKILL.md` do projeto. Instalado somente como plugin, o pacote fica fora do projeto e o agent interrompe a revisão por não encontrar as regras. Para executar revisões, use a instalação no projeto acima.

### Copilot CLI

```bash
copilot plugin marketplace add code-review
copilot plugin install marlabs-code-review@marlabs-code-review-marketplace
```

Instalação direta, sem marketplace:

```bash
copilot plugin install code-review:plugins/marlabs-code-review
```

Verificação (em uma sessão interativa do `copilot`): `/agent` lista os 2 agents e `/skills list` lista as 9 skills.

Atualização após nova versão: `copilot plugin update marlabs-code-review`.

### VS Code

Em `settings.json`:

```json
"chat.plugins.marketplaces": ["code-review"]
```

Depois, instale `marlabs-code-review` pela view de extensões (`@agentPlugins`) ou pelo comando **Chat: Install Plugin From Source**.

## Teste local antes de publicar

```bash
copilot plugin install ./plugins/marlabs-code-review
copilot plugin list
```

## Publicar uma nova versão

1. Atualize os arquivos do plugin.
2. Incremente `version` em `plugins/marlabs-code-review/plugin.json` e em `.github/plugin/marketplace.json`.
3. Crie a tag: `git tag v1.0.1 && git push --tags`.
