#!/bin/bash
set -euo pipefail

# ── 1. Install only what we need ─────────────────────────────
apt-get update -y
apt-get install -y apache2 php php-curl jq

# ── 2. Enable Apache and open firewall ───────────────────────
systemctl enable apache2
systemctl start apache2
ufw allow 'Apache Full'

# ── 3. Fix permissions ────────────────────────────────────────
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# ── 4. Fetch instance metadata once at boot ───────────────────
METADATA=$(curl -sf -H "Metadata:true" --noproxy "*" \
  "http://169.254.169.254/metadata/instance?api-version=2021-02-01" || echo "{}")

VM_NAME=$(echo "$METADATA"  | jq -r '.compute.name       // "unknown"')
VM_ZONE=$(echo "$METADATA"  | jq -r '.compute.zone       // "unknown"')
VM_SIZE=$(echo "$METADATA"  | jq -r '.compute.vmSize     // "unknown"')
VM_IP=$(echo "$METADATA"    | jq -r '.network.interface[0].ipv4.ipAddress[0].privateIpAddress // "unknown"')
VM_REGION=$(echo "$METADATA"| jq -r '.compute.location   // "unknown"')

# ── 5. metrics.php — lightweight real data API ────────────────
cat > /var/www/html/metrics.php <<'PHP'
<?php
header('Content-Type: application/json');
header('Cache-Control: no-cache');

// CPU — two /proc/stat samples 300ms apart
$s1 = file('/proc/stat')[0]; usleep(300000); $s2 = file('/proc/stat')[0];
$c1 = array_slice(preg_split('/\s+/', trim($s1)), 1);
$c2 = array_slice(preg_split('/\s+/', trim($s2)), 1);
$td = array_sum($c2) - array_sum($c1);
$id = $c2[3] - $c1[3];
$cpu = $td > 0 ? round((1 - $id / $td) * 100, 1) : 0;

// Memory
$mem = [];
foreach (file('/proc/meminfo') as $l) {
  [$k, $v] = explode(':', $l);
  $mem[trim($k)] = intval($v);
}
$mem_total = round($mem['MemTotal'] / 1024);
$mem_used  = round(($mem['MemTotal'] - $mem['MemAvailable']) / 1024);
$mem_pct   = $mem['MemTotal'] > 0 ? round($mem_used / $mem_total * 100) : 0;

// Disk
$disk_total = round(disk_total_space('/') / 1073741824, 1);
$disk_free  = round(disk_free_space('/')  / 1073741824, 1);
$disk_used  = round($disk_total - $disk_free, 1);
$disk_pct   = $disk_total > 0 ? round($disk_used / $disk_total * 100) : 0;

// Load average
$load = sys_getloadavg();

// Instance metadata
$raw  = @file_get_contents('http://169.254.169.254/metadata/instance?api-version=2021-02-01', false,
  stream_context_create(['http' => ['header' => "Metadata: true\r\n", 'timeout' => 1]]));
$meta = $raw ? json_decode($raw, true) : [];

echo json_encode([
  'cpu'      => $cpu,
  'mem_pct'  => $mem_pct,
  'mem_used' => $mem_used,
  'mem_total'=> $mem_total,
  'disk_pct' => $disk_pct,
  'disk_used'=> $disk_used,
  'disk_total'=> $disk_total,
  'load1'    => round($load[0], 2),
  'load5'    => round($load[1], 2),
  'load15'   => round($load[2], 2),
  'instance' => [
    'name'   => $meta['compute']['name']   ?? gethostname(),
    'zone'   => $meta['compute']['zone']   ?? '?',
    'size'   => $meta['compute']['vmSize'] ?? '?',
    'ip'     => $meta['network']['interface'][0]['ipv4']['ipAddress'][0]['privateIpAddress'] ?? '?',
    'region' => $meta['compute']['location'] ?? '?',
  ],
]);
PHP

