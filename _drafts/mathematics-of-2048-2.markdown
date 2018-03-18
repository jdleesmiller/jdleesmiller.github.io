---
layout: post
title: "The Mathematics of 2048 &mdash; Part 2: TBD"
date: 2017-07-09 16:00:00 +0000
categories: articles
---

--------------

consistency:
- allowed vs possible actions
- next state vs successor state
- use of 'game' to mean whichever 2048-like game we mean
- use of player rather than 'we'

The game of 2048 is ordinarily played on a 4x4 board, but it will be helpful to start with smaller boards: 2x2 and 3x3.

a mathematical framework called a Markov Decision Process (MDP). MDPs are a way of solving problems that involve making sequences of decisions in the presence of uncertainty. Such problems are all around us, and MDPs find many [applications](http://stats.stackexchange.com/questions/145122/real-life-examples-of-markov-decision-processes) in [economics](https://en.wikipedia.org/wiki/Decision_theory#Choice_under_uncertainty), [finance](https://www.minet.uni-jena.de/Marie-Curie-ITN/SMIF/talks/Baeuerle.pdf), and [artificial intelligence](http://incompleteideas.net/sutton/book/the-book.html).

In this first part, I will describe 2048 as seen through the lens of an MDP, and we will use this insight to explore the properties of a "toddler" version of the game on a 2-by-2 board playing to the 32 tile. We'll see that this game is much less fun than the grownup version on a 4-by-4 board, but still interesting.

In later parts, I will extend the approach to larger boards and tiles and maybe, one day, the full game of 2048. The code behind this post is [available here](https://github.com/jdleesmiller/twenty48), and it leads the blog posts, so you can peek ahead at later results if you like.

## 2048 for Toddlers and Small Computers

I'll start by introducing the key ideas behind an MDP in the context of the 2-by-2 "toddler" version of 2048. So, even if you are not familiar with MDPs, or with 2048, hopefully you will finish this section with an understanding of both.

### States, Actions and Transition Probabilities

The two main nouns in the language of MDPs are *state* and *action*. We assume that time progresses in discrete steps. At the start of each step, the process is in a given *state*, then a decision maker takes an *action*. The process then moves to a *successor state*, which may be determined in part by chance, for the start of the next step.

In the game, a *state* is a configuration of the board, such as <img src="/assets/2048/2x2_s1_1_1_0.svg" style="height: 2em;" alt="The state (2, 2, 2, -)" />. Each state specifies the value of the tile, if any, in each cell on the board. The decision maker is in this case the player, and he or she takes an *action* by swiping `left`, `right`, `up` or `down`. Each time the player takes an action, the process transitions to a new state.

In particular, the result of the player's action is that all of the tiles slide as far as possible in the chosen direction. If two tiles with the same value slide together, they merge into a single tile with value equal to the sum of the two tiles. For example, if we choose the action `up` from the state <img src="/assets/2048/2x2_s1_1_1_0.svg" style="height: 2em;" alt="The state (2, 2, 2, -)" />, the lower `2` tile slides up into the top row and is merged with the `2` tile in the top left to produce a `4` tile. The `2` tile in the top right has nowhere to go and stays put. This leaves the cells in the bottom row empty, but they don't stay empty, because the game now gets to place a tile in one of the empty cells.

This is where the element of chance comes in, because the game chooses which cell and which tile randomly. We can find out how the game does this by reading [its freely available source code](https://github.com/gabrielecirulli/2048): it picks an empty cell uniformly at random, and then in that cell it places a `2` tile with probability 0.9, or a `4` tile with probability 0.1. So, while we can't say for sure which successor state we will end up in given the player's action, with this information we can define a probability distribution over the possible successor states.

This probability distribution over the successor states, given the initial state and the player's action in that state, is encoded in the *transition probabilities*. In this case, there are four possible successor states as shown in the diagram below:

<p align="center">
<img src="/assets/2048/2x2_intro.svg" alt="Example with results of moving up from state (2, 2, 2, -)" width="75%" />
</p>

For example, the probability of transitioning to the leftmost successor state, <img src="/assets/2048/2x2_s2_1_1_0.svg" style="height: 2em;" alt="The state (4, 2, 2, -)" />, is 0.45, because the game picks the bottom left square with probability 0.5, and it places a `2` tile in that square with probability 0.9; since the choice of cell and the choice of tile are independent, the joint probability is \\(0.5 \\times 0.9 = 0.45\\).

Taken together, the states, actions and transition probabilities encode the game dynamics &mdash; essentially the rules of the game. Next we will look at what it means to win the game (or not).

### Rewards, Policies and Values

#### In General

Each state in an MDP comes with an associated *reward*, which the decision maker receives upon entering that state. The decision maker's objective is to take actions so as to collect as much reward as possible. To make this idea more precise, we'll need two more concepts: policies and values.

A *policy* describes how the decision maker decides which action to take in each state. In it's simplest form, a policy is a table that maps each state to an action, and at each time step the decision maker simply finds the current state in the table and takes the corresponding action.

The *value* of a state, given that the decision maker follows a given policy, is the *expected discounted sum of future rewards* that the decision maker will receive upon entering that state. To unpick that rather complicated statement, an equation is worth a lot of words, so let's explain that in the context of an equation.

We'll need some notation. Let \\(S\\) be the set of states, and for each state \\(s \\in S\\), let \\(A_s\\) be the set of actions that are possible in state \\(s\\). Then define:

1. The transition probabilities: let \\(\\Pr(s' \| s, a)\\) denote the probability that we transition to state \\(s' \\in S\\) for the next time step given that we are in state \\(s \\in S\\) and take action \\(a \\in A_s\\) in the current time step.

1. The reward: let \\(R(s)\\) denote the reward received for entering state \\(s\\).

1. The policy: let \\(\\pi(s) \\in A_s\\) denote the action to take in state \\(s\\) when following policy \\(\\pi\\). The policy \\(\\pi\\) maps from states to actions [^general].

1. The value: let \\(V^\\pi(s)\\) denote the value of state \\(s\\) when following policy \\(\\pi\\).

The value of a state when following policy \\(\\pi\\) is then given by
\\[
V^\\pi(s) = R(s) + \\gamma \\sum_{s'} \\Pr(s' \| s, \\pi(s)) V^\\pi(s')
\\]
where \\(\\gamma\\) is called the *discount factor*, and \\(0 < \\gamma < 1\\). The first term, \\(R(s)\\), is the immediate reward for entering state \\(s\\), and the second term is the *expected future reward*, assuming that we follow policy \\(\\pi\\) for the current state and also in the future. It is worth remarking that this is a recursive definition: the value of each state is defined in terms of the values of its possible successor states, weighted by the transition probabilities.

The discount factor, \\(\\gamma\\), trades off the value of the immediate reward against the value of the future rewards. In other words, it [accounts for the time value of money](https://en.wikipedia.org/wiki/Time_value_of_money) to the decision maker. If \\(\\gamma\\) is close to 1, it means that the decision maker is very patient: they don't mind waiting for future rewards; likewise, smaller values of \\(\\gamma\\) mean that the decision maker is less patient.

So, we can now state our objective more clearly: find a policy that maximizes value.

#### In 2048

For 2048, we want to define the rewards so that the player is rewarded for winning the game. Here we'll say that say that the player wins the game if they reach a state containing a 2048 tile [^winning]. Therefore, we will define the rewards so that the player gets a reward of 1 if they enter a state with a 2048 tile (i.e. win) and 0 for every other state.


### Results

#### How many States

One of the first questions we can ask is, how many states are there? One way to get an estimate is to observe that, for the 2x2 game, there are 4 cells, and each cell can be empty or take one of the values 2, 4, 8, 16 or 32. We'll assume that once we get a 32 tile, we have won, and we don't particularly care where the `32` tile is; that means we can focus on just the values up to 16. This gives us 5 possible values (blank + four numbers) for each cell, so \\(5^4 = 625\\) regular states plus one state for losing and one state for winning, so 627 in total.

That's not too scary for the 2x2 board, but if we apply the same logic to the 4x4 board with 16 cells and 11 possible values for each tile, the figure is \\(11^{16} = 45,949,729,863,572,161\\). That's about 46 quadrillion states, which won't fit on your Mac Book any time soon. We're therefore interested in how we can simplify the model by eliminating states. The two main ways of doing this are to remove states that are related by symmetry and to consider only reachable states.

#### Reachability

Just because we can write a state, does not mean that there is any sequence of moves from any start state that will actually generate that state. For example, the state
```
8 8
8 8
```
cannot occur in the 2x2 game, even though it was included in our estimate that there were 627 states. One way to see this is to observe that every state must contain at least one `2` or `4` tile, because the game adds one after each move; this implies the state with all 8s can't happen. (We can also use this observation to refine the state counting estimate above, but it doesn't make much difference.)

#### Non-Recurrence

A useful property of 2048 is that sum of the tiles on the board always increases by either 2 or 4 with each move. This property does not help us reduce the size of the state space, but we'll see that it does help us cut up the set of all possible states, so we don't have to worry about all of the states at once.

To see that the property holds, we can observe that:

1. The game adds a `2` or `4` tile after each move, which increases the sum of the tile values by either 2 or 4, and

2. if the player merges two tiles with the same value, that does not change the sum of the tile values.

For example, if we start with two `2` tiles, they contribute \\(2 + 2 = 4\\) to the sum, and the player merges them, the resulting `4` tile still contributes \\(4\\) to the sum.

This means that we can organize the states into *layers* according to the sum of their tiles. If the game is in a state in the layer with sum 10, we know that the next state must be in the layer with sum 12 or sum 14. This also implies that states never repeat in the course of the game: every move increases the sum.


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


## Machine Power

### Can't Get There from Here: State Reachability

Just because it is possible to write a state down doesn't mean that it can actually occur in the game. For example, hiding among the states we counted in the previous section was the state

```
   2 1024 1024 1024
1024 1024 1024 1024
1024 1024 1024 1024
1024 1024 1024 1024
```

which is clearly not a state that could actually happen in the game --- any move in the previous state would have had to merge some of those `1024` tiles.

The simplest way to count reachable states is basically a brute force approach: generate each possible start state, then for each of those states find all possible successor states, and so on. Based on the combinatorial bounds in the previous section, we can be confident that this is feasible for at least the 2x2 game and possibly the 3x3 game.

For example, one of the start states for the 2x2 game is <img src="/assets/2048/2x2_s1_0_0_1.svg" style="height: 2em;" alt="The state (2, -, -, 2)" />. The possible successors include those for any of the possible moves (`left`, `right`, `up` or `down`) --- we're not committing to any particular moves, just counting all of the possibilities. Here they are:

<p align="center">
<img src="/assets/2048/2x2_successors_example.svg" alt="All successors of the state (2, -, 2, -)" />
</p>

If the player moves `up`, for example, the `2` tile on the bottom row slides up. This leaves two available cells in the bottom row, and the game places a `2` or `4` tile into one of them, for a total of four possible successors. It's worth noting that one of these successors, <img src="/assets/2048/2x2_s1_1_1_0.svg" style="height: 2em;" alt="The state (2, 2, 2, -)" />, is also reachable if the player moves `left`, and the game places a `2` tile in the top right.

The search process continues from each one of the successor states, until we reach either a winning state (with a `2048` tile) or a losing state. A losing state effectively has no successor states, because there is no move that will change the board.

### By Any Other Name: Canonicalization

Many states are distinct but equivalent to other states. For example,
```
4 2
2
```
is the same as
```
2 4
  2
```
because they are mirror images of each other. If we knew that the best action in the former state was to go left, the best action in the latter state would be go to right. We can find other states by reflecting through different axes (or by rotating):
```
  2
2 4
```
and
```
2
4 2
```

Rather than treating each of these equivalent states as a separate state, we can just pick one of them as the 'canonical' form of that group of states. One approach to finding the canonical form is as follows: given a state, generate all of its possible rotations and reflections, sort them into some kind of order, and then choose the smallest one as the canonical state.

To define an ordering over the states, we can view each state as a number in which each cell contributes one digit. One way to do this is to start in the top left and read the cells by rows; for each cell, we write a \\(0\\) digit if the cell is empty, and the digit \\(i\\) for a cell that contains a \\(2^i\\) tile. For the four equivalent states above, the corresponding numbers would be:
```
2 1 1 0
1 2 0 1
0 1 1 2
1 0 2 1
```
The smallest of these numbers is \\(0112\\), so the corresponding state
```
  2
2 4
```
is the canonical state for this equivalence class of states.

### Lookahead

Just as we don't particularly care exactly what is on the board when we win,

# SCRATCH

- May be able to enumerate 4x4 to 6 or possibly 7; if we start with the last layer for which the max value was 5 (i.e. the last layer with max value < 6), then all of those states must be the same in the game to 6. It's only once we start getting some 6 tiles that the game to 6 starts looking different to the game to 11. Hopefully the number of states will start dropping as some of them become win states.

- For canonicalization, it's interesting to plot the ratio of reachable to canonical states. It starts out low but then approaches 8 as the game gets larger (in terms of both max tile and board size). So, in the limit we can expect it to get us a factor of 8.

- However... the big thing that's missing is reachability --- that seems to account for most of the orders of magnitude. I guess that's a result. So, getting those extra couple of points should help quite a bit with the story.

- If we can get a few more points, we can perhaps do a cheesy extrapolation to get an estimate for the number of states.

- The summary table is too large. Maybe we could have a table with the brain power limits in that section and then just carry forward the best one into the third section. Or I could try to break it up into methods and results. That would be more compact, but I feel like it would read better inline. OTOH maybe people will just want to skip to the results. The results could be presented quite compactly: a couple of graphs.

- Should we split this article into two? The combinatorial bounds are one somewhat interesting idea, and there is something of a result: we cut down the 2x2 and 3x3 boards significantly. Part 2 could then talk about the computational approach (actually enumerating the states). There's quite a bit of interesting technical detail I could talk about: the idea of layers (already introduced in part 1), map-reduce, b-trees, vbyte encoding, and zstandard compression. I think trying to fit all of that into part 1 will make it too large. The other way of slicing it would be to present the computational results here and then talk about the methods in part 2, but then I'd probably end up repeating a lot of the results. So... maybe worth trying to split it up this way.

- Another thing I would like to talk about is the length of the game. That doesn't necessarily fit with the 'counting states' title, but it also doesn't seem like quite enough for its own part. It does sort of fit after the idea of layers --- one way to truncate is to look for consecutive empty layers. Another is to look at the minimum and maximum number of moves.



The reward in `end` state is particularly important, because the `end` state is absorbing. In the diagram above, the `end` state has a

If the player loses, which happens when the board is full and no action is possible, the  The `end` state is 'absorbing' --- once the process reaches it, it never leaves.

Rewards serve to guide which actions the player will take. Each time the process changes state, the player may receive a reward, and it is assumed that the player wants to collect as much reward as possible over time. There are several possible reward systems, each of which corresponds to a different objective for the game. For now, we'll use a very simple reward system: the player receives a reward of 1 for entering a winning state, and otherwise receives zero reward. (It is a unit-less reward, but you could prepend a dollar sign if you like.)


The transition probabilities are represented by the weights of the edges, where thicker edges have higher probability. Edges with probability exactly 1 are marked with a circle behind the arrow, for reference.

TODO: maybe just explain how the end and win states work with respect to the normal states --- both are 'any win / loss' conditions. Move the 'absorbing' bit lower down? Maybe it will make more sense in the context of the rewards and the solve.

Toward the right hand edge of the diagram, there are two special states, `win` (in green) and `end`, which are used to model how the game ends. The `end` state is used to represent any state in which the board is full and it is not possible to merge any tiles --- that is, when the player has lost the game. We don't care exactly how the player lost, so a single `end` state suffices.

For reasons that will become clear shortly, the `end` state is 'absorbing': it has a single action that causes the process to transition back to the `end` state with probability 1. We also use the `end` state for it's absorbing character once the player has won. That is, whether the player wins or loses, they always finish in the `end` state, but if they win then they will get their via the `win` state.

The `win` state represents any state with an `8` tile --- just as we don't care what is on the board when the player loses, we don't care exactly how the player wins, so a single `win` state suffices to represent all of the possible winning states. The player is trying to choose actions such that they transition to the `win` state.

we are ready to talk about what the player is trying to achieve by playing the game. Here we'll assume that the player's objective is simply to reach a tile with a given target value --- in our example on the 2x2 board, it is the mighty `8` tile, but in the full game it would be the `2048` tile .



There are several ways we could set up the rewards, depending on what the player is trying to accomplish. For example, the player could be trying to reach the highest possible tile without losing; or they could just be trying to reach the `8` tile. In this post, we'll focus on the latter

For now, we'll set the rewards to reflect the latter option: they will receive a reward of 1 for entering the `win` state, and 0 for all other states, including the `end` state.





# Canonical States

# Rewards

Rewards serve to guide which actions the player will take. Each time the process changes state, the player may receive a reward, and it is assumed that the player wants to collect as much reward as possible over time. There are several possible reward systems, each of which corresponds to a different objective for the game. For now, we'll use a very simple reward system: the player receives a reward of 1 for entering a winning state, and otherwise receives zero reward. (It is a unit-less reward, but you could prepend a dollar sign if you like.)

To make this notion of collecting as much reward as possible over time precise, we'll need some notation for the four main MDP concepts. Let \\(S\\) be the set of states, and for each state \\(s \\in S\\), let \\(A_s\\) be the set of actions that are possible in state \\(s\\). Let \\(\\Pr(s' \| s, a)\\) denote the probability of transitioning to the state \\(s' \\in S\\) given that the process is in state \\(s \\in S\\) and the player takes action \\(a \\in A_s\\). Finally, let \\(R(s)\\) denote the reward received for entering state \\(s\\).

Our objective is to find a *policy* that tells the player which action to take in each state. Let \\(\\pi(s) \\in A_s\\) denote the action to take in state \\(s\\) when following policy \\(\\pi\\). For a given policy \\(\\pi\\), we can define the *value* of each state \\(s\\), \\(V^\\pi(s)\\), according to the policy, as the expected reward collected over time if we follow that policy from that state:

\\[
V^\\pi(s) = R(s) + \\gamma \\sum_{s'} \\Pr(s' \| s, \\pi(s)) V^\\pi(s')
\\]

where \\(\\gamma\\) is a *discount factor* that trades off the value of the immediate reward against the value of the future rewards. In other words, it [accounts for the time value of money](https://en.wikipedia.org/wiki/Time_value_of_money) to the decision maker. If \\(\\gamma\\) is close to 1, it means that the decision maker is very patient: they don't mind waiting for future rewards; likewise, smaller values of \\(\\gamma\\) mean that the decision maker is less patient.

The discount factor is often required in order to ensure that the value function converges --- if the process runs forever and continues to accumulate additive rewards, the geometric discounting ensures that the sum still converges. For the 2048 processes with the reward structure we're considering here, we'll see that we can safely set the discount factor to 1, because the process is a directed acyclic graph (DAG) except for the `end` state, which gives zero reward. It therefore has no loops that generate nonzero reward. We will however set the discount factor slightly less than 1 for the 4x4 game.

So, how do we find the policy? For each state, we want to choose the action that maximizes the expected future value:

\\[
\\pi(s) = \\mathop{\\mathrm{argmax}}\\limits_{a \\in A_s} \\left\\{
  \\sum_{s'} \\Pr(s' \| s, a) V^\\pi(s')
  \\right\\}
\\]

So, this gives us two linked equations. In general, we can these iteratively. That is, pick an initial policy, which might be very simple, compute the value of every state under that simple policy, and then find a new policy based on that value function, and so on. Perhaps remarkably, under very modest technical conditions, such an iterative process is guaranteed to converge to an optimal policy, \\(\\pi^\*\\), and an optimal value function \\(V^{\\pi^\*}\\) with respect to that optimal policy.

For 2048, it is not actually necessary to do this iterative calculation, however, again because the model is essentially a DAG. We can start at the 'leaf' nodes, for which all successors will either be the `win` state, which has a known reward of 1, or the `end` state, which has a known reward of 0. By working backward, we can therefore compute the values of all of the nodes. This special structure is fortunate, because it means we can solve very large models efficiently, particularly if we exploit the fact that we can organize the states into [layers](/articles/2017/12/10/counting-states-enumeration-2048.html#appendix-b-layers-and-mapreduce-for-parallelism) by the sum of their tiles. In the enumeration step, we worked forward from the start states. In the solve step, we can instead work backward through the layers. (Actually, with some additional bookkeeping, we can also work backwards by part with the same maximum tile value to further reduce the amount of data we have to process in any single batch.)



If we carry out this calculation for the 2x2 game to the `8` tile, we arrive at a somewhat simplified diagram in which each state has only a single action, namely the optimal action:

<p align="center">
<a href="/assets/2048/mdp_2x2_3_optimal.svg"><img src="/assets/2048/mdp_2x2_3_optimal.svg" alt="MDP model with only the optimal actions for the 2x2 game up to the 8 tile" /></a>
</p>

The number below each state is the value function for that state. It is notable that for this example the value function is always 1, and all paths to the `end` state are through the `win` state. That is, if you play optimally, it is impossible to lose this very short game to the `8` tile.

Key figures:
- a 2x2 game to say 16 that will hopefully be small enough that it will be easy to tabulate everything and draw some non-crazy diagrams; can I think canonicalize and point to previous blog post
- will the transient probabilies be interesting for the 2x2 game? If so, can present them here; otherwise may need to wait until the 3x3 game.
- then the 2x2 game demo that runs the policy
- then give the 2x2 game up to 32; make the point that playing optimally doesn't guarantee that you can win; in fact winning is very unlikely --- maybe graph out the average value as a function of the sum
- then show the 3x3 game to 1024
- then present results on number of states --- 25M reachable; 9M if following the optimal policy; only 1 in a million games will touch more than XX states
- graph out the total reachable per sum, total if following optimal policy; and also say the 1 in a million (and possibly 1 in a thousand?) lines
- can we get anything like that for the 4x4 game to 64? need to rewrite the solver to use less memory... or spin up the OVH box again and rerun the build. That is probably the smarter answer. Just need the policy files and then can hopefully do the reduction and get some numbers; expect it will be a massive reduction.



---

<sup><a name='footnote-mashups' href='#footnote-mashups-ref'>1</a></sup> Flappy Bird was released in May 2013, but it became popular in January 2014. And I should also mention [flappy 2048](https://hczhcz.github.io/Flappy-2048/), [Doge 2048](http://doge2048.com/) and, of course, [flappy Doge 2048](http://www.donaldguy.com/Flappy-Doge2048/)?

[^2]: In case you, like me, sometimes felt like the game was scheming against you, giving you exactly the wrong tile at the wrong time, reading the source code reveals no such evil. Never attribute to malice that which can be attributed to randomness. That said, [there is a version that tries to give you the worst possible tile](https://aj-r.github.io/Evil-2048). As you might expect, it is much harder.

[^general]: This treatment of MDPs is not fully general. For example, the policy can be stochastic, in which case...

[^winning]: Getting to the 2048 tile is not the only possible objective for the game. You could instead try to collect as many points as possible, which basically means playing for as long as possible, before filling up the board. In that case, you'd essentially want to give a reward of 1 (say) for every non-losing state, and then 0 reward for the losing state. It's certainly possible to go beyond the 2048 tile, so the number of states would be much larger in that case.

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
</script>
<script src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML" type="text/javascript"></script>
