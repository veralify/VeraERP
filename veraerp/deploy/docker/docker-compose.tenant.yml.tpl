name: tenant-__TENANT_SLUG__

services:
  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_DB: __TENANT_SLUG__
      POSTGRES_USER: __POSTGRES_USER__
      POSTGRES_PASSWORD: __POSTGRES_PASSWORD__
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U __POSTGRES_USER__ -d __TENANT_SLUG__"]
      interval: 10s
      timeout: 5s
      retries: 10

  odoo:
    image: __VERAERP_IMAGE__
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      TZ: __VERAERP_TIMEZONE__
      HOST: postgres
      PORT: 5432
      USER: __POSTGRES_USER__
      PASSWORD: __POSTGRES_PASSWORD__
    command:
      - odoo
      - --config=/etc/odoo/odoo.conf
    ports:
      - "__HOST_PORT__:8069"
    volumes:
      - ./odoo-data:/var/lib/odoo
      - ./odoo.conf:/etc/odoo/odoo.conf:ro

