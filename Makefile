rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

exec:
	./node_modules/coffee-script/bin/coffee src/main.coffee
doc: clean
	./node_modules/docco/bin/docco $(call rwildcard,src/,*) -o doc -l linear
clean:
	rm -r doc
