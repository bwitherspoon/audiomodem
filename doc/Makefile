GRAPHS := $(patsubst %.dot,%.svg,$(wildcard *.dot))
ASSETS := $(GRAPHS) index.html
REMOTE := cbwithersp42@files.cae.tntech.edu:~/public_html/audiomodem

all: $(ASSETS)

install: $(ASSETS)
	rsync -z $^ $(REMOTE)
clean:
	-$(RM) $(ASSETS)

index.html : ../README.md
	pandoc -s -f markdown -t html5 -o $@ $<

%.svg : %.dot
	dot -Tsvg -o $@ $<

%.html : %.md
	pandoc -s -f markdown -t html5 -o $@ $<

.PHONY: install clean

