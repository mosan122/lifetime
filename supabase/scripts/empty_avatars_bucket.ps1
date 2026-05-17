# Vacía el bucket "avatars" vía Storage API (Supabase no permite DELETE SQL en storage.objects).
#
# Uso (PowerShell):
#   $env:SUPABASE_URL = "https://TU-PROYECTO.supabase.co"
#   $env:SUPABASE_SERVICE_ROLE_KEY = "tu-service-role-key"
#   .\supabase\scripts\empty_avatars_bucket.ps1
#
# La service role key está en: Dashboard → Project Settings → API → service_role (secret)

param(
  [string]$ProjectUrl = $env:SUPABASE_URL,
  [string]$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY,
  [string]$Bucket = "avatars"
)

if ([string]::IsNullOrWhiteSpace($ProjectUrl) -or [string]::IsNullOrWhiteSpace($ServiceRoleKey)) {
  Write-Error "Define SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY."
  exit 1
}

$ProjectUrl = $ProjectUrl.TrimEnd("/")
$uri = "$ProjectUrl/storage/v1/bucket/$Bucket/empty"

$headers = @{
  Authorization = "Bearer $ServiceRoleKey"
  apikey        = $ServiceRoleKey
}

Write-Host "Vaciando bucket '$Bucket' en $ProjectUrl ..."
try {
  Invoke-RestMethod -Method Post -Uri $uri -Headers $headers
  Write-Host "Listo: bucket '$Bucket' vaciado."
}
catch {
  Write-Error $_
  exit 1
}
