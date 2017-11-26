---
layout: post
title: "The Mathematics of 2048: Counting States by Exhaustive Enumeration"
date: 2017-11-05 00:00:00 +0000
categories: articles
image: /assets/2048/2048_infeasible.png
description: How many board configurations are there in the game of 2048? Let's try to enumerate them.
---

&nbsp;

<img src="/assets/2048/2048_infeasible.png" alt="Screenshot of 2048 with an infeasible board configuration" style="width: 40%; float: right; margin-left: 10pt; border: 6pt solid #eee;"/>

So far in this series on the mathematics of [2048](http://gabrielecirulli.github.io/2048), we've seen that [it takes at least 938.8 moves](/articles/2017/08/05/markov-chain-2048.html) on average to win, and we've [obtained some rough estimates](/articles/2017/09/17/counting-states-combinatorics-2048.html) on the number of possible states using combinatorics.

In this post, we will try to refine those estimates by simply counting every reachable state by brute force enumeration. There are many states, so this will require some computer science as well as mathematics. With efficient processing and storage of states, we'll see that it is possible to enumerate all reachable states for 2x2 and 3x3 boards.

Enumeration of all states for the full game on a 4x4 board remains an open problem. I ran the code on an OVH HG-120 instance with 32 cores at 3.1GHz and 120GB RAM for one month, during which it enumerated 1.3 trillion states, which is a respectable half a million states per second, but that turns out to be nowhere near enough. At present, the best we we'll be able to do on the 4x4 board is to enumerate all states for the game played up to the `64` tile.

Overall, the results show that the combinatorial estimates from the last post were substantial overestimates, as suspected. However, the state space for the full game is still very large. If a large nation state or tech company decided that 2048 was their top priority, which may not be the craziest thing that's happened this year, I think they could probably finish the job. However, the full state set is unlikely to fit on your laptop any time soon.

The (research quality) code behind this article is open source, in case you would like to see the implementation or code for the plots. The code is in C++ with a ruby wrapper.

# Counting States

Here a *state* captures a complete configuration of the board by specifying which tile, if any, is in each of the board's cells. When counting states, our overall goal is to find the smallest number of states that will adequately capture all of the 'interesting' features of the game as a whole. In the previous post, the estimates from (very basic) combinatorics counted many states that can't actually occur in the game and so clearly don't capture anything very interesting. By enumerating states systematically from each of the possible start states, we ensure that the states we count are actually reachable in play.

We also have other kinds of freedom in choosing which states are interesting. Because the game ends when we obtain a `2048` tile, we won't care about where that tile is or what else is on the board, so we can condense all of the states with a `2048` tile into a special "win" state. Similarly, if we lose, we won't care exactly how we lost; we can condense all of losing states into a special "lose" state.

# Canonicalization and Symmetry

Many other non-interesting states that we'd like to avoid counting arise from the fact that some states are trivially related to each other by rotation or reflection. For example, in the game on a 2x2 board, the states
<p align="center">
  <img src="/assets/2048/2x2_s2_3_1_0.svg" alt="4 8 2 -">
  and
  <img src="/assets/2048/2x2_s3_2_0_1.svg" alt="8 4 - 2">
</p>
are just mirror images --- they are reflections through the vertical axis. If we swiped left in the first state, it would be essentially equivalent to swiping right in the second. We can therefore reduce the number of states we have to worry about by treating these states as equivalent. In general, the number of such equivalent states is the number of elements in the [dihedral group](https://en.wikipedia.org/wiki/Dihedral_group) for the square, \\(D_4\\), which is 8. For the first state above, these eight states are:
<p align="center"><img src="/assets/2048/2x2_canonical.svg" alt="Eight states with the same canonical state as 4 8 2 -"></p>
In this diagram, which is called a cycle graph, ⤴ denotes a rotation counterclockwise by 90&deg; and ↔ denotes a reflection about the vertical axis. The three states at the top are obtained by one or more rotations; for example, ⤴&sup2; means two rotations of 90&deg;, which add up to a rotation of 180&deg;. The four states at the bottom are obtained by zero or more rotations followed by a reflection.

When the tiles in a state are arranged in a symmetrical pattern, the number of equivalent states may be less than 8, because the symmetry means that some of the states in the above diagram will be identical. For example, the state <img src="/assets/2048/2x2_s2_1_1_0.svg" style="height: 2em;"> has only four, because it is symmetric along the diagonal. However, particularly on 3x3 and 4x4 boards, states with symmetric arrangements of tiles are not so common, so overall we can expect to reduce the number of states we need to count by roughly a factor of 8 by choosing only one of these equivalent states as the *canonical* state.

# States as Numbers

Which of the equivalent states should we choose as the canonical state? To answer this question, it will be helpful to think about states as numbers. We'll also see that this has significant computational benefits a bit later.

To write a state as a number, we can start in the top left and read the cells by rows; for each cell, we write a \\(0\\) digit if the cell is empty, and the digit \\(i\\) if the cell contains the \\(2^i\\) tile. For example, on a 2x2 board, the state <img src="/assets/2048/2x2_s2_3_1_0.svg" alt="4 8 2 -" style="height: 2em;">
would be written as the number \\(2310\\).

Since we're only interested in numbers up to 2048, which is \\(2^{11}\\), we could in principle write any state as a number in base 12 (rather than base 10, as we are accustomed to). However, because computers run on binary numbers, it will be more convenient to think of each state as a number in base 16 --- that is, hexadecimal. The state above would therefore be more properly written as `0x2310` for computer scientists or \\(2310_{16}\\) for mathematicians.

To find the canonical state, we simply try all eight possible rotations and reflections, convert the resulting states to numbers, and then pick the smallest one. For our example state, <img src="/assets/2048/2x2_s2_3_1_0.svg" alt="4 8 2 -" style="height: 2em;">, the candidates and their corresponding numbers are:

<table style="width: 1%; margin: 0px auto;">
<thead><tr><th>State</th><th>Number</th></tr></thead>
<tbody>
<tr><td><img src="/assets/2048/2x2_s2_3_1_0.svg" alt="4 8 2 -" style="height: 2em;"></td><td><code>0x2310</code></td></tr>
<tr><td><img src="/assets/2048/2x2_s3_2_0_1.svg" alt="8 4 - 2" style="height: 2em;"></td><td><code>0x3201</code></td></tr>
<tr><td><img src="/assets/2048/2x2_s1_0_2_3.svg" alt="2 - 4 8" style="height: 2em;"></td><td><code>0x1023</code></td></tr>
<tr><td><img src="/assets/2048/2x2_s2_1_3_0.svg" alt="4 2 8 -" style="height: 2em;"></td><td><code>0x2130</code></td></tr>
<tr><td><img src="/assets/2048/2x2_s0_3_1_2.svg" alt="- 8 2 4" style="height: 2em;"></td><td><code>0x0312</code></td></tr>
<tr><td><img src="/assets/2048/2x2_s1_2_0_3.svg" alt="2 4 - 8" style="height: 2em;"></td><td><code>0x1203</code></td></tr>
<tr><td><img src="/assets/2048/2x2_s0_1_3_2.svg" alt="- 2 8 4" style="height: 2em;"></td><td><strong><code>0x0132</code></strong></td></tr>
<tr><td><img src="/assets/2048/2x2_s3_0_2_1.svg" alt="8 - 4 2" style="height: 2em;"></td><td><code>0x3021</code></td></tr>
</tbody>
</table>

&nbsp;

The state <img src="/assets/2048/2x2_s0_1_3_2.svg" alt="- 2 8 4" style="height: 2em;"> has the smallest number, `0x0132`, so that is the canonical state for <img src="/assets/2048/2x2_s2_3_1_0.svg" alt="4 8 2 -" style="height: 2em;">.

# Enumeration

We're now ready to start enumerating states. The idea is to generate all possible (canonical) start states, then for each one try each possible move, then for each move generate all possible (canonical) successor states. In code (ruby) form, the basic algorithm for enumerating states looks like this:

```rb
def enumerate(board_size, max_exponent)
  # Open all of the possible canonicalized start states.
  opened = find_canonicalized_start_states(board_size)
  closed = Set[]

  while opened.any?
    # Treat opened as a stack, so this is a depth-first traversal.
    state = opened.pop

    # If we've already processed the state, or if this is
    # a win or lose state, there's nothing more to do for it.
    next if closed.member?(state)
    next if state.win?(max_exponent) || state.lose?

    # Process the state: open all of its possible canonicalized successors.
    [:left, :right, :up, :down].each do |direction|
      state.move(direction).random_successors.each do |successor|
        opened << successor.canonicalize
      end
    end

    closed << state
  end

  closed
end
```

The code for generating start states is [here](https://github.com/jdleesmiller/twenty48/blob/479f646e81c38f1967e4fc5942617f9650d2c735/lib/twenty48/builder.rb#L59-L68), and the code for the rest of the State methods, such as `random_successors` and `canonicalize`, is [here](https://github.com/jdleesmiller/twenty48/blob/479f646e81c38f1967e4fc5942617f9650d2c735/lib/twenty48/state.rb).

If we run this code for the 2x2 board up to the `32` tile, we get 57 states ([click to enlarge](/assets/2048/enumeration_2x2_ungrouped.svg)):
<p align="center">
  <a href="/assets/2048/enumeration_2x2_ungrouped.svg"><img src="/assets/2048/enumeration_2x2_ungrouped.svg" alt="States from the enumeration of the 2x2 game to 32"></a>
</p>
In this diagram, each edge is a possible state-successor pair. For example, from the state <img src="/assets/2048/2x2_s0_0_1_1.svg" alt="- - 2 2" style="height: 2em;">, we could swipe left or right, which would result in a `4` tile, and then the game adds a `2` or `4` tile at random, which leads to
<img src="/assets/2048/2x2_s0_1_2_0.svg" alt="- 2 4 -" style="height: 2em;">,
<img src="/assets/2048/2x2_s0_0_1_2.svg" alt="- - 2 4" style="height: 2em;">,
<img src="/assets/2048/2x2_s0_2_2_0.svg" alt="- 4 4 -" style="height: 2em;"> or
<img src="/assets/2048/2x2_s0_0_2_2.svg" alt="- - 4 4" style="height: 2em;"> after canonicalization;
or we could swipe up or down, which would leave the two `2` tiles unmerged and lead to
<img src="/assets/2048/2x2_s0_1_1_1.svg" alt="- 2 2 2" style="height: 2em;"> or
<img src="/assets/2048/2x2_s0_1_2_1.svg" alt="- 2 4 2" style="height: 2em;"> after canonicalization.

Not shown are the special 'lose' and 'win' states, so in total we have 59 states for the 2x2 game to the `32` tile. This compares favorably to the estimate of 529 states from the (simple) combinatorics arguments in the previous blog post. We've saved about one order of magnitude!

When we try to run this ruby code on the 3x3 or 4x4 boards, however, we quickly hit two problems: it's very slow, and it runs out of memory for the `closed` set. Profiling showed that it is spending most of its time manipulating states (sliding tiles, trying different reflections and rotations for canonicalization, and testing for win or lose conditions), so let's see how we can speed that up.

# Bit Bashing for Efficiency

The hexadecimal numerical representation for states has a convenient property: for the 4x4 board, we need to store 16 numbers, where each number takes 4 bits, for a total of 64 bits. Now that we all use 64-bit computers, this is an auspicious number: the whole board state can fit into a single 64-bit (8-byte) machine word. For example, the 4x4 state
<p align="center"><img src="/assets/2048/4x4_s0_2_2_11_0_1_3_0_2_0_1_0_0_0_0_0.svg" alt="- 4 4 2048 - 2 8 - 4 - 2 - - - - -"></p>
would be written `0x022b013020100000` in hexadecimal, or more clearly with the addition of line breaks
```
022b
0130
2010
0000
```

With the state represented as a 64-bit integer, we can also implement many common manipulations on states very efficiently using bit mask and shift operations, often without loops [^bit-bashing]. For example, the C++ function to reflect a 4x4 board state horizontally looks like:
```cpp
uint64_t reflect_horizontally(uint64_t state) {
  uint64_t c1, c2, c3, c4;
  c1 = state & 0xF000F000F000F000ULL;
  c2 = state & 0x0F000F000F000F00ULL;
  c3 = state & 0x00F000F000F000F0ULL;
  c4 = state & 0x000F000F000F000FULL;
  return (c1 >> 12) | (c2 >> 4) | (c3 << 4) | (c4 << 12);
}
```

While initially quite opaque, all this is doing is shuffling bits around. The role of first constant, `0xF000F000F000F000ULL`, becomes clearer if we omit the `0x` and `ULL`, which just tell the compiler that this is non-negative 64-bit integer in hexadecimal, and split it up over four lines:
```
F000
F000
F000
F000
```
The binary representation of the hexadecimal digit `F` is `1111`, so the effect of this bit mask is to make `c1` contain only the values in the first column of the board and zero bits everywhere else. The bit shift `c1 >> 12` at the end of the function moves the first column 12 bits, or three places, to the right, which makes it the last column. Similarly, `c2` selects the second column, and `c2 >> 4` moves it one place to the right, and so on with the third and fourth columns to reverse the order of the columns.

Some functions take a bit more work to decipher. If you're in the mood for a puzzle, here's a function that counts the number of cells available (value zero) in a 4x4 state (you can find [my explanation in comments here](https://github.com/jdleesmiller/twenty48/blob/479f646e81c38f1967e4fc5942617f9650d2c735/ext/twenty48/state.hpp#L68-L83)):
```cpp
int cells_available(uint64_t state) {
  state |= (state >> 2);
  state |= (state >> 1);
  state &= 0x1111111111111111ULL;
  uint64_t count = ((state * 0x1111111111111111ULL) >> 60);
  if (count == 0 && state != 0) return 0;
  return 16 - count;
}
```

Profiling (with [perf](https://en.wikipedia.org/wiki/Perf_(Linux))) showed that such tricks made a big difference --- compared to the obvious implementations with arrays and loops, these functions require very few CPU instructions and contain few or no branches, which allows the CPU to keep its [instruction pipelines](https://en.wikipedia.org/wiki/Instruction_pipelining) full. Having improved sequential speed to the point where profiling was no longer identifying any hotspots, the next step is to look at how we can parallelize.

# MapReduce for Parallelism

To break up the state space into more manageable pieces, we can use to a useful property of the game: *The sum of the tiles on the board increases by either 2 or 4 with each move.* This property holds because merging two tiles does not change the sum of the tiles on the board, and the game then adds either a 2 or a 4 tile. [^property-3]

This property is useful here because it means that we can organize the states into *layers* according to the sum of their tiles. We can therefore generate the whole state space by working through a single layer at a time, rather than having to deal with the whole state space at once.

To parallelize the work within each layer, we can use the [MapReduce](https://en.wikipedia.org/wiki/MapReduce) concept made famous by Google. The 'map' step here is to take one complete layer of states with sum \\(s\\) and break it up into pieces; then, for each piece, generate all of the successor states, which will have either sum \\(s + 2\\) or \\(s + 4\\). The 'reduce' step is to merge all of the pieces for the layer with sum \\(s + 2\\) together into a complete layer, removing any duplicates. The pieces with sum \\(s + 4\\) are retained until the next layer, in which states have sum \\(s + 2\\), is processed, at which point they will be included in the merge.

To make the merge in the reduce step efficient, we want the map step to output a sorted list of states for each piece; that way we can merge the pieces together in linear time. Fortunately, Google again comes to our aid: they released a very convenient in-memory [B-tree implementation](https://code.google.com/archive/p/cpp-btree/) that plays well with the C++ standard template library. [B-tree](https://en.wikipedia.org/wiki/B-tree) are most commonly found in relational database systems, where they are often used to maintain indexes on columns, but they are useful data structures in their own right: they provide logarithmic lookup and also logarithmic insertion --- much better than logarithmic plus linear time insertion into a sorted list, with relatively little memory overhead.

To break the state space up into even smaller pieces, which reduces the amount of work we need to do in each merge step, we can exploit an another property of the game: *the maximum tile value on the board must either stay the same or double with each move.* This property holds because the maximum tile value never decreases, and when it does increase, it can only increase as the result of merging two tiles --- that is, even if you have for example four `16` tiles in a row and you merge them, the result after one move is two `32` tiles, not one `64` tile.

Together with the property above, this means that from a list of states in which all states have tile sum \\(s\\) and maximum tile value \\(k\\), the generated successors will all fall into one of four categories:

<table>
  <tbody>
    <tr>
      <th align="right">Tile Sum</th>
      <td align="right">\(s+2\)</td>
      <td align="right">\(s+2\)</td>
      <td align="right">\(s+4\)</td>
      <td align="right">\(s+4\)</td>
    </tr>
    <tr>
      <th align="right">Max Tile Value</th>
      <td align="right">\(k\)</td>
      <td align="right">\(2k\)</td>
      <td align="right">\(k\)</td>
      <td align="right">\(2k\)</td>
    </tr>
  </tbody>
</table>

There is a bit more bookkeeping to keep track of which pieces need to be merged together at each step, but it is basically the same idea. Here's the full state space for the 2x2 game to the `32` tile again, but with the states grouped by tile sum and maximum tile value, here written \\(s / k\\):
<p align="center">
  <a href="/assets/2048/enumeration_2x2_grouped.svg"><img src="/assets/2048/enumeration_2x2_grouped.svg" alt="States from the enumeration of the 2x2 game to 32 with grouping into parts by sum and max value"></a>
</p>
For example, in the leftmost group, both states have tile sum 4 and maximum tile value `2`. The transitions are to groups with tile sum either 6 or 8 and maximum tile value `2` or `4`.

# Encoding and Compression

Finally, when we are working with billions or trillions of states, and each state takes 8 bytes, even fitting them all on disk is not trivial (or at least not cheap). To reduce the storage space required, and also the amount of input/output required, we can exploit the fact that the states are stored as large sorted lists of integers; rather than storing each integer in full, we can use a [variable-width encoding scheme](https://en.wikipedia.org/wiki/Variable-width_encoding) to store the differences between successive states (as integers). These differences will generally be smaller than the values themselves, so it is usually possible to store the differences in a smaller number of bytes.

Variable width encodings are most commonly encountered in the [UTF-8](https://en.wikipedia.org/wiki/UTF-8) character encoding for unicode, which you using as you read this webpage. They are also sometimes used for storing [integer primary key indexes](https://en.wikipedia.org/wiki/Database_index) in some relation databases, which also face the problem of efficiently storing large lists of sorted integers. The implementation used here is [libvbyte](https://github.com/cruppstahl/libvbyte) from Christoph Rupp, based on work by [Daniel Lemire](https://github.com/lemire/MaskedVbyte).

This turns out to be very effective:
TODO results

For longer term storage, I also [found by Pareto analysis](/articles/2017/05/01/compression-pareto-docker-gnuplot.html) that Facebook's [Zstandard](https://github.com/facebook/zstd) compression algorithm at level XXX happens to be extremely good at compressing the vbyte-encoded data. It reduces the storage requirement to YYY bits per state.

# Results

<p align="center">
<img src="/assets/2048/enumeration_3x3_to_1024.svg" alt="TODO" />
</p>

<table>
  <thead>
    <tr>
      <th>Board Size</th>
      <th>Maximum Tile</th>
      <th>Combinatorics Bound</th>
      <th>Actual</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>2x2</th>
      <th>32</th>
      <td align="right">529</td>
      <td align="right">58</td>
    </tr>
    <tr>
      <th>3x3</th>
      <th>1024</th>
      <td align="right">786,513,819</td>
      <td align="right">25,179,013</td>
    </tr>
    <tr>
      <th>4x4</th>
      <th>64</th>
      <td align="right">2,816,814,940,129</td>
      <td align="right">41,051,975,514</td>
    </tr>
    <tr>
      <th>4x4</th>
      <th>2048</th>
      <td align="right">44,096,167,159,459,777</td>
      <td align="right">Unknown</td>
    </tr>
  </tbody>
</table>


---

There are several operations we need to perform:
1. Moving (sliding) the tiles.
1. Transpose the board (like a matrix, on its NW-SE diagonal)
1. Reflect horizontally
1. Reflect vertically

Moving the tiles is somewhat complicated, but we can break the board down and just consider one row (or column, if we transpose the board) at a time. Within a single row, there are 4 cells, and each cell has 4 bits, so in total we only have 16 bits, or 2 bytes, or about 65k values. We can therefore just enumerate all of them and keep a lookup table.










count every reachable state by brute force enumeration. Here a *state* captures a complete configuration of the board by specifying which tile, if any, is in each of the board’s cells. The basic approach will be to enumerate all of the possible starting states, and then for each of those consider all possible moves the player could make, and then for each of those enumerate each of the possible successor states, and so on recursively until we reach winning states.

Intuitively, and based on the estimates from the previous post, we might expect that there are a lot of states, and we'll see that this is indeed the case.

However, with some interesting computational tricks, we will be able to complete the enumeration of states on 2x2 and 3x3 boards and on the 4x4 board up to the 64 tile. In particular, we'll see how to apply:

- a healthy (?) dose of [bit bashing](https://en.wikipedia.org/wiki/Bit_manipulation) to efficiently represent and manipulate states,
- Google's [MapReduce](https://en.wikipedia.org/wiki/MapReduce) framework to parallelize the computation,
- Google's [in-memory implementation](https://github.com/google/btree) of the venerable [B-tree](https://en.wikipedia.org/wiki/B-tree) data structure mostly commonly found in relational databases,
- a [variable-width encoding](https://en.wikipedia.org/wiki/Variable-width_encoding) approach most commonly found in the [UTF-8](https://en.wikipedia.org/wiki/UTF-8) character encoding for unicode and also for storing [integer primary key indexes](https://en.wikipedia.org/wiki/Database_index) in some relation databases, and finally
- Facebook's [Zstandard](https://github.com/facebook/zstd) compression algorithm to store the data with remarkably effective compression --- XXXb per state.


# Enumeration of States



For the four equivalent states above, the corresponding numbers would be:

One way to do this is to
```
2 1 1 0
```


- numbering states
- canonicalization
- mapreduce
  - idea: can just do breadth first search, but we quickly run out of memory
  - so cut up the state space into small pieces that we know can't overlap
  - can we get a diagram showing the progression for the 2x2 game?



# Symmetry and Canonicalization

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

The number of symmetries is the number of elements in the [dihedral group](https://en.wikipedia.org/wiki/Dihedral_group) for the square, \\(D_4\\), which has 8 elements. When the tiles are arranged in a symmetrical pattern, the reduction in the number of states due to canonicalization may be lower than 8, but in most cases it does map 8 states to a single canonical state.

# Enumeration

```rb
def enumerate(board_size, max_exponent)
  opened = find_canonicalized_start_states(board_size)
  closed = Set[]
  while (state = opened.pop)
    next if closed.member?(state)
    next if state.win?(max_exponent) || state.lose?
    DIRECTIONS.each do |direction|
      state.move(direction).random_successors.each do |successor|
        opened << successor.canonicalize
      end
    end
    closed << state
  end
  closed
end
```

# MapReduce

Use 'property 3' again to partition the states into layers.

Generating successors is the 'map' state.

Reducing in this case means merging the sets of successor states together, removing duplicates.

Can also use another property: the maximum tile value can either stay the same or double.

So, from a state with sum \\(n\\) and maximum tile \\(k\\), you can go to
- \\((n+2, k)\\)
- \\((n+2, 2k)\\)
- \\((n+4, k)\\)
- \\((n+4, 2k)\\)

There is a bit more bookkeeping to This further reduces the number of states that we need to merge together at any one time.

To make the merging efficient, we basically need sorted lists of states. To maintain the sorted lists, use a B-tree. The B-tree has logarithmic lookup and also logarithmic insertion --- much better than logarithmic plus linear time insertion into a sorted list, with relatively little memory overhead. Fortunately Google provides a very convenient in-memory B-tree implementation that plays well with the C++ STL. I also benchmarked this against a hashtable, albeit one with a fairly naive linear probing scheme for resolving collisions, and found that the B-tree was faster and also easier to use, because it didn't require me to guess the number of successor states in order to avoid having to grow the table.

# Encoding and Compression

The next question is how we can store the sorted lists. The simplest way to do this is to store them directly, with 8 bytes per state. However, we can do better by (1) delta encoding and then (2) using a variable width encoding to store the deltas.

Once the map reduce process has moved on to the next layer (or next part), we can also compress the delta-encoded files. After trying several compression algorithms (link to previous blog post), I found that Zstandard level XXX did a particularly good job on this dataset.

Graph of Pareto frontier.

# Results

<table>
  <thead>
    <tr>
      <th>Maximum Tile</th>
      <th>Number of States</th>
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
      <th align="right" valign="top" rowspan="2">8</th>
      <td>Combinatorics Estimate</td>
      <td align="right">73</td><td align="right">19,665</td><td align="right">43,046,689</td>
    </tr>
    <tr>
      <td>Actual</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="2">16</th>
      <td>Baseline</td>
      <td align="right">233</td><td align="right">261,615</td><td align="right">4,294,901,729</td>
    </tr>
    <tr>
      <td>Layer Reachability</td>
      <td align="right">233</td><td align="right">261,615</td><td align="right">4,294,901,729</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="2">32</th>
      <td>Baseline</td>
      <td align="right">537</td><td align="right">1,933,425</td><td align="right">152,544,843,873</td>
    </tr>
    <tr>
      <td>Layer Reachability</td>
      <td align="right">529</td><td align="right">1,933,407</td><td align="right">152,544,843,841</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="2">64</th>
      <td>Baseline</td>
      <td align="right">1,033</td><td align="right">9,815,535</td><td align="right">2,816,814,940,129</td>
    </tr>
    <tr>
      <td>Layer Reachability</td>
      <td align="right">905</td><td align="right">9,814,437</td><td align="right">2,816,814,934,817</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="2">128</th>
      <td>Baseline</td>
      <td align="right">1,769</td><td align="right">38,400,465</td><td align="right">33,080,342,678,945</td>
    </tr>
    <tr>
      <td>Layer Reachability</td>
      <td align="right">905</td><td align="right">38,369,571</td><td align="right">33,080,342,314,753</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="2">256</th>
      <td>Baseline</td>
      <td align="right">2,793</td><td align="right">124,140,015</td><td align="right">278,653,866,803,169</td>
    </tr>
    <tr>
      <td>Layer Reachability</td>
      <td align="right">905</td><td align="right">123,560,373</td><td align="right">278,653,849,430,401</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="2">512</th>
      <td>Baseline</td>
      <td align="right">4,153</td><td align="right">347,066,865</td><td align="right">1,819,787,258,282,209</td>
    </tr>
    <tr>
      <td>Layer Reachability</td>
      <td align="right">905</td><td align="right">339,166,485</td><td align="right">1,819,786,604,950,209</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="2">1024</th>
      <td>Baseline</td>
      <td align="right">5,897</td><td align="right">865,782,255</td><td align="right">9,718,525,023,289,313</td>
    </tr>
    <tr>
      <td>Layer Reachability</td>
      <td align="right">905</td><td align="right">786,513,819</td><td align="right">9,718,504,608,259,073</td>
    </tr>

    <tr>
      <th align="right" valign="top" rowspan="2">2048</th>
      <td>Baseline</td>
      <td align="right">8,073</td><td align="right">1,970,527,185</td><td align="right">44,096,709,674,720,289</td>
    </tr>
    <tr>
      <td>Layer Reachability</td>
      <td align="right">905</td><td align="right">1,400,665,575</td><td align="right">44,096,167,159,459,777</td>
    </tr>

  </tbody>
</table>

# Footnotes

[^bit-bashing]: The bit bashing techniques used here are based mainly on [2048-ai](https://github.com/nneonneo/2048-ai/blob/1f25f2e19e82a477600fd1b437e710d584f99e99/2048.cpp) by Robert Xiao and [2048-c](https://github.com/kcwu/2048-c/blob/209a1f5ea635222a859c493a90d3304328117af3/micro_optimize.cc) by Kuang-che Wu, with some help from [Bit Twiddling Hacks](http://graphics.stanford.edu/~seander/bithacks.html) by Sean Eron Anderson. The original motivation for 2048-ai and 2048-c was to allow real time search for 2048 AI bots.

[^property-3]: This property was called called *Property 3* in the [previous post](/articles/2017/09/17/counting-states-combinatorics-2048.html), and we also used it anonymously in the [first post](/2017/08/05/markov-chain-2048.html). It is a very useful property.

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
</script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS-MML_HTMLorMML" type="text/javascript"></script>
