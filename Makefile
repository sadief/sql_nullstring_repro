#!make

NOW:=$(shell date +"%s")

ifeq ($(BINARY),)
BINARY=$(CMDNAME)
endif

ifeq ($(VERSION),)
export VERSION=$(shell cat VERSION)
export BUILD=$(shell git rev-parse HEAD)
export LDFLAGSBASE=-X main.Version=${VERSION} -X main.Build=${BUILD}
endif

ifeq ($(INCPATH),)
export INCPATH=$(GOPATH)
endif

CONFIG_DIR=./config
DEPLOY_DIR=./deploy

SOURCEDIR=.
SOURCES := $(shell find $(SOURCEDIR) -name "*.go" -not -path "./cmd*" -not -path "./client*" -not -path "./vendor*")
PROTO_DIR=api
PROTO_FILES_IN=$(shell find "$(PROTO_DIR)" -name '*.proto')
MESSAGE_PROTOS=$(shell find "$(PROTO_DIR)" ! -name '*service.proto' -name '*.proto')
SERVICE_PROTOS=$(shell find "$(PROTO_DIR)" -name '*service.proto')
PB_FILES=$(PROTO_FILES_IN:.proto=.pb.go)
GW_FILES=$(SERVICE_PROTOS:.proto=.pb.gw.go)
VL_FILES=$(PROTO_FILES_IN:.proto=.validator.pb.go)
GRPC_DESCRIPTOR=$(PROTO_DIR)/grpc_descriptor.pb
PROTO_FILES_OUT=$(PB_FILES) $(GW_FILES) $(VL_FILES) $(GRPC_DESCRIPTOR)
PROTOC=protoc \
		-I"${INCPATH}/src/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis/" \
		-I"${INCPATH}/src/github.com/grpc-ecosystem/grpc-gateway" \
		-I"${INCPATH}/src/github.com/golang/protobuf" \
		-I"${INCPATH}/src/github.com/googleapis/googleapis" \
		-I"${PROTO_DIR}" \
		-I"${INCPATH}/src/$(REPO)/$(PROTO_DIR)" \
		-I"${INCPATH}/src" \
		-I"./vendor/"

# OUTPUT="$(DEPLOY_DIR)/server"
# DEBUG_OUTPUT="./debug"

LDFLAGS=$(LDFLAGSBASE) -X main.Repo=${REPO}
LDFLAGSWITCH=-ldflags "$(LDFLAGS)"

INT_FILES=internal/files.go

CONTAINER_TAG=gcr.io/$(GOOG_PROJECT)/$(BINARY):$(VERSION)-$(NOW)
CONTAINER_LATEST_TAG=gcr.io/$(GOOG_PROJECT)/$(BINARY):latest

GOOG_CMD=gcloud --project=$(GOOG_PROJECT)

TEST_FILES=$(shell find -name '*_test.go')
RESULTS_DIR=./results

TEST_OUTPUT=$(RESULTS_DIR)/test-output.xml
COV_OUTPUT=$(RESULTS_DIR)/coverage.out
COV_TXT_OUTPUT=$(RESULTS_DIR)/coverage.txt
COV_HTML_OUTPUT=$(RESULTS_DIR)/coverage.html
COB_OUTPUT=$(RESULTS_DIR)/coverage.xml
CHECK_OUTPUT=$(RESULTS_DIR)/checkstyle-result.xml

DB_DIR=./db
MIGRATION_DIR=$(DB_DIR)/migrations
QUERY_FILE=$(DB_DIR)/queries.sql
SQL_DIR=$(DB_DIR)/queries
SQL_FILES=$(shell find $(SQL_DIR) -name '*.sql')


Gopkg.lock: Gopkg.toml
	dep ensure

requirements:
	dep ensure

tooling:
	go get github.com/azer/yolo
	go get github.com/t-yuki/gocover-cobertura
	go get github.com/mikefarah/yaml
	go get github.com/seanhagen/gotic
	go get github.com/jstemmer/go-junit-report
	go get github.com/giantswarm/semver-bump
	go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway
	go get -u github.com/mwitkow/go-proto-validators/protoc-gen-govalidators
	go get -u github.com/golang/protobuf/protoc-gen-go
	go get -u github.com/golang/dep/cmd/dep
	go get gopkg.in/alecthomas/gometalinter.v2
	go get github.com:googleapis/googleapis || true # will fail because no go files
	gometalinter.v2 --install

