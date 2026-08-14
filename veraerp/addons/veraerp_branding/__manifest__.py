{
    "name": "veraERP Branding",
    "version": "1.0.0",
    "category": "Tools",
    "summary": "White-label branding for veraERP",
    "depends": ["web"],
    "data": [
        "views/branding_templates.xml",
    ],
    "assets": {
        "web.assets_frontend": [
            "veraerp_branding/static/src/css/branding.css",
        ],
        "web.assets_backend": [
            "veraerp_branding/static/src/css/branding.css",
        ],
    },
    "installable": True,
    "application": False,
}
