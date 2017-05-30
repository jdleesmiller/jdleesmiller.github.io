%.png: %.dot
	dot -Tpng <$^ >$@

%.svg: %.dot
	dot -Tsvg <$^ >$@

figures: 2x2_intro_1.svg 2x2_intro_2.svg 2x2_s1_1_1_0.svg

default: figures
