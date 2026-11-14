param(
    [int]$Port = 8080,
    [string]$Root = "D:\Portfolio website"
)

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
try {
    $listener.Start()
} catch {
    $Port = 8081
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
    $listener.Start()
}

Write-Output "HTTP server running at http://localhost:$Port/"

try {
    while ($true) {
        $client = $null
        try {
            $client = $listener.AcceptTcpClient()
            $stream = $client.GetStream()
            
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
            $line = $reader.ReadLine()
            
            if (-not [string]::IsNullOrEmpty($line)) {
                $parts = $line.Split(' ')
                if ($parts.Length -ge 2) {
                    $method = $parts[0]
                    $rawPath = $parts[1]
                    
                    $cleanPath = $rawPath.Split('?')[0].TrimStart('/')
                    if ([string]::IsNullOrEmpty($cleanPath) -or $cleanPath -eq "") {
                        $cleanPath = "index.html"
                    }
                    $cleanPath = [System.Uri]::UnescapeDataString($cleanPath).Replace('/', '\')
                    $targetFile = [System.IO.Path]::GetFullPath((Join-Path $Root $cleanPath))
                    
                    $fullRoot = [System.IO.Path]::GetFullPath($Root)
                    if ($targetFile.StartsWith($fullRoot) -and (Test-Path $targetFile -PathType Leaf)) {
                        $ext = [System.IO.Path]::GetExtension($targetFile).ToLower()
                        $contentType = switch ($ext) {
                            ".html" { "text/html; charset=utf-8" }
                            ".htm"  { "text/html; charset=utf-8" }
                            ".css"  { "text/css" }
                            ".js"   { "application/javascript" }
                            ".jpg"  { "image/jpeg" }
                            ".jpeg" { "image/jpeg" }
                            ".png"  { "image/png" }
                            ".gif"  { "image/gif" }
                            ".svg"  { "image/svg+xml" }
                            ".json" { "application/json" }
                            ".pdf"  { "application/pdf" }
                            default { "application/octet-stream" }
                        }
                        
                        $fileBytes = [System.IO.File]::ReadAllBytes($targetFile)
                        $headerStr = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($fileBytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
                        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerStr)
                        
                        $stream.Write($headerBytes, 0, $headerBytes.Length)
                        $stream.Write($fileBytes, 0, $fileBytes.Length)
                    } else {
                        $bodyStr = "404 Not Found"
                        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyStr)
                        $headerStr = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($bodyBytes.Length)`r`nConnection: close`r`n`r`n"
                        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerStr)
                        
                        $stream.Write($headerBytes, 0, $headerBytes.Length)
                        $stream.Write($bodyBytes, 0, $bodyBytes.Length)
                    }
                }
            }
            
            $stream.Flush()
            $stream.Close()
        } catch {
            # Safely ignore client disconnects / network aborts
        } finally {
            if ($client -ne $null) {
                try { $client.Close() } catch {}
            }
        }
    }
} finally {
    $listener.Stop()
}
