# OpenSSL

Generates self-signed certs for local development.

Example docker-compose file:

```
version: "3"

services:
  web:
    image: nginx:stable-alpine
    ports:
      - "443:443"
    volumes:
      - certs:/etc/ssl/certs
    command: ["nginx", "-g", "daemon off;"]

  openssl:
    image: fieldwork/openssl
    environment:
      COUNTRY: UK
      STATE: Greater Manchester
      LOCATION: Manchester
      ORGANISATION: Fieldwork
      ISSUER_CN: Fieldwork
      PUBLIC_CN: example.localhost
      ISSUER_NAME: intermediate
      PUBLIC_NAME: example_localhost
    volumes:
      - certs:/etc/ssl/certs

volumes:
  certs: {}
```
