param(
  [string]$WebhookUrl = "http://localhost:5678/webhook/havoc-ti",
  [string]$Phone = "5527999999999",
  [string]$Message = "abrir_chamado",
  [string]$Name = "Teste Script"
)

$headers = @{ "Content-Type" = "application/json" }

# Payload simulando Evolution API v2
$payload = @{
  instance = "Havoc-TI"
  data = @{
    key = @{
      remoteJid = "$Phone@s.whatsapp.net"
      fromMe = $false
      id = "TEST-" + (Get-Date -Format "yyyyMMddHHmmss")
    }
    pushName = $Name
    messageType = "conversation"
    message = @{
      conversation = $Message
    }
  }
} | ConvertTo-Json -Depth 10

Write-Host "Enviando payload para $WebhookUrl..."
Write-Host $payload

try {
  $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Headers $headers -Body $payload
  Write-Host "Resposta do n8n:" -ForegroundColor Green
  $response | ConvertTo-Json -Depth 5 | Write-Output
} catch {
  Write-Host "Erro ao chamar webhook:" -ForegroundColor Red
  Write-Host $_.Exception.Message
  if ($_.ErrorDetails) {
    Write-Host $_.ErrorDetails.Message
  }
}
