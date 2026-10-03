# Diretrizes para Agentes de IA (AGENTS.md)

Este documento estabelece as regras de engajamento, boas práticas e restrições para assistentes e agentes de Inteligência Artificial que atuarem no projeto **kfofo**.

---

## 🚫 Restrições Rígidas de Controle de Versão (Git)

1. **NUNCA fazer Commit:** A IA **não** deve executar `git commit`. A criação e finalização de commits fica a cargo exclusivo do desenvolvedor humano.
2. **NUNCA fazer Push:** A IA **não** deve executar `git push` para qualquer repositório remoto.
3. **Resumo de Pull Request Obrigatório:**
   - Sempre que concluir as tarefas em uma *feature branch*, a IA deve criar um arquivo Markdown (ex: `PR_SUMMARY.md` na raiz ou em um diretório temporário) contendo:
     - **Resumo das Alterações**: Visão geral de alto nível do que foi implementado/corrigido.
     - **Lista de Modificações**: Arquivos criados, alterados ou removidos.
     - **Como Testar**: Passos claros para validar as mudanças.
     - **Checklist de Qualidade**: Confirmação de testes executados (`mix test`), formatação (`mix format`), etc.
   - Este arquivo servirá para o desenvolvedor copiar e colar diretamente na descrição do Pull Request no GitHub/GitLab.

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

---

## 🔄 Fluxo de Trabalho Esperado pela IA

1. **Investigar antes de alterar**: Inspecionar os contextos e arquivos existentes antes de propor edições.
2. **Executar Validações**: Rodar `mix test` e verificar compilação (`mix compile --warnings-as-errors`) sempre que criar/modificar código Elixir.
3. **Gerar Documentação de PR**: Criar a documentação no final da tarefa conforme a regra de Git acima.
