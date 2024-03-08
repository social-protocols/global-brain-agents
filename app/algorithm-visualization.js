// TODO:
// -- shift further right according to whether child node has siblings (so that posts are not plotted on top of each other)
// -- plot edge with low opacity how much the note *would* have been affected by the parent if there were no sub top note

let currentScores = r2d3.data.score_data
let scoreEvents = r2d3.data.score_events
let voteEvents = r2d3.data.vote_events

let CHILD_NODE_SPREAD = 400
let CHILD_PARENT_OFFSET = 150

let ROOT_POST_RECT_X = 450
let ROOT_POST_RECT_Y = 30

let POST_RECT_WIDTH = 250
let POST_RECT_HEIGHT = 65

let LINEPLOT_X_OFFSET = -5
let LINEPLOT_Y_OFFSET = 120
let LINEPLOT_WIDTH = 300

let postLookup = {}
currentScores.forEach((d) => {
  postLookup[d["postId"]] = d
})

let children = {}
currentScores.forEach((d) => {
  let parentId = d["parentId"]
  if (!(parentId in children)) {
    children[parentId] = [d]
  } else {
    children[parentId].push(d)
    children[parentId].sort((a, b) => {
      return b["effect_on_parent"] - a["effect_on_parent"]
    })
  }
})

function assignPositionsFromRootRecursive(postId) {
  let post = postLookup[postId]
  if (postId in children) {
    let spread = 0
    let stepSize = 0
    if (children[postId].length > 1) {
      spread = CHILD_NODE_SPREAD
      stepSize = spread / (children[postId].length - 1)
    }
    children[postId].forEach((child, i) => {
      child.x = post.x + i * stepSize
      child.y = post.y + CHILD_PARENT_OFFSET
      assignPositionsFromRootRecursive(child["postId"])
    })
  }
  return post
}

let root = children["null"][0]
root.x = ROOT_POST_RECT_X
root.y = ROOT_POST_RECT_Y
assignPositionsFromRootRecursive(root["postId"])

r2d3.svg.html("")

// -----------------------------------
// --- LINE PLOTS --------------------
// -----------------------------------

let rootPostScore = scoreEvents.filter((d) => d["postId"] === root["postId"])
let rootPostVotes = voteEvents.filter((d) => d["postId"] === root["postId"])

let maxVoteEventId = d3.max(voteEvents, (d) => d.voteEventId)

let scaleProbability = d3.scaleLinear()
  .domain([0, 1])
  .range([100, 0])
let scaleVoteId = d3.scaleLinear()
  .domain([0, maxVoteEventId])
  .range([0, LINEPLOT_WIDTH])
let scaleUserColor = d3.scaleOrdinal()
  .domain(rootPostVotes.map((d) => d.userId))
  .range(d3.schemeSet2)

// Line data
let lineGenerator = d3.line()
let pathDataP = rootPostScore.map((e) => {
  return [scaleVoteId(e.voteEventId), scaleProbability(e.p)]
})
let pathP = lineGenerator(pathDataP)
let pathDataOverallProb = rootPostScore.map((e) => {
  return [scaleVoteId(e.voteEventId), scaleProbability(e.overallProb)]
})
let pathOverallProb = lineGenerator(pathDataOverallProb)

let lineGroup = r2d3.svg
  .append("g")
  .attr("transform", "translate(30, 10)")

// Add axes
let xAxis = d3.axisBottom(scaleVoteId)
  .tickValues([0, 5, 10, 15, 20])
  .tickSize(3)
let yAxis = d3.axisLeft(scaleProbability)
  .tickValues([0.0, 0.25, 0.5, 0.75, 1.0])
  .tickSize(3)
lineGroup
  .append("g")
  .attr("transform", "translate(0, 101)")
  .call(xAxis)
lineGroup
  .append("g")
  .call(yAxis)

//   lineGroup
//     .append("g")
//     .append("rect")
//     .attr("x", 0)
//     .attr("y", 0)
//     .attr("width", 260)
//     .attr("height", 130)
//     .attr("fill", "white")
//     .attr("stroke", "black")
//     .attr("opacity", 0.1)

// Add lines
lineGroup
  .append("path")
  .attr("d", pathOverallProb)
  .attr("stroke", "black")
  .attr("stroke-width", 2)
  .attr("opacity", 0.5)
  .attr("fill", "none")
lineGroup
  .append("path")
  .attr("d", pathP)
  .attr("stroke", "steelblue")
  .attr("stroke-width", 2)
  .attr("opacity", 0.5)
  .attr("fill", "none")


// Add up/down/clear sequence at the bottom of the chart

let upVoteEvents = rootPostVotes.filter((d) => d.vote == 1)
let downVoteEvents = rootPostVotes.filter((d) => d.vote == -1)
let clearVoteEvents = rootPostVotes.filter((d) => d.vote == 0)

