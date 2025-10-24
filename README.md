# latencia_dns.sh

## Descripción

**latencia_dns.sh** es un script escrito en Bash diseñado para medir la latencia de distintos servidores DNS. Permite comparar la velocidad de resolución de nombres de dominio entre el DNS local, proveedores públicos y servidores alternativos, facilitando la elección del DNS más rápido y estable.

## Funcionalidades

- Detección automática del DNS local del ISP.
- Pruebas de latencia múltiples por dominio, con cantidad configurable de consultas (`NUM_QUERIES`).
- Soporte de protocolos UDP y TCP, con fallback automático si UDP no responde.
- Cálculo de estadísticas por servidor DNS: mínimo, máximo y promedio de tiempo de respuesta.
- Separación entre DNS del ISP y DNS públicos/alternativos.
- Manejo de timeouts para consultas que no responden.
- Fácil de extender agregando nuevos proveedores de DNS o dominios de prueba.
- Evita resultados falsos gracias a múltiples consultas por dominio y fallback a TCP.  
- Extensible y configurable.

## Servdidores DNS incluidos por defecto
- Cloudflare
- Google
- Quad9
- NextDNS
- OpenDNS
- AdGuard
- CleanBrowsing
- YandexDNS
- OpenNIC


## Registro en archivo (log)

El script puede guardar un registro completo de la prueba en un archivo de log para análisis posterior:

- Por defecto, el log se guarda en: `logs/latencia_dns_log.txt`.  
- Se crean automáticamente los directorios necesarios si no existen.  
- Para habilitar o deshabilitar el log, modifica la variable de configuración:
  
```bash
ENABLE_LOG=true   # Activar log
ENABLE_LOG=false  # Desactivar log
```

## Dependencias

El script requiere que esté instalado el comando `dig`.  
Si no está presente, mostrará un mensaje de error y no se ejecutará.

### Instalación de `dig` (dnsutils)

- **Arch Linux / Manjaro**:
```bash
sudo pacman -S bind
```

- **Fedora / RHEL / CentOS**:
```bash
sudo dnf install bind-utils
```

- **Ubuntu / Debian**:
```bash
sudo apt update
sudo apt install dnsutils
```


## Ejemplo de uso
Bash:
```bash
./latencia_dns.sh
```
Fish:
```bash
bash latencia_dns.sh
```
