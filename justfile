build:
	./gradlew -Ppersistence=true dockerize

deploy:
	cd ./deployment && terraform init && terraform apply --auto-approve

deploy-kind:
	kind create cluster -n cs --config ./deployment/kind.config.yaml
	kind load docker-image controlplane:latest dataplane:latest identity-hub:latest catalog-server:latest issuerservice:latest -n cs
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=200s
	cd ./deployment && terraform init && terraform apply --auto-approve

destroy:
	terraform -chdir=deployment destroy

destroy-kind:
	kind delete cluster -n cs

seed jwt:
	GX_JWT="{{jwt}}" ./seed.sh

up:
	docker compose up -d

down arg:
	docker compose down {{ arg }}
