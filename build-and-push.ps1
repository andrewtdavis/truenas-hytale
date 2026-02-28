param(
  [string]$Registry = "ghcr.io",
  [string]$ImageName = "",
  [string]$Tag = "latest",
  [switch]$AlsoTagCommit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-OriginUrl {
  $url = (git remote get-url origin 2>$null)
  if (-not $url) {
    throw "Could not read git remote 'origin'."
  }
  return $url.Trim()
}

function Parse-GitHubRemote {
  param([string]$RemoteUrl)

  $patterns = @(
    "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(\.git)?$",
    "^https://(?<owner>[^.]+)\.github\.io/(?<repo>[^/]+)"
  )

  foreach ($pattern in $patterns) {
    if ($RemoteUrl -match $pattern) {
      return @{
        Owner = $matches["owner"].ToLowerInvariant()
        Repo  = $matches["repo"].ToLowerInvariant()
      }
    }
  }

  throw "Unsupported git remote URL format: $RemoteUrl"
}

function Ensure-Podman {
  $null = Get-Command podman -ErrorAction Stop
}

function Ensure-GhcrLogin {
  param([string]$RegistryHost)

  $login = (podman login --get-login $RegistryHost 2>$null)
  if (-not $login) {
    throw "No active podman login for $RegistryHost. Sign in via Podman Desktop or run: podman login $RegistryHost"
  }
}

Ensure-Podman
$origin = Get-OriginUrl
$repoInfo = Parse-GitHubRemote -RemoteUrl $origin

if (-not $ImageName) {
  $ImageName = $repoInfo.Repo
}

$image = "{0}/{1}/{2}:{3}" -f $Registry.ToLowerInvariant(), $repoInfo.Owner, $ImageName.ToLowerInvariant(), $Tag

Ensure-GhcrLogin -RegistryHost $Registry

Write-Host "Building image: $image"
podman build -t $image .

Write-Host "Pushing image: $image"
podman push $image

if ($AlsoTagCommit) {
  $sha = (git rev-parse --short HEAD).Trim().ToLowerInvariant()
  if (-not $sha) {
    throw "Failed to resolve current git commit."
  }

  $commitImage = "{0}/{1}/{2}:git-{3}" -f $Registry.ToLowerInvariant(), $repoInfo.Owner, $ImageName.ToLowerInvariant(), $sha
  Write-Host "Tagging commit image: $commitImage"
  podman tag $image $commitImage

  Write-Host "Pushing commit image: $commitImage"
  podman push $commitImage
}

Write-Host "Done."
Write-Host "Primary image: $image"
