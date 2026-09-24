# marlabs-code-review

Pacote npm **marlabs-code-review**: instala os 3 agents (Code Review Front-end, Code Review Back-end e Validação de Requisitos) e as 11 skills na pasta `.github/` do projeto.

Por enquanto, a instalação é feita somente via npm/npx.

## Estrutura

```text
.
├── .gitattributes                           # preserva os bytes do pacote (sem conversão de fim de linha)
├── package.json                             # pacote npm "marlabs-code-review"
├── bin/install.js                           # instalador npm (Node.js 14 ou superior, sem dependências)
├── SHA256SUMS                               # hashes dos arquivos originais do POC
└── plugins/marlabs-code-review/
    ├── plugin.json                          # manifesto do pacote (versão de distribuição)
    ├── README.md
    ├── com.github.copilot/agents/           # 3 agents (Copilot)
    ├── skills/                              # 11 skills (portáveis)
    └── code-review/                         # CHANGELOG, modelo de decisões e modelo de critérios de aceite do Jira
```

## Instalação

Não exige conta git nem acesso a nenhum repositório: o pacote é baixado do registro público do npm. Requer Node.js 14 ou superior e git.

Execute na raiz do projeto (qualquer pasta dentro de um repositório git):

```bash
npx marlabs-code-review
```

Versão específica:

```bash
npx marlabs-code-review@2.5.0
```

Opções:

| Opção | Efeito |
|---|---|
| `--target <pasta>` | Projeto de destino (padrão: pasta atual) |
| `--yes`, `-y` | Confirma a substituição de arquivos existentes sem perguntar |
| `--dry-run` | Mostra o plano sem alterar nada |
| `--version`, `-v` | Mostra a versão do pacote |
| `--help`, `-h` | Mostra a ajuda |

Com npm 7 ou superior, as opções vão depois do nome do pacote: `npx marlabs-code-review --dry-run`. Para pular a pergunta do npm sobre instalar o pacote temporário, use `npx --yes marlabs-code-review`.

Se o projeto tiver um `.npmrc` apontando para um registro privado do cliente que não repassa pacotes públicos, indique o registro público:

```bash
npx --registry https://registry.npmjs.org marlabs-code-review
```

O que o instalador garante:

- confere o `SHA256SUMS` do pacote antes de copiar e os arquivos instalados depois de copiar;
- nunca sobrescreve `.github/code-review/review-decisions.md` (decisões do time);
- mostra a versão instalada e a nova, e pede confirmação antes de substituir arquivos existentes (sem terminal interativo, exige `--yes`);
- não altera nada fora de `.github/agents`, `.github/skills` e `.github/code-review`, e não remove arquivos que não pertencem ao pacote;
- não faz commit: ao final mostra os comandos para revisar e comitar.

Atualização para uma nova versão: execute `npx marlabs-code-review@<versão>`, revise o diff e comite em um PR. Nesse PR, as regras aplicadas na revisão ainda são as da `BASE_BRANCH`; a nova versão passa a valer após o merge.

Logo após uma publicação, o download pode responder `404 Not Found` por alguns minutos enquanto o CDN do npm atualiza. Aguarde e execute de novo.

## Publicar no npm

A conta do npm usa 2FA por chave de segurança/passkey (sem código OTP de 6 dígitos). A confirmação é feita pelo navegador, o que exige **npm 9 ou superior (Node.js 18 ou superior)**. Com versões antigas, como o npm 6 do Node.js 14, o `npm publish` pede um OTP que não existe e a publicação falha.

O instalador continua compatível com Node.js 14; somente a publicação exige a versão mais nova. Com o nvm:

```bash
nvm install 22
nvm use 22
npm -v
```

Na raiz deste repositório:

```bash
npm login --auth-type=web
npm whoami
npm pack --dry-run
npm publish
```

O `npm login --auth-type=web` abre o navegador para confirmar com a passkey. Se o `npm publish` pedir confirmação, abra o link `https://www.npmjs.com/auth/cli/...` exibido, confirme com a passkey e pressione ENTER no terminal.

Depois, volte para a versão de Node.js do seu projeto (por exemplo, `nvm use 14`).

Tokens com "Bypass 2FA" não são recomendados: eles perdem a publicação direta a partir de janeiro de 2027 (ver [changelog do GitHub](https://github.blog/changelog/2026-07-31-restricting-npm-bypass-2fa-granular-access-tokens/)). Para automatizar a publicação, use trusted publishing (OIDC) ou staged publishing.

## Publicar uma nova versão

1. Os arquivos de agents e skills não são alterados neste repositório: eles devem permanecer idênticos ao POC, conferidos pelo `SHA256SUMS`. Se o POC mudar, copie os novos arquivos e regenere o `SHA256SUMS`.
2. Incremente `version` em `package.json` e em `plugins/marlabs-code-review/plugin.json`.
3. Publique no npm (seção acima). Uma versão publicada no npm não pode ser sobrescrita.
4. Crie a tag: `git tag v<versão> && git push --tags`.
