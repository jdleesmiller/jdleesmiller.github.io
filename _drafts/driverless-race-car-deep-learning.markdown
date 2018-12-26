---
layout: post
title: "Zero to Driverless Race Car with Deep Learning"
date: 2018-12-25 16:00:00 +0000
categories: articles
image: /assets/docker_chat_demo/chat.png
description: TODO
---

This post is based on the following talk. Abstract:

<blockquote>
Learn how to train a driverless car to drive around a simulated race track using end-to-end deep learning &mdash; from camera images to steering and throttle. Key techniques include deep neural networks, data augmentation, and transfer learning. This was a course project, so I'll introduce the key ideas and talk about the practical steps needed to get it working. You'll also see a lot of very dangerous driving.
</blockquote>

&nbsp;

<div style="position:relative;padding-top:56.25%;">
  <iframe src="https://www.youtube.com/embed/h_Ma-ZA-pP0" frameborder="0" allowfullscreen
allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" style="position:absolute;top:0;left:0;width:100%;height:100%;"></iframe>
</div>

&nbsp;

# Introduction

Today I'm going to talk about how to build a driverless race car using deep learning.

I should start by saying that this was a personal project, but it does have a connection to my work. By day, I'm CTO of [Overleaf](https://www.overleaf.com), the online LaTeX editor. Overleaf now has over three million users, but the first two were driverless car researchers, namely my co-founder and I! We started Overleaf while we were working on the [Heathrow Pod](<https://en.wikipedia.org/wiki/ULTra_(rapid_transit)#Heathrow_Terminal_5>), which was the world's first driverless taxi system. It launched in 2011, and it's still running, so if you ever have some time at London's Heathrow Airport, you should take a ride on the pods out to business parking and back to Terminal 5.

<div style="columns: 2; column-width: 300px;">
  <p>
    <a href="/assets/driverless/02-overleaf.jpg">
      <img src="/assets/driverless/02-overleaf.jpg" alt="Screenshot of the Overleaf home page" style="border: 1pt solid grey;">
    </a>
  </p>
  <p>
    <a href="/assets/driverless/03-heathrow-pod.jpg">
      <img src="/assets/driverless/03-heathrow-pod.jpg" alt="Photo of a driverless taxi from the Heathrow Pod system" style="border: 1pt solid grey;">
    </a>
  </p>
</div>

The key thing allowed us to put driverless taxis into active service way back in 2011 is that the taxis run on their own roads. It's a closed system, and we used a fairly traditional systems engineering approach to design and build the system and prove that it was safe.

Most research now is about how we get driverless cars to work safely on public roads, where we need to worry about human drivers and pedestrians and cyclists and traffic lights and stop signs, and lots of other messy things.

One of the pioneers in this area is Sebastian Thrun, who was a professor at Stanford and leader of the winning team in the 2005 [DARPA Grand Challenge](https://en.wikipedia.org/wiki/DARPA_Grand_Challenge). He later left to start Udacity, one of the leading [MOOC](https://en.wikipedia.org/wiki/Massive_open_online_course) providers. Udacity (perhaps unsurprisingly!) ran a course in 2016 [^courses] on driverless cars, the Self-Driving Car Engineer nano-degree, which I took in my copious free time.

<div style="columns: 2; column-width: 300px;">
  <p>
    <a href="/assets/driverless/04-udacity.jpg">
      <img src="/assets/driverless/04-udacity.jpg" alt="Photo of a Sebastian Thrun with the Udacity driverless car" style="border: 1pt solid grey;">
    </a>
  </p>
  <p>
    <a href="/assets/driverless/05-nvidia.jpg">
      <img src="/assets/driverless/05-nvidia.jpg" alt="First page of NVIDIA's End-to-End Learning for Self-Driving Cars" style="border: 1pt solid grey;">
    </a>
  </p>
</div>

This post is based on one of the labs in that course, which is in turn based on a 2016 paper from NVIDIA, called [End-to-End Learning for Self-Driving Cars](https://arxiv.org/abs/1604.07316). What they showed is that it's possible to take images from a front-mounted camera on a car, feed them into a convolutional neural network, which we'll talk about, and have it produce steering commands to drive the car. So, just like you look at the road ahead and decide whether you need to steer left or right, they did the same thing with a neural network.

What's remarkable about this is that it's very different from the systems engineering approach that we usually use in driverless car engineering. In that approach we break the overall problem of driving the car down into lots of subproblems, such as object detection, object classification, mapping, planning, etc., and have different subsystems responsible for each of those subproblems. The subsystems are then connected up in a microservices sort of way to build the whole system. Here, however, we're just going to train one big monolithic neural network, which will somehow drive the car. It feels a bit like magic.

Our task for this lab was to reproduce this magic, and this post follows steps I went through to do so, which were broadly:

- Collect training data in a simulator by driving around the track manually.
- Train a deep neural network using the camera images and steering angles.
- Use the network to drive the car around the track (in simulation).

In the middle, I'm going to handwave quite a lot about some of the theory. You may wish to skip that part if you are already familiar with convolutional neural networks.

# Collecting Training Data

The first thing we need to do is collect training data.

[^courses]: Udacity actually ran two driverless car courses. The first was [_CS373: Programming a Robotic Car_](https://eu.udacity.com/course/artificial-intelligence-for-robotics--cs373), which I completed in 2012, and is still offered for free. The second was the [_Self Driving Car Engineer_](https://eu.udacity.com/course/self-driving-car-engineer-nanodegree--nd013) nano-degree. Both were great!
