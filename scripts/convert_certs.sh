#!/bin/sh
set -e

# Çıktı dosyaları (Nginx config ile uyumlu olmalı)
CRT_FILE="/etc/nginx/certs/certificate.crt"
KEY_FILE="/etc/nginx/certs/private.key"
CERTS_DIR="/etc/nginx/certs"

# PFX dosyasını belirle
if [ -n "$PFX_FILE" ]; then
    # Eğer environment variable ile tam yol verildiyse onu kullan
    TARGET_PFX="$PFX_FILE"
else
    # Verilmediyse, sertifika klasöründeki ilk .pfx dosyasını bul (Otomatik keşif)
    TARGET_PFX=$(find "$CERTS_DIR" -maxdepth 1 -name "*.pfx" | head -n 1)
fi

# Dosya kontrolü
if [ -z "$TARGET_PFX" ] || [ ! -f "$TARGET_PFX" ]; then
    echo "Warning: No PFX file found at '$TARGET_PFX' or in '$CERTS_DIR'. Skipping conversion."
    exit 0
fi

echo "Using PFX file: $TARGET_PFX"

# Parolayı ortam değişkeninden al
PASS="${PFX_PASS}"

if [ -z "$PASS" ]; then
    echo "Warning: PFX_PASS is not set. Assuming empty password or relying on 'changeit'."
    PASS="changeit"
fi

# Sertifika veya anahtar yoksa veya PFX dosyası çıktılardan daha yeniyse dönüştür
# -nt: newer than
if [ ! -f "$CRT_FILE" ] || [ ! -f "$KEY_FILE" ] || [ "$TARGET_PFX" -nt "$CRT_FILE" ]; then
    echo "Extracting certificates from PFX..."
    
    # Private Key
    openssl pkcs12 -in "$TARGET_PFX" -nocerts -out "$KEY_FILE" -nodes -passin pass:"$PASS"
    
    # Certificate
    openssl pkcs12 -in "$TARGET_PFX" -nokeys -out "$CRT_FILE" -passin pass:"$PASS"
    
    # İzinleri ayarla (Private key güvenliği)
    chmod 600 "$KEY_FILE"
    chmod 644 "$CRT_FILE"
    
    echo "Extraction complete."
else
    echo "Certificates are up to date."
fi