lineGroup
  .append("g")
  .selectAll("polygon")
  .data(upVoteEvents)
  .join("polygon")
  .attr("points", (d) => {
    let x_base = scaleVoteId(d.voteEventId) + LINEPLOT_X_OFFSET
    let [x1, x2, x3] = [
      x_base,
      x_base + 10,
      x_base + 5
    ]
    let [y1, y2, y3] = [
      LINEPLOT_Y_OFFSET + 10,
      LINEPLOT_Y_OFFSET + 10,
      LINEPLOT_Y_OFFSET
    ]
    return `${x1},${y1} ${x2},${y2} ${x3},${y3}`
  })
  .attr("opacity", 0.5)
  .attr("fill", "green")

lineGroup
  .append("g")
  .selectAll("polygon")
  .data(downVoteEvents)
  .join("polygon")
  .attr("points", (d) => {
    let x_base = scaleVoteId(d.voteEventId) + LINEPLOT_X_OFFSET
    let [x1, x2, x3] = [
      x_base,
      x_base + 10,
      x_base + 5
    ]
    let [y1, y2, y3] = [
      LINEPLOT_Y_OFFSET + 0,
      LINEPLOT_Y_OFFSET + 0,
      LINEPLOT_Y_OFFSET + 10
    ]
    return `${x1},${y1} ${x2},${y2} ${x3},${y3}`
  })
  .attr("opacity", 0.5)
  .attr("fill", "red")

lineGroup
  .append("g")
  .selectAll("circle")
  .data(clearVoteEvents)
  .join("circle")
  .attr("cx", (d) => scaleVoteId(d.voteEventId) + LINEPLOT_X_OFFSET + 5)
  .attr("cy", LINEPLOT_Y_OFFSET + 5)
  .attr("r", 5)
  .attr("fill", "lightgrey")

// User "icons"

lineGroup
  .append("g")
  .selectAll("circle")
  .data(rootPostVotes)
  .join("circle")
  .attr("cx", (d) => scaleVoteId(d.voteEventId))
  .attr("cy", 140)
  .attr("r", 3)
  .attr("fill", (d) => scaleUserColor(d.userId))

lineGroup
  .append("g")
  .selectAll("ellipse")
  .data(rootPostVotes)
  .join("ellipse")
  .attr("cx", (d) => scaleVoteId(d.voteEventId))
  .attr("cy", 150)
  .attr("rx", 3)
  .attr("ry", 5)
  .attr("fill", (d) => scaleUserColor(d.userId))


// -----------------------------------
// --- EDGES -------------------------
// -----------------------------------

let edges = currentScores
  .filter((row) => row["parentId"] !== null)
  .map((row) => {
    return {
      parent: postLookup[row["parentId"]],
      post: postLookup[row["postId"]]
    }
  })

let edgeData = r2d3.svg
  .append("g")
  .selectAll("g")
  .data(edges, (d) => d.parent["postId"] + "-" + d.post["postId"])

let edgeGroup = edgeData
  .join("g")
  .attr("id", (d) => "edgeGroup" + d.parent["postId"] + "-" + d.post["postId"])

edgeGroup
  .append("line")
  .attr("x1", (d) => d.parent.x + POST_RECT_WIDTH / 2)
  .attr("y1", (d) => d.parent.y + POST_RECT_HEIGHT)
  .attr("x2", (d) => d.post.x + POST_RECT_WIDTH / 2)
  .attr("y2", (d) => d.post.y)
  .attr("stroke-width", (d) => {
    // measured in bits (i.e., [0, Inf)), we clamp at 10 and scale down to [0, 1]
    let maxWidth = 10
    let width = Math.min(maxWidth, d.post.effect_on_parent) / maxWidth
    return 1 + width * 100 + 30
  })
  .attr("stroke", (d) => {
    return d.post.parentP > d.post.parentQ ? "forestgreen" : "tomato"
  })
  .attr("opacity", 0.3)
  .style("stroke-linecap", "round")

edgeGroup
  .append("line")
  .attr("x1", (d) => d.parent.x + POST_RECT_WIDTH / 2)
  .attr("y1", (d) => d.parent.y + POST_RECT_HEIGHT)
  .attr("x2", (d) => d.post.x + POST_RECT_WIDTH / 2)
  .attr("y2", (d) => d.post.y)
  .attr("stroke-width", (d) => {
    // measured in bits (i.e., [0, Inf)), we clamp at 10 and scale down to [0, 1]
    let maxWidth = 10
    let width = Math.min(maxWidth, d.post.effect_on_parent) / maxWidth
    return 1 + width * 200
  })
  .attr("stroke", (d) => {
    return d.post.parentP > d.post.parentQ ? "forestgreen" : "tomato"
  })
  .style("stroke-linecap", "round")

// -----------------------------------
// --- NODES -------------------------
// -----------------------------------

let nodeData = r2d3.svg
  .append("g")
  .selectAll("g")
  .data(currentScores, (d) => d["postId"])

let nodeGroup = nodeData
  .join("g")
  .attr("id", (d) => "nodeGroup" + d["postId"])
  .attr("transform", (d) => `translate(${d.x}, ${d.y})`)

// Post container
nodeGroup.append("rect")
  .attr("x", 0)
  .attr("y", 0)
  .attr("width", POST_RECT_WIDTH)
  .attr("height", POST_RECT_HEIGHT)
  .style("fill", "white")
  .attr("stroke", (d) => {
    if (d.parentP == d.parentQ) {
      return "black"
    }
    return d.parentP > d.parentQ ? "forestgreen" : "tomato"
  })

