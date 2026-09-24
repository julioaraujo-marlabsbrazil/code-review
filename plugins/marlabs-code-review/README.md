# marlabs-code-review

Plugin no formato **Agent Plugins 1.0** que instala, em uma única operação, os 3 agents e as 11 skills de Code Review e Validação de Requisitos.

## Conteúdo

| Componente | Local no plugin | Origem no POC |
|---|---|---|
| Agent Code Review Back-end (Marlabs) | `com.github.copilot/agents/code-review-backend.agent.md` | `.github/agents/code-review-backend.md` |
| Agent Code Review Front-end (Marlabs) | `com.github.copilot/agents/code-review-frontend.agent.md` | `.github/agents/code-review-frontend.md` |
| Agent Validação de Requisitos (Marlabs) | `com.github.copilot/agents/requirements-validation.agent.md` | `.github/agents/requirements-validation.md` |
| architecture-review | `skills/architecture-review/SKILL.md` | `.github/skills/architecture-review/SKILL.md` |
| caching-inspector | `skills/caching-inspector/SKILL.md` | `.github/skills/caching-inspector/SKILL.md` |
| change-impact-analysis | `skills/change-impact-analysis/SKILL.md` | `.github/skills/change-impact-analysis/SKILL.md` |
| code-review-core | `skills/code-review-core/SKILL.md` | `.github/skills/code-review-core/SKILL.md` |
| database-migration-review | `skills/database-migration-review/SKILL.md` | `.github/skills/database-migration-review/SKILL.md` |
| false-positive-learning | `skills/false-positive-learning/SKILL.md` | `.github/skills/false-positive-learning/SKILL.md` |
| requirements-extraction | `skills/requirements-extraction/SKILL.md` | `.github/skills/requirements-extraction/SKILL.md` |
| requirements-traceability | `skills/requirements-traceability/SKILL.md` | `.github/skills/requirements-traceability/SKILL.md` |
| security-review | `skills/security-review/SKILL.md` | `.github/skills/security-review/SKILL.md` |
| test-impact-review | `skills/test-impact-review/SKILL.md` | `.github/skills/test-impact-review/SKILL.md` |
| ui-ux-consistency | `skills/ui-ux-consistency/SKILL.md` | `.github/skills/ui-ux-consistency/SKILL.md` |
| Changelog (referência) | `code-review/CHANGELOG.md` | `.github/code-review/CHANGELOG.md` |
| Modelo de decisões (referência) | `code-review/review-decisions.md` | `.github/code-review/review-decisions.md` |
| Modelo de critérios de aceite do Jira (referência) | `code-review/jira-acceptance-criteria-template.md` | `.github/code-review/jira-acceptance-criteria-template.md` |

O conteúdo de todos os arquivos é idêntico byte a byte ao POC (ver `SHA256SUMS` na raiz do repositório). A única diferença é o nome dos arquivos de agent, que recebem a extensão `.agent.md` exigida pela especificação para `com.github.copilot/agents/`.

A versão `2.5.0` é a versão de distribuição do plugin e acompanha a versão das regras declarada em `skills/code-review-core/SKILL.md`.
