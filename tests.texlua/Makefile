.PHONY: texlua luatex clean install

install:
	-@mkdir ~/.texmf/scripts/memoize
	cp ./memoize-extract.lua ~/.texmf/scripts/memoize

clean:
	-$(RM) -r mmz *.aux *.log main.pdf

texlua:
	texlua memoize-extract.lua

luatex:
	TEXMFCNF=".:" lualatex main.tex
