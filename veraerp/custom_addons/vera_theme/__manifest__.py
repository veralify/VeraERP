{
    "name": "veraERP Theme",
    "version": "1.0.0",
    "category": "Tools",
    "summary": "White-label theme and branding for veraERP",
    "license": "LGPL-3",
    "depends": ["web"],
    "data": [
        "views/branding_templates.xml",
    ],
    "assets": {
        "web.assets_frontend": [
            "vera_theme/static/src/css/branding.css",
        ],
        "web.assets_backend": [
            "vera_theme/static/src/css/branding.css",
        ],
    },
    "installable": True,
    "application": False,
}
