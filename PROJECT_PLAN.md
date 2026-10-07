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

## 💡 Funcionalidades Mapeadas & Novas Demandas

### 1. Barra de Busca Inteligente de Localização (Autocomplete)
- Substituir campos manuais isolados de "Estado" e "Cidade" por um campo de busca integrado com sugestões preditivas.
- Integração com Google Places / Google Maps (ou base estruturada de geolocalização) para autocompletar e sugerir bairros, cidades e estados enquanto o usuário digita.

### 2. Cards com Mini-Carrossel de Imagens
- Correção na extração e renderização das imagens dos imóveis nos cards da listagem.
- Mini-carrossel interativo diretamente dentro do card (com setas de navegação anterior/próxima e indicadores de posição), reproduzindo a experiência visual intuitiva das principais plataformas.

### 3. Página Interna de Detalhes do Imóvel
- Página interna dedicada no Kfofo (`/properties/:id`) para exibição completa do imóvel, sem redirecionar o usuário para o site de origem.
- Exibição de galeria completa de fotos em alta resolução, descrição detalhada, localização no mapa, tabela de especificações (área, quartos, banheiros, vagas, condomínio, IPTU) e identificação da fonte de origem.

### 4. Identidade Visual da Marca Kfofo (Branding & UI)
- Inclusão do logotipo e marca oficial do **Kfofo** no cabeçalho e na identidade visual geral.
- Remoção de qualquer terminologia técnica interna da interface do usuário (ex: referências a "LiveView", "extração SSR", "Scraper", etc.), mantendo a comunicação totalmente voltada para o usuário final que busca um lar.

### 5. Filtros de Pesquisa Unificados
- Filtros abrangentes (faixa de preço, número de quartos/banheiros, vagas de garagem, tipo: aluguel ou venda).
- Normalização transparente dos filtros para os marketplaces suportados.

### 6. Salvamento de Pesquisas e Filtros
- Permite ao usuário salvar conjuntos de filtros pré-definidos (ex: *"Aluguel em Moema até R$ 3.500 com 2 vagas"*).
- Evita que o usuário precise reconfigurar os filtros a cada nova visita ao site.

### 7. Destaque de Visualizações ("Nunca Visualizadas" vs "Já Visualizadas")
- Mecanismo visual para diferenciar imóveis inéditos daqueles que o usuário já abriu/visualizou.
- Filtro dedicado para exibir apenas imóveis não visualizados, facilitando as primeiras sessões de busca e destacando novas oportunidades.

### 8. Sistema de Notificação de Novos Anúncios
- Monitoramento em tempo real/periódico de buscas salvas.
- Envio de alertas/notificações quando um novo imóvel alinhado aos filtros salvos for publicado.

### 6. Sistema de Autenticação (Google Login)
- Login social com Google OAuth2 (será implementado futuramente).
- Vínculo de pesquisas salvas e histórico de imóveis visualizados ao perfil do usuário.

---

## 📍 Status Atual do Desenvolvimento

| Etapa | Descrição | Status |
| :--- | :--- | :---: |
| **Setup Base** | Setup do Projeto Elixir + Phoenix LiveView + Tailwind | 🟢 **Concluído** |
| **Scraper OLX** | Conector OLX com bypass TLS (Node/got-scraping) e parser SSR Floki | 🟢 **Concluído** |
| **Listagem Inicial** | Página LiveView inicial com busca e exibição em grid | 🟢 **Concluído** |
| **Busca de Local** | Autocomplete preditivo de Estado, Cidade e Bairro (Google Maps / Places) | 🟢 **Concluído** |
| **Carrossel de Cards** | Correção de imagens e mini-carrossel interativo no card | 🟢 **Concluído** |
| **Identidade Kfofo** | Aplicação da marca Kfofo, logotipo e limpeza de termos técnicos na UI | ⏳ *Próximo Passo* |
| **Página de Detalhes**| Página interna de anúncio com galeria completa e ficha do imóvel | ⏳ *Próximo Passo* |
| **Banco & Filtros** | Persistência PostgreSQL com Ecto e salvamento de buscas | ⏳ *A Seguir* |
| **Novos Portais** | Integrações com Zap Imóveis, QuintoAndar e Imovelweb | ⏳ *Fase 2* |
| **Notificações & Auth**| Login social com Google e alertas de novos imóveis | ⏳ *Fase 3* |

---

## 🚀 Próximos Passos Imediatos

1. **Página de Detalhes do Imóvel (`/properties/:id`)**: Desenvolver a visualização interna do anúncio dentro do Kfofo sem redirecionamento externo.
2. **Branding Kfofo & Refinamento da UI**: Aplicar logotipo e refinar visual da página principal.
3. **Persistência de Buscas (Ecto / PostgreSQL)**: Salvar pesquisas e filtros pré-definidos do usuário.
