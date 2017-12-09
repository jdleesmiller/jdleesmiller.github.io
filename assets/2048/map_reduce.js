/* global d3 */

(function () {
  function MapReduce (container) {
    var HEIGHT = 300
    var PIECE_WIDTH = 40
    var START_SIZE = 60
    var PIECE_SIZE = 30
    var PAD = 5 // between pieces when split
    var GROWTH = 0.8 // assumed growth during map step (per output layer)
    var SHRINKAGE = 0.8 // assumed shrinkage during reduce step
    var MAX_SUM = 12

    var svg = container.append('svg')
      .attr('width', '100%')
      .attr('height', HEIGHT)

    var figure = svg.append('svg').attr('y', '3em')

    //
    // Utilities
    //

    function times (n, f) {
      return Array(n).fill().map(f)
    }

    function sum (array) {
      return array.reduce(function (x, y) { return x + y }, 0)
    }

    //
    // Layers and Pieces
    //
    // Each layer is made up of a list of Pieces. Each Piece has a size, which
    // represents the number of elements, and an offset, which represents its
    // vertical position. Also track for each piece whether it's been reduced
    // yet (done).
    //
    var LAYERS = []

    function getLayer (sum) {
      var index = sum / 2
      if (index >= LAYERS.length) {
        LAYERS[index] = new Layer(sum, [])
      }
      return LAYERS[index]
    }

    function Layer (sum, pieces) {
      this.sum = sum
      this.pieces = pieces
    }

    Layer.prototype.pushPiece = function (done, size, parent) {
      this.pieces.push(new Piece(this, done, this.getTotalSize(), size, parent))
    }

    Layer.prototype.split = function (pieceSize) {
      if (this.pieces.length) {
        this.pieces = this.pieces[0].split(pieceSize)
      }
    }

    Layer.prototype.getPieceIndex = function (piece) {
      return this.pieces.indexOf(piece)
    }

    Layer.prototype.getTotalSize = function () {
      return sum(this.pieces.map(Piece.size))
    }

    Layer.prototype.join = function () {
      var totalSize = this.getTotalSize()
      this.pieces = []
      this.pushPiece(true, totalSize)
    }

    Layer.prototype.map = function () {
      var layer2 = getLayer(this.sum + 2)
      var layer4 = getLayer(this.sum + 4)
      this.pieces.forEach(function (piece) {
        var pieceSize = piece.size * GROWTH
        layer2.pushPiece(false, pieceSize, piece)
        layer4.pushPiece(false, pieceSize, piece)
      })
    }

    Layer.prototype.reduce = function () {
      this.pushPiece(true, this.getTotalSize() * SHRINKAGE)
      this.pieces = [this.pieces[this.pieces.length - 1]]
    }

    Layer.prototype.tidyUp = function () {
      if (this.pieces.length) {
        this.pieces[this.pieces.length - 1].offset = 0
      }
    }

    Layer.pieces = function (layer) {
      return layer.pieces
    }

    function Piece (layer, done, offset, size, parent) {
      this.layer = layer
      this.done = done
      this.offset = offset
      this.size = size
      this.parent = parent
    }

    Piece.prototype.split = function (pieceSize) {
      var numPieces = Math.floor(this.size / pieceSize)
      var pieces = times(numPieces, function (_, i) {
        var piece = new Piece(this.layer, this.done, i * pieceSize, pieceSize)
        return piece
      }.bind(this))
      var remainder = this.size % pieceSize
      if (remainder > 0) {
        pieces.push(
          new Piece(this.layer, this.done, numPieces * pieceSize, remainder))
      }
      return pieces
    }

    Piece.key = function (piece) {
      return [piece.layer.sum, piece.offset, piece.size].join(':')
    }

    Piece.x = function (piece) {
      return piece.layer.sum * PIECE_WIDTH
    }

    Piece.offset = function (piece) {
      return piece.offset
    }

    Piece.splitOffset = function (piece) {
      return Piece.offset(piece) + piece.layer.getPieceIndex(piece) * PAD
    }

    Piece.parentX = function (piece) {
      return Piece.x(piece.parent || piece)
    }

    Piece.parentOffset = function (piece) {
      return Piece.offset(piece.parent || piece)
    }

    Piece.parentSize = function (piece) {
      return Piece.size(piece.parent || piece)
    }

    Piece.size = function (piece) {
      return piece.size
    }

    Piece.fill = function (piece) {
      return piece.done ? 'blue' : 'red'
    }

    function getAllPieces (layers) {
      return [].concat.apply([], layers.map(Layer.pieces))
    }

    //
    // Labels: the sum and Map/Reduce labels at the top.
    //

    var label
    function drawLabels () {
      var sum = -2
      var sums = times(MAX_SUM / 2 + 2, function () {
        sum += 2
        return sum
      })
      svg.selectAll('text').data(sums).enter().append('text')
        .text(function (d) {
          if (d === 0) return 's'
          if (d > MAX_SUM) return '…'
          return 's + ' + d
        })
        .attr('x', function (d) { return (d + 0.5) * PIECE_WIDTH })
        .attr('text-anchor', 'middle')
        .attr('y', '1em')

      label = svg.append('text')
        .attr('text-anchor', 'middle')
        .attr('y', '2.5em')
        .attr('display', 'none')
    }

    function setLabel (text, sum) {
      if (text) {
        label
          .text(text)
          .attr('display', null)
          .attr('x', (sum + 0.5) * PIECE_WIDTH)
      } else {
        label.attr('display', 'none')
      }
    }

    //
    // Animation
    //

    function reset () {
      LAYERS = []
      getLayer(0).pushPiece(true, START_SIZE)
      getLayer(2).pushPiece(false, START_SIZE * GROWTH)
      getLayer(2).split(PIECE_SIZE)
      setLabel(null)
    }

    function drawPiece (pieces) {
      return pieces
        .attr('width', PIECE_WIDTH)
        .attr('fill', Piece.fill)
    }

    function animateSetup (t, pieces) {
      pieces.enter().append('rect')
        .attr('x', Piece.x)
        .attr('y', Piece.splitOffset)
        .attr('height', Piece.size)
        .call(drawPiece)

      pieces.exit().remove()
    }

    function animatePreMap (t, pieces) {
      pieces.enter().append('rect')
        .attr('x', Piece.x)
        .attr('y', Piece.offset)
        .attr('height', Piece.size)
        .attr('stroke', 'grey')
        .attr('stroke-opacity', 1e-6)
        .call(drawPiece)
        .transition(t)
        .attr('stroke-opacity', 1)

      pieces.exit().remove()
    }

    function animateMap (t, pieces) {
      pieces.enter().append('rect')
        .attr('x', Piece.parentX)
        .attr('y', Piece.parentOffset)
        .attr('height', Piece.parentSize)
        .call(drawPiece)
        .transition(t)
        .attr('x', Piece.x)
        .attr('y', Piece.splitOffset)
        .attr('height', Piece.size)

      pieces.exit().remove()
    }

    function animatePostMap (t, pieces) {
      pieces.enter().append('rect')
        .attr('x', Piece.x)
        .attr('y', Piece.offset)
        .attr('height', Piece.size)
        .call(drawPiece)
        .attr('fill-opacity', 1e-6)
        .transition(t)
        .attr('fill-opacity', 1)

      pieces.exit()
        .transition(t)
        .remove()
    }

    function animateReduce (t, pieces) {
      pieces.enter().append('rect')
        .attr('x', Piece.x)
        .attr('y', Piece.splitOffset)
        .attr('height', 0)
        .call(drawPiece)
        .transition(t)
        .attr('height', Piece.size)

      pieces.exit()
        .attr('height', Piece.size)
        .transition(t)
        .attr('height', 0)
        .remove()
    }

    function animatePostReduce (t, pieces) {
      pieces
        .transition()
        .attr('y', Piece.splitOffset)
    }

    function update (animate) {
      console.log(getAllPieces(LAYERS))
      var t = d3.transition().duration(1000)
      animate(t, figure.selectAll('rect').data(getAllPieces(LAYERS), Piece.key))
      return t
    }

    this.run = function () {
      var sum

      function loop () {
        function runPreMap () {
          getLayer(sum).split(PIECE_SIZE)
          setLabel('Map', sum)
          update(animatePreMap).on('end', runMap)
        }

        function runMap () {
          getLayer(sum).map()
          update(animateMap).on('end', runPostMap)
        }

        function runPostMap () {
          getLayer(sum).join()
          update(animatePostMap).on('end', runReduce)
        }

        function runReduce () {
          getLayer(sum + 2).reduce()
          setLabel('Reduce', sum + 2)
          update(animateReduce).on('end', runPostReduce)
        }

        function runPostReduce () {
          getLayer(sum + 2).tidyUp()
          sum += 2
          update(animatePostReduce).on('end', loop)
        }

        if (sum < MAX_SUM) {
          runPreMap()
        } else {
          start()
        }
      }

      function start () {
        sum = 0
        reset()
        update(animateSetup)
        setTimeout(loop, 1000)
      }

      drawLabels()
      start()
    }
  }

  document.addEventListener('DOMContentLoaded', function () {
    new MapReduce(d3.select('#map-reduce')).run()
  })
})()
