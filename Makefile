rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

all: lint build doc

exec:
	@echo "Executing application"
	@./node_modules/coffee-script/bin/coffee src/main.coffee

build: clean
	@echo "Compiling application"
	@./node_modules/coffee-script/bin/coffee -o bin -c src

doc: clean
	@echo "Generating Docco documentation"
	@./node_modules/docco/bin/docco $(call rwildcard,src/,*.coffee) -o doc \
	                                -l parallel
lint:
	@echo "Running coffeelint over source files"
	@./node_modules/coffeelint/bin/coffeelint -f linter-config.json \
	                                          $(call rwildcard,src/,*.coffee)
clean:
	@echo "Cleaning up results of previous compilations"
	@rm -rf doc bin
