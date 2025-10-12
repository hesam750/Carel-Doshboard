param(
    [int]$Port = 8000,
    [string]$Root = "$PSScriptRoot",
    [string]$BindHost = "localhost"
)

Add-Type -TypeDefinition @"
using System;
using System.Net;
public class HttpListenerResponseExtensions {
    public static void AddHeader(HttpListenerResponse resp, string name, string value) {
        resp.Headers[name] = value;
    }
}
"@

# Trust self-signed/invalid SSL certificates for local proxying to device
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::Expect100Continue = $false

$listener = New-Object System.Net.HttpListener
$prefix = "http://${BindHost}:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $Root at $prefix"

$logFile = Join-Path $Root 'proxy.log'
function WriteLog([string]$msg) {
    try {
        $line = ("[{0}] {1}" -f [DateTime]::UtcNow.ToString("o"), $msg)
        [System.IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine)
    } catch {}
}

function Get-ContentType($path) {
    switch ([System.IO.Path]::GetExtension($path).ToLower()) {
        ".html" { return "text/html; charset=utf-8" }
        ".htm" { return "text/html; charset=utf-8" }
        ".js" { return "application/javascript; charset=utf-8" }
        ".css" { return "text/css; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".svg" { return "image/svg+xml; charset=utf-8" }
        ".txt" { return "text/plain; charset=utf-8" }
        default { return "application/octet-stream" }
    }
}

function Handle-Proxy($context) {
    $request = $context.Request
    $response = $context.Response
    $targetUrl = $request.QueryString["url"]
    if ($targetUrl) {
        try { $targetUrl = [System.Uri]::UnescapeDataString($targetUrl) } catch {}
        # Safe trimming of surrounding whitespace and quotes/backtick
        $trimChars = [char[]]@([char]32, [char]9, [char]10, [char]13, [char]34, [char]39, [char]96)
        $targetUrl = $targetUrl.Trim($trimChars)
    }

    if (-not $targetUrl) {
        $response.StatusCode = 400
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("Missing url parameter")
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        $response.Close()
        return
    }

    # Preserve any extra query parameters beyond 'url' (e.g., &_=timestamp, &name=...)
    $extraPairs = @()
    foreach ($key in $request.QueryString.AllKeys) {
        if ($key -and $key -ne 'url') {
            $k = [System.Uri]::EscapeDataString($key)
            $v = [System.Uri]::EscapeDataString($request.QueryString[$key])
            $extraPairs += "$k=$v"
        }
    }
    # Build query string append safely for PS5 (no ternary operator)
    if ($extraPairs.Count -gt 0) {
        $qs = [string]::Join("&", $extraPairs)
        if ($targetUrl -match "\?") {
            $targetUrl = $targetUrl + "&" + $qs
        } else {
            $targetUrl = $targetUrl + "?" + $qs
        }
    }

    # Sanitize malformed query (example: turn container.html&v=123 into container.html?v=123)
    if ($targetUrl -notmatch "\?" -and $targetUrl.Contains("&")) {
        $ampIndex = $targetUrl.IndexOf("&")
        if ($ampIndex -gt -1) {
            $targetUrl = $targetUrl.Substring(0, $ampIndex) + '?' + $targetUrl.Substring($ampIndex + 1)
        }
    }

    # Local mapping: serve UI templates and static files from local FS instead of device
    try {
        $uri = [System.Uri]$targetUrl
        $path = $uri.AbsolutePath

        $localRel = $null
        if ($path.StartsWith("/commissioning/view/component/")) {
            $localRel = "view/component/" + $path.Substring("/commissioning/view/component/".Length)
        } elseif ($path.StartsWith("/view/component/")) {
            $localRel = "view/component/" + $path.Substring("/view/component/".Length)
        } elseif ($path.StartsWith("/commissioning/view/page/")) {
            $localRel = "view/page/" + $path.Substring("/commissioning/view/page/".Length)
        } elseif ($path.StartsWith("/view/page/")) {
            $localRel = "view/page/" + $path.Substring("/view/page/".Length)
        } elseif ($path.Equals("/cfield.json")) {
            $localRel = "cfield.json"
        } elseif ($path.Equals("/device.json")) {
            $localRel = "device.json"
        } elseif ($path.StartsWith("/locales/en/")) {
            $localRel = "locales/en-US/" + $path.Substring("/locales/en/".Length)
        }

        if ($localRel) {
            $localPath = Join-Path $Root $localRel
            if (Test-Path $localPath) {
                $bytesLocal = [System.IO.File]::ReadAllBytes($localPath)
                $resp = $context.Response
                $resp.ContentType = Get-ContentType $localPath
                $resp.OutputStream.Write($bytesLocal, 0, $bytesLocal.Length)
                $resp.Close()
                return
            }
        }
    } catch {
        # if URI parse fails, continue with proxying
    }

    try {
        # Primary path: WebClient (fast binary pass-through)
        $client = New-Object System.Net.WebClient
        $client.Headers.Add("User-Agent", "LocalProxy/1.0")
        if ($request.Headers["Authorization"]) { $client.Headers["Authorization"] = $request.Headers["Authorization"] }
        if ($request.HttpMethod -eq "POST" -and $request.ContentType) { $client.Headers["Content-Type"] = $request.ContentType }

        if ($request.HttpMethod -eq "POST") {
            $ms = New-Object System.IO.MemoryStream
            if ($request.HasEntityBody) { $request.InputStream.CopyTo($ms) }
            $bytesReq = $ms.ToArray()
            $bodyStr = [System.Text.Encoding]::UTF8.GetString($bytesReq)
            WriteLog(("POST -> {0} | CT={1} | Body={2}" -f $targetUrl, $request.ContentType, $bodyStr))
            $data = $client.UploadData($targetUrl, "POST", $bytesReq)
        } else {
            WriteLog(("GET -> {0}" -f $targetUrl))
            $data = $client.DownloadData($targetUrl)
        }

        $contentType = $client.ResponseHeaders["Content-Type"]
        if ($contentType) { $response.ContentType = $contentType }
        WriteLog(("RESP CT={0} Len={1}" -f $contentType, ($data.Length)))

        $encoding = $client.ResponseHeaders["Content-Encoding"]
        if ($encoding) {
            [HttpListenerResponseExtensions]::AddHeader($response, "Content-Encoding", $encoding)
        } else {
            if ($data.Length -ge 2 -and $data[0] -eq 0x1F -and $data[1] -eq 0x8B) {
                [HttpListenerResponseExtensions]::AddHeader($response, "Content-Encoding", "gzip")
            }
        }

        $response.OutputStream.Write($data, 0, $data.Length)
    } catch {
        # Fallback path: Invoke-WebRequest (robust for some devices)
        try {
            $hdrs = @{"User-Agent"="LocalProxy/1.0"}
            if ($request.Headers["Authorization"]) { $hdrs["Authorization"] = $request.Headers["Authorization"] }

            if ($request.HttpMethod -eq "POST") {
                $ms2 = New-Object System.IO.MemoryStream
                if ($request.HasEntityBody) { $request.InputStream.CopyTo($ms2) }
                $bytesReq2 = $ms2.ToArray()
                $ir = Invoke-WebRequest -UseBasicParsing -Uri $targetUrl -Headers $hdrs -Method Post -Body $bytesReq2 -TimeoutSec 10
            } else {
                $ir = Invoke-WebRequest -UseBasicParsing -Uri $targetUrl -Headers $hdrs -Method Get -TimeoutSec 10
            }

            if ($ir.Headers["Content-Type"]) { $response.ContentType = $ir.Headers["Content-Type"] }
            $text = [string]$ir.Content
            $outBytes = [System.Text.Encoding]::UTF8.GetBytes($text)
            $response.OutputStream.Write($outBytes, 0, $outBytes.Length)
        } catch {
            $response.StatusCode = 502
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("Proxy error: " + $_.Exception.Message)
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
    } finally {
        $response.Close()
    }
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        if ($request.Url.AbsolutePath -eq "/proxy") {
            Handle-Proxy $context
            continue
        }

        $relPath = $request.Url.AbsolutePath.TrimStart("/")
        if ([string]::IsNullOrWhiteSpace($relPath)) { $relPath = "index.html" }
        $fullPath = Join-Path $Root $relPath

        # Map missing short language en to en-US to avoid 404s
        if (-not (Test-Path $fullPath) -and $relPath.StartsWith("locales/en/")) {
            $mappedRel = $relPath.Replace("locales/en/", "locales/en-US/")
            $mappedFull = Join-Path $Root $mappedRel
            if (Test-Path $mappedFull) { $fullPath = $mappedFull }
        }

        if (-not (Test-Path $fullPath)) {
            $response.StatusCode = 404
            $msg = "Not Found: $relPath"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
            continue
        }

        $bytes = [System.IO.File]::ReadAllBytes($fullPath)
        $response.ContentType = Get-ContentType $fullPath

        # If file appears gzipped, add header so browser can decode
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0x1F -and $bytes[1] -eq 0x8B) {
            [HttpListenerResponseExtensions]::AddHeader($response, "Content-Encoding", "gzip")
        }

        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        $response.Close()
    } catch {
        try { $context.Response.StatusCode = 500 } catch {}
        try {
            $err = "Server error: " + $_.Exception.Message
            $b = [System.Text.Encoding]::UTF8.GetBytes($err)
            $context.Response.OutputStream.Write($b, 0, $b.Length)
            $context.Response.Close()
        } catch {}
    }
}