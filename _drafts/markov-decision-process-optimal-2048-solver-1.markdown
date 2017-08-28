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

This also allows us to tighten up our estimates for the total number of states, by discarding unreachable states in layers after the largest reachable layer. This has a large effect on the 2x2 board, since many states are invalid, and it has some effect on the 3x3 board. On the 4x4 board, there is very little effect --- we remove "only" 500 billion states from the total for the game to 2048.

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
      <th align="right" valign="top" rowspan="5">8</th>
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
      <td>Canonical</td>
      <td align="right">16</td><td align="right">1,187</td><td align="right">84,660</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="5">16</th>
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
      <td>Canonical</td>
      <td align="right">36</td><td align="right">16,835</td><td align="right">23,482,822</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="5">32</th>
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
      <td>Canonical</td>
      <td align="right">58</td><td align="right">124,373</td><td align="right">1,566,798,893</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="5">64</th>
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
      <td>Canonical</td>
      <td align="right">74</td><td align="right">594,047</td><td align="right">41,051,975,514</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="5">128</th>
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
      <td>Canonical</td>
      <td align="right">74</td><td align="right">2,064,919</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="5">256</th>
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
      <td>Canonical</td>
      <td align="right">74</td><td align="right">5,643,585</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="5">512</th>
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
      <td>Canonical</td>
      <td align="right">74</td><td align="right">12,789,512</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="5">1024</th>
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
      <td>Canonical</td>
      <td align="right">74</td><td align="right">25,179,013</td><td align="right">?</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="5">2048</th>
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
    <tr>
      <td>Canonical</td>
      <td align="right">74</td><td align="right">41,325,017</td><td align="right">?</td>
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

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
</script>
<script src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML" type="text/javascript"></script>
