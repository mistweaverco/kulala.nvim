test = nvim -l tests/minit.lua tests

tag ?= wip
watch = '*.lua' -o -name "*.js" -o -name "*.http" -name "*.txt"

version:
	./scripts/set-version.sh $(VERSION)
tag:
	./scripts/tag.sh
release:
	./scripts/tag.sh
docker-build:
	if [ "$(OS)" != "linux" ] && [ "$(OS)" != "windows" ]; then (echo "OS must be either linux or windows"; exit 1); fi
	docker build -t gorillamoe/kulala-nvim-$(OS)-testrunner:latest tests/_dockerfiles/$(OS)
docker-push:
	if [ "$(OS)" != "linux" ] && [ "$(OS)" != "windows" ]; then (echo "OS must be either linux or windows"; exit 1); fi
	docker push gorillamoe/kulala-nvim-$(OS)-testrunner:latest

watch:
	@while sleep 0.1; do find . -name $(watch) | entr -d -c $(test); done

watch_tag:
	@while sleep 0.1; do find . -name $(watch) | entr -d -c $(test) --tags=$(tag); done