$(QUERY_FILE): $(SQL_FILES)
	cat $^ > $@

db-status-local:
	goose -dir db/migrations postgres $(LOCAL_DB) status

migrate-up-local:
	goose -dir db/migrations postgres $(LOCAL_DB) up

migrate-down-local:
	goose -dir db/migrations postgres $(LOCAL_DB) down

db-status-production:
	goose -dir db/migrations postgres "$(DB_URL)" status

migrate-up-production:
	goose -dir db/migrations postgres "$(DB_URL)" up

migrate-down-production:
	goose -dir db/migrations postgres "$(DB_URL)" down

$(MIGRATION_DIR):
	mkdir -p $(MIGRATION_DIR)

create-migration: $(MIGRATION_DIR)
	goose -dir db/migrations create $(filter-out $@,$(MAKECMDGOALS)) sql


$(INT_FILES): $(DEPLOY_DIR)/ca-certificates.crt $(TEMPLATES) $(QUERY_FILE)
	gotic -package internal $^ > $@

$(PROTO_FILES_IN): VERSION
	@echo "Updating protobuf auto-generated code from defintions: $(PROTO_FILES_IN)"
	@find "$(PROTO_DIR)" -type f -name '*.proto' | xargs sed -i 's/version:.*/version: "v${VERSION}";/'

$(GRPC_DESCRIPTOR): $(PROTO_FILES_IN)
	$(PROTOC) \
		--include_imports \
		--include_source_info \
		--descriptor_set_out=$(PROTO_DIR)/grpc_descriptor.pb \
    $(PROTO_FILES_IN)

$(PB_FILES): $(PROTO_FILES_IN)
	$(PROTOC) \
		--go_out=plugins=grpc:"$(PROTO_DIR)" \
    $(PROTO_FILES_IN)

$(GW_FILES): $(PROTO_FILES_IN)
	$(PROTOC) \
	 	--grpc-gateway_out=logtostderr=true:"$(PROTO_DIR)" \
    $(PROTO_FILES_IN)

$(VL_FILES): $(PROTO_FILES_IN)
	$(PROTOC) \
		--govalidators_out=gogoimport=true:"$(PROTO_DIR)" \
    $(PROTO_FILES_IN)

protobuf: $(PROTO_FILES_OUT)
	go install ./api

clean-protobuf:
	if [ -f $(GRPC_DESCRIPTOR) ] ; then rm $(GRPC_DESCRIPTOR) ; fi
	if [ -f $(PB_FILES) ] ; then rm $(PB_FILES) ; fi
	if [ -f $(GW_FILES) ] ; then rm $(GW_FILES) ; fi
	if [ -f $(VL_FILES) ] ; then rm $(VL_FILES) ; fi

install:
	go install -v `go list ./... | grep -v vendor`


$(DEBUG_OUTPUT): Gopkg.lock generate $(INT_FILES) $(SOURCES)
	go build -a ${LDFLAGSWITCH} -o ${DEBUG_OUTPUT} -gcflags="-N -l" -installsuffix cgo -race .

$(RESULTS_DIR):
	mkdir -p $(RESULTS_DIR)

$(CHECK_OUTPUT): $(INT_FILES) $(RESULTS_DIR)
	gometalinter.v2 -j 2 --deadline=60s --checkstyle \
		--enable=nakedret --enable=unparam --enable=megacheck \
		--skip=api --skip=client --vendor ./... > $(CHECK_OUTPUT) || true

vet: $(CHECK_OUTPUT)

$(TEST_OUTPUT) $(COV_OUTPUT): $(INT_FILES) $(RESULTS_DIR)
	go test -v -coverprofile=$(COV_OUTPUT) -covermode count \
		`go list ./... | grep -v vendor | grep -v api` \
		2>&1 | go-junit-report > $(TEST_OUTPUT)

junit-test: $(TEST_OUTPUT)

$(COV_HTML_OUTPUT): $(COV_OUTPUT)
	go tool cover -html=$(COV_OUTPUT) -o $(COV_HTML_OUTPUT)

$(COB_OUTPUT): $(COV_OUTPUT)
	gocover-cobertura < $(COV_OUTPUT) > $(COB_OUTPUT)

coverage: $(COV_HTML_OUTPUT) $(COB_OUTPUT)

