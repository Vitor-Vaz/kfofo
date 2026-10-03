# Documento do Projeto & Status de Desenvolvimento - kfofo

---

## 🎯 Visão Geral do Projeto

O **kfofo** é um agregador inteligente de anúncios de imóveis (casas e apartamentos para aluguel, compra e financiamento). O objetivo principal é consolidar em uma única interface reativa anúncios vindos dos maiores marketplaces imobiliários do Brasil, facilitando a busca do usuário e otimizando a experiência de encontrar o imóvel ideal sem duplicar esforços.

---

## 🏗️ Arquitetura do Sistema

- **Abordagem**: Monolito Reativo com Phoenix LiveView.
- **Backend & Frontend**: Elixir + Phoenix Framework com LiveView (sem a necessidade de SPA separado em JS framework, garantindo menor complexidade de infraestrutura, baixa latência e alta concorrência com a BEAM).
- **Banco de Dados**: PostgreSQL com Ecto ORM.
- **Integrações de Dados (Scrapers/APIs)**: Módulos isolados em Elixir responsáveis pela busca e normalização dos dados vindos das plataformas externas.

---

## 🗺️ Roadmap de Integração de Marketplaces

1. **Fase 1 (Inicial)**: 🟢 **OLX** (Base inicial de testes e validação de scraping/API).
2. **Fase 2**: 🟡 **Zap Imóveis**.
3. **Fase 3**: 🟠 **QuintoAndar**.
4. **Fase 4**: 🔴 **Imovelweb**.

---

## 💡 Funcionalidades Mapeadas

### 1. Barra de Pesquisa Agregada
- Barra de pesquisa unificada no topo do site para busca por cidade, bairro, tipo de imóvel ou palavra-chave.
- Consulta simultânea nos conectores dos marketplaces agregados.

### 2. Filtros de Pesquisa Unificados
- Filtros abrangentes (faixa de preço, número de quartos/banheiros, vagas de garagem, tipo de contrato: aluguel, compra, financiamento).
- Normalização dos filtros para que funcionem de forma transparente em todos os marketplaces suportados.

### 3. Salvamento de Pesquisas e Filtros
- Permite ao usuário salvar conjuntos de filtros pré-definidos (ex: *"Aluguel em Moema até R$ 3.500 com 2 vagas"*).
- Evita que o usuário precise reconfigurar os filtros a cada nova visita ao site.

### 4. Destaque de Visualizações ("Nunca Visualizadas" vs "Já Visualizadas")
- Mecanismo visual para diferenciar imóveis inéditos daqueles que o usuário já abriu/visualizou.
- Filtro dedicado para exibir apenas imóveis não visualizados, facilitando as primeiras sessões de busca e destacando novas oportunidades.

### 5. Sistema de Notificação de Novos Anúncios
- Monitoramento em tempo real/periódico de buscas salvas.
- Envio de alertas/notificações quando uma nova casa alinhada aos filtros salvos for publicada em qualquer um dos marketplaces agregados.

### 6. Sistema de Autenticação (Google Login)
- Login social com Google OAuth2 (será implementado futuramente).
- Vínculo de pesquisas salvas e histórico de imóveis visualizados ao perfil do usuário.

---

## 🗄️ Modelagem de Banco de Dados

### Fase Inicial
- **Tabela `filters`**: Armazena as pesquisas e filtros configurados (parâmetros de busca, valores mínimos/máximos, localização, tipo de contrato).
- **Tabela `property_views` / cookie local**: Registro do histórico de imóveis visualizados.

### Fase Futura
- **Tabela `users`**: Armazena dados do usuário (Google ID, e-mail, nome, preferências de notificação).
- **Relacionamento**: `users` -> `filters` (1 para N).

---

## 📍 Status Atual do Desenvolvimento (Onde Estamos)

| Etapa | Descrição | Status |
| :--- | :--- | :---: |
| **Fase 0** | Definição de Escopo, Arquitetura e Regras da IA (`AGENTS.md`, `PROJECT_PLAN.md`) | 🟢 **Concluído** |
| **Fase 1.1** | Setup do Projeto Elixir + Phoenix LiveView (`mix phx.new`) | ⏳ *Próximo Passo* |
| **Fase 1.2** | Configuração do PostgreSQL e Banco de Dados | ⏳ *A Seguir* |
| **Fase 1.3** | Criação do Contexto `Kfofo.Filters` e tabela `filters` | ⏳ *A Seguir* |
| **Fase 1.4** | Construção da LiveView com Barra de Pesquisa e Filtros | ⏳ *Planejado* |
| **Fase 1.5** | Conector / Scraper Inicial da OLX | ⏳ *Planejado* |
| **Fase 1.6** | Controle de Imóveis "Visualizados vs Nunca Visualizados" | ⏳ *Planejado* |
| **Fase 2.0** | Integrações Zap Imóveis, QuintoAndar, Imovelweb | ⏳ *Futuro* |
| **Fase 3.0** | Sistema de Notificações e Login com Google | ⏳ *Futuro* |

---

## 🚀 Próximos Passos Imediatos

1. Inicializar o projeto Phoenix LiveView na pasta do repositório (`mix phx.new . --live`).
2. Configurar a conexão com o PostgreSQL em `config/dev.exs`.
3. Criar a migração Ecto e o contexto `Kfofo.Filters` para a tabela `filters`.
4. Desenvolver o componente LiveView da Barra de Pesquisa e Painel de Filtros.
