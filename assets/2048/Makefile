%.png: %.dot
	dot -Tpng <$^ >$@

%.svg: %.dot
	dot -Tsvg <$^ >$@

figures: 2x2_intro.svg 2x2_intro_annotated.svg

default: figures
