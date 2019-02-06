#!/bin/sh
# docker entrypoint script
# generate three tier certificate chain

if [ $RENEW == "yes" ]
then
  echo "Renewing. RENEW env var is: $RENEW"
  rm "$CERT_DIR/$ROOT_NAME.crt"
  rm "$CERT_DIR/$ISSUER_NAME.crt"
  rm "$CERT_DIR/$PUBLIC_NAME.crt"
  rm "$CERT_DIR/key.pem"
  rm "$CERT_DIR/chain.pem"
  rm "$CERT_DIR/fullchain.pem"
  rm "$CERT_DIR/dhparam.pem"
else
  echo "Not renewing. RENEW env var is: $RENEW"
fi

SUBJ="/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$ORGANISATION"

if [ ! -f "$CERT_DIR/$ROOT_NAME.crt" ]
then
  # generate root certificate
  echo "ROOT CERTIFICATE"
  ROOT_SUBJ="$SUBJ/CN=$ROOT_CN"

  echo "Generating RSA: $ROOT_NAME.key"
  openssl genrsa \
    -out "$ROOT_NAME.key" \
    "$RSA_KEY_NUMBITS"

  echo "Generating CSR: $ROOT_NAME.csr"
  openssl req \
    -new \
    -key "$ROOT_NAME.key" \
    -out "$ROOT_NAME.csr" \
    -subj "$ROOT_SUBJ"

  echo "Generating root certificate: $ROOT_NAME.crt"
  openssl req \
    -x509 \
    -key "$ROOT_NAME.key" \
    -in "$ROOT_NAME.csr" \
    -out "$ROOT_NAME.crt" \
    -days "$DAYS"

  # copy certificate to volume
  echo "Copying $ROOT_NAME.crt to $CERT_DIR."
  cp "$ROOT_NAME.crt" "$CERT_DIR"
else
  echo "ENTRYPOINT: $ROOT_NAME.crt already exists. Making a copy…"
  cp "$CERT_DIR/$ROOT_NAME.crt" .
fi

if [ ! -f "$CERT_DIR/$ISSUER_NAME.crt" ]
then
  echo "ISSUER CERTIFICATE"
  # generate issuer certificate
  ISSUER_SUBJ="$SUBJ/CN=$ISSUER_CN"

  echo "Generating RSA: $ISSUER_NAME.key"
  openssl genrsa \
    -out "$ISSUER_NAME.key" \
    "$RSA_KEY_NUMBITS"

  echo "Generating CSR."
  openssl req \
    -new \
    -key "$ISSUER_NAME.key" \
    -out "$ISSUER_NAME.csr" \
    -subj "$ISSUER_SUBJ"

  echo "Generating issuer certificate: $ISSUER_NAME.crt"
  openssl x509 \
    -req \
    -in "$ISSUER_NAME.csr" \
    -CA "$ROOT_NAME.crt" \
    -CAkey "$ROOT_NAME.key" \
    -out "$ISSUER_NAME.crt" \
    -CAcreateserial \
    -extfile issuer.ext \
    -days "$DAYS"

  # copy certificate to volume
  echo "Copying $ISSUER_NAME.crt to $CERT_DIR."
  cp "$ISSUER_NAME.crt" "$CERT_DIR"
else
  echo "ENTRYPOINT: $ISSUER_NAME.crt already exists. Making a copy…"
  cp "$CERT_DIR/$ISSUER_NAME.crt" .
fi

if [ ! -f "$CERT_DIR/key.pem" ]
then
  # generate public rsa key
  echo "Generating RSA: key.pem"
  openssl genrsa \
    -out "key.pem" \
    "$RSA_KEY_NUMBITS"

  # copy public rsa key to volume
  echo "Copying key.pem to $CERT_DIR"
  cp "key.pem" "$CERT_DIR"
else
  echo "ENTRYPOINT: key.pem already exists. Making a copy…"
  cp "$CERT_DIR/key.pem" .
fi

if [ ! -f "$CERT_DIR/$PUBLIC_NAME.crt" ]
then
  # generate public certificate
  echo "PUBLIC CERTIFICATE"
  PUBLIC_SUBJ="$SUBJ/CN=$PUBLIC_CN"

  echo "Generating CSR: $PUBLIC_NAME.csr"
  openssl req \
    -new \
    -key "key.pem" \
    -out "$PUBLIC_NAME.csr" \
    -subj "$PUBLIC_SUBJ"

  # append public cn to subject alt names
  echo "Appending to public.ext:"
  DNS=""
  dnscount=0
  for cn in ${PUBLIC_CN//;/ } ; do
    dnscount=$((dnscount+1))
    echo "DNS.$dnscount = $cn"
    echo "DNS.$dnscount = $cn" >> public.ext
  done

  echo "Generating certificate: $PUBLIC_NAME.crt"
  openssl x509 \
    -req \
    -in "$PUBLIC_NAME.csr" \
    -CA "$ISSUER_NAME.crt" \
    -CAkey "$ISSUER_NAME.key" \
    -out "$PUBLIC_NAME.crt" \
    -CAcreateserial \
    -extfile public.ext \
    -days "$DAYS"

  # copy certificate to volume
  echo "Copying $PUBLIC_NAME.crt to $CERT_DIR"
  cp "$PUBLIC_NAME.crt" "$CERT_DIR"
else
  echo "ENTRYPOINT: $PUBLIC_NAME.crt already exists. Making a copy…"
  cp "$CERT_DIR/$PUBLIC_NAME.crt" .
fi

if [ ! -f "$CERT_DIR/chain.pem" ]
then
  # make combined root and issuer chain.pem
  echo "Concat $CERT_DIR/$ISSUER_NAME.crt and $CERT_DIR/$ROOT_NAME.crt into $CERT_DIR/chain.pem"
  cat "$CERT_DIR/$ISSUER_NAME.crt" "$CERT_DIR/$ROOT_NAME.crt" > "$CERT_DIR/chain.pem"
else
  echo "ENTRYPOINT: chain.pem already exists"
fi

if [ ! -f "$CERT_DIR/fullchain.pem" ]
then
  # make combined root and issuer fullchain.pem
  echo "Concat $CERT_DIR/$PUBLIC_NAME.crt and $CERT_DIR/chain.pem into $CERT_DIR/fullchain.pem"
  cat "$CERT_DIR/$PUBLIC_NAME.crt" "$CERT_DIR/chain.pem" > "$CERT_DIR/fullchain.pem"
else
  echo "ENTRYPOINT: fullchain.pem already exists"
fi

if [ ! -f "$CERT_DIR/dhparam.pem" ] && [ $DHPARAMS == "yes" ]
then
  # generate dhparam.pem
  openssl dhparam -dsaparam -out dhparam.pem 4096

  # copy dhparam to volume
  echo "Copying dhparam.pem to $CERT_DIR"
  cp "dhparam.pem" "$CERT_DIR"
else
  echo "ENTRYPOINT: dhparam.pem already exists"
fi

# run command passed to docker run
exec "$@"
