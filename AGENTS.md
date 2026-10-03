# Diretrizes para Agentes de IA (AGENTS.md)

Este documento estabelece as regras de engajamento, boas práticas e restrições para assistentes e agentes de Inteligência Artificial que atuarem no projeto **kfofo**.

---

## 🚫 Restrições Rígidas de Controle de Versão (Git)

1. **NUNCA fazer Commit:** A IA **não** deve executar `git commit`. A criação e finalização de commits fica a cargo exclusivo do desenvolvedor humano.
2. **NUNCA fazer Push:** A IA **não** deve executar `git push` para qualquer repositório remoto.
3. **Resumo de Pull Request Obrigatório:**
   - Sempre que concluir as tarefas em uma *feature branch*, a IA deve criar um arquivo Markdown (`PR_SUMMARY.md` na raiz) contendo:
     - **Resumo das Alterações**: Visão geral direta e sucinta do que foi implementado/corrigido.
     - **Como Testar**: Comandos diretos para validação (`mix test`, `mix format`, etc.).
     - **Checklist de Qualidade**: Confirmação dos critérios de aceitação básicos.
   - Este arquivo servirá para o desenvolvedor copiar e colar na descrição do Pull Request no GitHub.

---

## 🚀 Arquitetura & Stack Tecnológica

- **Linguagem / Framework**: Elixir com Phoenix LiveView.
- **Estilo Arquitetural**: Monolito Phoenix (Front-end web reativo com LiveView e Back-end Elixir integrados).
- **Banco de Dados**: PostgreSQL com Ecto.
- **Estilização**: Tailwind CSS / Vanilla CSS responsivo.
- **Web Scraping / Data Ingestion**: Módulos/scrapers isolados em Elixir para cada marketplace agregado.

---

## 📋 Boas Práticas e Convenções de Código

### Elixir & Phoenix
1. **Design por Contextos (Phoenix Contexts)**:
   - Manter a regra de negócio separada da camada de apresentação LiveView.
   - Exemplo de contextos: `Kfofo.Properties`, `Kfofo.Filters`, `Kfofo.Scrapers`, `Kfofo.Notifications`.
2. **Tratamento de Erros Idiomático**:
   - Usar tuplas de status `{:ok, result}` e `{:error, reason}`.
   - Evitar `try/rescue` desnecessários ou supressão silenciosa de exceções.
3. **Formatação & Qualidade**:
   - Sempre rodar `mix format` antes de considerar uma alteração pronta.
   - Escrever testes unitários e de integração (`mix test`) para contextos e LiveViews.
4. **Programação Funcional Idiomática (Evitar `if`)**:
   - Evitar o uso de estruturas `if` imperativas.
   - Dar preferência a Pattern Matching em cabeçalhos de função, `case`, `with`, Guard Clauses (`when`) ou funções utilitárias (`Enum`, `Map`, `String`).
5. **Comentários de Código**:
   - Evitar comentários óbvios, redundantes ou divisores de seção (ex: `# Private Helpers`, `# Helpers`).
   - Manter o código limpo e autoexplicativo, utilizando `@doc` e `@moduledoc` apenas onde agrega valor real.

---

## 🔄 Fluxo de Trabalho Esperado pela IA

1. **Investigar antes de alterar**: Inspecionar os contextos e arquivos existentes antes de propor edições.
2. **Executar Validações**: Rodar `mix test` e verificar compilação (`mix compile --warnings-as-errors`) sempre que criar/modificar código Elixir.
3. **Gerar Documentação de PR**: Criar/atualizar `PR_SUMMARY.md` no final de cada tarefa.
