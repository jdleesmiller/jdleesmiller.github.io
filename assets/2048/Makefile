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
figures: 2x2_successors_example.svg \
	2x2_intro.svg 2x2_intro_1.svg 2x2_intro_2.svg \
	2x2_s1_0_0_1.svg 2x2_s1_1_1_0.svg 2x2_s2_1_1_0.svg \
	2x2_s2_3_1_0.svg 2x2_s3_2_0_1.svg 2x2_s1_0_2_3.svg 2x2_s2_1_3_0.svg \
	2x2_s0_3_1_2.svg 2x2_s1_2_0_3.svg 2x2_s0_1_3_2.svg 2x2_s3_0_2_1.svg \
	2x2_s0_0_1_1.svg 2x2_s0_1_2_0.svg 2x2_s0_0_1_2.svg 2x2_s0_1_1_1.svg \
	2x2_s0_1_2_1.svg 2x2_s0_2_2_0.svg 2x2_s0_0_2_2.svg \
	4x4_s0_2_2_11_0_1_3_0_2_0_1_0_0_0_0_0.svg \
	4x4_s2_3_4_5_4_5_4_5_5_4_5_4_4_5_4_5.svg \
	enumeration_2x2_grouped.svg enumeration_2x2_ungrouped.svg \
	markov_chain_initial_state.svg \
	markov_chain_0.svg markov_chain_1.svg markov_chain_2.svg markov_chain_3.svg \
	markov_chain_end.svg \
	markov_chain_big.svgz markov_chain_big_thumbnail.png
