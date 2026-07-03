#!/usr/bin/env bash
# System stats for the tmux top navbar (macOS + Linux). No external deps.
# Usage: stats.sh <navbar|cpu|ram|disk|net|ip|gpu|docker>
#
# Every value is prefixed with a Nerd Font icon, colored "thermometer" style
# -- green/yellow/red by how hard the resource is being worked, see
# heat()/heat_rate()/heat_abs().
#
# These icons are rendered by whichever terminal emulator is DISPLAYING the
# tmux session, not by the host this script runs on -- installing the font
# here does nothing for rendering. Every local machine/terminal app you SSH
# from needs a Nerd Font (e.g. JetBrainsMono Nerd Font, see
# scripts/install.sh's install_font()) installed and selected as its font,
# or these show up as blank boxes.
#
# To add a new stat: write a function that prints "#[fg=<hex>]<label> <value>"
# (or nothing, to hide the segment), then add it to the `jobs` list in
# navbar() below. Each job runs in parallel so a slow stat doesn't delay
# the others.

os="$(uname -s)"

# Catppuccin Mocha
C_GREEN="#A6E3A1"; C_YELLOW="#F9E2AF"; C_RED="#F38BA8"
C_IP="#94E2D5"; C_DOCKER="#89DCEB"

# Nerd Font icons, all Material Design Icons (md-cpu_64_bit,
# md-expansion_card, md-memory, md-harddisk, md-ip_network, md-docker) --
# requires a Nerd Font in the viewing terminal, see the note above.
I_CPU="󰻠"
I_GPU="󰢮"
I_RAM="󰍛"
I_DISK="󰋊"
I_IP="󰩠"
I_DOCKER="󰡨"

# pct (0-100, no "%") -> hex color
heat() {
  local p="${1%.*}"
  [ -z "$p" ] && p=0
  if   [ "$p" -ge 80 ]; then printf '%s' "$C_RED"
  elif [ "$p" -ge 50 ]; then printf '%s' "$C_YELLOW"
  else                       printf '%s' "$C_GREEN"
  fi
}

# throughput in KB/s -> hex color (net / docker io)
heat_rate() {
  local kb="${1%.*}"
  [ -z "$kb" ] && kb=0
  if   [ "$kb" -ge 10240 ]; then printf '%s' "$C_RED"
  elif [ "$kb" -ge 1024 ];  then printf '%s' "$C_YELLOW"
  else                           printf '%s' "$C_GREEN"
  fi
}

# absolute value against two caller-given thresholds -> hex color (docker disk,
# which has no natural 0-100% scale to divide by)
heat_abs() {
  local v="${1%.*}" yellow="$2" red="$3"
  [ -z "$v" ] && v=0
  if   [ "$v" -ge "$red" ];    then printf '%s' "$C_RED"
  elif [ "$v" -ge "$yellow" ]; then printf '%s' "$C_YELLOW"
  else                              printf '%s' "$C_GREEN"
  fi
}

cpu_pct() {
  if [ "$os" = "Darwin" ]; then
    top -l 1 -n 0 | awk '/CPU usage/ {
      for (i = 1; i <= NF; i++)
        if ($i == "idle") { gsub(/%/, "", $(i-1)); printf "%.0f", 100 - $(i-1) }
    }'
  else
    # two /proc/stat samples ~0.2s apart -> instantaneous busy %
    read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
    sleep 0.2
    read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
    local idle1=$((i1 + w1)) idle2=$((i2 + w2))
    local tot1=$((u1 + n1 + s1 + i1 + w1 + q1 + sq1 + st1))
    local tot2=$((u2 + n2 + s2 + i2 + w2 + q2 + sq2 + st2))
    local dt=$((tot2 - tot1)) di=$((idle2 - idle1))
    awk -v di="$di" -v dt="$dt" 'BEGIN { printf "%.0f", (dt > 0 ? (1 - di / dt) * 100 : 0) }'
  fi
}

cpu() {
  local p; p=$(cpu_pct)
  printf '#[fg=%s]%s %s%%' "$(heat "$p")" "$I_CPU" "$p"
}

# GPU % — omitted entirely (empty string) when no GPU is present.
gpu() {
  local v=""
  if [ "$os" = "Darwin" ]; then
    v=$(ioreg -r -d 1 -w 0 -c AGXAccelerator 2>/dev/null \
      | grep -o '"Device Utilization %"=[0-9]*' | head -1 | awk -F= '{print $2}')
  elif command -v nvidia-smi >/dev/null 2>&1; then
    v=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null \
      | head -1 | awk '{print $1}')
  fi
  [ -z "$v" ] && return
  printf '#[fg=%s]%s %s%%' "$(heat "$v")" "$I_GPU" "$v"
}

