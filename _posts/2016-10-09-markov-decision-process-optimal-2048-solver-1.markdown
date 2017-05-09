---
layout: post
title: "Towards an Optimal 2048 Solver with Markov Decision Processes &mdash; Part 1"
date: 2016-10-09 16:00:00 +0000
categories: articles
---

<p align='center'>
  <img src='/assets/2048/2048.png' width='30%' alt='Screenshot of 2048'>
</p>

The first half of 2014 was bad for productivity. It gave rise to a trifecta of distraction with [flapping birds](https://en.wikipedia.org/wiki/Flappy_Bird), [simulated goats](https://en.wikipedia.org/wiki/Goat_Simulator), and merging tiles --- the remarkably addictive [2048](http://gabrielecirulli.github.io/2048). <sup><a name='footnote-mashups-ref' href='#footnote-mashups'>1</a></sup> We have mostly [moved on](https://www.google.com/trends/explore?date=2014-01-01%202014-12-31&q=%2Fm%2F0_gzt9y,2048,goat%20simulator&hl=en) since then, but in this article I'd like to revisit this fun little puzzle game. In particular, I'll use an enormously powerful mathematical decision making framework called a Markov Decision Process (MDP) for the very important task of deciding whether to swipe left, right, up or down.

I have two motivations. First, 2048 is a nice way to learn about MDPs. This article doesn't assume any prior knowledge of MDPs, and it will introduce the necessary concepts as they arise. Second, MDPs hold the promise of obtaining a *provably optimal* solution for the game &mdash; a way of playing that we can show mathematically to be the (or a) best possible way of playing.

There are already [lots of good strategies](http://stackoverflow.com/a/22389702/2053820) and [good bots](http://stackoverflow.com/questions/22342854/what-is-the-optimal-algorithm-for-the-game-2048) for playing 2048 --- if in doubt, check out this [video of a bot playing well past the 8192 tile](https://www.youtube.com/watch?v=96ab_dK6JM0). However, the bots are based on heuristics, which give no particular guarantees on how well they play. It might be possible to play much better than the strongest current bots and humans, or not; by using MDPs we may be able to find out.

Before we get too excited, however, I should point out the 'Towards' in the title. We will see that the full game of 2048 is in fact quite hard, and we won't get all the way to a provably optimal solution, at least not right now, and at least not on my laptop. Instead, we'll start with games with the same rules but on smaller boards, which we'll see are easier to solve.

## 2048 for Toddlers and Small Computers

In this part 1, we'll investigate a 'toddler' version of the game, on a 2-by-2 board &mdash; one quarter the size of the 4-by-4 board on which 2048 is normally played. We'll see that there's still quite a bit that can be said, even for the toddler version.

Let's start by recapping the rules of 2048, which we can deduce from [its freely available source code](https://github.com/gabrielecirulli/2048):

1. When the game starts, the board contains two tiles in random positions. Each tile is either a 2, with probability 0.9, or a 4, with probability 0.1.

1. For each move, we can swipe left, right, up or down to slide all the tiles as far as possible in that direction. If two tiles with the same value slide together, they merge into a single tile with value equal to the sum of the two tiles.

1. After each move, the game places one new tile in a random position. Again, the new tile either has value 2, with probability 0.9, or value 4, with probability 0.1. [^2]

1. The game ends when either (a) the board is full, and it is not possible to move any tile, in which case we lose, or (b) a tile with value 2048 is reached.

The toddler version on the 2-by-2 board is played with the same rules as the full game, except that, as we'll see later, it's not possible to make it all the way to the 2048 tile on a 2-by-2 board. We'll instead settle for winning at a lower value.

To illustrate the rules, here is a quick example:

```
2    -- right --> 2 2   or  4 2  or    2  or    2
  2                 2         2      2 2      4 2
```

## A Markov Decision Process Approach

MDPs are a way of looking at problems that involve making decisions in the presence of uncertainty. Such problems are all around us, and MDPs are simple but powerful way of approaching them, with many [applications](http://stats.stackexchange.com/questions/145122/real-life-examples-of-markov-decision-processes) in [economics](https://en.wikipedia.org/wiki/Decision_theory#Choice_under_uncertainty), [finance](https://www.minet.uni-jena.de/Marie-Curie-ITN/SMIF/talks/Baeuerle.pdf), and [artificial intelligence](http://incompleteideas.net/sutton/book/the-book.html). If you are not familiar with MDPs, 2048 provides a nice example to learn more about them in practice --- while there are some heavy mathematics at work behind the scenes, setting up a problem as an MDP and solving it is often surprisingly easy.

In this part 1, we'll start with the toddler version of 2048, which is played on a 2-by-2 board. We'll learn how to model the game as an MDP, and we'll see how we can solve all 2-by-2 games. In part 2, we'll graduate to a 3-by-3 board. We'll see that some more clever techniques are required to reduce the problem size enough for us to actually solve 3-by-3 games. Finally, in part 3, we'll turn our hand to the grown-up version on a 4-by-4 board. There the curse of dimensionality will finally catch up with us, and we will abandon all hope of provable optimality for the time being; we'll instead shift focus to approximate solution techniques based on what we've learned on the smaller boards.

All of the code and most of the data (except some really big files) used for this article [are available here](https://github.com/jdleesmiller/twenty_48). The code is leading the articles --- I haven't written part 2 yet, but the code for part 2 and many of the results are already available there.

and we'll define the game in the terms used in a Markov Decision Process: states, actions, and rewards.

A *state* is a configuration of the board; it specifies the position of all of the tiles on the board. From this state, we take an *action* to bring us to a new, *successor state*. However, the action does not uniquely determine the successor state; there is an element of chance, because the game adds a random tile after we swipe. Again, it's a 2 with probability 0.9 or a 4 with probability 0.1.


The transition probabilities encode the rules of the game.

Next we need to define the objective. There are several different objectives we might have --- maximising the score (in 2048, your score increases every time you merge tiles), playing for as long as possible, or getting to the maximum tile as quickly as possible. In MDP terms, we will receive a reward of 1 when we win and repeat this forever, basking in glory.

The problem with basking in glory forever is that your sums will diverge. To avoid this, we need to introduce a discount rate. A discount rate captures what in finance is usually phrased as the time value of money --- that a dollar you get today is worth more than a dollar you get tomorrow. A mathematically convenient way of representing this is to "discount" future rewards by a constant factor less than 1, usually denoted \\(\\gamma\\) (gamma). If \\(\\gamma = 0.95\\), it means that a dollar you get tomorrow is worth the same to you as $0.95 today.

# SCRATCH

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

---

<sup><a name='footnote-mashups' href='#footnote-mashups-ref'>1</a></sup> Flappy Bird was released in May 2013, but it became popular in January 2014. And I should also mention [flappy 2048](https://hczhcz.github.io/Flappy-2048/), [Doge 2048](http://doge2048.com/) and, of course, [flappy Doge 2048](http://www.donaldguy.com/Flappy-Doge2048/)?

[^2]: In case you, like me, sometimes felt like the game was scheming against you, giving you exactly the wrong tile at the wrong time, reading the source code reveals no such evil. Never attribute to malice that which can be attributed to randomness. That said, [there is a version that tries to give you the worst possible tile](https://aj-r.github.io/Evil-2048). As you might expect, it is much harder.

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
</script>
<script src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML" type="text/javascript"></script>
