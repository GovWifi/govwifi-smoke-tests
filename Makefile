DOCKER_COMPOSE=docker compose -f docker-compose.yml
BUNDLE_FLAGS=
CERTIFICATE_PATH=smoke_test_certificates

ROOT=smoke_test_root_ca
INTERMEDIATE=smoke_test_intermediate_ca
CLIENT=smoke_test_client
VALID_FOR=9000

TEST_ENV_VARS = \
    -e DOCKER=docker \
    -e GW_SUPER_ADMIN_USER \
    -e GW_SUPER_ADMIN_PASS \
    -e GW_SUPER_ADMIN_2FA_SECRET \
    -e GW_USER \
    -e GW_PASS \
    -e GW_2FA_SECRET \
    -e GOOGLE_API_CREDENTIALS \
    -e GOOGLE_API_TOKEN_DATA \
    -e RADIUS_KEY \
    -e RADIUS_IPS \
    -e SUBDOMAIN \
    -e NOTIFY_SMOKETEST_API_KEY \
    -e NOTIFY_GO_TEMPLATE_ID \
    -e NOTIFY_BASE_URL \
    -e GOVWIFI_PHONE_NUMBER \
    -e SMOKETEST_PHONE_NUMBER \
    -e NOTIFY_FIELD \
    -e EAP_TLS_CLIENT_CERT \
    -e EAP_TLS_CLIENT_KEY \
    -e ENVIRONMENT

build:
	$(DOCKER_COMPOSE) build

lint: build
	$(DOCKER_COMPOSE) run --rm app bundle exec rubocop

test: build
	$(DOCKER_COMPOSE)  run --rm $(TEST_ENV_VARS) app bundle exec rspec spec/system

test-lib: build
	$(DOCKER_COMPOSE)  run --rm $(TEST_ENV_VARS) app bundle exec rspec spec/lib

stop:
	$(DOCKER_COMPOSE) down -v

shell: build
	$(DOCKER_COMPOSE) run --rm $(TEST_ENV_VARS) app bundle exec sh

certs:
	mkdir -p $(CERTIFICATE_PATH)
	openssl req -x509 -newkey rsa:4096 -keyout $(CERTIFICATE_PATH)/$(ROOT).key -out $(CERTIFICATE_PATH)/$(ROOT).pem -sha256 -days $(VALID_FOR) -nodes -subj '/CN=Smoke Test Root CA'

	openssl req -newkey 4096 -keyout $(CERTIFICATE_PATH)/$(INTERMEDIATE).key -outform pem -keyform pem -out $(CERTIFICATE_PATH)/$(INTERMEDIATE).req -nodes -subj '/CN=Smoke Test Intermediate CA'
	openssl x509 -req -CA $(CERTIFICATE_PATH)/$(ROOT).pem -CAkey $(CERTIFICATE_PATH)/$(ROOT).key -in $(CERTIFICATE_PATH)/$(INTERMEDIATE).req -out $(CERTIFICATE_PATH)/$(INTERMEDIATE).pem -extensions v3_ca -days $(VALID_FOR) -CAcreateserial -extfile openssl.conf -CAserial $(CERTIFICATE_PATH)/intermediate.srl

	openssl req -newkey 4096 -keyout $(CERTIFICATE_PATH)/$(CLIENT).key -outform pem -keyform pem -out $(CERTIFICATE_PATH)/$(CLIENT).req -nodes -subj '/CN=Client'
	openssl x509 -req -CA $(CERTIFICATE_PATH)/$(INTERMEDIATE).pem -CAkey $(CERTIFICATE_PATH)/$(INTERMEDIATE).key -in $(CERTIFICATE_PATH)/$(CLIENT).req -out $(CERTIFICATE_PATH)/$(CLIENT).pem -extensions v3_client -days $(VALID_FOR) -CAcreateserial -extfile openssl.conf -CAserial $(CERTIFICATE_PATH)/client.srl
	rm -f $(CERTIFICATE_PATH)/*.req

.PHONY: build stop test shell
