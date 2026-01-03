# 📱 Guia de Integração: WhatsApp (Evolution API) -> Chatwoot -> n8n -> GLPI

## Produção (Ubuntu + aapanel)

- Pré‑requisitos:
  - Docker Engine e plugin Compose instalados
  - Crie a rede externa: `docker network create stack_network`
  - Domínio configurado no aapanel com SSL (Let's Encrypt) e reverse proxy

- Ajustes de `.env` (raiz):
  - `SERVER_URL=https://SEU_DOMINIO_API` (Evolution)
  - `AUTHENTICATION_API_KEY` defina um segredo forte
  - `POSTGRES_PASSWORD` e `REDIS_PASSWORD` fortes
  - N8N: defina `N8N_BASIC_AUTH_*` e mude `WEBHOOK_URL`/`N8N_EDITOR_BASE_URL` para `https://SEU_DOMINIO_N8N/`

- Chatwoot (`Chatwoot/.env`):
  - `FRONTEND_URL=https://SEU_DOMINIO_CHATWOOT`
  - `FORCE_SSL=true`
  - `SECRET_KEY_BASE` forte

- Exposição de portas: bind em `127.0.0.1` (já aplicado nos compose) e publique via aapanel:
  - Chatwoot → proxy para `http://127.0.0.1:3000`
  - Evolution API → `http://127.0.0.1:8081`
  - n8n → `http://127.0.0.1:5678`
  - GLPI → `http://127.0.0.1:18080`
  - Zabbix Web → `http://127.0.0.1:18081`
  - MinIO Console → `http://127.0.0.1:9005`

- Subir stack:
  - `docker compose up -d`

- Checks de saúde:
  - `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081/manager/health` → `200`
  - `docker exec chatwoot_web wget --spider -q http://evolution_api:8080/manager/health`
  - `docker exec evolution_api wget --spider -q http://chatwoot_web:3000`
  - `docker exec chatwoot_web wget --spider -q http://n8n:5678/`

- Instância e QR (Evolution v2.3.7):
  - Pelo Manager: criar instância “WhatsApp (Baileys)” com `qrcode=true`
  - Via API: `POST /instance/create` com `{"instanceName":"...","qrcode":true}`
  - Recuperar QR: `GET /instance/connect/{instanceName}` (campo `base64`)

- Integrações:
  - Evolution → Chatwoot: já configurado em `evolution/compose.yaml` (`CHATWOOT_URL=http://chatwoot_web:3000`)
  - Chatwoot → n8n: use `http://n8n:5678/webhook/...` na automação
  - n8n → GLPI: configure credenciais e endpoints no workflow

- Segurança:
  - Troque todos os segredos padrão no `.env`
  - Restrinja portas públicas ao aapanel; não exponha diretamente em 0.0.0.0
  - Faça backup dos volumes Docker (Postgres, Redis, Chatwoot storage, Evolution instances)

## Teste ponta a ponta

- Criar instância e gerar QR → parear WhatsApp
- Enviar mensagem WhatsApp → chega ao Chatwoot
- Disparar fluxo n8n via webhook → criar/atualizar ticket no GLPI

## Troubleshooting

- "Invalid integration" ao criar instância:
  - Use o Manager ou tente `integration` válido (p.ex. `WHATSAPP-BAILEYS`)
  - Se persistir, omita `integration` com `qrcode=true`

- QR não aparece:
  - Remova a instância e recrie
  - Mantenha `CONFIG_SESSION_PHONE_CLIENT/NAME=Chrome` e não defina versão


Este guia detalha o processo para configurar a comunicação entre o WhatsApp (via Evolution API), a plataforma de atendimento Chatwoot e o orquestrador n8n. O objetivo final é permitir que mensagens recebidas via WhatsApp possam abrir tickets automaticamente no GLPI ou serem tratadas por agentes humanos.

# 📱 Esquema de Configuração da Automação (Chatwoot -> n8n)

 A chave do sucesso é usar o **endereço interno** (nome do serviço) para a comunicação entre containers e o **endereço externo** (192.168.29.71) onde for necessário (como na criação da URL do n8n para visualização).

---

## Fase 1: Chatwoot <-> Evolution (O Canal)

Aqui, o Chatwoot precisa se comunicar com a Evolution API para gerenciar o WhatsApp.

| Configuração | Local | Valor a Inserir | Observações |
| :--- | :--- | :--- | :--- |
| **Evolution API URL** | Chatwoot (Configuração do Inbox) | `http://evolution_api:8080` | **Importante:** Use o nome do serviço Docker (`evolution_api`) e a **porta interna 8080** (a porta 8081 é apenas para acesso externo). |
| **Evolution API Key** | Chatwoot (Configuração do Inbox) | `B8963286-1598-4542-8952-223366998855` | Chave definida no `.env` da Evolution. |
| **Evolution Instance Name** | Chatwoot (Configuração do Inbox) | `chatwoot_session` | O nome da instância criado na Evolution. |

---

## Fase 2: n8n (O Gatilho)

O n8n precisa gerar a URL que o Chatwoot chamará.

### 2.1. Configuração do Nó Webhook (n8n)
1.  Crie um Workflow no n8n.
2.  Adicione o nó **Webhook**.
    *   **Method:** POST.
    *   **Endpoint URL:** Deixe o n8n gerar a URL. Ela será similar a: `http://192.168.29.71:5678/webhook/SEU_ID_UNICO`
    *   *Nota: O n8n usará o IP externo configurado (192.168.29.71) pois definimos `WEBHOOK_URL` no compose.*

### 2.2. Obter a URL Interna para o Chatwoot
A URL do passo 2.1 é a URL pública (para acesso externo). No entanto, quando configurarmos o Chatwoot, **devemos modificar o host** para usar o endereço interno do Docker:

| Tipo de URL | Endereço Interno a Ser Usado no Chatwoot |
| :--- | :--- |
| **Webhook URL** | `http://n8n:5678/webhook/SEU_ID_UNICO` |

---

## Fase 3: Chatwoot -> n8n (O Webhook de Saída)

Esta é a ponte principal para iniciar a automação.

| Configuração | Local | Valor a Inserir | Observações |
| :--- | :--- | :--- | :--- |
| **Webhook URL** | Chatwoot (Configurações > Webhooks) | `http://n8n:5678/webhook/SEU_ID_UNICO` | **Crucial:** Use o nome do serviço `n8n` para a comunicação interna entre os containers. |
| **Webhook Eventos** | Chatwoot (Configurações > Webhooks) | Marcar: `message_created`, `conversation_created` | Garante que novas mensagens de WhatsApp acionem o fluxo. |
| **Filtro de Inbox** | Chatwoot (Configurações > Webhooks) | Filtrar para o Inbox de WhatsApp | Recomendado para evitar que mensagens de Email ou Chat Live ativem a automação indevidamente. |

---

## ✅ Lista de Verificação Pós-Configuração

Após inserir as URLs conforme o esquema acima, execute estes testes:

1.  **Evolution OK:** Envie um WhatsApp. A mensagem aparece no Chatwoot? (Se sim, Fase 1 OK).
2.  **n8n Escutando:** Ative o Workflow no n8n.
3.  **Webhook OK:** Envie um segundo WhatsApp. O nó Webhook Trigger do n8n mostra um Item de dados recebido? (Se sim, Fase 2 e 3 OK).

---

## 🛠️ Solução de Problemas Comuns

### Erro na Geração do QR Code / Conexão (Evolution API v2.1.1+)

Se você estiver enfrentando problemas onde o QR Code não é gerado ou a conexão cai constantemente, certifique-se de que a versão da Evolution API e as variáveis de ambiente de identificação do navegador estejam configuradas corretamente.

**Versão Recomendada:**
Certifique-se de usar a tag específica da versão no seu `.env` ou `docker-compose.yaml` (evite usar `latest` em produção para garantir estabilidade):
```bash
EVOLUTION_IMAGE=atendai/evolution-api:v2.1.1
```

**Variáveis Obrigatórias para Conexão (Fix do Chrome):**
Nas versões mais recentes da biblioteca subjacente (Baileys), é necessário identificar explicitamente o cliente como um navegador Chrome para evitar bloqueios ou falhas na geração do QR Code. Adicione/Verifique estas variáveis no arquivo `.env` da Evolution API:

```env
# Correção para geração de QR Code e estabilidade da conexão
CONFIG_SESSION_PHONE_CLIENT=Chrome
CONFIG_SESSION_PHONE_NAME=Chrome
```

*Sem estas variáveis, a instância pode ficar presa no status "connecting" ou não exibir o QR Code.*

**Variável a REMOVER (Causa Conflito):**
A variável `CONFIG_SESSION_PHONE_VERSION` (ex: `2.2413.1`) **NÃO** deve ser utilizada nas versões recentes. A presença dela fixa uma versão antiga do WhatsApp Web que é incompatível com a API atual, impedindo a geração do QR Code. Se ela estiver no seu `.env`, **remova-a**.