ram() {
  local used total pct
  if [ "$os" = "Darwin" ]; then
    total=$(sysctl -n hw.memsize | awk '{ printf "%.1f", $1 / 1073741824 }')
    used=$(top -l 1 -n 0 | awk '/PhysMem/ {
      v = $2
      if (v ~ /G$/)      { sub(/G/, "", v); printf "%.1f", v }
      else if (v ~ /M$/) { sub(/M/, "", v); printf "%.1f", v / 1024 }
    }')
  else
    read -r used total < <(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2}
      END { printf "%.1f %.1f", (t - a) / 1048576, t / 1048576 }' /proc/meminfo)
  fi
  pct=$(awk -v u="$used" -v t="$total" 'BEGIN { printf "%.0f", (t > 0) ? u / t * 100 : 0 }')
  # total barely changes -- pad used to its width (not a worst-case guess)
  # so the "/" doesn't drift as used gains/loses a digit.
  local u="${used}G" t="${total}G" w=${#total}
  (( ${#used} > w )) && w=${#used}
  ((w += 1))
  printf '#[fg=%s]%s %-*s/%s' "$(heat "$pct")" "$I_RAM" "$w" "$u" "$t"
}

disk() {
  local mount="/" line used total pct
  [ "$os" = "Darwin" ] && mount="/System/Volumes/Data"
  line=$(df -h "$mount" | awk 'NR==2')
  used=$(printf '%s' "$line" | awk '{ gsub(/Gi/, "G", $3); print $3 }')
  total=$(printf '%s' "$line" | awk '{ gsub(/Gi/, "G", $2); print $2 }')
  pct=$(printf '%s' "$line" | awk '{ gsub(/%/, "", $5); print $5 }')
  # total (filesystem size) is fixed -- pad used to its width instead of a
  # worst-case guess, so the "/" doesn't drift as used gains/loses a digit.
  local w=${#total}
  (( ${#used} > w )) && w=${#used}
  printf '#[fg=%s]%s %-*s/%s' "$(heat "$pct")" "$I_DISK" "$w" "$used" "$total"
}

# Network RX/TX rate for the primary non-loopback interface. Samples ~1s.
net() {
  local iface rx1 tx1 rx2 tx2
  if [ "$os" = "Darwin" ]; then
    iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
    [ -z "$iface" ] && iface="en0"
    read -r rx1 tx1 <<<"$(netstat -ibn 2>/dev/null | awk -v i="$iface" '$1==i && /Link/ { print $7, $10; exit }')"
    sleep 1
    read -r rx2 tx2 <<<"$(netstat -ibn 2>/dev/null | awk -v i="$iface" '$1==i && /Link/ { print $7, $10; exit }')"
  else
    iface=$(ip route 2>/dev/null | awk '/^default/ { print $5; exit }')
    [ -z "$iface" ] && iface=$(awk 'NR>2 { gsub(/:/, "", $1); if ($1 != "lo") { print $1; exit } }' /proc/net/dev)
    if [ -z "$iface" ]; then printf '#[fg=%s]n/a' "$C_GREEN"; return; fi
    read -r rx1 tx1 <<<"$(awk -v i="${iface}:" '$1==i { print $2, $10 }' /proc/net/dev)"
    sleep 1
    read -r rx2 tx2 <<<"$(awk -v i="${iface}:" '$1==i { print $2, $10 }' /proc/net/dev)"
  fi
  local rx tx; read -r rx tx <<<"$(awk -v r1="$rx1" -v t1="$tx1" -v r2="$rx2" -v t2="$tx2" \
    'BEGIN { print r2 - r1, t2 - t1 }')"
  local kb; kb=$(awk -v r="$rx" -v t="$tx" 'BEGIN { printf "%.0f", (r > t ? r : t) / 1024 }')
  printf '#[fg=%s]' "$(heat_rate "$kb")"
  # rx/tx have no stable anchor to pad against (unlike ram/disk's total) --
  # pad each to the wider of the two so at least this pair doesn't drift.
  awk -v rx="$rx" -v tx="$tx" '
    function fmt(v) { return (v >= 1048576) ? sprintf("%.1fM", v / 1048576) : sprintf("%.0fK", v / 1024) }
    BEGIN {
      r = fmt(rx); t = fmt(tx)
      w = (length(r) > length(t)) ? length(r) : length(t)
      printf "↓%-*s ↑%s", w, r, t
    }
  '
}

ip() {
  local a=""
  if [ "$os" = "Darwin" ]; then
    a="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"
  else
    a="$(hostname -I 2>/dev/null | awk '{ print $1 }')"
    [ -n "$a" ] || a="$(ip route get 1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i+1); exit } }')"
  fi
  printf '#[fg=%s]%s %s' "$C_IP" "$I_IP" "${a:-—}"
}

# Docker summary — hidden entirely when docker isn't installed, the daemon
# isn't reachable, or nothing is running (all three just mean "nothing to
# summarize"). containers  cpu%  mem-used/limit  disk, each metric after the
# container count identified by the same icon its system-wide counterpart
# uses (I_CPU/I_RAM/I_DISK), so the group reads the same way as the rest of
# the navbar.
docker_seg() {
  command -v docker >/dev/null 2>&1 || return 0

  local tmp; tmp=$(mktemp -d)
  # disk usage is independent of the stats call below — run it in the
  # background so its latency overlaps instead of stacking on top.
  ( timeout 2 docker system df --format '{{.Size}}' 2>/dev/null > "$tmp/df" ) &
  local df_pid=$!

  local raw
  raw=$(timeout 2 docker stats --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}' 2>/dev/null)
  if [ -z "$raw" ]; then
    wait "$df_pid" 2>/dev/null
    rm -rf "$tmp"
    return 0
  fi

  wait "$df_pid" 2>/dev/null
  local disk_mb
  disk_mb=$(awk '{ v = $0 + 0; if ($0 ~ /GB/) v *= 1024; else if ($0 ~ /kB/) v /= 1024; s += v }
    END { printf "%.0f", s }' "$tmp/df")
  rm -rf "$tmp"

  local n; n=$(printf '%s\n' "$raw" | wc -l)

  local cpu_sum
  cpu_sum=$(printf '%s\n' "$raw" | awk -F'|' '{ gsub("%", "", $1); s += $1 } END { printf "%.0f", s }')

  local mem_used mem_limit
  read -r mem_used mem_limit <<<"$(printf '%s\n' "$raw" | awk -F'|' '
    function toMiB(v) { return (v ~ /GiB/) ? (v + 0) * 1024 : (v + 0) }
    { split($2, a, " / "); su += toMiB(a[1]); sl += toMiB(a[2]) }
    END { printf "%.0f %.0f", su, sl }
  ')"

  local mem_pct; mem_pct=$(awk -v u="$mem_used" -v l="$mem_limit" 'BEGIN { printf "%.0f", (l > 0) ? u / l * 100 : 0 }')
  local disk_c; disk_c=$(heat_abs "${disk_mb:-0}" 5120 20480)
  local disk_fmt; disk_fmt=$(awk -v m="$disk_mb" 'BEGIN { if (m >= 1024) printf "%.1fG", m / 1024; else printf "%dM", m }')

  printf '#[fg=%s]%s %s #[fg=%s]%s %s%% #[fg=%s]%s %sM/%sM #[fg=%s]%s %s' \
    "$C_DOCKER" "$I_DOCKER" "$n" \
    "$(heat "$cpu_sum")" "$I_CPU" "$cpu_sum" \
    "$(heat "$mem_pct")" "$I_RAM" "$mem_used" "$mem_limit" \
    "$disk_c" "$I_DISK" "$disk_fmt"
}

# Runs every stat concurrently (docker + net each block ~1s on their own) and
# assembles the line in a fixed order once they've all finished.
navbar() {
  local tmp; tmp=$(mktemp -d)
  cpu        > "$tmp/1_cpu"    &
  gpu        > "$tmp/2_gpu"    &
  ram        > "$tmp/3_ram"    &
  disk       > "$tmp/4_disk"   &
  net        > "$tmp/5_net"    &
  docker_seg > "$tmp/6_docker" &
  wait

  local f first=1
  for f in "$tmp"/*; do
    local v; v=$(<"$f")
    [ -z "$v" ] && continue
    if [ "$first" -eq 0 ]; then
      # a heavier divider between the "system" group (cpu/gpu/ram/disk/net)
      # and the "docker" group, a plain "  " gap between stats within a group
      case "$f" in
        */6_docker) printf ' #[fg=#6C7086]│#[fg=default] ' ;;
        *)          printf '  ' ;;
      esac
    fi
    printf '%s' "$v"
    first=0
  done
  rm -rf "$tmp"
}

case "${1:-navbar}" in
  navbar) navbar ;;
  cpu)    cpu    ;;
  gpu)    gpu    ;;
  ram)    ram    ;;
  disk)   disk   ;;
  net)    net    ;;
  ip)     ip     ;;
  docker) docker_seg ;;
esac
