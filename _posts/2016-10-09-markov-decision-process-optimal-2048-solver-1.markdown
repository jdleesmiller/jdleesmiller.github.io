---
layout: post
title: "The Mathematics of 2048 &mdash; Part 1: How Many States are There?"
date: 2016-10-09 16:00:00 +0000
categories: articles
---

<img src="/assets/2048/2048.png" alt="Screenshot of 2048" style="width: 40%; float: right; margin-left: 10pt; border: 6pt solid #eee;"/>

For several months in early 2014, everyone was addicted to [2048](http://gabrielecirulli.github.io/2048). Like the Rubik's cube, it is a very simple game, and yet it is very compelling. It seems to strike the right balance along so many dimensions --- not too easy but not too hard; not too predictable but comfortingly familiar; not too demanding but still absorbing.

To better understand what makes the game work so well, I have been trying to analyze it mathematically. In this first part, we'll work toward answering one of the most basic questions we can ask about the game: how many possible configurations of the board ("states") are there?

In future parts, we'll explore how many moves it can take to win the game, and then how to model the game as a Markov Decision Process, which may in principle let us 'solve' the game --- that is, to find the best possible way to play. The insights gained in each part will help us in the next.

## The Name of the Game

Let's start with a recap of the rules of the game and some useful properties.

The board comprises 16 cells in a 4x4 grid. Each cell can be empty or can contain a tile with a value that is a power of 2 between 2 and 2048. There are 11 such powers of 2, namely 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 and 2048.

Twice at the beginning of the game and then after each move, the game places a random tile on the board. We can see exactly how by [reading the game's source code](https://github.com/gabrielecirulli/2048): it selects an empty cell uniformly at random and then places there a `2` tile with probability 0.9 or a `4` tile with probability 0.1. The game therefore starts with two randomly placed tiles on the board, each of which is either a `2` or a `4`.

The player moves `left`, `right`, `up` or `down`, and all of the tiles slide as far as possible in that direction. If two tiles with the same value slide together, they merge into a single tile with twice that value. For example, if two `8` tiles merge, the result is a single `16` tile.

The game continues until either (a) a `2048` tile is obtained, in which case the player wins, or (b) the board is full and it is not possible to move any tile, in which case the player loses. The game will let you play past the `2048` tile, but for now we'll restrict our attention to the primary objective, which is to reach the `2048` tile.

## Brain Power

### Let Me Count the Ways: Combinatorics

We're now ready to start counting the number of possible board positions, which here we'll call *states*. We will start with some very coarse estimates and then refine them. It will also help to generalize to 2048-like games played on different sized boards (not just 4x4) and up to different tiles (not just the 2048 tile). We'll see that the smaller games are much more tractable, and we'll use them to develop the key ideas in later sections.

The most basic way to estimate the number of states in 2048 is to observe that there are 16 cells, and each cell can either be blank or contain a tile with a value that is one of the 11 powers of 2 from 2 to 2048. That gives 12 possibilities for each of the 16 cells, for a total of \\(12^{16}\\) possible states that we can write in this way. That is 184 quadrillion (~\\(10^{17}\\)) states, which won't fit on my laptop any time soon.

More generally, let \\(B\\) be the board size, and let \\(K\\) be the exponent of the winning tile with value \\(2^K\\). For convenience, let \\(C\\) denote the number of cells on the board, so \\(C=B^2\\). For the usual 4x4 game to 2048, \\(B=4\\), \\(C=16\\), and \\(K = 11\\), since \\(2^{11} = 2048\\), and our estimate for the number of states is \\[(K + 1)^C.\\] Now let's see how we can refine this estimate.

First, since the game ends when we obtain a \\(2^K\\) tile, we don't particularly care about where that tile is or what else is on the board. We can therefore condense all of the states with a \\(2^K\\) tile into a special "win" state. In the remaining states, each cell can either be blank or hold one of \\(K - 1\\) tiles. This reduces the number of states we have to worry about to \\[K^C + 1\\] where the \\(1\\) is for the win state.

Second, we can observe that some of those \\(K^C\\) states can never occur in the game. In particular, the rules of the game imply two important properties:

**Property 1:** There are always at least two tiles on the board.

**Property 2:** There is always at least one `2` or `4` tile on the board.

The first property holds because even if you start with two tiles and merge them, there is still one left, and then the game adds a random tile, leaving two tiles. The second property holds because the game always adds a `2` or `4` tile after each move.

We therefore know that in any valid state there must be at least two tiles on the board, and that one of them must be a `2` or `4` tile. To account for this, we can subtract all states with no `2` or `4` tile, of which are \\((K-2)^C\\), and also the states with just one `2` tile and all other cells empty, of which there are \\(C\\), and the states with only one `4` tile and all other cells empty, of which there are again \\(C\\). This gives an estimate of
\\[K^C - (K-2)^C - 2C + 1\\]
states in total. Of course, when \\(K\\) or \\(C\\) is large, this looks pretty much just like \\(K^C\\), which is the dominant term, but this correction is more significant for smaller values.

Let's use this formula to tabulate the estimated number of states various board sizes and maximum tiles:

<table>
  <thead>
    <tr>
      <th>Maximum Tile</th>
      <th colspan="3">Board Size</th>
    </tr>
    <tr>
      <th></th>
      <th align="right">2x2</th>
      <th align="right">3x3</th>
      <th align="right">4x4</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="right">8</td>
      <td align="right">73</td>
      <td align="right">19,665</td>
      <td align="right">43,046,689</td>
    </tr>
    <tr>
      <td align="right">16</td>
      <td align="right">233</td>
      <td align="right">261,615</td>
      <td align="right">4,294,901,729</td>
    </tr>
    <tr>
      <td align="right">32</td>
      <td align="right">537</td>
      <td align="right">1,933,425</td>
      <td align="right">152,544,843,873</td>
    </tr>
    <tr>
      <td align="right">64</td>
      <td align="right">1,033</td>
      <td align="right">9,815,535</td>
      <td align="right">2,816,814,940,129</td>
    </tr>
    <tr>
      <td align="right">128</td>
      <td align="right">1,769</td>
      <td align="right">38,400,465</td>
      <td align="right">33,080,342,678,945</td>
    </tr>
    <tr>
      <td align="right">256</td>
      <td align="right">2,793</td>
      <td align="right">124,140,015</td>
      <td align="right">278,653,866,803,169</td>
    </tr>
    <tr>
      <td align="right">512</td>
      <td align="right">4,153</td>
      <td align="right">347,066,865</td>
      <td align="right">1,819,787,258,282,209</td>
    </tr>
    <tr>
      <td align="right">1024</td>
      <td align="right">5,897</td>
      <td align="right">865,782,255</td>
      <td align="right">9,718,525,023,289,313</td>
    </tr>
    <tr>
      <td align="right">2048</td>
      <td align="right">8,073</td>
      <td align="right">1,970,527,185</td>
      <td align="right">44,096,709,674,720,289</td>
    </tr>
  </tbody>
</table>

We can see immediately that the 2x2 and 3x3 games have far fewer states than the 4x4 game. Using the argument above, we've also also managed to reduce our estimate for the number of tiles in the 4x4 game to 2048 to "only" 44 quadrillion, or \\(10^{16}\\).

### Don't Look Back: Non-Recurrence

The rules of the game also imply another important property:

**Property 3:** The sum of the tiles on the board increases by either 2 or 4 with each move.

This holds because merging two tiles does not change the sum of the tiles on the board, and the game then adds either a `2` or a `4` tile.

An important consequence of Property 3 is that states never repeat in the course of a game --- that is, states do not recur. This means that we can organize the states into *layers* according to the sum of their tiles. If the game is in a state in the layer with sum 10, we know that the next state must be in the layer with sum 12 or sum 14. We can also therefore count the number of states in each layer, to get an idea of how the game progresses over time.

Let \\(S\\) denote the sum of the tiles on the board. We want to count the number of ways that up to \\(C\\) numbers, each of which is a power of 2 between 2 and \\(2^{K-1}\\), can be added together to produce \\(S\\).

Fortunately, this turns out to be a variation on a well-studied problem in combinatorics: counting the [compositions of an integer](TODO). In general, a composition of an integer \\(S\\) is an ordered collection of integers that sum to \\(S\\); each integer in the collection is called a *part*. For example, there are four compositions of the integer \\(3\\), namely \\(1 + 1 + 1\\), \\(1 + 2\\), \\(2 + 1\\) and \\(3\\). When there are restrictions on the parts, such as being a power of two and only having a certain number of parts, the term is a *restricted* composition.

Even more fortunately, Chinn and Niederhausen (XXXX) have already studied exactly this kind of restricted composition and derived a recurrence that allows us count the number of compositions in which there are a specific number of parts, and each part is a power of 2. Let \\(N(s, c)\\) denote the number of compositions of a (positive) integer \\(s\\) into exactly \\(c\\) parts where each part is a power of 2. It then holds that
\\[
N(s, c) = \\begin{cases}
\\sum_{i = 0}^{\\lfloor \\log_2 s \\rfloor} N(s - 2^i, c - 1), & 2 \\le c \\le s \\\\\\\\
1, & c = 1 \\textrm{ and } s \\textrm{ is a power of 2} \\\\\\\\
0, & \\textrm{otherwise}
\\end{cases}
\\]
because for every composition of \\(s - 2^i\\) into \\(c - 1\\) parts, we can obtain a composition of \\(s\\) with \\(c\\) parts by adding one part with value \\(2^i\\).

We now just need to make a few minor adjustments to the summation bounds: we would like to use powers of 2 starting at 2 and at most \\(2^{K-1}\\), since if we have a \\(2^K\\) tile the game is won. To this end, let \\(N_m(s, c)\\) denote the number of compositions of \\(s\\) into exactly \\(c\\) parts where each part is a power of 2 between \\(2^m\\) and \\(2^{K-1}\\). This is given by
\\[
N_m(s, c) = \\begin{cases}
\\sum_{i = m}^{K - 1} N(s - 2^i, c - 1), & 2 \\le c \\le s \\\\\\\\
1, & c = 1 \\textrm{ and }
     s = 2^i \\textrm{ for some } i \\in \\{ m, \\ldots, K-1 \\} \\\\\\\\
0, & \\textrm{otherwise}
\\end{cases}
\\]
following the same logic as above.

Now we have a formula for exactly \\(c\\) parts, but we want a formula for up to \\(c\\) parts. We can follow the same rationale as in the previous section: subtract off the states with no 2 or 4 tile, of which there are \\(N_3(s, c)\\). According to property 1, we need at least 2 parts, so we start summing at \\(c=2\\). This gives
\\[
\\sum_{c = 2}^{C} {C \\choose c} \\left( N_1(s, c) - N_3(s, c) \\right)
\\]
as our estimate for the number of states with sum \\(s\\). Here \\(C \\choose c\\) is a [binomial coefficient](TODO) that gives the number ways of choosing \\(c\\) of the possible \\(C\\) cells into which to place the tiles. Let's plot it out.

<p align="center">
<img src="/assets/2048/layers_summary.png" alt="Number of states by sum of tiles (with K=11)" />
</p>

We can have \\(C\\) values, each up to \\(2^{K-1}\\), so the maximum achievable sum is \\(C 2^{K-1}\\). If we sum over all of the possible sums from 4 to \\(C 2^{K-1}\\), and add one for the special win state, we get the same number of states as we estimated in the previous section, which is a helpful sanity check.

In terms of magnitude, we can see that the 2x2 game never has more than 60 states with a given sum, the 3x3 game peaks at about 3 million states, and the 4x4 game peaks at about 32 trillion states (\\(10^{13}\\)). The number of states grows rapidly early in the game but then tapers off and eventually decreases as the board fills up. On the decreasing portion of the curve, we see discontinuities: particularly for higher sums, it may happen that there are no tiles that will fit on the board and sum to that value.

### A Bridge too Far: Layer Reachability

Another useful consequence of Property 3 is that if two consecutive layers have no states, it's not possible to reach later layers. This is because the sum can increase by at most 4 per turn; if there are two adjacent zeros, then the sum would have to increase by 6 in order to reach the subsequent layer. If we calculate which layers have zero states, we find that the largest reachable layer sums without ever attaining a `2048` tile are:

<table style="width: auto;">
  <thead>
    <tr>
      <th>Board Size</th>
      <th>Largest Tile Sum from Layers</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>2x2</td>
      <td align="right">60</td>
    </tr>
    <tr>
      <td>3x3</td>
      <td align="right">2,044</td>
    </tr>
    <tr>
      <td>4x4</td>
      <td align="right">9,212</td>
    </tr>
  </tbody>
</table>

This gives us another nice result: it is not possible to reach the `2048` tile on a 2x2 or 3x3 board, because the largest achievable sum is less than 2048. Essentially, there is not enough room on the board. The highest tile we can reach on the 2x2 board is the `32` tile, and the highest on the 3x3 board is the `1024` tile.

This also allows us to tighten up our estimates for the total number of states, by discarding unreachable states in layers after the largest reachable layer.


<table>
  <thead>
    <tr>
      <th>Maximum Tile</th>
      <th>Method</th>
      <th colspan="3">Board Size</th>
    </tr>
    <tr>
      <th></th>
      <th></th>
      <th align="right">2x2</th>
      <th align="right">3x3</th>
      <th align="right">4x4</th>
    </tr>
  </thead>
  <tbody>

    <tr>
      <th align="right" valign="top" rowspan="4">8</th>
      <td>Baseline</td>
      <td align="right">82</td><td align="right">19,684</td><td align="right">43,046,722</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">73</td><td align="right">19,665</td><td align="right">43,046,689</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">73</td><td align="right">19,665</td><td align="right">43,046,689</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">70</td><td align="right">8,461</td><td align="right">675,154</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="4">16</th>
      <td>Baseline</td>
      <td align="right">257</td><td align="right">262,145</td><td align="right">4,294,967,297</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">233</td><td align="right">261,615</td><td align="right">4,294,901,729</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">233</td><td align="right">261,615</td><td align="right">4,294,901,729</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">198</td><td align="right">128,889</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="4">32</th>
      <td>Baseline</td>
      <td align="right">626</td><td align="right">1,953,126</td><td align="right">152,587,890,626</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">537</td><td align="right">1,933,425</td><td align="right">152,544,843,873</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">529</td><td align="right">1,933,407</td><td align="right">152,544,843,841</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">350</td><td align="right">975,045</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="4">64</th>
      <td>Baseline</td>
      <td align="right">1,297</td><td align="right">10,077,697</td><td align="right">2,821,109,907,457</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">1,033</td><td align="right">9,815,535</td><td align="right">2,816,814,940,129</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">905</td><td align="right">9,814,437</td><td align="right">2,816,814,934,817</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">478</td><td align="right">4,702,959</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="4">128</th>
      <td>Baseline</td>
      <td align="right">2,402</td><td align="right">40,353,608</td><td align="right">33,232,930,569,602</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">1,769</td><td align="right">38,400,465</td><td align="right">33,080,342,678,945</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">905</td><td align="right">38,369,571</td><td align="right">33,080,342,314,753</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">478</td><td align="right">16,418,531</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="4">256</th>
      <td>Baseline</td>
      <td align="right">4,097</td><td align="right">134,217,729</td><td align="right">281,474,976,710,657</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">2,793</td><td align="right">124,140,015</td><td align="right">278,653,866,803,169</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">905</td><td align="right">123,560,373</td><td align="right">278,653,849,430,401</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">478</td><td align="right">44,971,485</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="4">512</th>
      <td>Baseline</td>
      <td align="right">6,562</td><td align="right">387,420,490</td><td align="right">1,853,020,188,851,842</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">4,153</td><td align="right">347,066,865</td><td align="right">1,819,787,258,282,209</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">905</td><td align="right">339,166,485</td><td align="right">1,819,786,604,950,209</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">478</td><td align="right">102,037,195</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="4">1024</th>
      <td>Baseline</td>
      <td align="right">10,001</td><td align="right">1,000,000,001</td><td align="right">10,000,000,000,000,001</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">5,897</td><td align="right">865,782,255</td><td align="right">9,718,525,023,289,313</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">905</td><td align="right">786,513,819</td><td align="right">9,718,504,608,259,073</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">478</td><td align="right">201,032,939</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="4">2048</th>
      <td>Baseline</td>
      <td align="right">14,642</td><td align="right">2,357,947,692</td><td align="right">45,949,729,863,572,162</td>
    </tr>
    <tr>
      <td>Improved</td>
      <td align="right">8,073</td><td align="right">1,970,527,185</td><td align="right">44,096,709,674,720,289</td>
    </tr>
    <tr>
      <td>Truncated</td>
      <td align="right">905</td><td align="right">1,400,665,575</td><td align="right">44,096,167,159,459,777</td>
    </tr>
    <tr>
      <td>Reachable</td>
      <td align="right">478</td><td align="right">330,122,597</td><td align="right">?</td>
    </tr>

  </tbody>
</table>

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

Let's see how many states we count when we take into account reachability.

<table>
  <thead>
    <tr>
      <th>Maximum Tile</th>
      <th colspan="4">Board Size / Bound</th>
    </tr>
    <tr>
      <th></th>
      <th align="right">2x2 Reachable</th>
      <th align="right">2x2 Upper Bound</th>
      <th align="right">3x3 Reachable</th>
      <th align="right">3x3 Upper Bound</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="right">8</td>
      <td align="right">70</td>
      <td align="right">73</td>
      <td align="right">8461</td>
      <td align="right">19,665</td>
    </tr>
    <tr>
      <td align="right">16</td>
      <td align="right">198</td>
      <td align="right">233</td>
      <td align="right">128,889</td>
      <td align="right">261,615</td>
    </tr>
    <tr>
      <td align="right">32</td>
      <td align="right">350</td>
      <td align="right">537</td>
      <td align="right">975,045</td>
      <td align="right">1,933,425</td>
    </tr>
    <tr>
      <td align="right">64</td>
      <td align="right">477</td>
      <td align="right">1,033</td>
      <td align="right">4,702,960</td>
      <td align="right">9,815,535</td>
    </tr>
    <tr>
      <td align="right">128</td>
      <td align="right">477</td>
      <td align="right">1,769</td>
      <td align="right">16,418,531</td>
      <td align="right">38,400,465</td>
    </tr>
    <tr>
      <td align="right">256</td>
      <td align="right">477</td>
      <td align="right">2,793</td>
      <td align="right">44,971,485</td>
      <td align="right">124,140,015</td>
    </tr>
    <tr>
      <td align="right">512</td>
      <td align="right">477</td>
      <td align="right">4,153</td>
      <td align="right">102,037,195</td>
      <td align="right">347,066,865</td>
    </tr>
    <tr>
      <td align="right">1024</td>
      <td align="right">477</td>
      <td align="right">5,897</td>
      <td align="right">201,032,939</td>
      <td align="right">865,782,255</td>
    </tr>
    <tr>
      <td align="right">2048</td>
      <td align="right">477</td>
      <td align="right">8,073</td>
      <td align="right">330,122,597</td>
      <td align="right">1,970,527,185</td>
    </tr>
  </tbody>
</table>

### By Any Other Name: Canonicalization

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

#### Canonicalization

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

#### Non-Recurrence

A useful property of 2048 is that sum of the tiles on the board always increases by either 2 or 4 with each move. This property does not help us reduce the size of the state space, but we'll see that it does help us cut up the set of all possible states, so we don't have to worry about all of the states at once.

To see that the property holds, we can observe that:

1. The game adds a `2` or `4` tile after each move, which increases the sum of the tile values by either 2 or 4, and

2. if the player merges two tiles with the same value, that does not change the sum of the tile values.

For example, if we start with two `2` tiles, they contribute \\(2 + 2 = 4\\) to the sum, and the player merges them, the resulting `4` tile still contributes \\(4\\) to the sum.

This means that we can organize the states into *layers* according to the sum of their tiles. If the game is in a state in the layer with sum 10, we know that the next state must be in the layer with sum 12 or sum 14. This also implies that states never repeat in the course of the game: every move increases the sum.

#### Solving the Toddler Version

- ideas:
  - could generate all reachable states without canonicalization, just to show how much less than 627 it is. I wonder whether it will be 250 --- 2 * 5**3.
  - some sort of D3 visualization of all of the states and the optimal policy; I guess we could instead show all of the possible action transitions and just highlight the ones that occur in the optimal policy, but it's already a lot of lines even with just the optimal transitions shown
  - explain the optimality idea last?

- can't get to 2048
- how to show the game? would like to get one picture
- bottleneck

# SCRATCH


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
