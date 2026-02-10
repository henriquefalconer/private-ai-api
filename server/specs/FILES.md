# ai-server Repository Layout

```
server/
├── specs/                     # This folder — all markdown specifications
│   ├── ARCHITECTURE.md
│   ├── FUNCTIONALITIES.md
│   ├── SECURITY.md
│   ├── INTERFACES.md
│   ├── REQUIREMENTS.md
│   ├── SCRIPTS.md
│   └── FILES.md
├── scripts/
│   ├── install.sh             # One-time setup script for server machine
│   ├── uninstall.sh           # Remove server-side LaunchAgent and plist
│   ├── warm-models.sh         # Optional: pre-load models at boot / startup
│   └── test.sh                # Comprehensive server functionality tests
├── SETUP.md                   # Setup instructions
└── README.md                  # Overview and quick start
```

No additional files required for v1 core functionality.
