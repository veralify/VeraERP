ARG ODOO_VERSION=18.0
FROM odoo:${ODOO_VERSION}

USER root
RUN mkdir -p /mnt/extra-addons/custom_addons
COPY custom_addons/ /mnt/extra-addons/custom_addons/
RUN chown -R odoo:odoo /mnt/extra-addons/custom_addons
USER odoo
