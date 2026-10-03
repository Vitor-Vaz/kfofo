# kfofo 🏡

Agregador inteligente de imóveis (aluguel, compra e financiamento) integrando os maiores marketplaces do Brasil em um monolito Phoenix LiveView com Elixir.

---

## 📚 Documentação do Projeto

- 📌 **[Plano de Desenvolvimento & Status (PROJECT_PLAN.md)](./PROJECT_PLAN.md)**: Detalhamento de funcionalidades, roadmap de marketplaces (OLX, Zap Imóveis, QuintoAndar, Imovelweb), modelagem de dados e status atual.
- 🤖 **[Diretrizes para IAs (AGENTS.md)](./AGENTS.md)**: Regras de engajamento, restrições de Git (sem commit/push direto por IA) e modelo de PR Summary.

---

## 🛠️ Stack Tecnológica

- **Backend & Frontend**: Elixir 1.16 + Phoenix 1.7 LiveView + Bandit
- **Database**: PostgreSQL (Ecto)
- **Styling**: Tailwind CSS + Core Components

---

## 🚀 Como Rodar Localmente

1. Obtenha as dependências do Elixir:
   ```bash
   mix deps.get
   ```

2. Crie e migre o banco de dados PostgreSQL (certifique-se que o PostgreSQL está rodando):
   ```bash
   mix ecto.setup
   ```

3. Inicie o servidor Phoenix:
   ```bash
   mix phx.server
   # ou interativo via IEx:
   iex -S mix phx.server
   ```

Acesse [`http://localhost:4000`](http://localhost:4000) no seu navegador.
