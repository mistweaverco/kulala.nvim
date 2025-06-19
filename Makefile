test = nvim -l tests/minit.lua tests --shuffle-tests -o utfTerminal -Xoutput --color -v
build_ts = scripts/build_ts.sh

tag ?= wip
watch = '*.lua'
# watch = '*.lua' -o -name "*.js" -o -name "*.http" -name "*.txt"
git_ls = git ls-files -cdmo --exclude-standard

version:
	./scripts/set-version.sh $(VERSION)
tag:
	./scripts/tag.sh
release:
	./scripts/tag.sh
docker-build:
	if [ "$(OS)" != "linux" ] && [ "$(OS)" != "windows" ]; then (echo "OS must be either linux or windows"; exit 1); fi
	docker build -t push.docker.build/mwco/kulala-nvim-$(OS)-testrunner:latest tests/_dockerfiles/$(OS)
docker-push:
	if [ "$(OS)" != "linux" ] && [ "$(OS)" != "windows" ]; then (echo "OS must be either linux or windows"; exit 1); fi
	docker push push.docker.build/mwco/kulala-nvim-$(OS)-testrunner:latest

vimdocs:
	./scripts/vimdocs.sh

test:
	$(test)

watch:
	@while sleep 0.1; do find . -name $(watch) | entr -d -c $(test); done

watch_tag:
	@while sleep 0.1; do $(git_ls) | entr -d -c $(test) --tags=$(tag); done

watch_ts:
	@while sleep 0.1; do find . -name '*.ts' | entr -d -c $(build_ts); done
