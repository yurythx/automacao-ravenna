# Test Storage Integration (End-to-End)
# Cria conversa, faz upload de anexo e valida o redirecionamento para o MinIO.

$ErrorActionPreference = 'Stop'

# Configurações
$ip = "192.168.29.71"
$baseUrl = "http://$ip` :3000"
$accountId = 1
$token = "CDuFU9XcuoXTF7uHarDFWCw3"
$headers = @{ "api_access_token" = $token }
$sampleFile = "sample_upload.txt"

function Print-Step ($msg) {
    Write-Host "`n➜ $msg" -ForegroundColor Cyan
}

# 0. Preparar Arquivo de Teste
$filePath = Join-Path $PSScriptRoot $sampleFile
if (-not (Test-Path $filePath)) {
    Print-Step "Criando arquivo de teste..."
    "Teste de Integração MinIO $(Get-Date)" | Set-Content $filePath
}

try {
    # 1. Obter Inbox
    Print-Step "Obtendo Inbox..."
    $resp = Invoke-RestMethod -Uri "$baseUrl/api/v1/accounts/$accountId/inboxes" -Headers $headers -Method Get
    if ($resp.payload.inboxes.Count -eq 0) {
        throw "Nenhuma inbox encontrada. Crie uma inbox API primeiro."
    }
    $inboxId = $resp.payload.inboxes[0].id
    Write-Host "Inbox ID: $inboxId" -ForegroundColor Gray

    # 2. Criar Contato (ou usar existente)
    Print-Step "Preparando Contato..."
    $contactBody = @{ name = 'MinIO Tester'; email = 'tester@minio.local'; phone_number = '+5511999999999' } | ConvertTo-Json
    try {
        $contact = Invoke-RestMethod -Uri "$baseUrl/api/v1/accounts/$accountId/contacts" -Headers $headers -Method Post -Body $contactBody -ContentType 'application/json'
        $contactId = $contact.payload.contact.id
    } catch {
        # Se falhar (ex: duplicado), busca o primeiro
        $contacts = Invoke-RestMethod -Uri "$baseUrl/api/v1/accounts/$accountId/contacts" -Headers $headers -Method Get
        $contactId = $contacts.payload.contacts[0].id
    }
    Write-Host "Contact ID: $contactId" -ForegroundColor Gray

    # 3. Criar Conversa
    Print-Step "Criando Conversa..."
    $convBody = @{ source_id = "test_$(Get-Random)"; inbox_id = $inboxId; contact_id = $contactId; status = "open" } | ConvertTo-Json
    # Tenta criar, se falhar tenta pegar existente (API do Chatwoot as vezes reclama de conversa aberta)
    try {
        $conv = Invoke-RestMethod -Uri "$baseUrl/api/v1/accounts/$accountId/conversations" -Headers $headers -Method Post -Body $convBody -ContentType 'application/json'
        $conversationId = $conv.payload.conversation.id
    } catch {
        Write-Host "Tentando usar conversa existente..." -ForegroundColor Yellow
        $convs = Invoke-RestMethod -Uri "$baseUrl/api/v1/accounts/$accountId/conversations?status=open" -Headers $headers -Method Get
        if ($convs.payload.conversations.Count -gt 0) {
            $conversationId = $convs.payload.conversations[0].id
        } else {
            throw "Não foi possível criar ou encontrar uma conversa."
        }
    }
    Write-Host "Conversation ID: $conversationId" -ForegroundColor Gray

    # 4. Upload do Arquivo (Robust HttpClient)
    Print-Step "Enviando Anexo (Upload)..."
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.DefaultRequestHeaders.Add('api_access_token', $token)

    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add((New-Object System.Net.Http.StringContent('Teste MinIO End-to-End')), 'content')
    
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    $fileContent = New-Object System.Net.Http.ByteArrayContent($bytes, 0, $bytes.Length)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('text/plain')
    $content.Add($fileContent, 'attachments[]', $sampleFile)

    $uploadUrl = "$baseUrl/api/v1/accounts/$accountId/conversations/$conversationId/messages"
    $response = $client.PostAsync($uploadUrl, $content).Result
    
    if ($response.StatusCode -ne 'OK') {
        throw "Falha no upload. Status: $($response.StatusCode)"
    }
    
    $respBody = $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json
    $attachmentUrl = $respBody.attachments[0].data_url
    
    if (-not $attachmentUrl) {
        throw "Upload parecia ok, mas não retornou URL do anexo."
    }
    Write-Host "Upload Sucesso! URL: $attachmentUrl" -ForegroundColor Green

    # 5. Validar Redirecionamento (O Teste Real)
    Print-Step "Validando Redirecionamento (Chatwoot -> MinIO)..."
    
    # Fazemos uma request sem seguir redirect para ver o 302
    $check = Invoke-WebRequest -Uri $attachmentUrl -Headers $headers -MaximumRedirection 0 -ErrorAction SilentlyContinue
    
    if ($check.StatusCode -eq 302 -or $check.StatusCode -eq 301) {
        $target = $check.Headers['Location']
        Write-Host "Redirecionamento OK!" -ForegroundColor Green
        Write-Host "De: $attachmentUrl"
        Write-Host "Para: $target"
        
        if ($target -match ":9004") {
            Write-Host "✅ O destino aponta corretamente para a porta do MinIO (9004)." -ForegroundColor Green
        } else {
            Write-Host "⚠️ O destino não parece ser o MinIO (:9004). Verifique a URL." -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Falha: O Chatwoot não redirecionou. Status: $($check.StatusCode)" -ForegroundColor Red
        Write-Host "Isso indica que o arquivo pode estar sendo servido localmente (Disk) ou proxy incorreto."
    }

} catch {
    Write-Host "Erro Fatal: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
