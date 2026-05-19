.PHONY: all clean

all: main.pdf

main.pdf: main.tex
	latexmk -pdf main.tex

clean:
	latexmk -C
	rm -f *.bbl *.run.xml
