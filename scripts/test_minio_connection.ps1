
Add-Type -AssemblyName System.Net.Http
$accessKey = 'minioadmin'
$secretKey = 'minioadmin'
$region = 'us-east-1'
$service = 's3'
$endpoint = 'http://192.168.29.71:9004'

# Function to calculate HMAC-SHA256
function Get-HmacSha256 {
    param($Key, $Data)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $Key
    return $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Data))
}

# Function to calculate Hex string
function Get-HexString {
    param($Bytes)
    return [BitConverter]::ToString($Bytes).Replace('-', '').ToLower()
}

# Date and Time
$date = Get-Date
$amzDate = $date.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$dateStamp = $date.ToUniversalTime().ToString("yyyyMMdd")

# Canonical Request
$method = 'GET'
$canonicalUri = '/'
$canonicalQueryString = ''
$canonicalHeaders = "host:192.168.29.71:9004`nx-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`nx-amz-date:$amzDate`n"
$signedHeaders = 'host;x-amz-content-sha256;x-amz-date'
$payloadHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' # Empty payload hash
$canonicalRequest = "$method`n$canonicalUri`n$canonicalQueryString`n$canonicalHeaders`n$signedHeaders`n$payloadHash"

# String to Sign
$algorithm = 'AWS4-HMAC-SHA256'
$credentialScope = "$dateStamp/$region/$service/aws4_request"
$stringToSign = "$algorithm`n$amzDate`n$credentialScope`n$(Get-HexString -Bytes ([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonicalRequest))))"

# Signature
$kDate = Get-HmacSha256 -Key ([System.Text.Encoding]::UTF8.GetBytes("AWS4$secretKey")) -Data $dateStamp
$kRegion = Get-HmacSha256 -Key $kDate -Data $region
$kService = Get-HmacSha256 -Key $kRegion -Data $service
$kSigning = Get-HmacSha256 -Key $kService -Data 'aws4_request'
$signature = Get-HexString -Bytes (Get-HmacSha256 -Key $kSigning -Data $stringToSign)

# Authorization Header
$authorization = "$algorithm Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature"
$authorization = $authorization -replace "`r", "" -replace "`n", ""

# Request
$client = New-Object System.Net.Http.HttpClient
$request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $endpoint)
$request.Headers.Add('x-amz-date', $amzDate)
$request.Headers.Add('x-amz-content-sha256', $payloadHash)
$request.Headers.TryAddWithoutValidation('Authorization', $authorization) | Out-Null

try {
    $response = $client.SendAsync($request).Result
    Write-Host "StatusCode: $($response.StatusCode)"
    $content = $response.Content.ReadAsStringAsync().Result
    Write-Host "Content: $content"
} catch {
    Write-Host "Error: $_"
}