# ── 6. index.html — baked with real instance info ─────────────
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>VMSS · ${VM_NAME}</title>
<style>
  :root{--bg:#0a0e17;--card:#111827;--border:#1f2937;--accent:#3b82f6;--green:#10b981;--yellow:#f59e0b;--red:#ef4444;--text:#f1f5f9;--muted:#64748b}
  *{box-sizing:border-box;margin:0;padding:0}
  body{background:var(--bg);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;min-height:100vh;padding:2rem 1rem}
  .page{max-width:860px;margin:0 auto}

  /* header */
  .header{display:flex;align-items:center;justify-content:space-between;margin-bottom:2rem;padding-bottom:1rem;border-bottom:1px solid var(--border)}
  .header h1{font-size:1.4rem;font-weight:700;color:#fff}
  .header h1 span{color:var(--accent)}
  .pill{display:inline-flex;align-items:center;gap:6px;background:rgba(16,185,129,.1);border:1px solid rgba(16,185,129,.3);color:var(--green);padding:4px 12px;border-radius:99px;font-size:.75rem}
  .dot{width:7px;height:7px;border-radius:50%;background:var(--green);animation:blink 2s ease-in-out infinite}
  @keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}

  /* instance banner */
  .banner{background:var(--card);border:1px solid var(--border);border-left:3px solid var(--accent);border-radius:8px;padding:1rem 1.2rem;margin-bottom:1.5rem;display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:.5rem}
  .bi label{font-size:.65rem;color:var(--muted);text-transform:uppercase;letter-spacing:.08em;display:block;margin-bottom:2px}
  .bi span{font-size:.85rem;color:#fff;font-weight:600}

  /* stat cards */
  .cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:1rem;margin-bottom:1.5rem}
  .card{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:1rem 1.2rem}
  .card .label{font-size:.65rem;color:var(--muted);text-transform:uppercase;letter-spacing:.08em;margin-bottom:.5rem}
  .card .val{font-size:2rem;font-weight:700;line-height:1}
  .card .sub{font-size:.7rem;color:var(--muted);margin-top:.3rem}
  .bar{height:4px;background:rgba(255,255,255,.07);border-radius:2px;margin-top:.7rem;overflow:hidden}
  .bar-fill{height:100%;border-radius:2px;transition:width 1s ease}
  .c-green{color:var(--green)}.c-yellow{color:var(--yellow)}.c-red{color:var(--red)}.c-blue{color:var(--accent)}
  .bg-green{background:var(--green)}.bg-yellow{background:var(--yellow)}.bg-red{background:var(--red)}.bg-blue{background:var(--accent)}

  /* load */
  .load-row{display:grid;grid-template-columns:repeat(3,1fr);gap:1rem;margin-bottom:1.5rem}
  .load-card{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:.9rem;text-align:center}
  .load-card .lval{font-size:1.6rem;font-weight:700;color:var(--accent)}
  .load-card .llbl{font-size:.65rem;color:var(--muted);text-transform:uppercase;letter-spacing:.08em;margin-top:.2rem}

  /* lb info */
  .lb{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:1rem 1.2rem;margin-bottom:1.5rem}
  .lb h3{font-size:.75rem;color:var(--muted);text-transform:uppercase;letter-spacing:.08em;margin-bottom:.8rem}
  .lb-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:.6rem}
  .lb-item label{font-size:.65rem;color:var(--muted);display:block;margin-bottom:2px}
  .lb-item span{font-size:.8rem;color:#fff;font-weight:500}

  footer{text-align:center;font-size:.7rem;color:var(--muted);margin-top:2rem;padding-top:1rem;border-top:1px solid var(--border)}
  #ts{color:var(--accent)}
</style>
</head>
<body>
<div class="page">

  <div class="header">
    <h1>VMSS <span>Monitor</span></h1>
    <div class="pill"><div class="dot"></div>Live</div>
  </div>

  <!-- Instance banner — baked at boot with real metadata -->
  <div class="banner">
    <div class="bi"><label>Instance</label><span>${VM_NAME}</span></div>
    <div class="bi"><label>Zone</label><span>Availability Zone ${VM_ZONE}</span></div>
    <div class="bi"><label>Size</label><span>${VM_SIZE}</span></div>
    <div class="bi"><label>Private IP</label><span>${VM_IP}</span></div>
    <div class="bi"><label>Region</label><span>${VM_REGION}</span></div>
  </div>

  <!-- Metric cards — updated every 4s from metrics.php -->
  <div class="cards">
    <div class="card">
      <div class="label">CPU</div>
      <div class="val" id="cpu-val">--</div>
      <div class="sub">real-time usage</div>
      <div class="bar"><div class="bar-fill bg-green" id="cpu-bar" style="width:0%"></div></div>
    </div>
    <div class="card">
      <div class="label">Memory</div>
      <div class="val" id="mem-val">--</div>
      <div class="sub" id="mem-sub">loading...</div>
      <div class="bar"><div class="bar-fill bg-blue" id="mem-bar" style="width:0%"></div></div>
    </div>
    <div class="card">
      <div class="label">Disk</div>
      <div class="val" id="disk-val">--</div>
      <div class="sub" id="disk-sub">loading...</div>
      <div class="bar"><div class="bar-fill bg-yellow" id="disk-bar" style="width:0%"></div></div>
    </div>
  </div>

  <!-- Load average -->
  <div class="load-row">
    <div class="load-card"><div class="lval" id="l1">--</div><div class="llbl">1 min avg</div></div>
    <div class="load-card"><div class="lval" id="l5">--</div><div class="llbl">5 min avg</div></div>
    <div class="load-card"><div class="lval" id="l15">--</div><div class="llbl">15 min avg</div></div>
  </div>

  <!-- LB info -->
  <div class="lb">
    <h3>Load Balancer</h3>
    <div class="lb-grid">
      <div class="lb-item"><label>Type</label><span>Azure Standard LB</span></div>
      <div class="lb-item"><label>SKU</label><span>Standard</span></div>
      <div class="lb-item"><label>Health probe</label><span>HTTP :80 /</span></div>
      <div class="lb-item"><label>Zones</label><span>1 · 2 · 3</span></div>
      <div class="lb-item"><label>Instances</label><span>3 healthy</span></div>
      <div class="lb-item"><label>Outbound</label><span>NAT Gateway</span></div>
    </div>
  </div>

  <footer>
    Refresh to hit a different instance via the load balancer &nbsp;·&nbsp; <span id="ts"></span>
  </footer>
</div>

<script>
function color(v){return v<50?'bg-green':v<80?'bg-yellow':'bg-red'}
function setBar(bid,v){const b=document.getElementById(bid);if(b){b.style.width=v+'%';b.className='bar-fill '+color(v);}}

async function refresh(){
  try{
    const d=await fetch('/metrics.php').then(r=>r.json());
    document.getElementById('cpu-val').textContent=d.cpu+'%';
    setBar('cpu-bar',d.cpu);
    document.getElementById('mem-val').textContent=d.mem_pct+'%';
    document.getElementById('mem-sub').textContent=d.mem_used+' MB / '+d.mem_total+' MB';
    setBar('mem-bar',d.mem_pct);
    document.getElementById('disk-val').textContent=d.disk_pct+'%';
    document.getElementById('disk-sub').textContent=d.disk_used+' GB / '+d.disk_total+' GB';
    setBar('disk-bar',d.disk_pct);
    document.getElementById('l1').textContent=d.load1;
    document.getElementById('l5').textContent=d.load5;
    document.getElementById('l15').textContent=d.load15;
  }catch(e){}
  document.getElementById('ts').textContent=new Date().toUTCString().slice(0,25)+' UTC';
}
refresh();
setInterval(refresh,4000);
</script>
</body>
</html>
HTML

# ── 7. Set correct permissions ────────────────────────────────
chown www-data:www-data /var/www/html/index.html /var/www/html/metrics.php
chmod 644 /var/www/html/index.html /var/www/html/metrics.php

systemctl restart apache2