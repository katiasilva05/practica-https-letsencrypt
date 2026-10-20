[README.md](https://github.com/user-attachments/files/33715035/README.md)
# Práctica: HTTPS con Let’s Encrypt y Certbot

## 1. Objetivo

Documentar la configuración de HTTPS en Apache, primero mediante un certificado autofirmado de prueba y después mediante un certificado válido emitido por Let’s Encrypt con Certbot. También se describe la adaptación de WordPress para que utilice HTTPS.

> **Importante:** el certificado autofirmado sirve para pruebas y provoca una advertencia en el navegador. No es equivalente a un certificado público de Let’s Encrypt. El certificado de Let’s Encrypt requiere un nombre DNS que apunte a la IP pública de la instancia y que el servidor sea accesible desde Internet por el puerto 80 durante la validación HTTP-01.

## 2. Requisitos previos

- Instancia Ubuntu en AWS con acceso SSH y permisos `sudo`.
- Apache instalado y WordPress funcionando por HTTP.
- Reglas de entrada del grupo de seguridad AWS: TCP 22 para SSH, TCP 80 para HTTP y TCP 443 para HTTPS.
- Un nombre DNS que se pueda administrar y que apunte a la IP pública actual de la instancia.
- Conectividad desde la instancia a los repositorios de paquetes y a los servicios de Let’s Encrypt.

En esta práctica se utilizó como ejemplo `wordpress-prueba-2026.duckdns.org`. Sustituirlo si se usa otro nombre.

## 3. Certificado autofirmado de prueba

Durante las pruebas se creó un certificado autofirmado y una clave privada para Apache. Este tipo de certificado permite comprobar que el servicio TLS está configurado, pero los navegadores no confían en él de forma predeterminada.

Ejemplo de creación de un certificado autofirmado (ejecutar en el servidor; adaptar las rutas si ya existe una configuración):

```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/prueba-https.key \
  -out /etc/ssl/certs/prueba-https.crt \
  -subj "/CN=prueba-https.local"
sudo chmod 600 /etc/ssl/private/prueba-https.key
sudo a2enmod ssl
```

Una configuración temporal de Apache puede usar estas directivas dentro de un bloque `<VirtualHost *:443>`:

```apache
SSLEngine on
SSLCertificateFile /etc/ssl/certs/prueba-https.crt
SSLCertificateKeyFile /etc/ssl/private/prueba-https.key
```

Después de modificar la configuración se comprueba la sintaxis y se recarga Apache:

```bash
sudo apache2ctl configtest
sudo systemctl reload apache2
```

La salida esperada de la comprobación es `Syntax OK`. La página de prueba se puede abrir con `https://IP_PUBLICA/ruta-de-prueba/`; el navegador mostrará una advertencia porque el certificado es autofirmado.

## 4. Configuración de DNS y AWS

1. Consultar la IPv4 pública actual de la instancia en la consola EC2.
2. Configurar el registro DNS del subdominio para que apunte a esa IP.
3. Comprobar la resolución:
   ```bash
   getent hosts wordpress-prueba-2026.duckdns.org
   ```
4. Verificar que la IP resuelta coincide con la IP pública actual de EC2.
5. Verificar que las reglas del grupo de seguridad permiten el tráfico HTTP (80) y HTTPS (443).

La IP pública de una instancia puede cambiar si se detiene y vuelve a iniciar, salvo que se utilice una Elastic IP. Si cambia, hay que actualizar el registro DNS.

## 5. Instalar y ejecutar Certbot

El script `scripts/setup_letsencrypt_certificate.sh` automatiza la preparación de Certbot y la solicitud del certificado mediante el complemento de Apache.

Antes de ejecutarlo:

1. Editar `scripts/.env` y establecer el dominio y el correo electrónico reales.
2. Confirmar que el dominio resuelve a la IP correcta.
3. Confirmar que el puerto TCP 80 es accesible desde Internet y que Apache sirve la web por HTTP.

Ejecución:

```bash
chmod +x scripts/*.sh
sudo bash scripts/setup_letsencrypt_certificate.sh
```

Certbot puede solicitar aceptar las condiciones del servicio. Si el certificado se emite correctamente, comprobarlo con:

```bash
sudo certbot certificates
sudo apache2ctl -S
```

Si falla la validación, revisar primero el DNS y el acceso externo al puerto 80. No repetir la solicitud sin corregir la causa.

## 6. Configurar WordPress para HTTPS

Una vez emitido y activado el certificado para el dominio:

1. Hacer una copia de seguridad de `wp-config.php`.
2. Revisar si existen constantes `WP_HOME` y `WP_SITEURL`:
   ```bash
   sudo grep -nE 'WP_HOME|WP_SITEURL' /var/www/html/wp-config.php
   ```
3. Si están definidas, actualizar ambas para usar el dominio HTTPS real. Si no están definidas, se pueden añadir antes de la línea `/* That's all, stop editing! Happy publishing. */`:
   ```php
   define('WP_HOME', 'https://wordpress-prueba-2026.duckdns.org');
   define('WP_SITEURL', 'https://wordpress-prueba-2026.duckdns.org');
   ```
   Sustituir el dominio de ejemplo por el dominio que realmente se haya certificado. No añadir las constantes duplicadas.
4. Comprobar la web en `https://DOMINIO_REAL/`, iniciar sesión si procede y revisar que no haya contenido mixto.
5. Comprobar la renovación:
   ```bash
   sudo certbot renew --dry-run
   ```

No configurar WordPress para usar HTTPS antes de que el certificado válido esté instalado y funcione.

## 7. Evidencias recomendadas

El apartado de entregables citado exige un documento técnico y los scripts indicados; el texto citado no enumera capturas obligatorias. Como evidencias de apoyo, se pueden guardar:

- Página de prueba HTTPS con certificado autofirmado.
- Configuración DNS apuntando a la IP pública de EC2.
- Mensaje de éxito de Certbot o salida de `sudo certbot certificates`.
- WordPress abierto con `https://` y el certificado válido visible en el navegador.
- Salida de `sudo apache2ctl configtest` mostrando `Syntax OK`.

## 8. Estructura del repositorio

```text
.
├── README.md
├── conf/
│   └── README.md
└── scripts/
    ├── .env
    ├── install_lamp.sh
    └── setup_letsencrypt_certificate.sh
```

## 9. Entrega en GitHub

1. Crear un repositorio con el nombre de la práctica.
2. Subir `README.md`, `conf/` y `scripts/`.
3. Añadir al profesor como colaborador según las instrucciones del curso.
4. No subir contraseñas, tokens, claves privadas, credenciales AWS ni archivos con secretos. El archivo `.env` de esta entrega solo contiene valores de configuración no secretos y un correo de ejemplo que debe editarse.
