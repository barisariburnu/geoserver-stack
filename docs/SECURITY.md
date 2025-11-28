# GeoServer Güvenlik Yapılandırma Rehberi

Bu dokümanda GeoServer kurulumunuzun güvenliğini sağlamak için adımlar açıklanmaktadır.

## 🔐 Temel Güvenlik

### 1. Admin Şifresini Değiştirme

> [!CAUTION]
> Varsayılan admin şifresi `geoserver/geoserver` **MUTLAKA** değiştirilmelidir!

#### İlk Kurulum (.env dosyası)

```bash
# .env dosyasında
GEOSERVER_ADMIN_USER=admin
GEOSERVER_ADMIN_PASSWORD=YourStrongPasswordHere123!
```

#### GeoServer Web Arayüzünden

1. Admin paneline giriş yapın
2. `Security` → `Users, Groups, Roles`
3. `Users` sekmesi → `admin` kullanıcısına tıklayın
4. `Change password` ile şifreyi değiştirin

#### Güçlü Şifre Kriterleri

- Minimum 12 karakter
- Büyük ve küçük harf
- Rakam ve özel karakter
- Sözlükte olmayan kelimeler
- Önceki şifrelerle farklı

```powershell
# PowerShell ile rastgele güçlü şifre üret
-join ((48..57) + (65..90) + (97..122) + (33..47) | Get-Random -Count 16 | ForEach-Object {[char]$_})
```

### 2. Kullanıcı ve Rol Yönetimi

#### Yeni Kullanıcı Oluşturma

1. `Security` → `Users, Groups, Roles`
2. `Add new user`
3. Kullanıcı adı ve şifre girin
4. Uygun rolleri atayın

#### Rol Tabanlı Erişim (RBAC)

| Rol | Açıklama | Önerilen Kullanım |
|-----|----------|-------------------|
| `ADMIN` | Tam yetki | Sadece sistem yöneticileri |
| `GROUP_ADMIN` | Workspace yöneticisi | Veri yöneticileri |
| `AUTHENTICATED` | Kimliği doğrulanmış | Standart kullanıcılar |
| `ANONYMOUS` | Anonim erişim | Genel okuma |

#### Layer Bazlı Güvenlik

`Security` → `Data` → `Add new rule`

```
workspace.layer.operation = ROLE
```

Örnekler:
```
*.*.r = *                    # Tüm layer'lara okuma erişimi
myworkspace.*.w = ADMIN      # Sadece admin yazabilir
sensitive.*.* = AUTHENTICATED # Kimlik doğrulama gerekli
```

## 🔒 HTTPS/SSL Yapılandırması

### Self-Signed Sertifika Oluşturma (Test için)

```powershell
# OpenSSL ile self-signed sertifika
openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
  -keyout geoserver.key `
  -out geoserver.crt `
  -subj "/C=TR/ST=Istanbul/L=Istanbul/O=Organization/CN=localhost"

# PFX formatına çevir
openssl pkcs12 -export -out geoserver.pfx `
  -inkey geoserver.key `
  -in geoserver.crt `
  -password pass:YourPassword
```

### Let's Encrypt ile Sertifika (Production)

```powershell
# Certbot kurulumu (Windows)
# https://certbot.eff.org/instructions Windows Apache

# Standalone mode
certbot certonly --standalone -d yourdomain.com

# Sertifika dizini: C:\Certbot\live\yourdomain.com\
```

### Docker Compose HTTPS Konfigürasyonu

```yaml
services:
  geoserver:
    ports:
      - "8080:8080"
      - "8443:8443"
    
    volumes:
      - ./ssl/geoserver.crt:/opt/ssl/geoserver.crt:ro
      - ./ssl/geoserver.key:/opt/ssl/geoserver.key:ro
    
    environment:
      - SSL_CERT_PATH=/opt/ssl/geoserver.crt
      - SSL_KEY_PATH=/opt/ssl/geoserver.key
