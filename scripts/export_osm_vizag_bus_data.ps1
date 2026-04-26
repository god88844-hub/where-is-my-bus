param(
  [string]$OutputPath = (Join-Path $PSScriptRoot '..\docs\osm_vizag_bus_routes.json'),
  [double]$South = 17.60,
  [double]$West = 83.10,
  [double]$North = 17.95,
  [double]$East = 83.50,
  [string]$OverpassUrl = 'https://overpass-api.de/api/interpreter'
)

$ErrorActionPreference = 'Stop'

function Get-OsmKey {
  param(
    [Parameter(Mandatory = $true)][string]$Type,
    [Parameter(Mandatory = $true)]$Id
  )

  return "$Type/$Id"
}

function Get-OsmTag {
  param(
    [Parameter(Mandatory = $true)]$Element,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if ($null -eq $Element -or $null -eq $Element.tags) {
    return $null
  }

  $property = $Element.tags.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $null
  }

  return [string]$property.Value
}

function Test-StopLike {
  param(
    [Parameter(Mandatory = $true)]$Element,
    [string]$Role = ''
  )

  $publicTransport = Get-OsmTag $Element 'public_transport'
  $highway = Get-OsmTag $Element 'highway'

  return (
    $Role -match 'stop|platform' -or
    $publicTransport -match 'platform|stop_position' -or
    $highway -eq 'bus_stop'
  )
}

function Get-OsmCoordinate {
  param(
    [Parameter(Mandatory = $true)]$Element,
    [Parameter(Mandatory = $true)]$ElementsByKey
  )

  if ($Element.type -eq 'node' -and $null -ne $Element.lat -and $null -ne $Element.lon) {
    return [pscustomobject]@{
      lat = [Math]::Round([double]$Element.lat, 7)
      lng = [Math]::Round([double]$Element.lon, 7)
    }
  }

  if ($Element.type -eq 'way' -and $null -ne $Element.nodes) {
    $lat = 0.0
    $lng = 0.0
    $count = 0

    foreach ($nodeId in @($Element.nodes)) {
      $node = $ElementsByKey[(Get-OsmKey 'node' $nodeId)]
      if ($null -eq $node -or $null -eq $node.lat -or $null -eq $node.lon) {
        continue
      }

      $lat += [double]$node.lat
      $lng += [double]$node.lon
      $count++
    }

    if ($count -gt 0) {
      return [pscustomobject]@{
        lat = [Math]::Round($lat / $count, 7)
        lng = [Math]::Round($lng / $count, 7)
      }
    }
  }

  return [pscustomobject]@{
    lat = $null
    lng = $null
  }
}

function New-StopRecord {
  param(
    [Parameter(Mandatory = $true)]$Element,
    [Parameter(Mandatory = $true)]$ElementsByKey,
    [int]$Sequence = 0,
    [string]$Role = ''
  )

  $coordinate = Get-OsmCoordinate $Element $ElementsByKey
  $name = Get-OsmTag $Element 'name'
  if ([string]::IsNullOrWhiteSpace($name)) {
    $name = Get-OsmTag $Element 'local_ref'
  }
  if ([string]::IsNullOrWhiteSpace($name)) {
    $name = Get-OsmTag $Element 'ref'
  }

  return [pscustomobject]@{
    sequence = $Sequence
    osmType = $Element.type
    osmId = [int64]$Element.id
    role = $Role
    name = $name
    lat = $coordinate.lat
    lng = $coordinate.lng
    highway = Get-OsmTag $Element 'highway'
    publicTransport = Get-OsmTag $Element 'public_transport'
    osmUrl = "https://www.openstreetmap.org/$($Element.type)/$($Element.id)"
  }
}

$culture = [System.Globalization.CultureInfo]::InvariantCulture
$bbox = [string]::Format($culture, '{0},{1},{2},{3}', $South, $West, $North, $East)
$quote = [char]34

