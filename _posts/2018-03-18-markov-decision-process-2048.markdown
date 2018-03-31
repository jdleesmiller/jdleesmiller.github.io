---
layout: post
title: "The Mathematics of 2048: Optimal Play with Markov Decision Processes"
date: 2018-03-18 23:00:00 +0000
categories: articles
image: /assets/2048/mdp_2x2_3_with_no_canonicalization.png
description: Finding provably optimal strategies for 2048 using Markov Decision Processes
---

&nbsp;

<img src="/assets/2048/mdp_player.png" alt="Screenshot of a provably optimal endgame on the 4x4 board to the 64 tile" style="width: 40%; float: right; margin-left: 10pt; border: 6pt solid #eee;"/>

So far in this series on the mathematics of [2048](http://gabrielecirulli.github.io/2048), we've used Markov chains to learn that [it takes at least 938.8 moves](/articles/2017/08/05/markov-chain-2048.html) on average to win, and we've explored the number of possible board configurations in the game using [combinatorics](/articles/2017/09/17/counting-states-combinatorics-2048.html) and then [exhaustive enumeration](/articles/2017/12/10/counting-states-enumeration-2048.html).

In this post, we'll use Markov Decision Processes to find provably optimal strategies for 2048 when played on the 2x2 and 3x3 boards, which shed some light on successful strategies for the 4x4 board. The full game on the 4x4 board to the `2048` tile will prove intractably large for the methods used here, but we will be able to find a provably optimal strategy for a shorter version of the game played on the 4x4 board up to the `64` tile.

The (research quality) code behind this article is [open source](https://github.com/jdleesmiller/twenty48).

&nbsp;

## Markov Decision Processes for 2048

Markov Decision Processes ([MDPs](https://en.wikipedia.org/wiki/Markov_decision_process)) are a mathematical framework for modeling and solving problems in which we need to make a sequence of related decisions in the presence of uncertainty. Such problems are all around us, and MDPs find many [applications](http://stats.stackexchange.com/questions/145122/real-life-examples-of-markov-decision-processes) in [economics](https://en.wikipedia.org/wiki/Decision_theory#Choice_under_uncertainty), [finance](https://www.minet.uni-jena.de/Marie-Curie-ITN/SMIF/talks/Baeuerle.pdf), and [artificial intelligence](http://incompleteideas.net/book/the-book.html). For 2048, the sequence of decisions is the direction to swipe in each turn, and the uncertainty arises because the game adds new tiles to the board at random.

To set up the game of 2048 as an MDP, we will need to write it down in a specific way. This will involve six main concepts: *states*, *actions* and *transition probabilities* will encode the game's dynamics; *rewards*, *values* and *policies* will be used to capture what the player is trying to accomplish and how they should do so. To develop these six concepts, we will take as an example the smallest non-trivial 2048-like game, which is played on the 2x2 board only up to the `8` tile. Let's start with the first three.

### States, Actions and Transition Probabilities

A *state* captures the configuration of the board at a given point in the game by specifying the value of the tile, if any, in each of the board's cells. For example, <img src="/assets/2048/2x2_s0_1_1_0.svg" style="height: 2em;"> is a possible state in a game on a 2x2 board. An *action* is swiping left, right, up or down. Each time the player takes an action, the process transitions to a new state.

The *transition probabilities* encode the game's dynamics by determining which states are likely to come next, in view of the current state and the player's action. Fortunately, we can find out exactly how 2048 works by reading [its source code](https://github.com/gabrielecirulli/2048). Most important [^merging] is the process the game uses to place a random tile on the board, which is always the same: *pick an available cell uniformly at random, then add a new tile either with value `2`, with probability 0.9, or value `4`, with probability 0.1*.

At the start of each game, two random tiles are added using this process. For example, one of these possible start states is <img src="/assets/2048/2x2_s0_1_1_0.svg" style="height: 2em;" alt="- 2 2 -; two 2 tiles on the anti-diagonal">. For each of the possible actions in this state, namely `L`eft, `R`right, `U`p and `D`own, the possible next states and the corresponding transition probabilities are:

<p align="center">
<img src="/assets/2048/mdp_s0_1_1_0_with_no_canonicalization.svg" alt="Actions and transitions from the state - 2 2 -" style="max-height: 40em;" />
</p>

In this diagram, there is an arrow for each possible transition to a successor state, on the right hand side. The weight of the arrow and the label indicate the corresponding transition probability. For example, if the player swipes right (`R`), both `2` tiles go to the right edge, leaving two available cells on the left. The new tile will be a `4` with probability 0.1, and it can either go into the top left or the bottom left cell, so the probability of the state <img src="/assets/2048/2x2_s2_1_0_1.svg" style="height: 2em;" alt="4 2 - 2"> is \\(0.1 \\times 0.5 = 0.05\\).

From each of those successor states, we can continue this process of enumerating their allowed actions and successor states, recursively. For <img src="/assets/2048/2x2_s2_1_0_1.svg" style="height: 2em;" alt="4 2 - 2">, the possible successors are:

<p align="center">
<img src="/assets/2048/mdp_s2_1_0_1_with_no_canonicalization.svg" alt="Actions and transitions from the state 4 2 - 2" style="max-height: 40em;" />
</p>

Here swiping right is not allowed, because none of the tiles can move right. Moreover, if the player reaches the successor state <img src="/assets/2048/2x2_s2_1_1_2.svg" style="height: 2em;" alt="4 2 2 4">, highlighted in red, they have lost, because there are no allowed actions from that state. This would happen if the player were to swipe left, and the game were to place a `4` tile, which it would do with probability 0.1; this suggests that swiping left may not be the best action in this state.

For one final example, if the player moves up instead of left, one of the possible successor states is <img src="/assets/2048/2x2_s2_2_1_0.svg" style="height: 2em;" alt="4 4 2 -">, and if we enumerate the allowed actions and and successor states from that state, we can see that swiping left or right will then result in an `8` tile, which means the game is won (highlighted in green):

<p align="center">
<img src="/assets/2048/mdp_s2_2_1_0_with_no_canonicalization.svg" alt="Actions and transitions from the state 4 4 2 -" style="max-height: 40em;" />
</p>

If we repeat this process for all of the possible start states, and all of their possible successor states, and so on recursively until win or lose states are reached, we can build up a full model with all of the possible states, actions and their transition probabilities. For the 2x2 game to the `8` tile, that model looks like this (<a href="/assets/2048/mdp_2x2_3_with_no_canonicalization.svg">click to enlarge</a>; you may then need to scroll down):

<p align="center">
<a href="/assets/2048/mdp_2x2_3_with_no_canonicalization.svg"><img src="/assets/2048/mdp_2x2_3_with_no_canonicalization.svg" alt="Full MDP model for the 2x2 game to the 8 tile without canonicalization techniques from Appendix A" id="mdp_2x2_3_with_no_canonicalization" /></a>
</p>

To make the diagram smaller, all of the losing states have been collapsed into a single `lose` state, shown as a red oval, and all of the winning states have been similarly collapsed into a single `win` state, shown as a green star. This is because we don't particularly care how the player won or lost, only that they did.

Play proceeds roughly from left to right in the diagram, because the states have been organized into 'layers' by the sum of their tiles. A useful property of the game is that after each action the sum of the tiles on the board increases by either 2 or 4. This is because merging tiles does not change the sum of the tiles on the board, and the game always adds either a `2` tile or a `4` tile. The possible start states, which are in the layers with sum 4, 6 and 8, are drawn in blue.

Even for this smallest example, there are 70 possible states and 530 possible transitions in the model. It is possible significantly reduce those numbers, however, by observing that many of the states we've enumerated above are trivially related by rotations and reflections, as described in [Appendix A](#appendix-a-canonicalization). This observation is important in practice for reducing the size of the models so that they can be solved efficiently, and it makes for more legible diagrams, but it is not essential for us to move on to our second set of MDP concepts.

### Rewards, Values and Policies

To complete our specification of the model, we need to somehow encode the fact that the player's objective is to reach the `win` state [^objectives]. We do this by defining *rewards*. In general, each time an MDP enters a state, the player receives a reward that depends on the state. Here we'll set the reward for entering the `win` state to 1, and the reward for entering all other states to 0. That is, the one and only way to earn a reward is to reach the win state. [^absorbing]

Now that we have an MDP model of the game in terms of states, actions, transition probabilities and rewards, we are ready to solve it. A solution for an MDP is called a *policy*. It is basically a table that lists for every possible state which action to take in that state. To solve an MDP is to find an *optimal policy*, which is one that allows the player to collect as much reward as possible over time.

To make this precise, we will need our final MDP concept: the *value* of a state according to a given policy is the expected, discounted reward the player will collect if they start from that state and follow the policy thereafter. To explain what that means will require some notation.

Let \\(S\\) be the set of states, and for each state \\(s \\in S\\), let \\(A_s\\) be the set of actions that are allowed in state \\(s\\). Let \\(\\Pr(s' \| s, a)\\) denote the probability of transitioning to each successor state \\(s' \\in S\\), given that the process is in state \\(s \\in S\\) and the player takes action \\(a \\in A_s\\). Let \\(R(s)\\) denote the reward for entering state \\(s\\). Finally, let \\(\\pi\\) denote a policy and \\(\\pi(s) \\in A_s\\) denote the action to take in state \\(s\\) when following policy \\(\\pi\\).

For a given policy \\(\\pi\\) and state \\(s\\), the value of state \\(s\\) according to \\(\\pi\\) is
\\[
V^\\pi(s) = R(s) + \\gamma \\sum_{s'} \\Pr(s' \| s, \\pi(s)) V^\\pi(s')
\\]
where the first term is the immediate reward, and the summation gives the expected value of the successor states, assuming the player continues to follow the policy.

The factor \\(\\gamma\\) is a *discount factor* that trades off the value of the immediate reward against the value of the expected future rewards. In other words, it accounts for [the time value of money](https://en.wikipedia.org/wiki/Time_value_of_money): a reward now is typically worth more than the same reward later. If \\(\\gamma\\) is close to 1, it means that the player is very patient: they don't mind waiting for future rewards; likewise, smaller values of \\(\\gamma\\) mean that the player is less patient. For now, we'll set the discount factor \\(\\gamma\\) to 1, which matches our assumption that the player cares only about winning, not about how long it takes to win [^discounting].

So, how do we find the policy? For each state, we want to choose the action that maximizes the expected future value:

\\[
\\pi(s) = \\mathop{\\mathrm{argmax}}\\limits_{a \\in A_s} \\left\\{
  \\sum_{s'} \\Pr(s' \| s, a) V^\\pi(s')
  \\right\\}
\\]

So, this gives us two linked equations, and we can solve them iteratively. That is, pick an initial policy, which might be very simple, compute the value of every state under that simple policy, and then find a new policy based on that value function, and so on. Perhaps remarkably, under very modest technical conditions, such an iterative process is guaranteed to converge to an optimal policy, \\(\\pi^\*\\), and an optimal value function \\(V^{\\pi^\*}\\) with respect to that optimal policy.

This standard iterative approach works well for the MDP models for games on the 2x2 board, but it breaks down for the 3x3 and 4x4 game models, which have many more states and therefore take much more memory and compute power. Fortunately, it turns out that we can exploit the particular structure of our 2048 models to solve these equations much more efficiently, as described in [Appendix B](#appendix-b-solution-methods).

## Optimal Play on the 2x2 Board

We're now ready to see some optimal policies in action! If you leave the random seed at `42` and press the `Start` button below, you'll see it reach the `8` tile in 5 moves. The random seed determines the sequence of new tiles that the game will place; if you choose a different random seed by clicking the `⟲` button, you will (usually) see a different game unfold.

<p class="twenty48-policy-player" data-board-size="2" data-max-exponent="3" data-packed-policy-path="/assets/2048/game-board_size-2.max_exponent-3/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-0.alternate_actions-false.values-true.txt" data-initial-seed="42">Loading&hellip;</p>

For the 2x2 game to the `8` tile, there is not actually much to see. If the player follows the optimal policy, they will always win. (As we saw above, when building the transition probabilities, if the player does not play optimally, it is possible to lose.) This is reflected in the fact that the value of the state remains at 1.00 for the whole game --- when playing optimally, there is at least one action in every reachable state that leads to a win.

If we instead ask the player to play to the `16` tile, a win is no longer assured even when playing optimally. In this case, picking a new random seed should lead to a win 96% of the time for the game to the `16` tile, so I've set the initial seed to one of the rare seeds that leads to a loss.

<p class="twenty48-policy-player" data-board-size="2" data-max-exponent="4" data-packed-policy-path="/assets/2048/game-board_size-2.max_exponent-4/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-0.alternate_actions-false.values-true.txt" data-initial-seed="20">Loading&hellip;</p>

As a result of setting the discount factor, \\(\\gamma\\), to 1, the value of each state also conveniently tells us the probability of winning from that state. Here the value starts at 0.96 and then eventually drops to 0.90, because the outcome hinges on the next tile being a `2` tile. Unfortunately, the game delivers a `4` tile, so the player loses, despite playing optimally.

Finally, we've [previously established](/articles/2017/09/17/counting-states-combinatorics-2048.html#layer-reachability) that the largest reachable tile on the 2x2 board is the `32` tile, so let's see the corresponding optimal policy. Here the probability of winning drops to only 8%.

<p class="twenty48-policy-player" data-board-size="2" data-max-exponent="5" data-packed-policy-path="/assets/2048/game-board_size-2.max_exponent-5/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-0.alternate_actions-false.values-true.txt" data-initial-seed="47">Loading&hellip;</p>

It's worth remarking that each of the policies above is *an* optimal policy for the corresponding game, but there is no guarantee of uniqueness. There may be many optimal policies that are equivalent, but we can say with certainty that none of them are strictly better.

If you'd like to explore these models for the 2x2 game in more depth, [Appendix A](#appendix-a-canonicalization) provides some diagrams that show all the possible paths through the game.

# Optimal Play on the 3x3 Board

On the 3x3 board, it is possible to play up to the `1024` tile, and that game has some [25 million states](/articles/2017/12/10/counting-states-enumeration-2048.html#results). Drawing an MDP diagram like we did for the 2x2 games is therefore clearly out of the question, but we can still watch an optimal policy in action [^missing]:

<p class="twenty48-policy-player" data-board-size="3" data-max-exponent="10" data-packed-policy-path="/assets/2048/game-board_size-3.max_exponent-a/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-1e-07.alternate_actions-false.values-true.txt" data-initial-seed="56">Loading&hellip;</p>

Much like the 2x2 game to `32`, the 3x3 game to `1024` is very hard to win --- if playing optimally, the probability of winning is only about 1%. For some less frustrating entertainment, here also is the game to `512`, for which the probability of winning if playing optimally is much higher, at about 74%:

<p class="twenty48-policy-player" data-board-size="3" data-max-exponent="9" data-packed-policy-path="/assets/2048/game-board_size-3.max_exponent-9/layer_model-max_depth-0/packed_policy-discount-1.method-v.alternate_action_tolerance-1e-09.threshold-1e-07.alternate_actions-false.values-true.txt" data-initial-seed="42">Loading&hellip;</p>

At the risk of anthropomorphizing a large table of states and actions, which is what a policy is, I see here elements of strategies that I use when I play 2048 on the 4x4 board [^me]. We can see the policy pinning the high value tiles to the edges and usually corners (though in the game to `1024`, it often puts the `512` tile in the middle of an edge). We can also see it being 'lazy' --- even when it has two high value tiles lined up to merge, it will continue merging lower value tiles. Particularly within the tight constraints of the 3x3 board, it makes sense that it will take the opportunity to [increase the sum of its tiles]( /articles/2017/08/05/markov-chain-2048.html#binomial-probabilities) at no risk of (immediately) losing --- if it gets stuck merging smaller tiles, it can always merge the larger ones, which opens up the board.

It's important to note that we did not teach the policy about these strategies or give it any other hints about how to play. All of its behaviors and any apparent intelligence emerges solely from solving an optimization problem with respect to the transition probabilities and reward function we supplied.

# Optimal Play on the 4x4 Board

As established in the last post, the game to the `2048` tile on the 4x4 board has at least trillions of states, and so far it has not been possible to even enumerate all the states, let alone solve the resulting MDP for an optimal policy.

We can, however, complete the enumeration and the solve for the 4x4 game up to the `64` tile --- that model has "only" about 40 billion states. Like the 2x2 game to `8` above, it is impossible to lose when playing optimally, so it essentially does not matter which actions the player takes. This does not make for very interesting viewing, because in many cases there are several good actions, and the choice between them is arbitrary.

However, if we reduce the discount factor, \\(\\gamma\\), that makes the player slightly impatient, so that it prefers to win sooner rather than later. It then looks a bit more directed. Here is an optimal player for \\(\\gamma = 0.99\\):

<p class="twenty48-policy-player" data-board-size="4" data-max-exponent="6" data-packed-policy-path="/assets/2048/game-board_size-4.max_exponent-6/layer_model-max_depth-0/packed_policy-discount-0.99.method-v.alternate_action_tolerance-1e-09.threshold-1e-07.alternate_actions-false.values-true.txt" data-initial-seed="42">Loading&hellip;</p>

The value starts around 0.72; the exact initial value reflects the expected number of moves it will take to win from the randomly selected start state. It gradually increases with each move, as the reward for reaching the win state gets closer. Again the policy shows good use of the edges and corners to build sequences of tiles in an order that's convenient to merge.

## Conclusion

We've seen how to represent the game of 2048 as a Markov Decision Process and obtained provably optimal policies for the smaller games on the 2x2 and 3x3 boards and a partial game on the 4x4 board.

The methods used here require us to enumerate all of the states in the model in order to solve it. Using [efficient strategies for enumerating the states](/articles/2017/12/10/counting-states-enumeration-2048.html) and [efficient strategies for solving the model](#appendix-b-solution-methods) makes this feasible for models with up to 40 billion states, which was the number for the 4x4 game to `64`. The calculations for that model took roughly one week on an OVH HG-120 instance with 32 cores at 3.1GHz and 120GB RAM. The next-largest 4x4 game, played up to the `128` tile, is likely to contain many times that number of states and would require many times the computing power. Calculating a provably optimal policy for the full game to the `2048` tile will likely require different methods.

It is common to find that MDPs are too large to solve in practice, so there are a range of proven techniques for finding approximate solutions. These typically involve storing the value function and/or policy approximately, for example by training a (possibly deep) neural network. They can also be trained on simulation data, rather than requiring enumeration of the full state space, using reinforcement learning methods. The availability of provably optimal policies for smaller games may make 2048 a useful test bed for such methods --- that would be an interesting future research topic.

---

&nbsp;

## Appendix A: Canonicalization

As we've seen with the full model for the 2x2 game to the `8` tile, the number of states and transitions grows quickly, and even games on the 2x2 board become hard to draw in this form.

To help keep the size of the model under control, we can reuse an observation from the [previous post about enumerating states](/articles/2017/12/10/counting-states-enumeration-2048.html#canonicalization-and-symmetry): many of the successor states are just rotations or reflections of each other. For example, the states
<p align="center">
  <img src="/assets/2048/2x2_s2_1_0_1.svg" alt="4 2 - 2">
  and
  <img src="/assets/2048/2x2_s1_2_1_0.svg" alt="2 4 2 -">
</p>
are just mirror images --- they are reflections through the vertical axis. If the best action in the first state was to swipe left, the best action in the second state would necessarily be to swipe right. So, from the perspective of deciding which action to take, it suffices to pick one of the states as the *canonical state* and determine the best action to take from the canonical state. A state's canonical state is obtained by finding all of its possible rotations and reflections, writing each one as a number in base 12, and picking the state with the smallest number --- see the [previous post](/articles/2017/12/10/counting-states-enumeration-2048.html#canonicalization-and-symmetry) for the details. The important point here is that each canonical state stands in for a class of equivalent states that are related to it by rotation and reflection, so we don't have to deal with them all individually. By replacing the successor states above with their canonical states, we obtain a much more compact diagram:

<p align="center">
<img src="/assets/2048/mdp_s0_1_1_0_with_state_canonicalization.svg" alt="Actions and transitions from the state - 2 2 - with successor state canonicalization" />
</p>

It's somewhat unfortunate that the diagram appears to imply that swiping up (`U`) from <img src="/assets/2048/2x2_s0_1_1_0.svg" style="height: 2em;"> somehow leads to <img src="/assets/2048/2x2_s0_1_1_1.svg" style="height: 2em;">. However, the paradox is resolved if you read the arrows to also include a rotation or reflection as required to find the actual successor's canonical state.

### Equivalent Actions

We can also observe that in the diagram above it does not actually matter which direction the player swipes from the state <img src="/assets/2048/2x2_s0_1_1_0.svg" style="height: 2em;"> --- the canonical successor states and their transition probabilities are the same for all of the actions. To see why, it helps to look at the 'intermediate state' after the player has swiped to move the tiles but before the game has added a new random tile:

<p align="center">
<img src="/assets/2048/mdp_s0_1_1_0_move_states.svg" alt="Intermediate states resulting from moving left, right, up or down from the state - 2 2 -" />
</p>

The intermediate states are drawn with dashed lines. The key observation is that they are all related by 90&deg; rotations. These rotations don't matter when we eventually canonicalize the successor states.

More generally, if two or more actions have the same canonical 'intermediate state', then those actions must have identical canonical successor states and transition probabilities and therefore are equivalent. In the example above, the canonical intermediate state happens to be the last one, <img src="/assets/2048/2x2_s0_0_1_1.svg" style="height: 2em;" alt="- - 2 2">.

We can therefore simplify the diagram for <img src="/assets/2048/2x2_s0_1_1_0.svg" style="height: 2em;"> further if we just collapse all of the equivalent actions together:

<p align="center">
<img src="/assets/2048/mdp_s0_1_1_0_with_action_canonicalization.svg" alt="Actions and transitions from the state - 2 2 - with successor state and action canonicalization" />
</p>

Of course, states for which all actions are equivalent in this way are relatively rare. Considering another potential start state, <img src="/assets/2048/2x2_s0_0_1_1.svg" style="height: 2em;">, we see that swiping left and right are equivalent, but swiping up is distinct; swiping down is not allowed, because the tiles already on the bottom.

<p align="center">
<img src="/assets/2048/mdp_s0_0_1_1_with_action_canonicalization.svg" alt="Actions and transitions from the state - - 2 2 with successor state and action canonicalization" />
</p>

### MDP Model Diagrams for 2x2 Games

Using canonicalization, we can shrink the models enough to just about draw out the full MDPs for some small games. Let's again start with the smallest non-trivial model: the 2x2 game played just up to the `8` tile ([click to enlarge](/assets/2048/mdp_2x2_3.svg)):

<p align="center">
<a href="/assets/2048/mdp_2x2_3.svg"><img src="/assets/2048/mdp_2x2_3.svg" alt="Full MDP model for the 2x2 game up to the 8 tile" /></a>
</p>

Compared to the figure without canonicalization, this is much more compact. We can see that the shortest possible game comprises only a single move: if we are lucky enough to start in the state <img src="/assets/2048/2x2_s0_0_2_2.svg" style="height: 2em;"> with two adjacent `4` tiles, which happens in only one game in 150, we just need to merge them together to reach an `8` tile and the `win` state. On the other hand, we can see that it is still possible to lose: if from state <img src="/assets/2048/2x2_s0_0_2_2.svg" style="height: 2em;"> the player swipes up, they reach <img src="/assets/2048/2x2_s0_1_2_2.svg" style="height: 2em;"> with probability 0.9, and then if they swipe up again, they reach <img src="/assets/2048/2x2_s2_1_1_2.svg" style="height: 2em;"> with probability 0.9, at which point the game is lost.

We can further simplify the diagram if we know the optimal policy. Specifying the policy induces a Markov chain from the MDP model, because every state has a single action, or group of equivalent actions, identified by the policy. The induced chain for the 2x2 game to the `8` tile is:

<p align="center">
<a href="/assets/2048/mdp_2x2_3_optimal.svg"><img src="/assets/2048/mdp_2x2_3_optimal.svg" alt="MDP model with only the optimal actions for the 2x2 game up to the 8 tile" /></a>
</p>

We can see that the `lose` state no longer has any edges leading into it, because it is impossible to lose when playing optimally in the 2x2 game to the `8` tile. Each state is also now labelled with its value, which in this case is always 1.000. Because we've set the discount factor \\(\\gamma\\) to 1, the value of a state is in fact the probability of winning from that state when playing optimally.

They get a bit messier, but can build similar models for the 2x2 game to [the `16` tile](/assets/2048/mdp_2x2_4.svg):

<p align="center">
<a href="/assets/2048/mdp_2x2_4.svg"><img src="/assets/2048/mdp_2x2_4.svg" alt="Full MDP model for the 2x2 game up to the 16 tile" /></a>
</p>

If we look at the optimal policy for the game to the `16` tile, we see that the start states (in blue) all have values less than one, and that there are paths to the `lose` state, in particular from two states that have tile sum 14:

<p align="center">
<a href="/assets/2048/mdp_2x2_4_optimal.svg"><img src="/assets/2048/mdp_2x2_4_optimal.svg" alt="MDP model with only the optimal actions for the 2x2 game up to the 16 tile" /></a>
</p>

That is, even if we play this game to the `16` tile optimally, we can still lose, depending on the particular sequence of `2` and `4` tiles that the game deals us. In most cases, we will win, however --- the values of the start states are all around 0.96, so we'd expect to win roughly 96 games out of a hundred.

Our prospects in the game to the `32` tile on the 2x2 board, however, are much worse. Here is the full model:

<p align="center">
<a href="/assets/2048/mdp_2x2_5.svg"><img src="/assets/2048/mdp_2x2_5.svg" alt="Full MDP model for the 2x2 game up to the 32 tile" /></a>
</p>

We can see a lot of edges leading to the `lose` state, which is a bad sign. This is confirmed when we look at the diagram restricted to optimal play:

<p align="center">
<a href="/assets/2048/mdp_2x2_5_optimal.svg"><img src="/assets/2048/mdp_2x2_5_optimal.svg" alt="MDP model with only the optimal actions for the 2x2 game up to the 32 tile" /></a>
</p>

The average start state value is around 0.08, so we'd expect to win only about 8 games out of a hundred. The main reason becomes clear if we look at the right hand edge of the chain: once we reach a state with tile sum 28, the only way to win is to get a `4` tile in order to reach the state <img src="/assets/2048/2x2_s2_2_3_4.svg" style="height: 2em;">. If we get a `2` tile, which happens 90% of the time, we lose. It's probably not a very fun game.

## Appendix B: Solution Methods

To efficiently solve an MDP model like the ones we've constructed here for 2048, we can exploit several important properties of its structure:

1. The transition model is a [directed acyclic graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph) (DAG). The sum of the tiles must increase, namely by either 2 or 4, with each move, so it is never possible to go back to a state you have already visited.

2. Moreover, the states can be organized into 'layers' by the sums of their tiles, as we did in [the first MDP model figure](#mdp_2x2_3_with_no_canonicalization), and all transitions will be from the current layer with sum \\(s\\) to either the next layer, with sum \\(s+2\\), or the one after, with sum \\(s+4\\).

3. All states in the layer with the largest sum will transition to either a lose or win state, which have a known value, namely 0 or 1, respectively.

Property (3) means that we can loop through all of the states in the last layer, in which all successor values are known, to generate the value function for that last layer. Then, using property (2), we know that the states in the second last layer must transition to either states in the last layer, for which we have just calculated values, or to a win or lose state, which have known values. In this way we can work backward, layer by layer, always knowing the values of states in the next two layers; this allows us to build both the value function and the optimal policy for the current layer.

In the [previous post](/articles/2017/12/10/counting-states-enumeration-2048.html#appendix-b-layers-and-mapreduce-for-parallelism) we worked forward from the start states to enumerate all of the states, layer by layer, using a map-reduce approach to parallelize the work within each layer. For the solve, we can use the output of that enumeration, which is a large list of states, to work backward, again using a map-reduce approach to parallelize the work within each layer. And like last time we can further break up the layers into 'parts' by their maximum tile value, with some additional book keeping.

The [main solver implementation](https://github.com/jdleesmiller/twenty48/blob/3605cfaeba0a602d9917f84d1a2862afe4ad1bb6/ext/twenty48/layer_solver.hpp) is still fairly memory-intensive, because it has to keep the value functions for up to four parts in memory at once in order to process a given part in one pass. This can be reduced to one part in memory at a time if we calculate what is usually called \\(Q^\\pi(s,a)\\), the value for each possible state-action pair according to policy \\(\\pi\\), rather than \\(V^\\pi(s)\\), but [that solver implementation](https://github.com/jdleesmiller/twenty48/blob/3605cfaeba0a602d9917f84d1a2862afe4ad1bb6/ext/twenty48/layer_q_solver.hpp) proved to be much slower, so all of the results presented here use the main \\(V^\\pi\\) solver on a machine with lots of RAM.

With both solvers, the layered structure of the model allows us to build and solve a model in just one forward pass and one backward pass, which is a substantial improvement on the usual iterative solution method, and one of the reasons that we're able to solve these fairly large MDP models with billions of states. The canonicalization methods in [Appendix A](#appendix-a-canonicalization), which reduce the number of states we need to consider, and the [low level efficiency gains](/articles/2017/12/10/counting-states-enumeration-2048.html#appendix-a-bit-bashing-for-efficiency) from the previous post are also important reasons.

---

&nbsp;

Thanks to [Hope Thomas](https://twitter.com/h0peth0mas) for reviewing drafts of this article.

If you've read this far, perhaps you should [follow me on twitter](https://twitter.com/jdleesmiller), or even apply to work at [Overleaf](https://www.overleaf.com/jobs). `:)`


# Footnotes

[^merging]: There is also some nuance in how tiles are merged: if you have four `2` tiles in a row, for example, and you swipe to merge them, the result is two `4` tiles, not a single `8` tile. That is, you can’t merge newly merged tiles in a single swipe. The original code for merging tiles [is here](https://github.com/gabrielecirulli/2048/blob/ac03b1f01628038039b74b67f2e284b233bd143e/js/game_manager.js#L145-L180), and the simplified but equivalent code I used to merge a line (row or column) of tiles [is here](https://github.com/jdleesmiller/twenty48/blob/master/ext/twenty48/line.hpp#L29-L54) with [tests here](https://github.com/jdleesmiller/twenty48/blob/3605cfaeba0a602d9917f84d1a2862afe4ad1bb6/test/twenty48/common/line_with_known_tests.rb).

[^objectives]: There are several other possible objectives. For example, in the [first post](/articles/2017/08/05/markov-chain-2048.html) in this series, I tried to reach the target `2048` tile in the smallest possible number of moves; and many people I've talked to play to reach the largest possible tile, which is also what the game's points system encourages. These different objectives could also be captured by setting up the model and its rewards appropriately. For example, a simple reward of 1 per move until the player loses would represent the objective of playing as long as possible, which would I think be equivalent to trying to reach the largest possible tile.

[^absorbing]: Technically, we need one more special state, in addition to the `win` and `lose` states, to make this reward system work as described. The equations that we develop for \\(\\pi\\) and \\(V^\\pi\\) assume that all states have at least one allowed action and successor state, so we can't just stop the process at the `lose` and `win` states. Instead, we can add an *absorbing state*, `end`, with a trivial action that just brings the process back into the `end` state with probability one. Then we can add a trivial action to both the `lose` and `win` states to transition to the absorbing `end` state with probability 1. So long as the `end` state attracts zero reward, it will not change the outcome. It's also worth mentioning that there are more general ways of defining an MDP that would provide other ways of working around this technicality, for example by making the rewards depend on the whole transition rather than just the state and by making policies stochastic which, as a side effect, means that we can handle states with no allowed actions, but they require more notation.

[^discounting]: In addition to being [well founded](https://en.wikipedia.org/wiki/Time_preference) in economic theory, the discount factor is often required technically in order to ensure that the value function converges. If the process runs forever and continues to accumulate additive rewards, it could accumulate infinite value. The geometric discounting ensures that the infinite sum still converges even if this happens. For the processes with the reward structure we're considering here, we can safely set the discount factor to 1, because the process is constructed so that there are no loops with nonzero reward, and therefore all rewards are bounded.

[^missing]: There is a caveat for the 3x3 and 4x4 policies: the full optimal policies for every state are too large to ship to the browser (without unduly imposing on GitHub's generosity in hosting this website). The player therefore only has access to the policy for the states that have a probability of at least \\(10^{-7}\\) of actually occurring when playing according to the optimal policy. This means that, unfortunately, roughly one in hundred readers will choose a random seed that takes the process to a state that is not included in the data available on the client, in which case it will stop with an error. These states are selected by calculating the transient probabilities for the Markov chain induced by the optimal policy. The mathematics are essentially the same as those in [the first post about Markov chains for 2048](/articles/2017/08/05/markov-chain-2048.html).

[^me]: Of course, I'm not claiming here to be great at 2048. The [data in my first post](/articles/2017/08/05/markov-chain-2048.html#putting-theory-to-the-test) suggest otherwise!

<script src="/assets/2048/mdp_player.96cb5779dd7942e99648.js" type="text/javascript" charset="utf-8"></script>
<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
</script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS-MML_HTMLorMML" type="text/javascript"></script>
