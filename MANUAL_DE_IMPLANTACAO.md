# Manual de Implantação e Operação
## Stack de Atendimento e Automação: Chatwoot, Evolution API, MinIO, n8n

Este documento oficializa a configuração e o procedimento de implantação da solução integrada de atendimento via WhatsApp.

**Data da Versão:** 11/12/2025
**Status:** Produção / Validado
**IP do Servidor (Host):** `projetoravenna.cloud`

---

## 1. Visão Geral da Arquitetura

A solução é composta por serviços containerizados orquestrados via Docker Compose.

*   **Evolution API v2**: Gateway de WhatsApp. Conecta ao aparelho celular e converte mensagens em Webhooks.
*   **Chatwoot**: Plataforma de atendimento multicanal. Recebe as mensagens da Evolution API.
*   **MinIO**: Armazenamento de objetos (S3 Compatible). Armazena anexos e mídias do Chatwoot para persistência segura e performance.
*   **n8n**: Ferramenta de automação de fluxo (Workflow). Intermedia regras de negócio.
*   **Redis & Postgres**: Serviços de infraestrutura para persistência de dados e filas.

---

## 2. Configuração do Ambiente (Domínio projetoravenna.cloud)

Esta implantação está padronizada para operar no domínio `projetoravenna.cloud`. Todas as referências internas e webhooks foram configurados para este endereço.

### 2.1. Arquivos de Configuração Críticos

#### A. Raiz `.env`
Controla as variáveis globais da Evolution API e URLs base.
*   **SERVER_URL**: `https://evolution.projetoravenna.cloud`

#### B. `Chatwoot/.env`
Controla a configuração do Chatwoot, incluindo conexão com banco, Redis e **MinIO**.
*   **FRONTEND_URL**: `https://atendimento.projetoravenna.cloud`
*   **Storage (S3/MinIO)**: Configurado com estratégia de "Variáveis Duplas" (`AWS_*` e `STORAGE_*`) para garantir compatibilidade total.
    *   Endpoint: `https://minio.projetoravenna.cloud`
    *   Bucket: `chatwoot`
    *   Force Path Style: `true`

#### C. `n8n/compose.yaml`
Define as URLs de callback para os webhooks do n8n.
*   **WEBHOOK_URL**: `https://n8n.projetoravenna.cloud/`
*   **N8N_EDITOR_BASE_URL**: `https://n8n.projetoravenna.cloud/`

---

## 3. Procedimento de Implantação (Deploy)

Para subir o ambiente completo (ou reiniciar após alterações de IP):

1.  **Parar containers antigos (Limpeza):**
    ```powershell
    docker compose down
    ```

2.  **Verificar configurações:**
    Certifique-se de que os arquivos `.env` citados acima contenham os domínios corretos.

3.  **Criar Rede Docker:**
    A stack utiliza uma rede externa para comunicação entre os serviços. Crie-a se ainda não existir:
    ```powershell
    docker network create stack_network
    ```

4.  **Iniciar a Stack:**
    ```powershell
    docker compose up -d
    ```

5.  **Aguardar Inicialização:**
    Os serviços `evolution_api` e `chatwoot_web` podem levar de 1 a 2 minutos para ficarem totalmente operacionais (migrações de banco, etc).

6.  **Setup Inicial (Criação de Conta):**
    Acesse `http://192.168.29.71:3000`. Você será redirecionado para a tela de configuração inicial.
    *   Preencha os dados do administrador e da empresa.
    *   Siga o fluxo de onboarding do próprio Chatwoot.

---

## 4. Validação e Testes (Scripts Automatizados)

Para garantir que a integração está 100% funcional, utilize os scripts PowerShell localizados na pasta `scripts/`.

### 4.1. Diagnóstico Geral
Verifica o status de todos os serviços (n8n, Chatwoot, Evolution) e lista instâncias/webhooks.
*   **Script:** `scripts/check_services.ps1`
*   **Resultado Esperado:** Relatório verde com "STATUS: ONLINE" para todos os serviços.

### 4.2. Teste de Armazenamento (End-to-End)
Cria uma conversa, faz upload de anexo e valida se o Chatwoot redireciona corretamente para o MinIO (Porta 9004).
*   **Script:** `scripts/test_storage_integration.ps1`
*   **Resultado Esperado:** Mensagem "Redirecionamento OK!" e URL apontando para `:9004`.

---

## 5. Guias Detalhados

Para configurações específicas e aprofundadas de cada componente, consulte os guias dedicados:

*   📄 **[INTEGRACAO_CHATWOOT_MINIO.md](INTEGRACAO_CHATWOOT_MINIO.md)**: Detalha a configuração do armazenamento S3, solução de problemas de upload e variáveis de ambiente específicas do MinIO.
*   📄 **[INTEGRACAO_CHATWOOT_N8N.md](INTEGRACAO_CHATWOOT_N8N.md)**: Guia para configuração de Webhooks entre Chatwoot e n8n (Rede Interna Docker) e solução para validação de URL.
*   📄 **[INTEGRACAO_WHATSAPP.md](INTEGRACAO_WHATSAPP.md)**: Explica o fluxo da mensagem (Evolution -> Chatwoot -> n8n), configuração de Webhooks e criação de Caixas de Entrada.

---

## 6. Manutenção Futura

### Mudança de IP
Caso o servidor mude de IP novamente (ex: de `192.168.29.71` para outro), execute o processo de **Search & Replace** em todo o projeto, focando nos arquivos listados na seção 2.1.
Não esqueça de atualizar também os scripts na pasta `scripts/` para que os testes continuem válidos.

### Backup
Recomenda-se backup periódico dos volumes Docker, especialmente:
*   `pg_data` (Banco de dados PostgreSQL)
*   `redis_data` (Filas do Redis)
*   `minio_data` (Arquivos e Anexos)
