# Guia de Integração Chatwoot + MinIO (S3)

Este documento detalha a configuração necessária para fazer o Chatwoot salvar arquivos (anexos, avatares, exportações) no MinIO (armazenamento compatível com S3) em vez do disco local.

Esta configuração foi validada e está funcional em ambiente Docker.

## 1. Visão Geral da Arquitetura

- **Chatwoot**: Plataforma de atendimento.
- **MinIO**: Servidor de armazenamento de objetos compatível com API S3 da Amazon.
- **Objetivo**: O Chatwoot deve enviar arquivos para o bucket `chatwoot` no MinIO.

## 2. Configuração do MinIO

Certifique-se de que o serviço MinIO esteja rodando e acessível.
No arquivo `minio/compose.yaml`, a porta da API S3 deve estar exposta (ex: `9004:9000`).

- **URL Externa**: `http://192.168.29.71:9004` (IP da máquina host)
- **Usuário (Access Key)**: `minioadmin`
- **Senha (Secret Key)**: `minioadmin`
- **Bucket**: `chatwoot`

## 3. Configuração do Chatwoot (`.env`)

O arquivo `.env` do Chatwoot deve conter as seguintes variáveis.

**Importante:** Usamos `ACTIVE_STORAGE_SERVICE=s3_compatible` e definimos **ambos** os conjuntos de variáveis (`AWS_*` e `STORAGE_*`) para garantir compatibilidade máxima com diferentes versões das bibliotecas internas do Chatwoot.

```env
# Storage Configuration
ACTIVE_STORAGE_SERVICE=s3_compatible

# Configuração Padrão AWS (Usada por muitas libs S3)
S3_BUCKET_NAME=chatwoot
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_REGION=us-east-1
AWS_S3_ENDPOINT=http://192.168.29.71:9004
AWS_S3_FORCE_PATH_STYLE=true

# Aliases para compatibilidade específica do Chatwoot/Rails
STORAGE_ACCESS_KEY_ID=minioadmin
STORAGE_SECRET_ACCESS_KEY=minioadmin
STORAGE_REGION=us-east-1
STORAGE_ENDPOINT=http://192.168.29.71:9004
STORAGE_BUCKET_NAME=chatwoot
STORAGE_FORCE_PATH_STYLE=true
```

### Pontos de Atenção:
1.  **ENDPOINT**: Deve ser o IP da máquina host (`http://192.168.29.71:9004`), **não** use `http://minio:9000` se o Chatwoot precisar gerar URLs públicas para o navegador do usuário, pois o navegador não consegue resolver `minio`.
2.  **FORCE_PATH_STYLE**: Deve ser `true`. O MinIO requer isso para funcionar corretamente com buckets no formato `host/bucket` em vez de `bucket.host`.
3.  **Reinício**: Após alterar o `.env`, é necessário recriar o container para aplicar as mudanças:
    ```bash
    docker compose up -d
    ```

## 4. Validação e Testes

Scripts PowerShell foram criados na pasta `scripts/` para validar a integração sem precisar usar a interface web.

### Script de Diagnóstico de Conexão (`scripts/test_minio_connection.ps1`)
Testa se é possível conectar ao MinIO com as credenciais fornecidas e listar os buckets.
- **Sucesso**: Retorna `StatusCode: OK` e XML com lista de buckets.
- **Falha**: Retorna `Forbidden` ou erro de conexão.

### Script de Upload de Teste (`scripts/upload_to_conversation_httpclient.ps1`)
Simula o envio de um anexo para uma conversa no Chatwoot.
- **Sucesso**: Retorna o JSON da mensagem criada com a URL do anexo.
- **Erro 422**: Geralmente indica credenciais S3 inválidas configuradas no Chatwoot.

### Script de Verificação de Redirecionamento (`scripts/check_single_redirect.ps1`)
Verifica se a URL do anexo gerada pelo Chatwoot redireciona corretamente para o MinIO.
- O Chatwoot gera URLs assinadas que apontam para ele mesmo (`/rails/active_storage/...`).
- Ao acessar essa URL, ele deve responder com `302 Found` e o cabeçalho `Location` apontando para `http://192.168.29.71:9004/...`.

## 5. Troubleshooting Comum

| Sintoma | Causa Provável | Solução |
|---------|----------------|---------|
| Erro 422 ao enviar arquivo | Chatwoot não consegue autenticar no S3 | Verifique `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`. Reinicie o container. |
| Arquivo envia, mas não abre (404/Erro de Rede) | URL gerada aponta para `minio:9000` ou `localhost` | Ajuste `AWS_S3_ENDPOINT` para o IP da LAN (`192.168.29.71`). |
| Erro `SignatureDoesNotMatch` | Credenciais erradas ou hora do servidor dessincronizada | Verifique credenciais. Garanta que servidor e cliente estejam com relógios sincronizados. |

---
*Documentação gerada em 09/12/2025.*
