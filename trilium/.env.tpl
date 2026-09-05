TZ=Europe/London
# Trilium ignores PUID/PGID and the --user directive; these are its equivalents.
USER_UID=950
USER_GID=950
# Caddy fronts this; uniquelocal covers the docker bridge and LAN ranges so
# express reads the real client IP from X-Forwarded-For.
TRILIUM_NETWORK_TRUSTEDREVERSEPROXY=uniquelocal
