# 🛠️ Scripts de Automação e Diagnóstico

Esta pasta contém scripts PowerShell para validar, testar e configurar a integração da stack (Chatwoot, MinIO, Evolution API, n8n).

> **Nota:** Todos os scripts estão configurados para o IP **192.168.29.71**.

## � Scripts Principais (Use estes primeiro)

Estes scripts consolidam várias verificações em relatórios únicos.

### 1. `check_services.ps1`
**Diagnóstico Geral.** Verifica se todos os serviços estão online e comunicando.
*   ✅ Status do n8n (Healthz)
*   ✅ Conexão com Chatwoot API (e valida Token)
*   ✅ Listagem de Webhooks ativos no Chatwoot
*   ✅ Status da Evolution API (Instâncias conectadas)
*   ✅ Status do MinIO

### 2. `test_storage_integration.ps1`
**Teste End-to-End de Armazenamento.** Valida se o fluxo de arquivos está 100% funcional.
*   1. Cria uma conversa de teste.
*   2. Faz upload de um arquivo (`sample_upload.txt`) via API.
*   3. **Verifica o Redirecionamento**: Confirma se o Chatwoot está enviando o usuário para o MinIO (Porta 9004) ao acessar o anexo.

---

## 🔧 Utilitários de Setup & Debug

Scripts auxiliares para tarefas específicas ou configurações iniciais.

### MinIO (Baixo Nível)
*   **`test_minio_connection.ps1`**: Testa conexão direta S3 (sem passar pelo Chatwoot). Útil para validar credenciais e rede.

### Configuração (Setup)
*   **`setup_n8n_webhook.ps1`**: Configura webhook inicial no n8n.

### Consultas (Debug)
*   **`test_n8n_webhook.ps1`**: Envia um payload fake para o n8n testar a recepção.

---

## �️ Como Executar

No PowerShell (Admin):

```powershell
# Verificar status geral
.\check_services.ps1

# Testar upload e minio
.\test_storage_integration.ps1
```
