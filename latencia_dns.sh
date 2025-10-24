#!/bin/bash
# latgencia_dns.sh
#
# Prueba de latencia de DNS con manejo de fallos y timeout
# Detecta DNS local dinámicamente
# Calcula min, max, promedio de varios dominios
# Salta DNS que no responden y continúa

# Comprueba si el comando dig está disponible
if ! command -v dig >/dev/null 2>&1; then
    echo "dig no se encontró. Por favor, instala dnsutils."
    exit 1
fi

# Configuración
LOG_FILE="logs/latencia_dns_log.txt"
ENABLE_LOG=true
TIMEOUT_CMD=3  # Segundos máximos por intento
NUM_QUERIES=5  # Número de consultas por dominio

# Función para obtener el servidor DNS local
get_local_dns() {
    local dns=""
    if command -v resolvectl >/dev/null 2>&1; then
        dns=$(resolvectl status | awk '/Current DNS Server:/ {print $4; exit}')
    fi
    if [[ -z "$dns" ]]; then
        dns=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
    fi

    if [[ -z "$dns" ]]; then
        echo "No se pudo detectar el DNS del ISP. Continuando sin él."
    fi

    echo "$dns"
}

declare -A dns_providers
# Rápidos, orientados a la privacidad
dns_providers["Cloudflare"]="1.1.1.1 1.0.0.1"
dns_providers["Google"]="8.8.8.8 8.8.4.4"
dns_providers["Quad9"]="9.9.9.9 149.112.112.112"
dns_providers["NextDNS"]="45.90.28.202 45.90.30.202"

# Seguridad / aptos para familia
dns_providers["OpenDNS"]="208.67.222.222 208.67.220.220"
dns_providers["AdGuard"]="176.103.130.132 176.103.130.134"
dns_providers["CleanBrowsing"]="185.228.168.168 185.228.169.9"

# Regionales / alternativos opcionales
dns_providers["YandexDNS"]="77.88.8.8 77.88.8.1"
dns_providers["OpenNIC"]="185.121.177.177 169.239.202.202"


local_dns=$(get_local_dns)
[[ -n "$local_dns" ]] && dns_providers["DNS_Local"]="$local_dns"

test_domains=(
    "google.com"
    "amazon.com"
    "facebook.com"
    "youtube.com"
    "reddit.com"
    "wikipedia.org"
    "twitter.com"
    "gmail.com"
    "google.com"
    "whatsapp.com"
)

temp_results=$(mktemp)
isp_sorted=$(mktemp)
non_isp_sorted=$(mktemp)
$ENABLE_LOG && mkdir -p "$(dirname "$LOG_FILE")"
$ENABLE_LOG && echo "Prueba de Latencia DNS - $(date)" > "$LOG_FILE"

# Función para probar la latencia de un servidor DNS
test_dns() {
    local ip=$1
    local protocol=$2
    local timings=()

    for domain in "${test_domains[@]}"; do
        for i in $(seq 1 $NUM_QUERIES); do
            result=$(timeout $TIMEOUT_CMD dig @"$ip" "$domain" +$protocol +time=2 +tries=1 +stats 2>/dev/null | grep "Query time")
            if [[ $? -ne 0 ]]; then
                echo "timeout"
                return
            fi
            if [[ $result =~ ([0-9]+) ]]; then
                timings+=("${BASH_REMATCH[1]}")
            fi
        done
    done

    if [ ${#timings[@]} -eq 0 ] && [ "$protocol" = "udp" ]; then
        test_dns "$ip" "tcp"
        return
    fi

    if [ ${#timings[@]} -gt 0 ]; then
        local min=${timings[0]}
        local max=${timings[0]}
        local total=0
        for t in "${timings[@]}"; do
            (( t < min )) && min=$t
            (( t > max )) && max=$t
            total=$((total + t))
        done
        local avg=$((total / ${#timings[@]}))
        echo "$avg $min $max $ip"
    else
        echo "0 0 0 $ip"
    fi
}

# Comienza la prueba de DNS
echo
echo "-------------------------------------"
echo "Comenzando Prueba de Servidores DNS:"
echo "-------------------------------------"
echo

# Informar al usuario sobre la duración de la prueba
echo "Cada DNS se prueba contra ${#test_domains[@]} dominios y cada dominio tiene $NUM_QUERIES consultas."
echo

for domain in "${test_domains[@]}"; do
    echo "$domain"
done

echo
echo "Por favor, ten paciencia..."

# Ejecuta la prueba para cada proveedor de DNS
for provider in "${!dns_providers[@]}"; do
    echo -e "\n$provider" | tee -a "$temp_results"
    for ip in ${dns_providers[$provider]}; do
        result=$(test_dns "$ip" "udp")
        if [[ $result == "timeout" ]]; then
            echo "$ip: (Sin respuesta, saltando...)" | tee -a "$temp_results"
            continue
        fi

        avg=$(awk '{print $1}' <<< "$result")
        min=$(awk '{print $2}' <<< "$result")
        max=$(awk '{print $3}' <<< "$result")
        ip_only=$(awk '{print $4}' <<< "$result")

        if [ "$avg" -gt 0 ]; then
            echo "$provider $ip_only $avg $min $max" >> "$temp_results.data"
            echo "$ip_only Latencia: Promedio=$avg ms Min=$min ms Max=$max ms" | tee -a "$temp_results"
        else
            echo "$provider $ip_only 0 0 0" >> "$temp_results.data"
            echo "$ip_only: No alcanzable" | tee -a "$temp_results"
        fi
    done
done

# Ordena los resultados por ISP y no ISP
awk '$1 == "DNS_Local" && $3 > 0' "$temp_results.data" | sort -k3 -n > "$isp_sorted"
awk '$1 != "DNS_Local" && $3 > 0' "$temp_results.data" | sort -k3 -n > "$non_isp_sorted"

# Muestra resultados finales
echo
echo "----------------------------------------------------"
echo "RESULTADOS: (los servidores DNS más rápidos arriba)"
echo "----------------------------------------------------"
echo

# Encabezado
printf "%-40s %-10s %-10s %-10s\n" "DNS Provider (IP)" "Min" "Max" "Promedio"

# Función para imprimir una fila de resultados de forma ordenada
print_dns_row() {
    local provider=$1
    local ip=$2
    local avg=$3
    local min=$4
    local max=$5

    if [ "$avg" -gt 0 ]; then
        printf "%-40s %-10s %-10s %-10s\n" "$provider ($ip)" "${min}ms" "${max}ms" "${avg}ms"
    else
        printf "%-40s %-10s %-10s %-10s\n" "$provider ($ip)" "N/A" "N/A" "N/A"
    fi
}

# Imprime primero el DNS del ISP
cat "$isp_sorted" | while read -r provider ip avg min max; do
    print_dns_row "$provider" "$ip" "$avg" "$min" "$max"
done

# Imprime los DNS que no son del ISP
cat "$non_isp_sorted" | while read -r provider ip avg min max; do
    print_dns_row "$provider" "$ip" "$avg" "$min" "$max"
done
echo
