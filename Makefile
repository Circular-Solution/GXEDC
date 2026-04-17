.PHONY: build deploy-local

export DOCKER_HOST := unix://$(HOME)/.colima/default/docker.sock

build:
	./gradlew -Ppersistence=true dockerize
	docker build -t gx-basic-functions:latest ../resources/gx-basic-functions

deploy:
	kind create cluster -n cs --config ./deployment/shared/kind.config.yaml
	kind load docker-image controlplane:latest dataplane:latest identity-hub:latest catalog-server:latest issuerservice:latest gx-basic-functions:latest -n cs
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
	cd ./deployment/local && terraform init && terraform apply

# i could terraform destroy but this is just faster
destroy:
	kind delete cluster -n cs
