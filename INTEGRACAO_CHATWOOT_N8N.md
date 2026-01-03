# Integração Chatwoot + n8n (Rede Interna Docker)

Este documento detalha como configurar a comunicação via Webhook entre o **Chatwoot** e o **n8n** utilizando a rede interna do Docker.

## ⚠️ O Problema da Validação de URL
Ao tentar adicionar um Webhook na interface gráfica do Chatwoot (`Configurações > Integrações > Webhooks`) apontando para um endereço interno do Docker (ex: `http://n8n:5678/webhook/n8n`), o sistema retorna o erro:
> "Por favor, insira uma URL válida"

Isso ocorre porque o frontend do Chatwoot bloqueia URLs que não parecem ser domínios públicos (ex: não terminam em .com, .br, etc), impedindo o uso de hostnames internos do Docker.

## ✅ A Solução: Criação via API
Para contornar essa validação de frontend, o Webhook deve ser criado diretamente via **API do Chatwoot**. O backend aceita endereços internos sem problemas.

### Script Automatizado
Disponibilizamos um script PowerShell para realizar essa configuração automaticamente.

**Localização:** `scripts/force_add_webhook.ps1`

**O que o script faz:**
1. Conecta na API do Chatwoot (`http://192.168.29.71:3000`).
2. Autentica com o token do administrador.
3. Envia uma requisição POST forçando a URL interna: `http://n8n:5678/webhook/n8n`.
4. Assina os eventos: `conversation_created`, `message_created`, `message_updated`, etc.

**Como executar:**
```powershell
scripts/force_add_webhook.ps1
```

### Execução Manual (cURL)
Se preferir fazer manualmente via terminal/cURL:

```bash
curl -X POST "http://192.168.29.71:3000/api/v1/accounts/1/webhooks" \
-H "Content-Type: application/json" \
-H "api_access_token: SEU_TOKEN_AQUI" \
-d '{
  "webhook": {
    "url": "http://n8n:5678/webhook/n8n",
    "subscriptions": [
      "conversation_created",
      "conversation_status_changed",
      "conversation_updated",
      "message_created",
      "message_updated",
      "webwidget_triggered"
    ]
  }
}'
```

## Configuração no n8n
Para que o n8n receba esses dados, seu workflow deve iniciar com o nó **Webhook**:
*   **Authentication:** None
*   **HTTP Method:** POST
*   **Path:** `n8n`
    *   *Nota: A URL final interna será `http://n8n:5678/webhook/n8n`*

## Verificação
Para confirmar se o Webhook foi criado e está ativo:
1. Execute o script de diagnóstico:
   ```powershell
   scripts/check_services.ps1
   ```
2. Procure na saída a seção "Webhooks configurados". Você deve ver:
   ```text
   - Webhook (ID: X): http://n8n:5678/webhook/n8n
   ```
