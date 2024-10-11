version:
	./scripts/set-version.sh $(VERSION)
tag:
	./scripts/tag.sh
release:
	./scripts/tag.sh
docker-build:
	if [ "$(OS)" != "linux" ] || [ "$(OS)" != "windows" ]; then (echo "OS must be either linux or windows"; exit 1); fi
	docker build -t ghcr.io/mistweaverco/kulala-nvim-$(OS)-testrunner:latest tests/_dockerfiles/$(OS)
docker-push:
	if [ "$(OS)" != "linux" ] || [ "$(OS)" != "windows" ]; then (echo "OS must be either linux or windows"; exit 1); fi
	docker push ghcr.io/mistweaverco/kulala-nvim-$(OS)-testrunner:latest

