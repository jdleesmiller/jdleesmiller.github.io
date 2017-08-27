%.png: %.dot
	dot -Tpng <$^ >$@

%.svg: %.dot
	dot -Tsvg <$^ >$@

%.svgz: %.svg
	cat $^ | gzip -c9 >$@

all: figures

markov_chain_big_thumbnail.png: markov_chain_big.svg
	convert -density 2 $^ $@

.PHONY: figures
figures: 2x2_successors_example.svg 2x2_intro.svg 2x2_intro_1.svg 2x2_intro_2.svg 2x2_s1_0_0_1.svg 2x2_s1_1_1_0.svg 2x2_s2_1_1_0.svg markov_chain_0.svg markov_chain_1.svg markov_chain_2.svg markov_chain_3.svg markov_chain_loop.svg markov_chain_end.svg markov_chain_big.svgz markov_chain_big_thumbnail.png