```

### Nginx Reverse Proxy ile HTTPS

`nginx.conf`:

```nginx
upstream geoserver {
    server localhost:8080;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    location /geoserver {
        proxy_pass http://geoserver;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

## 🛡️ Network Güvenlik

### 1. IP Bazlı Erişim Kısıtlaması

#### GeoServer Service Security

`Security` → `Service Security`

```xml
<serviceAccessControl>
  <service>WMS</service>
  <remoteAddress>192.168.1.0/24</remoteAddress>
  <allowed>true</allowed>
</serviceAccessControl>
```

#### Windows Firewall

```powershell
# Sadece local network'ten erişime izin ver
New-NetFirewallRule `
  -DisplayName "GeoServer HTTP" `
  -Direction Inbound `
  -LocalPort 8080 `
  -Protocol TCP `
  -Action Allow `
  -RemoteAddress 192.168.1.0/24

# Belirli IP'den erişim
New-NetFirewallRule `
  -DisplayName "GeoServer HTTPS Admin" `
  -Direction Inbound `
  -LocalPort 8443 `
  -Protocol TCP `
  -Action Allow `
  -RemoteAddress 192.168.1.100
```

### 2. CORS Yapılandırması

`webapps/geoserver/WEB-INF/web.xml`:

```xml
<filter>
  <filter-name>CorsFilter</filter-name>
  <filter-class>org.apache.catalina.filters.CorsFilter</filter-class>
  <init-param>
    <param-name>cors.allowed.origins</param-name>
    <param-value>https://yourdomain.com,https://app.yourdomain.com</param-value>
  </init-param>
  <init-param>
    <param-name>cors.allowed.methods</param-name>
    <param-value>GET,POST,HEAD,OPTIONS</param-value>
  </init-param>
</filter>
```

### 3. Rate Limiting

#### Nginx ile Rate Limiting

```nginx
http {
    limit_req_zone $binary_remote_addr zone=geoserver:10m rate=10r/s;
    
    server {
        location /geoserver {
            limit_req zone=geoserver burst=20 nodelay;
            proxy_pass http://geoserver;
        }
    }
}
```

## 🔍 Monitoring ve Audit

### 1. Logging Konfigürasyonu

`data_dir/logging.xml`:

```xml
<logging>
  <level>PRODUCTION_LOGGING</level>
  <location>logs/geoserver.log</location>
  <stdOutLogging>false</stdOutLogging>
</logging>
```

#### Audit Logging

`Security` → `Authentication` → `Enable audit logging`

Log formatı:
```
[DATE] [USER] [IP] [SERVICE] [LAYER] [OPERATION] [RESULT]
```

### 2. Security Headers

```yaml
# docker-compose.yml
environment:
  - JAVA_OPTS=-DGEOSERVER_CSRF_DISABLED=false
             -Dorg.geoserver.web.header.X-Frame-Options=SAMEORIGIN
             -Dorg.geoserver.web.header.X-Content-Type-Options=nosniff
             -Dorg.geoserver.web.header.X-XSS-Protection=1;mode=block
```

### 3. Failed Login Monitoring

```powershell
# PowerShell script - failed-login-monitor.ps1
$logPath = "D:\geoserver_data\logs\geoserver.log"
$pattern = "Authentication failed"

Get-Content $logPath -Tail 100 | Select-String $pattern | ForEach-Object {
    Write-Host "Failed login detected: $_" -ForegroundColor Red
}
```

## 🗄️ Veri Güvenliği

### 1. Database Credentials

> [!WARNING]
> Veritabanı şifreleri asla hardcode etmeyin!

#### Environment Variables Kullanımı

```bash
# .env dosyası
DB_HOST=localhost
DB_PORT=5432
DB_NAME=gisdb
DB_USER=gisuser
DB_PASSWORD=SecurePassword123!
```

`datastore.xml`:
```xml
<entry key="host">${DB_HOST}</entry>
<entry key="port">${DB_PORT}</entry>
<entry key="user">${DB_USER}</entry>
<entry key="passwd">${DB_PASSWORD}</entry>
```

### 2. Encrypted Passwords

GeoServer Master Password:

1. `Security` → `Passwords` → `Master Password Provider`
2. `Change Master Password`
3. Yeni güçlü şifre girin

### 3. Data Directory Permissions

```powershell
# Sadece SYSTEM ve Administrators erişebilsin
icacls "D:\geoserver_data" /inheritance:r
icacls "D:\geoserver_data" /grant:r "SYSTEM:(OI)(CI)F"
icacls "D:\geoserver_data" /grant:r "Administrators:(OI)(CI)F"
```

## 🚨 Security Best Practices

### Checklist

- [ ] Admin şifresi değiştirildi
- [ ] Güçlü şifre politikası uygulandı
- [ ] HTTPS/SSL yapılandırıldı
- [ ] IP kısıtlamaları uygulandı
- [ ] RBAC aktif
- [ ] Layer bazlı güvenlik yapılandırıldı
- [ ] CORS politikası tanımlı
- [ ] Audit logging aktif
- [ ] Veri dizini izinleri kısıtlı
- [ ] Database credentials şifreli
- [ ] Firewall kuralları aktif
- [ ] Security headers ayarlı
- [ ] Failed login monitoring

### Düzenli Güvenlik Kontrolleri

```powershell
# Haftalık güvenlik kontrolü
# security-check.ps1

Write-Host "Security Check - $(Get-Date)" -ForegroundColor Cyan

# 1. Admin şifre yaşı
# 2. SSL sertifika geçerlilik
# 3. Failed login sayısı
# 4. User/role değişiklikleri
# 5. Data access patterns
```

### Güvenlik Güncellemeleri

```powershell
# GeoServer versiyonunu kontrol et
docker exec geoserver curl -s http://localhost:8080/geoserver/rest/about/version.json

# Docker image güncellemesi
docker-compose pull
docker-compose up -d
```

## 🔐 Advanced Security

### 1. OAuth2/OIDC Integration

```xml
<!-- geofence-security.xml -->
<security>
  <oauth2>
    <enabled>true</enabled>
    <provider>keycloak</provider>
    <clientId>geoserver</clientId>
    <clientSecret>secret</clientSecret>
  </oauth2>
</security>
```

### 2. LDAP/Active Directory

`Security` → `Authentication` → `Add new authentication provider`

```
Type: LDAP
Server URL: ldap://ad.example.com:389
User DN Pattern: cn={0},ou=users,dc=example,dc=com
```

### 3. Two-Factor Authentication (2FA)

Reverse proxy (Nginx) ile 2FA:
- Google Authenticator
- Duo Security
- Microsoft Authenticator

## 📋 Incident Response

### Güvenlik İhlali Durumunda

1. **Hemen yapılacaklar:**
   ```powershell
   # Container'ı durdur
   docker-compose stop
   
   # Logları kaydet
   docker-compose logs geoserver > incident-logs.txt
   ```

2. **Şifreleri değiştir:**
   - Admin şifresi
   - Database credentials
   - SSL sertifikaları

3. **Analiz et:**
   - Erişim logları
   - Audit trail
   - Network logs

4. **Güvenlik yamaları:**
   ```powershell
   docker-compose pull
   docker-compose up -d
   ```

## 🔗 Kaynaklar

- [GeoServer Security Documentation](https://docs.geoserver.org/stable/en/user/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [Let's Encrypt](https://letsencrypt.org/)
