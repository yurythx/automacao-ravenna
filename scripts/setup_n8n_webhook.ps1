param(
    [string]$EvolutionUrl = "http://192.168.29.71:8081",
    [string]$Instance = "Havoc",
    [string]$ApiKey = "",
    [string]$N8nUrl = "http://n8n:5678",
    [string]$WebhookPath = "evolution-havoc",
    [string[]]$Events = @(
        "APPLICATION_STARTUP",
        "MESSAGE_RECEIVED",
        "MESSAGE_UPDATE",
        "MESSAGE_SEND"
    ),
    [bool]$EnsureInstance = $true
)

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Error "ApiKey obrigatório. Informe via parâmetro -ApiKey."
    exit 1
}

$headers = @{
    "apikey" = $ApiKey
    "Content-Type" = "application/json"
}

$instanceBody = (@{ instanceName = $Instance } | ConvertTo-Json)

$createEndpoint = "$EvolutionUrl/instance/create"
if ($EnsureInstance) {
    try {
        Write-Host "Garantindo existência da instância '$Instance'..."
        $createResp = Invoke-RestMethod -Uri $createEndpoint -Method Post -Headers $headers -Body $instanceBody
        $createResp | ConvertTo-Json -Depth 6 | Write-Output
    } catch {
        Write-Host "Aviso: criação/garantia da instância pode já existir ou falhou: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $responseBody = $reader.ReadToEnd()
                Write-Host "Detalhes (Body): $responseBody"
            }
        }
    }
}

$bodyFlat = [ordered]@{
    url = "$N8nUrl/webhook/$WebhookPath"
    enabled = $true
    webhook_by_events = $false
    events = $Events
}
$jsonBodyFlat = ($bodyFlat | ConvertTo-Json -Depth 6)

try {
    Write-Host "Configurando Webhook da Evolution para o n8n..."
    Write-Host "Instance: $Instance"
    Write-Host "Webhook URL: $($bodyFlat.url)"
    $endpoint1 = "$EvolutionUrl/webhook/set/$Instance"
    $endpoint2 = "$EvolutionUrl/webhook/set"
    $payload2Obj = [ordered]@{
        instanceName = $Instance
        url = $bodyFlat.url
        enabled = $bodyFlat.enabled
        webhook_by_events = $bodyFlat.webhook_by_events
        events = $bodyFlat.events
    }
    $payload2 = ($payload2Obj | ConvertTo-Json -Depth 6)
    $endpoint3 = "$EvolutionUrl/instance/webhook/set/$Instance"
    $response = $null
    $success = $false
    try {
        $response = Invoke-RestMethod -Uri $endpoint1 -Method Post -Headers $headers -Body $jsonBodyFlat
        $success = $true
        Write-Host "Webhook configurado com sucesso em: $endpoint1"
    } catch {
        Write-Host "Tentativa 1 falhou ($endpoint1): $($_.Exception.Message)"
    }
    if (-not $success) {
        try {
            $response = Invoke-RestMethod -Uri $endpoint2 -Method Post -Headers $headers -Body $payload2
            $success = $true
            Write-Host "Webhook configurado com sucesso em: $endpoint2"
        } catch {
            Write-Host "Tentativa 2 falhou ($endpoint2): $($_.Exception.Message)"
        }
    }
    if (-not $success) {
        try {
            $response = Invoke-RestMethod -Uri $endpoint3 -Method Post -Headers $headers -Body $jsonBodyFlat
            $success = $true
            Write-Host "Webhook configurado com sucesso em: $endpoint3"
        } catch {
            Write-Host "Tentativa 3 falhou ($endpoint3): $($_.Exception.Message)"
        }
    }
    if ($success) {
        $response | ConvertTo-Json -Depth 6 | Write-Output
    } else {
        Write-Error "Todas as tentativas de configurar o webhook falharam."
    }
} catch {
    Write-Host "Erro ao configurar webhook: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            Write-Host "Detalhes do erro (Body): $responseBody"
        }
    }
}
