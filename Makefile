rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

all: lint doc
exec:
	@echo "Executing application"
	@./node_modules/coffee-script/bin/coffee src/main.coffee
doc: clean
	@echo "Generating Docco documentation"
	@./node_modules/docco/bin/docco $(call rwildcard,src/,*.coffee) -o doc \
	                                -l linear
lint:
	@echo "Running coffeelint over source files"
	@./node_modules/coffeelint/bin/coffeelint -f linter-config.json \
	                                          $(call rwildcard,src/,*.coffee)
clean:
	@echo "Cleaning up results of previous compilations"
	@rm -rf doc