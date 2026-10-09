# Documento do Projeto & Status de Desenvolvimento - kfofo

---

## 🎯 Visão Geral do Projeto

O **kfofo** é um agregador inteligente de anúncios de imóveis (casas e apartamentos para aluguel, compra e financiamento). O objetivo principal é consolidar em uma única interface anúncios vindos dos maiores marketplaces imobiliários do Brasil, facilitando a busca do usuário e otimizando a experiência de encontrar o imóvel ideal sem duplicar esforços e sem necessidade de sair da plataforma para visualizar os detalhes.

---

## 🏗️ Arquitetura do Sistema

- **Abordagem**: Monolito Reativo com Phoenix LiveView.
- **Backend & Frontend**: Elixir + Phoenix Framework com LiveView (sem a necessidade de SPA separado em JS framework, garantindo menor complexidade de infraestrutura, baixa latência e alta concorrência com a BEAM).
- **Banco de Dados**: PostgreSQL com Ecto ORM.
- **Integrações de Dados (Scrapers/APIs)**: Módulos isolados em Elixir responsáveis pela busca e normalização dos dados vindos das plataformas externas (contando com runtime Node.js/got-scraping para bypass de TLS/anti-bot quando necessário).

---

## 🗺️ Roadmap de Integração de Marketplaces

1. **Fase 1 (Inicial)**: 🟢 **OLX** (Conector funcional e extração ativa).
2. **Fase 2**: 🟡 **Zap Imóveis**.
3. **Fase 3**: 🟠 **QuintoAndar**.
4. **Fase 4**: 🔴 **Imovelweb**.

---

## 💡 Planejamento de Funcionalidades por Prazo

### ⚡ 1. Imediato (Refinamentos de UI, UX e Carrossel)
- **Carregamento e Transição Suave do Carrossel de Imagens**:
  - Ajustar o carregamento para que todas as fotos do card venham carregadas previamente.
  - Implementar animação fluida de transição/deslizamento lateral (slide/track) ao navegar entre fotos pelas setas ou gestos de swipe, eliminando recarregamentos ou flashes a cada clique.
- **Redimensionamento dos Cards de Imóveis**:
  - Aumentar a escala e largura dos cards para ocuparem pelo menos 80% lateralmente, exibindo menos cards de uma vez por linha para uma experiência mais confortável e imersiva.
- **Expansão do Elemento de Pesquisa**:
  - Ampliar o tamanho lateral do componente de busca e filtros para acompanhar a nova escala da página.
- **Remoção de Elementos Residuais do Phoenix**:
  - Remover o cabeçalho padrão do Phoenix (`app.html.heex` / links @elixirphoenix) e restrições de largura herdadas (`max-w-2xl`).
- **Persistência dos Filtros de Busca (Cache / Cookies / LocalStorage / Query Params)**:
  - Salvar o estado da busca para que a recarga da página (F5) não resete os filtros e a localização preenchidos.
- **Estilização da Caixa de Texto de Busca**:
  - Exibir o texto inicial padrão da pesquisa em itálico e com tonalidade mais clara/suave.

---

### 🟡 2. Médio Prazo (Nova Jornada do Usuário, Detalhes & Portais)
- **Refatoração da Jornada do Usuário no Site**:
  - **1º Acesso (Página Inicial / Hero Search)**:
    - Interface focada em uma caixa de busca ampla e imersiva no centro da tela com imagem de fundo temática de lares/casas.
  - **Página de Resultados de Busca**:
    - Após submeter os filtros, transição para tela com layout em duas seções: barra lateral dedicada para filtros de pesquisa e área principal expandida com os cards de imóveis.
  - **Botão de Detalhes & Página Interna do Imóvel (`/properties/:id`)**:
    - Cada card terá botão dedicado de "Detalhes" abrindo a ficha completa do imóvel (galeria em alta resolução, ficha técnica com condomínio/IPTU, descrição completa e link de origem).
- **Expansão de Marketplaces (Novos Scrapers)**:
  - 🟡 **Zap Imóveis** (Fase 2).
  - 🟠 **QuintoAndar** (Fase 3).
  - 🔴 **Imovelweb** (Fase 4).
- **Refinamento de Scraping / Filtro de Região e Cidade (Ex: Nova Iguaçu, São João de Meriti, Resende / RJ)**:
  - Mapear e normalizar a hierarquia de mesorregiões e municípios da OLX para estados como RJ e SP (ex: Baixada/Metropolitana `/rio-de-janeiro-e-regiao/nova-iguacu`, Sul Fluminense `/serra-angra-dos-reis-e-regiao/resende`, Região dos Lagos, etc.) ou aplicar query param de busca direta por cidade (`q=...`), evitando que a OLX receba rotas sem a mesorregião e redirecione para anúncios genéricos da capital.
