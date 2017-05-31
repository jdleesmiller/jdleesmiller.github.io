---
layout: post
title: "The Mathematics of 2048 &mdash; Part 1"
date: 2016-10-09 16:00:00 +0000
categories: articles
---

<img src="/assets/2048/2048.png" alt="Screenshot of 2048" style="width: 40%; float: right; margin-left: 10pt; border: 6pt solid #eee;"/>

For several months in early 2014, everyone was addicted to [2048](http://gabrielecirulli.github.io/2048). Like the Rubik's cube, it is a very simple game, and yet it is very compelling. It seems to strike the right balance along so many dimensions --- not too easy but not too hard; not too predictable but comfortingly familiar; not too demanding but still absorbing.

To better understand what makes the game work so well, I have been working on analyzing it using a mathematical framework called a Markov Decision Process (MDP). MDPs are a way of solving problems that involve making sequences of decisions in the presence of uncertainty. Such problems are all around us, and MDPs find many [applications](http://stats.stackexchange.com/questions/145122/real-life-examples-of-markov-decision-processes) in [economics](https://en.wikipedia.org/wiki/Decision_theory#Choice_under_uncertainty), [finance](https://www.minet.uni-jena.de/Marie-Curie-ITN/SMIF/talks/Baeuerle.pdf), and [artificial intelligence](http://incompleteideas.net/sutton/book/the-book.html).

In this first part, I will describe 2048 as seen through the lens of an MDP, and we will use this insight to explore the properties of a "toddler" version of the game on a 2-by-2 board playing to the X tile. We'll see that this game is much less fun than the grownup version on a 4-by-4 board, but still interesting.

In later parts, I will extend the approach to larger boards and tiles and maybe, one day, the full game of 2048. The code behind this post is [available here](https://github.com/jdleesmiller/twenty48), and it leads the blog posts, so you can peek ahead at later results if you like.

## 2048 for Toddlers and Small Computers

I'll start by introducing the key ideas behind an MDP in the context of the 2-by-2 "toddler" version of 2048. So, even if you are not familiar with MDPs, or with 2048, hopefully you will finish this section with an understanding of both.

### States, Actions and Transition Probabilities

The two most important nouns in the language of MDPs are *state* and *action*. We assume that time progresses in discrete time steps. At the start of each time step, the process is in a given *state*, then a decision maker takes an *action*, and then the process moves to a *successor state*, which may be determined in part by chance, for the start of the next time step.

In the game, a *state* is a configuration of the board, such as <img src="/assets/2048/2x2_s1_1_1_0.svg" style="height: 2em;" alt="The state (2, 2, 2, -)" />. A state specifies the value of the tile, if any, in each cell. The decision maker is in this case the player, and he or she takes an *action* from a state by swiping `left`, `right`, `up` or `down`. The result of the action is that all of the tiles slide as far as possible in that direction. If two tiles with the same value slide together, they merge into a single tile with value equal to the sum of the two tiles.

For example, if we choose the action `up` from <img src="/assets/2048/2x2_s1_1_1_0.svg" style="height: 2em;" alt="The state (2, 2, 2, -)" />, the lower `2` tile slides up into the top row and is merged with the `2` tile to produce a `4` tile. The `2` tile in the upper right has nowhere to go and stays put. This leaves the cells in the bottom row empty, but they don't stay empty, because the game now gets to place a tile in one of the empty cells.

This is where the element of chance comes in, because the game chooses which cell and which tile randomly. We can find out how the game does this by reading [its freely available source code](https://github.com/gabrielecirulli/2048): it picks an empty cell uniformly at random, and then in that cell it places a `2` tile with probability 0.9, or a `4` tile with probability 0.1. So, while we can't say for sure which successor state we will end up in given the player's action, with this information we can define a probability distribution over the possible successor states.

This probability distribution over the successor states, given the initial state and the player's action in that state, is defined by the *transition probabilities*.

<p align="center">
<img src="/assets/2048/2x2_intro.svg" alt="Example with results of moving up from state (2, 2, 2, -)" width="75%" />
</p>


For example, in the leftmost board below, <img src="/assets/2048/2x2_s1_1_1_0.svg" style="height: 2em;" alt="The state (2, 2, 2, -)" />, the new tile appears in the bottom left square with probability 0.5, and it is a `2` with probability 0.9, which gives a joint probability of \\(0.5 \\times 0.9 = 0.45\\) for that outcome.



In this example, we can

transition probs


### Rewards, Values and Policies

At some point we also need to talk about the start states... but interestingly MDPs don't really distinguish particular start states.

Each state comes with an associated *reward*, which the decision maker receives upon entering it. To "solve" the problem, we are looking for a *optimal policy* that tells the decision maker which action to take in each state, in order to collect as much reward as possible. In its simplest form, an optimal policy is a table that maps each state to the best action to take in that state, and the decision maker simply looks up its actions in this policy table.

Let's start by recapping the rules of 2048, which we can deduce from [its freely available source code](https://github.com/gabrielecirulli/2048):

1. When the game starts, the board contains two tiles in randomly chosen cells. Each tile is either a 2, with probability 0.9, or a 4, with probability 0.1.

1. For each move, we can swipe left, right, up or down to slide all the tiles as far as possible in that direction. If two tiles with the same value slide together, they merge into a single tile with value equal to the sum of the two tiles.

1. After each move, the game places one new tile in a random position. Again, the new tile either has value 2, with probability 0.9, or value 4, with probability 0.1. [^2]

1. The game ends when either (a) the board is full, and it is not possible to move any tile, in which case we lose, or (b) a tile with value 2048 is reached.

The toddler version on the 2-by-2 board is played with the same rules as the full game, except that, as we'll see later, it's not possible to make it all the way to the 2048 tile on a 2-by-2 board. We'll instead settle for winning at a lower value.

To illustrate the rules, here is a quick example:

<p align="center">
<img src="/assets/2048/2x2_intro_1.svg" alt="Example with results of moving up from state (-, 2, 2, -)" width="75%" />
</p>

Here we suppose that the game starts with two `2` tiles in the diagonal cells. If our first move is `up`, the lower `2` tile slides up, leaving the cells in the bottom row empty. The game then selects one of the two empty tiles at random, which is to say with probability 0.5 each, and adds either a `2` tile to that cell, with probability 0.9, or a `4` tile, with probability 0.1. For example, in the leftmost board below, <img src="/assets/2048/2x2_s1_1_1_0.svg" style="height: 2em;" alt="The state (2, 2, 2, -)" />, the new tile appears in the bottom left square with probability 0.5, and it is a `2` with probability 0.9, which gives a joint probability of \\(0.5 \\times 0.9 = 0.45\\) for that outcome.

If we suppose that the leftmost outcome is the one that happens, and our second move is `left`, the two `2` tiles on the first row merge together into a `4` tile in the top left, leaving the cells in the righthand column empty. The game then selects one of those two empty tiles at random, as above, and so on.

<p align="center">
<img src="/assets/2048/2x2_intro_2.svg" alt="Example with results of sliding left from state (2, 2, 2, -)" width="75%" />
</p>

Next we will see how to map these rules into the language of Markov Decision Processes.

## A Markov Decision Process Approach

Markov Decision Processes (MDPs) are a way of solving problems that involve making sequences of decisions in the presence of uncertainty. Such problems are all around us, and MDPs are simple but powerful way of approaching them, with many [applications](http://stats.stackexchange.com/questions/145122/real-life-examples-of-markov-decision-processes) in [economics](https://en.wikipedia.org/wiki/Decision_theory#Choice_under_uncertainty), [finance](https://www.minet.uni-jena.de/Marie-Curie-ITN/SMIF/talks/Baeuerle.pdf), and [artificial intelligence](http://incompleteideas.net/sutton/book/the-book.html).


In the case of 2048,

- there is one move per time step,
- a state is a board configuration, such as <img src="/assets/2048/2x2_s1_1_1_0.svg" style="height: 2em;" alt="The state (2, 2, 2, -)" />, and
- an action is a move, such as `left`.

The game dynamics are encoded in the *transition probabilities* that, together with the current state and the action taken, define a probability distribution over the next state. The transition probabilities are where we handle both the tile movement and merging rules, which are deterministic, and the placement of new `2` and `4` tiles, which are non-deterministic. For the example above, we can label each of these components.

<p align="center">
<img src="/assets/2048/2x2_intro_2_annotated.svg" alt="The example above with states, actions, transition probabilities and successor states labelled." width="80%" />
</p>

The final piece of the puzzle is to define the *rewards*, which will require us to make the notion of choosing a policy to "collect as much reward as possible" more precise. This is a bit more technical, so we will need some notation [^general]. Let's start with the transition probabilities. Let \\(S\\) be the set of states, and for each state \\(s \\in S\\), let \\(A_s\\) be the set of actions that are valid in state \\(s\\). Then let \\(\\Pr(s, a, s')\\) denote the probability that, if we begin in state \\(s \\in S\\) and take action \\(a \\in A_s\\), we transition to state \\(s' \\in S\\) in the next time step.

Next, the policy. let \\(\\pi: S \\rightarrow A \\), where \\(\\pi(s) \\in A_s\\) is the action to take in state \\(s\\).

\\(A = \\bigcup_{s \\in S} A_s\\)

Define the *value*, \\(V(s)\\), of state \\(s\\) to be the expected discounted sum of future rewards from state \\(s\\), if we follow policy \\(\\pi\\). That is,
\\[
V(s) = R(s) + \\gamma \\sum_{s'} \\Pr(s, \\pi(s), s') V(s')
\\]



# SCRATCH

An *optimal policy* is one that maximises the expected (discounted) sum of the future rewards from each state, if the decision maker follows that policy.

If we can formulate 2048 as an MDP and find an optimal policy for that MDP, we can legitimately claim to have *solved* the game of 2048 --- to have found the (or a) best way of playing.


That last sentence may be improved by dissection:  


In equations, we can write this precisely as follows. Fo

Let \\(\\pi\\) be a For each state \\(s\\), let \\(\\pi(s)\\) denote the action that  \\(V(s)\\) denote the value of


We will formulate 2048 as an MDP, as follows. A configuration of the board is a *state*, and the direction we swipe is an *action* that we take in that state. The game mechanics of moving and merging tiles and then adding a random (2 or 4) tile are captured by the *transition probabilities* and corresponding *successor states*.






MDPs are a way of looking at problems that involve making decisions in the presence of uncertainty. Such problems are all around us, and MDPs are simple but powerful way of approaching them, with many [applications](http://stats.stackexchange.com/questions/145122/real-life-examples-of-markov-decision-processes) in [economics](https://en.wikipedia.org/wiki/Decision_theory#Choice_under_uncertainty), [finance](https://www.minet.uni-jena.de/Marie-Curie-ITN/SMIF/talks/Baeuerle.pdf), and [artificial intelligence](http://incompleteideas.net/sutton/book/the-book.html). If you are not familiar with MDPs, 2048 provides a nice example to learn more about them in practice --- while there are some heavy mathematics at work behind the scenes, setting up a problem as an MDP and solving it is often surprisingly easy.

In this part 1, we'll start with the toddler version of 2048, which is played on a 2-by-2 board. We'll learn how to model the game as an MDP, and we'll see how we can solve all 2-by-2 games. In part 2, we'll graduate to a 3-by-3 board. We'll see that some more clever techniques are required to reduce the problem size enough for us to actually solve 3-by-3 games. Finally, in part 3, we'll turn our hand to the grown-up version on a 4-by-4 board. There the curse of dimensionality will finally catch up with us, and we will abandon all hope of provable optimality for the time being; we'll instead shift focus to approximate solution techniques based on what we've learned on the smaller boards.

All of the code and most of the data (except some really big files) used for this article [are available here](https://github.com/jdleesmiller/twenty_48). The code is leading the articles --- I haven't written part 2 yet, but the code for part 2 and many of the results are already available there.

and we'll define the game in the terms used in a Markov Decision Process: states, actions, and rewards.

A *state* is a configuration of the board; it specifies the position of all of the tiles on the board. From this state, we take an *action* to bring us to a new, *successor state*. However, the action does not uniquely determine the successor state; there is an element of chance, because the game adds a random tile after we swipe. Again, it's a 2 with probability 0.9 or a 4 with probability 0.1.


The transition probabilities encode the rules of the game.

Next we need to define the objective. There are several different objectives we might have --- maximising the score (in 2048, your score increases every time you merge tiles), playing for as long as possible, or getting to the maximum tile as quickly as possible. In MDP terms, we will receive a reward of 1 when we win and repeat this forever, basking in glory.

The problem with basking in glory forever is that your sums will diverge. To avoid this, we need to introduce a discount rate. A discount rate captures what in finance is usually phrased as the time value of money --- that a dollar you get today is worth more than a dollar you get tomorrow. A mathematically convenient way of representing this is to "discount" future rewards by a constant factor less than 1, usually denoted \\(\\gamma\\) (gamma). If \\(\\gamma = 0.95\\), it means that a dollar you get tomorrow is worth the same to you as $0.95 today.

Here we're aiming not primarily to build a stronger AI, but instead to try to develop a way of saying *how strong* the AIs are --- are they essentially optimal, or is there even more room to improve? We can only know by using techniques such as Markov Decision Processes to try to find what optimal is.

What we can't yet say is *how good* those strategies and bots are. Could we find even better strategies and bots? The MDP approach used here can in principle answer that question, and also other interesting, more theoretical questions: What is the largest achievable tile? The highest possible score? The fastest possible game?


However, while we can measure their success empirically against each other.

The consensus view on the [best strategies]() for playing 2048 centres around three main ideas:

1. Monotonicity: you want to have chains of increasing numbers.

2. Smoothness: you want adjacent tiles to have similar values.

3. Maximise free tiles: other things being equal, you'd rather not have lots of


The best strategies for playing are pretty uncontroversial.

We had to teach the computer those strategies. Can the computer play without being given all those hints? The optimal strategy emerges from the rules of the game and computation; it's very 'pure'.

Everyone has their favourite heuristic for playing the game. [Never swipe down!](http://www.dailydot.com/debug/how-to-win-2048/) is a surprisingly popular refrain.

[Monotonicity and Smoothness!](http://2048strategy.com/2048-strategy/) [Maximise Free Tiles!]()

# 2048-like games

## 2x2 Simplification

# 2048 as a Markov Decision Process

To use an MDP to solve our game, we need to talk about the game in a very specific way, in terms of *states*, *actions* and *rewards*.

A **state** is a particular configuration of the 2048 board. So, for example, here are some states on our 2x2 board.

(examples)

An **action** is a swipe (left, right, up or down).

The **reward** is set so that we get a reward of 1 for winning and 0 for others.

What game are we playing? Get to the 2048 tile. Nothing less, nothing more.

Discounting --- actually, may not be needed (footnote), since all games must end.

# Symmetries

One of the first ways we can reduce the number of states we have to consider is to take into account symmetries.

# Reachability

Example of state that is unreachable:

```
8 8
8 8
```

State generation.

# Result: Completely Solve 2x2 Games

# 2x2 Game to 4

The first slightly interesting game.

# 2x2 Game to 8

Maybe plot average reward.

# 2x2 Game of 64 is Un-winnable

75 states

# Next Time: 3x3 Games

We'll see that the same techniques apply, and we'll need some new techniques to handle the exponential growth in the size of the models.

# MDP background

1. You are in a particular **state**.

2. You then take an **action** with the goal of influencing your next state.

3. However, the world gets to intervene: the state in which you actually

Digits: http://xkcd.com/1344/

Expectimax: https://web.uvic.ca/~maryam/AISpring94/Slides/06_ExpectimaxSearch.pdf




The

While most


I have been working on solving  with mathematics. In this part 1, I'll describe how to model 2048 as a Markov Decision Process (MDP) and present some results for a "toddler" version of the game on a 2-by-2 board.

The first half of 2014 was bad for productivity. It gave rise to a trifecta of distraction with [flapping birds](https://en.wikipedia.org/wiki/Flappy_Bird), [simulated goats](https://en.wikipedia.org/wiki/Goat_Simulator), and merging tiles: [2048](http://gabrielecirulli.github.io/2048). <sup><a name='footnote-mashups-ref' href='#footnote-mashups'>1</a></sup> Most of us have since [moved on](https://www.google.com/trends/explore?date=2014-01-01%202014-12-31&q=%2Fm%2F0_gzt9y,2048,goat%20simulator&hl=en), but I would like to revisit 2048.





I have been working toward solving 2048 mathematically.

since then, but in this article I'd like to revisit this fun little puzzle game. In particular, I'll use an enormously powerful mathematical decision making framework called a Markov Decision Process (MDP) for the very important task of deciding whether to swipe left, right, up or down.

I have two motivations. First, 2048 is a nice way to learn about MDPs. This article doesn't assume any prior knowledge of MDPs, and it will introduce the necessary concepts as they arise. Second, MDPs hold the promise of obtaining a *provably optimal* solution for the game &mdash; a way of playing that we can show mathematically to be the (or a) best possible way of playing.

There are already [lots of good strategies](http://stackoverflow.com/a/22389702/2053820) and [good bots](http://stackoverflow.com/questions/22342854/what-is-the-optimal-algorithm-for-the-game-2048) for playing 2048 --- if in doubt, check out this [video of a bot playing well past the 8192 tile](https://www.youtube.com/watch?v=96ab_dK6JM0). However, the bots are based on heuristics, which give no particular guarantees on how well they play. It might be possible to play much better than the strongest current bots and humans, or not; by using MDPs we may be able to find out.

Before we get too excited, however, I should point out the 'Towards' in the title. We will see that the full game of 2048 is in fact quite hard, and we won't get all the way to a provably optimal solution, at least not right now, and at least not on my laptop. Instead, we'll start with games with the same rules but on smaller boards, which we'll see are easier to solve.


---

<sup><a name='footnote-mashups' href='#footnote-mashups-ref'>1</a></sup> Flappy Bird was released in May 2013, but it became popular in January 2014. And I should also mention [flappy 2048](https://hczhcz.github.io/Flappy-2048/), [Doge 2048](http://doge2048.com/) and, of course, [flappy Doge 2048](http://www.donaldguy.com/Flappy-Doge2048/)?

[^2]: In case you, like me, sometimes felt like the game was scheming against you, giving you exactly the wrong tile at the wrong time, reading the source code reveals no such evil. Never attribute to malice that which can be attributed to randomness. That said, [there is a version that tries to give you the worst possible tile](https://aj-r.github.io/Evil-2048). As you might expect, it is much harder.

[^general]: This treatment of MDPs is not fully general. For example, the policy can be stochastic, in which case...

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
</script>
<script src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML" type="text/javascript"></script>