test: $(INT_FILES)
	go test -v ./...

citest: tooling requirements clean junit-test vet coverage

generate: $(INT_FILES)
	go generate ./...

build: $(OUTPUT)

debug: $(DEBUG_OUTPUT)

patch-bump:
	semver-bump patch-release

minor-bump:
	semver-bump minor-release

endpoint: $(PROTO_FILES_OUT)
	$(GOOG_CMD) endpoints services deploy $(GRPC_DESCRIPTOR) grpc-api.yml

gcloud-creds:
	$(GOOG_CMD) container clusters get-credentials $(GOOG_CONTAINERS) -z $(GOOG_ZONE) || true

kube-creds:
	kubectl create clusterrolebinding myname-cluster-admin-binding --clusterrole=cluster-admin --user=$(EMAIL) || true

deploy-update-auth:
	$(GOOG_CMD) container clusters update $(GOOG_CONTAINERS) --no-enable-legacy-authorization -z $(GOOG_ZONE) || true

auth: gcloud-creds kube-creds deploy-update-auth

$(UNSAFE_KEY):
	openssl genrsa -out $(UNSAFE_KEY) 2048

$(UNSAFE_CRT): $(UNSAFE_KEY)
	openssl req -new -x509 -key $(UNSAFE_KEY) \
		-out $(UNSAFE_CRT) -days 3650 \
		-subj "/C=CA/ST=BC/L==Vancouver/O=Biba/OU=Biba/CN=:10000"

regen-certs:
	certbot -d $(DOMAIN) --manual --preferred-challenges dns certonly \
		--config-dir ./config/config --work-dir ./config/work --logs-dir ./config/logs
	cp ./config/config/live/$(DOMAIN)/privkey.pem ./config/privkey.pem
	openssl rsa -inform pem -in ./config/privkey.pem -outform pem > ./config/nginx.key
	cp ./config/config/live/$(DOMAIN)/fullchaim.pem ./config/nginx.crt

secrets: auth
	./config/update-secrets.sh

container: deploy.yaml

deploy.yaml: clean build $(CONFIG_DIR)/deployment.yaml VERSION $(NOW)
	$(GOOG_CMD) builds submit --tag $(CONTAINER_TAG) $(DEPLOY_DIR)
	$(GOOG_CMD) container images add-tag $(CONTAINER_TAG) $(CONTAINER_LATEST_TAG) --quiet
	sed -e "s|image: gcr.io/biba-backbot/$(SERVICE):latest|image: $(CONTAINER_TAG)|" < $(CONFIG_DIR)/deployment.yaml > $@

test-deploy:
	kubectl delete -f $(CONFIG_DIR)/deployment.yaml
	kubectl apply -f $(CONFIG_DIR)/deployment.yaml

deploy: protobuf deploy.yaml endpoint secrets
	kubectl apply -f ./deploy.yaml

run: $(OUTPUT)
	docker-compose build $(SERVICE)
	docker-compose up

user:
	docker-compose pull users
	docker-compose up -d --no-deps --build users

rebuild: $(OUTPUT)
	docker-compose up -d --no-deps --build $(SERVICE)

stop:
	docker-compose stop

clean:
	if [ -f ${OUTPUT} ] ; then rm ${OUTPUT} ; fi
	if [ -d results ] ; then rm -rf results ; fi
	if [ -f $(QUERY_FILE) ]; then rm $(QUERY_FILE); fi
	if [ -f $(INT_FILES) ] ; then rm $(INT_FILES) ; fi
	if [ -f deploy.yaml ]; then rm deploy.yaml; fi

cideploy: clean deploy
	$(eval rev:=$(shell git rev-parse --verify HEAD))
	honeybadger deploy -k $(HONEYBADGER_API_KEY) -e production -r $(REPO) -s $(rev)
	curl https://api.honeycomb.io/1/markers/biba-services \
		-H "X-Honeycomb-Team: $(HONEYCOMB_API_KEY)" \
		-d '{"message":"jenkins deploy ${JOB_NAME} - ${BUILD_ID} - $(rev)", "type":"deploy","start_time":$(NOW),"url":"$(BUILD_URL)"}'

.DEFAULT_GOAL: build-clean
.PHONY: clean generate test vet deps build build-container build-clean run deploy grpc protobuf cideploy $(NOW)