- **Filtros Avançados & Ordenação**:
  - Ordenação por preço (menor/maior), mais recentes e filtros adicionais de vagas e banheiros.
- **Destaque de Visualizações ("Nunca Visualizados" vs "Já Visualizados")**:
  - Identificação visual para anúncios já abertos pelo usuário e filtro para exibir apenas novidades.
- **Persistência de Buscas Salvas no Banco (Ecto / PostgreSQL)**:
  - Schemas para armazenamento de histórico e buscas favoritas.

---

### 🔵 3. Longo Prazo (Autenticação, Tendências & Alertas)
- **Sugestões Rápidas Dinâmicas (Top Buscas / Trending Searches)**:
  - Tabela no banco de dados (`searches_analytics` / `popular_locations`) para contabilizar os termos, bairros e cidades mais buscados pelos usuários da plataforma.
  - Alimentar dinamicamente os chips de "Sugestões Rápidas" da página inicial com as localizações em alta no momento.
- **Sistema de Autenticação (Google Login)**:
  - Login social com Google OAuth2 para sincronização de preferências entre dispositivos.
- **Sistema de Notificações de Novos Anúncios**:
  - Monitoramento contínuo e envio de alertas automáticos quando novos anúncios compatíveis forem encontrados.

---

## 📍 Status Atual do Desenvolvimento

| Etapa | Descrição | Prazo / Prioridade | Status |
| :--- | :--- | :---: | :---: |
| **Setup Base** | Setup Elixir + Phoenix LiveView + Tailwind + PostgreSQL | - | 🟢 **Concluído** |
| **Scraper OLX** | Conector OLX com bypass TLS e parser Floki | - | 🟢 **Concluído** |
| **Busca de Local** | Autocomplete preditivo (Google Places API New) com Bairro | - | 🟢 **Concluído** |
| **Carrossel & Imagens** | Carregamento total e animação de slide lateral | ⚡ Imediato | 🟢 **Concluído** |
| **Escala dos Cards** | Ampliação lateral dos cards (pelo menos 80% da tela) | ⚡ Imediato | 🟢 **Concluído** |
| **Escala da Busca** | Aumento da largura lateral do elemento de pesquisa | ⚡ Imediato | 🟢 **Concluído** |
| **Limpeza de Layout** | Remoção do header padrão Phoenix e restrição `max-w-2xl` | ⚡ Imediato | 🟢 **Concluído** |
| **Persistência da Busca**| Salvar filtros em cache/cookie/localStorage contra F5 | ⚡ Imediato | 🟢 **Concluído** |
| **Estilo da Busca** | Texto padrão em itálico e mais claro na caixa de texto | ⚡ Imediato | 🟢 **Concluído** |
| **Filtro Região/Cidade**| Mapeamento de regiões OLX (Nova Iguaçu, Meriti, Resende) | 🟡 Médio Prazo | ⏳ *Backlog* |
| **Nova Jornada (Hero)** | 1º acesso com busca centralizada e imagem de fundo | 🟡 Médio Prazo | 🟢 **Concluído** |
| **Layout Resultados** | Filtros na barra lateral e listagem de cards ao lado | 🟡 Médio Prazo | 🟢 **Concluído** |
| **Ordenação Resultados**| Ordenar por menor preço, maior preço e mais recentes | 🟡 Médio Prazo | 🟢 **Concluído** |
| **Filtros Adicionais** | Filtro de Tipo de Imóvel (apto/casa/quarto) e Vagas (1 a 5+) | 🟡 Médio Prazo | 🟢 **Concluído** |
| **Página de Detalhes**| Página interna de anúncio com ficha e galeria completa | 🟡 Médio Prazo | ⏳ *Planejado* |
| **Novos Portais** | Integrações com Zap Imóveis, QuintoAndar e Imovelweb | 🟡 Médio Prazo | ⏳ *Planejado* |
| **Top Buscas Dinâmicas**| Tabela de analytics para alimentar sugestões rápidas em alta | 🔵 Longo Prazo | ⏳ *Planejado* |
| **Auth & Alertas** | Google OAuth2 e notificações de novos imóveis | 🔵 Longo Prazo | ⏳ *Planejado* |