$query = @"
[out:json][timeout:120][maxsize:536870912];
(
  relation[${quote}route${quote}=${quote}bus${quote}]($bbox);
  node[${quote}highway${quote}=${quote}bus_stop${quote}]($bbox);
  node[${quote}public_transport${quote}~${quote}platform|stop_position${quote}]($bbox);
  way[${quote}highway${quote}=${quote}bus_stop${quote}]($bbox);
  way[${quote}public_transport${quote}~${quote}platform|stop_position${quote}]($bbox);
);
out body;
>;
out body qt;
"@

$query = $query -replace '\s+', ' '
$body = 'data=' + [System.Uri]::EscapeDataString($query)
$response = Invoke-RestMethod `
  -Uri $OverpassUrl `
  -Method Post `
  -Body $body `
  -ContentType 'application/x-www-form-urlencoded; charset=UTF-8' `
  -TimeoutSec 180 `
  -UserAgent 'vizag-bus-app-data/1.0'

$elementsByKey = @{}
foreach ($element in @($response.elements)) {
  $elementsByKey[(Get-OsmKey $element.type $element.id)] = $element
}

$routeRelations = @($response.elements | Where-Object {
    $_.type -eq 'relation' -and (Get-OsmTag $_ 'route') -eq 'bus'
  })

$routes = foreach ($relation in ($routeRelations | Sort-Object @{ Expression = { Get-OsmTag $_ 'ref' } }, @{ Expression = { Get-OsmTag $_ 'name' } })) {
  $sequence = 0
  $routeStops = foreach ($member in @($relation.members)) {
    $memberElement = $elementsByKey[(Get-OsmKey $member.type $member.ref)]
    if ($null -eq $memberElement) {
      continue
    }

    $role = [string]$member.role
    if (-not (Test-StopLike $memberElement $role)) {
      continue
    }

    $sequence++
    New-StopRecord $memberElement $elementsByKey $sequence $role
  }

  [pscustomobject]@{
    osmType = 'relation'
    osmId = [int64]$relation.id
    ref = Get-OsmTag $relation 'ref'
    name = Get-OsmTag $relation 'name'
    from = Get-OsmTag $relation 'from'
    to = Get-OsmTag $relation 'to'
    operator = Get-OsmTag $relation 'operator'
    network = Get-OsmTag $relation 'network'
    stopCount = @($routeStops).Count
    stops = @($routeStops)
    osmUrl = "https://www.openstreetmap.org/relation/$($relation.id)"
  }
}

$uniqueStopObjects = @($response.elements | Where-Object {
    $_.type -ne 'relation' -and (Test-StopLike $_)
  } | ForEach-Object {
    New-StopRecord $_ $elementsByKey
  } | Sort-Object osmType, osmId -Unique)

$routeStopKeys = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($route in @($routes)) {
  foreach ($stop in @($route.stops)) {
    [void]$routeStopKeys.Add((Get-OsmKey $stop.osmType $stop.osmId))
  }
}

$export = [pscustomobject]@{
  metadata = [pscustomobject]@{
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    sourceMapUrl = 'https://www.openstreetmap.org/#map=13/17.74133/83.31173&layers=T'
    overpassUrl = $OverpassUrl
    overpassQuery = $query.Trim()
    bbox = [pscustomobject]@{
      south = $South
      west = $West
      north = $North
      east = $East
    }
    license = 'OpenStreetMap data from OpenStreetMap contributors, available under the Open Database License.'
    routeRelationCount = @($routes).Count
    uniqueRouteStopObjectCount = $routeStopKeys.Count
    uniqueStopObjectCount = @($uniqueStopObjects).Count
  }
  routes = @($routes)
  uniqueStopObjects = @($uniqueStopObjects)
}

$resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$export | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

Write-Host "Wrote $resolvedOutputPath"
Write-Host "Routes: $(@($routes).Count)"
Write-Host "Unique route stop objects: $($routeStopKeys.Count)"
Write-Host "Unique stop objects in response: $(@($uniqueStopObjects).Count)"
