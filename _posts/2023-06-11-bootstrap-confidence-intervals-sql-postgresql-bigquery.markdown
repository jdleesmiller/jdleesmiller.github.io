---
layout: post
title: "Bootstrap Confidence Intervals in SQL for PostgreSQL and BigQuery"
date: 2023-06-11 12:00:00 +0000
categories: articles
image: /assets/sql-bootstrap/cats-example.png
description: Calculate bootstrap confidence intervals in mostly standard SQL, for PostgreSQL and BigQuery.
---

A confidence interval is a good way to express the uncertainty in an estimate. This post is about how to calculate approximate confidence intervals in portable (mostly) standard SQL using [bootstrapping](<https://en.wikipedia.org/wiki/Bootstrapping_(statistics)>). We'll also see that BigQuery is surprisingly fast at running the required bootstrap calculations, which makes it easy to add a confidence interval to nearly any point estimate you calculate in BigQuery.

The code for this article is [open source](https://github.com/jdleesmiller/sql-bootstrap).

### Background: Confidence Intervals and the Bootstrap

Let's start with some background on confidence intervals and the bootstrap, illustrated with a small example. If you already know all about these, feel free to [skip to the queries](#the-bootstrap-in-sql).

Suppose we want to find the average mass of an (adult, domestic) cat [^cat-mass], and we've started by selecting 10 cats at random and measuring their masses in kilograms:

<div class="small-table" markdown="block">

|Name        | Mass (kg)|
|:-----------|---------:|
|Apollo      |       3.2|
|Bean        |       2.4|
|Casper      |       6.9|
|Daisy       |       3.2|
|Ella        |       5.1|
|Finn        |       3.5|
|Ginger      |       5.9|
|Harley      |       3.3|
|Iago        |       5.5|
|Jasper      |       5.4|
|**Mean**    |       4.4|
|**Std Dev** |       1.5|

</div>

The _sample mean_ for these ten cats is 4.4kg, with a standard deviation of 1.5kg. What can we now say about the _population mean_ for all cats? The sample mean is our best estimate for the population mean, but it may be inaccurate, because it is based on a (very) small subset of the population; this inaccuracy is called sampling error. A confidence interval quantifies sampling error by calculating an interval that we can be confident, up to a defined confidence level, contains the population mean. For example, one of the methods we'll use below calculates a confidence interval at the 95% level for the average mass of a cat as [3.4kg, 5.5kg] based on these 10 measurements.

Before looking at how to calculate that interval, it's worth spending a few words on what it means. Firstly, it is not a claim that 95% of all cats weigh between 3.4kg and 5.5kg; instead, it is a claim that the *mean* over all cats is likely in this range. Secondly, it is not strictly speaking a claim that the population mean lies in that range "with probability 0.95" [^credible-interval]. Instead, the preferred interpretation is that, if one were to repeat the whole experiment many times, each time re-running all the data collection and analysis on a new sample to calculate a 95% confidence interval, the (fixed) population mean would lie outside the calculated interval in only 5% of the repeats. This is somewhat sobering, firstly because we have no way of knowing if the one experiment we actually did was one of the unlucky 5%, and secondly because, even if we do everything right, if we do a lot of different experiments we should expect to be wrong in 5% of them. That is still, however, better than one is likely to do with point estimates alone!

On to the confidence interval calculations without bootstrapping. Under the (here reasonable) assumption that the population distribution is normal, which is to say that the distribution of the mass of all cats is normal, a confidence interval can be obtained from the quantiles of the [\\(t\\)-distribution](https://en.wikipedia.org/wiki/Student%27s_t-distribution). In particular, for a sample of size \\(n\\) with sample mean \\(\\bar{x}\\) and (sample) standard deviation \\(s\\), the endpoints of a \\(C \\times 100 \\%\\) confidence interval are given by
\\begin{equation}
\\bar{x} \\pm Q_t\\left(\\frac{1-C}{2}, n - 1\\right) \\frac{s}{\\sqrt{n}}
\\label{t-ci}
\\end{equation}
where \\(Q_t(\\alpha, k)\\) denotes the quantile function of the \\(t\\)-distribution with \\(k\\) degrees of freedom, evaluated at quantile \\(\\alpha\\), where in this case \\(\\alpha = \\frac{1-C}{2}\\) and \\(k = n - 1\\). The second term in the above equation is the standard error of the sample mean, scaled by the \\(Q_t\\) quantile. For a 95% confidence level and sample size 10, \\(\\alpha = 0.025\\), \\(k = 9\\), and the \\(Q_t\\) factor is -2.26, which leads to the interval [3.4kg, 5.5kg], as noted above [^q196].  

The process for finding the bootstrap confidence interval looks very different. Rather than a formula, it is an algorithm. To calculate a bootstrap confidence interval, we repeatedly _resample_ this original sample, with replacement, and compute the mean for each resample. The first such resampling might be:

<div class="small-table" markdown="block">

|Name        | Mass (kg)|
|:-----------|---------:|
|Apollo      |       3.2|
|Bean        |       2.4|
|Casper      |       6.9|
|Casper      |       6.9|
|Casper      |       6.9|
|Casper      |       6.9|
|Ella        |       5.1|
|Ella        |       5.1|
|Finn        |       3.5|
|Finn        |       3.5|
|**Mean**    |       5.1|
|**Std Dev** |       1.8|

</div>

Here we've chosen Casper four times and left out several of the other cats altogether, as can happen when resampling with replacement. Casper is a rather heavy cat, which has pulled up the mean for this resample to 5.1kg. The second resample might then be:

<div class="small-table" markdown="block">

|Name        | Mass (kg)|
|:-----------|---------:|
|Casper      |       6.9|
|Casper      |       6.9|
|Daisy       |       3.2|
|Finn        |       3.5|
|Finn        |       3.5|
|Finn        |       3.5|
|Ginger      |       5.9|
|Harley      |       3.3|
|Harley      |       3.3|
|Jasper      |       5.4|
|**Mean**    |       4.6|
|**Std Dev** |       1.6|

</div>

This time, some of the cats that were missing from the first sample reappear, and there are fewer Caspers pulling up the mean, so it returns to 4.6kg, closer to our original sample. If we then repeat this process 998 more times to collect a total of 1000 resampled means, we are likely to find something like the following bootstrap distribution:

<p align="center">
<img src="/assets/sql-bootstrap/cats-example.svg" alt="Histogram of the empirical bootstrap distribution of the mean mass of a cat. The distribution is roughly bell-shaped, centered roughly on the sample mean of 4.4kg, with tails from roughly 3kg to roughly 6kg." style="max-height: 40em;" />
</p>

To form the desired 95% confidence interval, the simplest approach is to simply read off the the 2.5% and 97.5% quantiles from this empirical bootstrap distribution as the 95% confidence interval, which in this case gives the interval [3.6kg, 5.3kg]. 

One way to think about bootstrapping is as a 'what if' sensitivity analysis with the observations in a sample. It essentially asks for each observation, what would our estimate look like if we had not collected this observation? Or if we'd seen this observation several times instead of just once? If the sample is large, or if the observations are fairly similar, then losing or double counting a few of them shouldn't make a big difference, and bootstrap distribution will be sharp and the confidence interval tight. If, on the other hand, the sample is smaller, or there is more variability in the observations, then the bootstrap distribution will be more dispersed and the confidence interval wider.

This example hints at several important caveats:

1. Bootstrap CIs require a lot of computation. There is no hard and fast rule for the number of resamples that one should use, but 1000 is generally regarded as the minimum for calculation of confidence intervals. This means that instead of computing a statistic once, bootstrapping requires that it be computed thousands of times. Fortunately, the required computation can be efficiently parallelized, as we shall see below.
1. Bootstrap CIs are approximate. In [many common cases](https://en.wikipedia.org/wiki/Confidence_interval#Confidence_interval_for_specific_distributions), there are more accurate and efficient methods of calculating confidence intervals. They should be used where possible. Bootstrapping is still a useful technique for more complicated cases or as an additional check on other methods.
1. The 'percentile bootstrap' approach of calculating the confidence interval directly from the quantiles of the bootstrap distribution is simple to implement and intuitively appealing, but it is known to produce intervals that are too narrow, particularly for small sample sizes. This may explain why the bootstrap interval obtained above was narrower than the \\(t\\) interval. There are some ways to correct for this [^correction], but this approach will do for now.

### The Bootstrap in SQL

Now that we've seen the idea behind the bootstrap, let's see an example of how to implement it in SQL. Suppose we have scaled up our cat weighing experiment and now have a table, `cats`, with 10000 rows. Each row records a unique identifier for the cat and its mass in kilograms.

```sql
> SELECT count(*) FROM cats;
count
-------
10000
(1 row)

> SELECT * FROM cats ORDER BY random() LIMIT 10;
  id  |       mass       
------+------------------
 3091 | 4.25136586892616
 5680 | 4.34285504738124
 5895 | 5.63979916384868
 1952 |  5.1710561140116
 3847 | 4.82984705465995
 2861 | 4.33598448266297
  592 | 6.52217568717482
 2915 | 3.87406259543517
 6338 |  4.0396866933194
 6726 | 4.71685250612103
(10 rows)
```

The mean mass for this sample is given by:

```sql
SELECT avg(mass) FROM cats;
        avg        
-------------------
 4.492052081409403
(1 row)
```

The following query calculates a 95% CI around this estimate using 1000 resamples (for PostgreSQL; the query for BigQuery is [here](https://github.com/jdleesmiller/sql-bootstrap/blob/d654236aa6f669fcd5ab68c3827d40eeb95d3092/example-sql/bq-bootstrap-pure-percent.sql)):

```sql
WITH bootstrap_indexes AS (
  SELECT generate_series(1, 1000) AS bootstrap_index
),
bootstrap_data AS (
  SELECT mass, ROW_NUMBER() OVER (ORDER BY id) - 1 AS data_index
  FROM cats
),
bootstrap_map AS (
  SELECT floor(random() * (
    SELECT count(data_index) FROM bootstrap_data)) AS data_index,
    bootstrap_index
  FROM bootstrap_data
  JOIN bootstrap_indexes ON TRUE
),
bootstrap AS (
  SELECT bootstrap_index,
    avg(mass) AS mass_avg
  FROM bootstrap_map
  JOIN bootstrap_data USING (data_index)
  GROUP BY bootstrap_index
),
bootstrap_ci AS (
  SELECT
    percentile_cont(0.025) WITHIN GROUP (ORDER BY mass_avg) AS mass_lo,
    percentile_cont(0.975) WITHIN GROUP (ORDER BY mass_avg) AS mass_hi
  FROM bootstrap
),
sample AS (
  SELECT avg(mass) AS mass_avg
  FROM cats
)
SELECT *
FROM sample
JOIN bootstrap_ci ON TRUE;
```

Let's take it one [CTE](https://www.postgresql.org/docs/13/queries-with.html) at a time:

1. `bootstrap_indexes` enumerates the bootstrap resamples, 1 to 1000, as `bootstrap_index`.
1. `bootstrap_data` generates a contiguous sequence of row numbers, one for each row in the input data, `data_index`. (Here I've used `id` as the natural way to order the rows, but you could use anything.) The `- 1` is important, because it makes the sequence start from 0 rather than 1, and the next CTE will generate random indexes starting at 0.
1. `bootstrap_map` performs the resampling with replacement by generating 10000 random integers in the range of the `data_index` for each of the 1000 resamples. The `JOIN bootstrap_indexes ON TRUE` produces the full [Cartesian product](https://en.wikipedia.org/wiki/Cartesian_product) of the bootstrap and data indexes, so for 1000 resamples of 10000 observations, there are 10 million rows in this CTE.
1. `bootstrap` computes the mean mass for each resample by joining the bootstrap data with the bootstrap map by `data_index`, grouping by `bootstrap_index`, and calculating the mean within each group (i.e. within each resample).
1. `bootstrap_ci` uses the `percentile_cont` [ordered-set aggregate function](https://www.postgresql.org/docs/13/functions-aggregate.html) to find the 2.5% and 97.5% percentiles of the empirical bootstrap distribution.
1. `sample` computes the most likely estimate as we did above.

Finally, we put them all together to get a single row with the most likely estimate, `mass_avg`, as above, and the confidence interval bounds, `mass_lo` and `mass_hi`:

```sql
     mass_avg      |      mass_lo      |     mass_hi      
-------------------+-------------------+------------------
 4.492052081409403 | 4.470893493719024 | 4.51113963545513
(1 row)
```

That is, our estimate here is 4.49kg with 95% CI [4.47kg, 4.51kg]. In this case, the data were [generated](https://github.com/jdleesmiller/sql-bootstrap/blob/d654236aa6f669fcd5ab68c3827d40eeb95d3092/make-example-data.R) with a true mass of 4.5kg, so the mean is not far out, and the true rate is within the 95% confidence interval, as we'd expect to happen 95% of the time. (If you rerun the same query on the example data, you may get somewhat different numbers due to randomness in the bootstrap sampling, but with 1000 resamples they should not be very different very often.)

This query takes ~20s to run on my instance, and `EXPLAIN ANALYZE` shows most of that time is spent joining the `bootstrap_map` and `bootstrap_data` back together in the `bootstrap` CTE. Let's see if we can speed it up.

### The Poisson Bootstrap in SQL

The overall effect of resampling with replacement is that each of the observations in the original sample is used a random number of times in any given resample. One way to think of this random number of times is as a _bootstrap weight_ for each observation in each resample. Returning to the cats example above, the first two resamples could instead have been expressed in terms of bootstrap weights, as follows:

<table style="margin-bottom: 30px;">
  <thead>
    <tr>
      <th colspan="2">Original Sample</th>
      <th>Resample 1</th>
      <th>Resample 2</th>
      <th>&hellip;</th>
      <th>Resample 1000</th>
    </tr>
    <tr>
      <th style="text-align: left">Name</th>
      <th style="text-align: right">Mass (kg)</th>
      <th>Bootstrap Weight</th>
      <th>Bootstrap Weight</th>
      <th>&hellip;</th>
      <th>Bootstrap Weight</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="text-align: left">Apollo</td>
      <td style="text-align: right">3.2</td>
      <td style="text-align: right">1</td>
      <td style="text-align: right">0</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Bean</td>
      <td style="text-align: right">2.4</td>
      <td style="text-align: right">1</td>
      <td style="text-align: right">0</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Casper</td>
      <td style="text-align: right">6.9</td>
      <td style="text-align: right">4</td>
      <td style="text-align: right">2</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Daisy</td>
      <td style="text-align: right">3.2</td>
      <td style="text-align: right">0</td>
      <td style="text-align: right">1</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Ella</td>
      <td style="text-align: right">5.1</td>
      <td style="text-align: right">2</td>
      <td style="text-align: right">0</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Finn</td>
      <td style="text-align: right">3.5</td>
      <td style="text-align: right">2</td>
      <td style="text-align: right">3</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Ginger</td>
      <td style="text-align: right">5.9</td>
      <td style="text-align: right">0</td>
      <td style="text-align: right">1</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Harley</td>
      <td style="text-align: right">3.3</td>
      <td style="text-align: right">0</td>
      <td style="text-align: right">2</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Iago</td>
      <td style="text-align: right">5.5</td>
      <td style="text-align: right">0</td>
      <td style="text-align: right">0</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
    <tr>
      <td style="text-align: left">Jasper</td>
      <td style="text-align: right">5.4</td>
      <td style="text-align: right">0</td>
      <td style="text-align: right">1</td>
      <td style="text-align: center">&hellip;</td>
    </tr>
  </tbody>
</table>

For example, Casper appears in the first resample 4 times and so has weight 4. For each resample, the weights sum up to the number of observations in the original sample, namely 10. To calculate the mean mass for each resample, we take the weighted average of the cat masses using the bootstrap weights.

In general, for a sample of \\(n\\) original observations, the bootstrap weights for each resample jointly follow a \\(\\textrm{Multinomial}(n,\\frac{1}{n},\\ldots,\\frac{1}{n})\\) [distribution](https://en.wikipedia.org/wiki/Multinomial_distribution). The approach in the [Poisson bootstrap](https://www.unofficialgoogledatascience.com/2015/08/an-introduction-to-poisson-bootstrap26.html) is to make two simplifying approximations to how we generate these bootstrap weights:

1. Approximate the \\(n\\)–dimensional multinomial distribution with \\(n\\) independent \\(\\textrm{Binomial}(n, \\frac{1}{n})\\) [distributions](https://en.wikipedia.org/wiki/Binomial_distribution). The advantage is that the independent binomial distributions for each observation can be sampled in parallel [^multinomial-binomial]. The disadvantage is that the total number of observations in a resample, which was constrained to be exactly \\(n\\) in the multinomial case, may not add up to \\(n\\) in the binomial case. When computing a statistic like a mean, where we divide through by the number of observations, this turns out not to make much difference, provided \\(n\\) is large enough to avoid very sparse resamples (\\(n \\gtrapprox 100\\)).

1. Approximate the \\(\\textrm{Binomial}(n, \\frac{1}{n})\\) distribution by a \\(\\textrm{Poisson}(1)\\) [distribution](https://en.wikipedia.org/wiki/Poisson_distribution). This is a [good approximation](https://en.wikipedia.org/wiki/Binomial_distribution#Poisson_approximation) for any reasonably large \\(n\\), and it avoids having the weights depend on \\(n\\), which is again helpful for parallel running.

These simplifications allow us to avoid the join that was the most expensive part of the 'pure' bootstrap; instead, the query attaches the Poisson weights directly to the observations and computes the required weighted mean. The Poisson bootstrap query for the `cats` example with 1000 resamples looks like this (for PostgreSQL; the query for BigQuery is [here](https://github.com/jdleesmiller/sql-bootstrap/blob/d654236aa6f669fcd5ab68c3827d40eeb95d3092/example-sql/bq-bootstrap-poisson-percent.sql)):

```sql
WITH bootstrap_indexes AS (
  SELECT generate_series(1, 1000) AS bootstrap_index
),
bootstrap_data AS (
  SELECT mass, bootstrap_index, random() AS bootstrap_u
  FROM cats
  JOIN bootstrap_indexes ON TRUE
),
bootstrap_weights AS (
  SELECT bootstrap_data.*, (CASE
    WHEN bootstrap_u < 0.367879441171442 THEN 0
    WHEN bootstrap_u < 0.735758882342885 THEN 1
    WHEN bootstrap_u < 0.919698602928606 THEN 2
    WHEN bootstrap_u < 0.981011843123846 THEN 3
    WHEN bootstrap_u < 0.996340153172656 THEN 4
    WHEN bootstrap_u < 0.999405815182418 THEN 5
    WHEN bootstrap_u < 0.999916758850712 THEN 6
    WHEN bootstrap_u < 0.999989750803325 THEN 7
    WHEN bootstrap_u < 0.999998874797402 THEN 8
    WHEN bootstrap_u < 0.999999888574522 THEN 9
    WHEN bootstrap_u < 0.999999989952234 THEN 10
    WHEN bootstrap_u < 0.999999999168389 THEN 11
    WHEN bootstrap_u < 0.999999999936402 THEN 12
    WHEN bootstrap_u < 0.99999999999548 THEN 13
    WHEN bootstrap_u < 0.9999999999997 THEN 14
    ELSE 15 END) AS bootstrap_weight
  FROM bootstrap_data
),
bootstrap AS (
  SELECT bootstrap_index,
    sum(bootstrap_weight * mass) / sum(bootstrap_weight) AS mass_avg
  FROM bootstrap_weights
  GROUP BY bootstrap_index
),
bootstrap_ci AS (
  SELECT
    percentile_cont(0.025) WITHIN GROUP (ORDER BY mass_avg) AS mass_lo,
    percentile_cont(0.975) WITHIN GROUP (ORDER BY mass_avg) AS mass_hi
  FROM bootstrap
),
sample AS (
  SELECT avg(mass) AS mass_avg
  FROM cats
)
SELECT *
FROM sample
JOIN bootstrap_ci ON TRUE;
```

Let's again take it one CTE at a time:

- `bootstrap_indexes` is as it was in the pure case.
- `bootstrap_data` generates 1000 \\(\\textrm{Uniform}(0,1)\\) random numbers for each of the 10000 observations; like `bootstrap_map` in the 'pure' bootstrap query above, it has 10 million rows.
- `bootstrap_weights` converts these variates from the uniform distribution to the Poisson distribution using [inverse transform sampling](https://en.wikipedia.org/wiki/Inverse_transform_sampling), in which we invert the Poisson cumulative distribution function [^do-not-combine]. The `CASE` statement here is basically an unrolled loop generated from [this R code](https://github.com/jdleesmiller/sql-bootstrap/blob/d654236aa6f669fcd5ab68c3827d40eeb95d3092/make-sql-bootstrap.R#L22-L35); it encodes that, when drawing from the \\(\\textrm{Poisson}(1)\\) distribution, one obtains 0 with probability 0.368, 0 or 1 with probability 0.736, 0, 1, or 2 with probability 0.920, and so on, up to 15 where the probability is so close to 1 that we start to hit the limits of 64-bit floating point numbers.
- `bootstrap` again computes the mean mass for each resample, but this time it does so by finding a weighted average using the bootstrap weights.
- `bootstrap_ci` and `sample` are exactly as before.

This query produces essentially the same results, but in ~12s rather than ~20s for the 'pure' bootstrap query above, which may not seem like much given all the extra mathematics, but it can be a larger savings for larger datasets.

### Benchmark Results

So, let's see some timings for the pure and Poisson approaches and PostgreSQL and BigQuery, as we vary the size of the sample:

<p align="center">
<img src="/assets/sql-bootstrap/benchmark.svg" alt="Running times with Postgres for the Pure Bootstrap and Poisson Bootstrap increase from near zero for one thousand cats to roughly 2200s and 700s, respectively. Running times with BigQuery remain near zero over the entire range." style="max-height: 40em;" />
</p>

These are wall clock times for 1000 bootstrap resamples. The Postgres instance used here was a Google Cloud SQL instance with 4 vCPUs and 16GiB of RAM, running Postgres 15.2. Each point is based on 10 trials. The error bars are (of course!) bootstrap 95% CIs.

The main conclusions are that the Poisson queries run faster than the pure queries, and that BigQuery is a lot faster than Postgres on both kinds of queries. Execution times with BigQuery remained essentially constant over the whole range. This is basically because BigQuery parallelized the bootstrap across many nodes, whereas Postgres ran it serially. The CPU times that BigQuery reported for queries that I ran manually were comparable to the wall clock times for Postgres.

I had hoped Postgres would also parallelize the queries, but it did not. It only ever used one out of its four available cores. The [docs](https://www.postgresql.org/docs/15/parallel-safety.html) indicate that `random` is currently labelled as `PARALLEL RESTRICTED`, which might be a contributing factor.

It would be unwise to draw any conclusions about the absolute or relative costs of Postgres and BigQuery from these results, but I did learn a few things related to costs, so here they are. I spent £35 on running the Cloud SQL instance for a few days and £12 on 100 "flat rate flex slots" for BigQuery for a few hours. That said, the Cloud SQL instance was not always busy, and I had to rerun some tests after all my results perished in a `make` accident [^precious]. Had I avoided that, it probably would have finished in about half the time (and cost). The queries with less than \\(10^6\\) cats all ran fine in BigQuery's on-demand pricing model and apparently fit within the free tier. For the larger datasets, I hit a limit (understandably) on the amount of CPU time they were using for the bootstrap resamples, which was very large compared to the size of the input data that the query was billed on. To get around that, I had to reserve some capacity, which required putting in a quota increase request but was otherwise a fairly painless process.

Finally, we should check that the generated intervals are correct. Here is a comparison with the `boot` package from R:

<p align="center">
<img src="/assets/sql-bootstrap/check.svg" alt="There is a violin plot for each method used, and all of the violins are roughly similar in their position and shape. The line for Student's t intervals runs somewhere through the thickest part of the violin in each case, but generally there is more mass on the inside of the interval, indicating some undercoverage." style="max-height: 40em;" />
</p>

Each row shows the distribution of the 95% confidence interval endpoints over 100 bootstrapping trials for a fixed sample of 100 cats, as computed with R as the baseline, and Postgres and BigQuery using the 'pure' and Poisson bootstrap queries above. The plots also include the \\(t\\) intervals from equation \\eqref{t-ci} and, because this is synthetic data, the normal CI calculated from the true population variance used to generate the dataset.

There is good agreement between the distributions for R and the two SQL queries, which indicates that the queries are computing the right things. All of the bootstrap percentile intervals undercover somewhat with respect to the \\(t\\) interval, which as noted above is a common problem for percentile intervals. There are some methods that attempt to correct for this [^correction]. For this particular sample, the \\(t\\) interval is also too narrow compared to the interval obtained using the true population variance, but on average it would cover correctly here.

### Conclusions

We have seen how to implement bootstrap confidence intervals in (mostly) standard SQL. The full set of example queries is [here](https://github.com/jdleesmiller/sql-bootstrap/tree/d654236aa6f669fcd5ab68c3827d40eeb95d3092/example-sql). The queries run remarkably quickly in BigQuery, and they are usable for relatively small samples, at least, in Postgres. Using the Poisson approximation can significantly speed up the queries.

Where a [standard formula](https://en.wikipedia.org/wiki/Confidence_interval#Confidence_interval_for_specific_distributions) exists for confidence intervals, it is usually best to use it. However, if you do need to bootstrap, and all you have is SQL, it turns out you can do it. 

### Footnotes

[^cat-mass]: This seems like the sort of thing that should be known, but estimates vary. Googling `cat` produces an info box with a range of 3.6kg–4.5kg, apparently without a definition (what quantiles?) or source. Wikipedia says [4kg-5kg](https://en.wikipedia.org/wiki/Cat#Size). National Geographic gives a rather broader range of [5lb-20lb](https://www.nationalgeographic.com/animals/mammals/facts/domestic-cat), which is 2.3kg–9.1kg. Anyway, it is just an example.
[^credible-interval]: For that, one instead wants a Bayesian interval estimate, often called a [credible interval](https://en.wikipedia.org/wiki/Credible_interval). Fortunately, the two kinds of intervals do agree in many important cases.
[^q196]: In this formula, the exact \\(Q_t\\) quantile for a 95% confidence interval is often replaced with the constant 1.96, which is the corresponding quantile for the normal distribution. This approximation is good for large samples, since the \\(t\\) distribution approaches the Normal distribution as the sample size increases. On a sample of size 10, it yields something more like a 92% confidence interval. Put differently, if we lazily use 1.96 instead of the correct \\(t\\) quantile, we should expect to be wrong 8% of the time instead of 5% of the time, which is about 60% more often! Most spreadsheets now have a `T.DIST` function, so using the right number is not much more work. Maybe databases will catch up eventually.
[^multinomial-binomial]: It may be helpful to think of this in physical terms. The physical analogy for the multinomial distribution would be rolling an \\(n\\)-sided die \\(n\\) times; the weight of an observation would be the number of times the die lands on the corresponding face. For the binomial approximation, it would be flipping a (very) unfair coin with probability \\(\\frac{1}{n}\\) of coming up heads; each observation gets its own coin, which is flipped \\(n\\) times, and the observation's weight is the number of heads. Instead of rolling one giant die, which might look more like a disco ball, for the whole sample, the binomial approximation lets us flip the \\(n\\) independent coins in parallel.
[^do-not-combine]: It might be tempting to combine the `bootstrap_data` and `bootstrap_weights` CTEs, but `CASE WHEN random() < x THEN y WHEN random() < z THEN w ...` will generate a new random number for each `WHEN`, rather than repeatedly testing the same random number against the breaks of the target CDF. That might be an interesting way to sample from a Geometric distribution, but it is not what we want here.
[^precious]: If you hit Ctrl-C to interrupt `make`, it deletes the target by default, because it doesn't want to leave half-built files hanging around. That is not what you want when the target is a CSV with all your results in it. The solution is to mark the target as `.PRECIOUS`.
[^correction]: There are [several ways](<https://en.wikipedia.org/wiki/Bootstrapping_(statistics)#Deriving_confidence_intervals_from_the_bootstrap_distribution>) to calculate a confidence interval from the bootstrap distribution, of which the percentile bootstrap is the simplest. Queries for the "Studentized" bootstrap are available in the companion repo [here for Postgres](https://github.com/jdleesmiller/sql-bootstrap/blob/d654236aa6f669fcd5ab68c3827d40eeb95d3092/example-sql/pg-bootstrap-pure-student.sql) and [here for BigQuery](https://github.com/jdleesmiller/sql-bootstrap/blob/d654236aa6f669fcd5ab68c3827d40eeb95d3092/example-sql/bq-bootstrap-pure-student.sql). The Studentized intervals seem to have better coverage, but in my experience they are quite sensitive to outliers. I am not sure there is any broad consensus on which one of these approaches is best overall.

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
</script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS-MML_HTMLorMML" type="text/javascript"></script>