// Post content
nodeGroup.append("foreignObject")
  .attr("x", 0)
  .attr("y", 0)
  .attr("width", POST_RECT_WIDTH)
  .attr("height", POST_RECT_HEIGHT)
  .append("xhtml:div")
  .style("width", `${POST_RECT_WIDTH}px`)
  .style("height", `${POST_RECT_HEIGHT}px`)
  .style("overflow", "auto")
  .style("box-sizing", "border-box")
  .style("padding", "5px")
  .html((d) => d.content)

// https://stackoverflow.com/questions/2685911/is-there-a-way-to-round-numbers-into-a-reader-friendly-format-e-g-1-1k
function numberToText(number) {
  decPlaces = 10
  let abbrev = ["k", "m", "b", "t"]
  for (let i = abbrev.length - 1; i >= 0; i--) {
    let size = Math.pow(10, (i + 1) * 3)
    if (size <= number) {
      number = Math.round(number * decPlaces / size) / decPlaces
      if ((number == 1000) && (i < abbrev.length - 1)) {
        number = 1
        i++
      }
      number += abbrev[i]
      break
    }
  }
  return number
}

function addUpvoteProbabilityBar(
  groupSelection,
  x,
  fill,
  heightPercentageFunc,
  heightNaivePercentageFunc,
  opacityFunc,
  displayFunc,
) {
  let group = groupSelection.append("g")

  group
    .append("rect")
    .attr("width", 25)
    .attr("height", POST_RECT_HEIGHT)
    .attr("x", x)
    .attr("y", 0)
    .attr("opacity", 0.05)
    .style("fill", "transparent")
    .attr("stroke", "black")
    .attr("display", displayFunc)

  group
    .append("rect")
    .attr("width", 25)
    .attr("height", (d) => heightPercentageFunc(d) * POST_RECT_HEIGHT)
    .attr("x", x)
    .attr("y", (d) => {
      return POST_RECT_HEIGHT - heightPercentageFunc(d) * POST_RECT_HEIGHT
    })
    .attr("opacity", opacityFunc)
    .style("fill", fill)
    .attr("display", displayFunc)

  group
    .append("rect")
    .attr("width", 5)
    .attr("height", (d) => heightNaivePercentageFunc(d) * POST_RECT_HEIGHT)
    .attr("x", x)
    .attr("y", (d) => {
      return POST_RECT_HEIGHT - heightNaivePercentageFunc(d) * POST_RECT_HEIGHT
    })
    .style("fill", fill)
    .attr("display", displayFunc)

  // --- KEEP FOR POTENTIAL REUSE TO PLOT THE BAYESIAN PRIOR --->
  // group
  //   .append("line")
  //   .attr("x1", x)
  //   .attr("x2", x + 25)
  //   .attr("y1", POST_RECT_HEIGHT / 2 - 0.75)
  //   .attr("y2", POST_RECT_HEIGHT / 2 - 0.75)
  //   .attr("stroke", "black")
  //   .attr("opacity", 0.7)
  //   .style("stroke-dasharray", "5, 2")
  //   .style("stroke-width", 1.5)
  // <------
}

let voteGroup = nodeGroup.append("g")

// Upvote arrow
voteGroup
  .append("g")
  .attr("transform", `translate(-20, ${POST_RECT_HEIGHT / 2 - 15})`)
  .append("polygon")
  .attr("points", "0,10 10,10 5,0")
  .attr("opacity", 0.5)

// Downvote arrow
voteGroup
  .append("g")
  .attr("transform", `translate(-20, ${POST_RECT_HEIGHT / 2 + 5})`)
  .append("polygon")
  .attr("points", "0,0 10,0 5,10")
  .attr("opacity", 0.5)

// Upvote count
voteGroup
  .append("text")
  .text((d) => numberToText(d.count))
  .attr("width", 10)
  .attr("x", -15)
  .attr("y", POST_RECT_HEIGHT / 2 - 20)
  .attr("text-anchor", "middle")

// Downvote count
voteGroup
  .append("text")
  .text((d) => numberToText(d.sampleSize - d.count))
  .attr("width", 10)
  .attr("x", -15)
  .attr("y", POST_RECT_HEIGHT / 2 + 30)
  .attr("text-anchor", "middle")

addUpvoteProbabilityBar(
  voteGroup,
  -55,
  "black",
  (d) => d.overallProb,
  (d) => d.count / d.sampleSize == 0 ? 0.05 : d.count / d.sampleSize,
  (d) => 1 - (1 / (1 + 0.3 * d.sampleSize)),
  () => "inline"
)

addUpvoteProbabilityBar(
  voteGroup,
  -85,
  "steelblue",
  (d) => d.p,
  (d) => {
    return d.informedCount && (d.informedCount !== 0) ?
      d.informedCount / d.informedTotal :
      0.05
  },
  (d) => 1 - (1 / (1 + 0.3 * d.informedTotal)),
  (d) => children[d.postId] ? "inline" : "none"
)
