%.png: %.dot
	dot -Tpng <$^ >$@

%.svg: %.dot
	dot -Tsvg <$^ >$@

%.svgz: %.svg
	cat $^ | gzip -c9 >$@

all: figures mdp_policies

markov_chain_big_thumbnail.png: markov_chain_big.svg
	convert -density 2 $^ $@

.PHONY: figures mdp_policies

figures: 2x2_successors_example.svg \
	2x2_intro.svg 2x2_intro_1.svg 2x2_intro_2.svg \
	2x2_s1_0_0_1.svg 2x2_s0_1_1_0.svg 2x2_s1_1_1_0.svg 2x2_s2_1_1_0.svg \
	2x2_s2_3_1_0.svg 2x2_s3_2_0_1.svg 2x2_s1_0_2_3.svg 2x2_s2_1_3_0.svg \
	2x2_s0_3_1_2.svg 2x2_s1_2_0_3.svg 2x2_s0_1_3_2.svg 2x2_s3_0_2_1.svg \
	2x2_s0_0_1_1.svg 2x2_s0_1_2_0.svg 2x2_s0_0_1_2.svg 2x2_s0_1_1_1.svg \
	2x2_s0_1_2_1.svg 2x2_s0_2_2_0.svg 2x2_s0_0_2_2.svg 2x2_s2_1_0_1.svg \
	2x2_s2_2_1_0.svg 2x2_s1_2_1_0.svg 2x2_s0_1_2_2.svg 2x2_s2_1_1_2.svg \
	2x2_s2_2_3_4.svg \
	4x4_s0_2_2_11_0_1_3_0_2_0_1_0_0_0_0_0.svg \
	4x4_s2_3_4_5_4_5_4_5_5_4_5_4_4_5_4_5.svg \
	enumeration_2x2_grouped.svg enumeration_2x2_ungrouped.svg \
	markov_chain_initial_state.svg \
	markov_chain_0.svg markov_chain_1.svg markov_chain_2.svg markov_chain_3.svg \
	markov_chain_end.svg \
	markov_chain_big.svgz markov_chain_big_thumbnail.png \
	mdp_s0_1_1_0_with_no_canonicalization.svg \
	mdp_s2_1_0_1_with_no_canonicalization.svg \
	mdp_s2_2_1_0_with_no_canonicalization.svg \
	mdp_s0_1_1_0_with_state_canonicalization.svg \
	mdp_s0_1_1_0_with_action_canonicalization.svg \
	mdp_s0_0_1_1_with_action_canonicalization.svg \
	mdp_s0_1_1_0_move_states.svg \
	mdp_2x2_3.svg mdp_2x2_4.svg mdp_2x2_5.svg \
	mdp_2x2_3_with_no_canonicalization.svg \
	mdp_2x2_3_optimal.svg mdp_2x2_4_optimal.svg mdp_2x2_5_optimal.svg

mdp_policies: \
	game-board_size-2.max_exponent-3/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-0.alternate_actions-false.values-true.dat \
	game-board_size-2.max_exponent-4/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-0.alternate_actions-false.values-true.dat \
	game-board_size-2.max_exponent-5/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-0.alternate_actions-false.values-true.dat \
	game-board_size-3.max_exponent-9/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-1e-07.alternate_actions-false.values-true.dat \
	game-board_size-3.max_exponent-a/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-1e-07.alternate_actions-false.values-true.dat \
	game-board_size-4.max_exponent-6/layer_model-max_depth-0/packed_policy-discount-0.99.method-v.alternate_action_tolerance-1e-09.threshold-1e-07.alternate_actions-false.values-false.dat

game-board_size-2.max_exponent-3/layer_model-max_depth-0/%.dat : ../../../twenty48/data/game-board_size-2.max_exponent-3/layer_model-max_depth-0/%.dat
	mkdir -p $(dir $@)
	cp $< $@

game-board_size-2.max_exponent-4/layer_model-max_depth-0/%.dat : ../../../twenty48/data/game-board_size-2.max_exponent-4/layer_model-max_depth-0/%.dat
	mkdir -p $(dir $@)
	cp $< $@

game-board_size-2.max_exponent-5/layer_model-max_depth-0/%.dat : ../../../twenty48/data/game-board_size-2.max_exponent-5/layer_model-max_depth-0/%.dat
	mkdir -p $(dir $@)
	cp $< $@

game-board_size-3.max_exponent-9/layer_model-max_depth-0/%.dat : ../../../twenty48/data/game-board_size-3.max_exponent-9/layer_model-max_depth-0/%.dat
	mkdir -p $(dir $@)
	cp $< $@

game-board_size-3.max_exponent-a/layer_model-max_depth-0/%.dat : ../../../twenty48/data/game-board_size-3.max_exponent-a/layer_model-max_depth-0/%.dat
	mkdir -p $(dir $@)
	cp $< $@

game-board_size-4.max_exponent-6/layer_model-max_depth-0/%.dat : ../../../twenty48/data/game-board_size-4.max_exponent-6/layer_model-max_depth-0/%.dat
	mkdir -p $(dir $@)
	cp $< $@
