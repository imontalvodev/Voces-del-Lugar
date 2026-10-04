# HTTPS en la red local con un certificado propio de Caddy: hace falta para
# que el navegador de otro equipo dé el micrófono y la posición. La app y la
# API salen por el mismo origen. El navegador avisará del certificado.
#
# docker run -d --name voces-https --network host \
#   -v "$PWD/deploy/Caddyfile.red:/etc/caddy/Caddyfile:ro,z" \
#   -v "$PWD/apps/flutter/build:/build:ro,z" -v voces_caddy:/data -e VOCES_HOST=<IP> caddy:2
{
	auto_https disable_redirects
	default_sni {$VOCES_HOST:localhost}
}

https://{$VOCES_HOST:localhost}:8443, https://localhost:8443 {
	tls internal
	handle /api/* {
		reverse_proxy 127.0.0.1:8001
	}
	handle {
		root * /build/web
		file_server
	}
}
