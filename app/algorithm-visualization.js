try {
  let CHILD_NODE_SPREAD = 400
  let CHILD_PARENT_OFFSET = 150

  let ROOT_POST_RECT_X = 80
  let ROOT_POST_RECT_Y = 20

  let POST_RECT_WIDTH = 250
  let POST_RECT_HEIGHT = 65

  let postLookup = {}
  r2d3.data.forEach((d) => {
    let postId = d["postId"]
    postLookup[postId] = d
  })

  let children = {}
  r2d3.data.forEach((d) => {
    let parentId = d["parentId"]
    if (!(parentId in children)) {
      children[parentId] = [d]
    } else {
      children[parentId].push(d)
      children[parentId].sort((a, b) => {
          return b["effect_on_parent_magnitude"] - a["effect_on_parent_magnitude"]
      })
    }
  })

  function assignPositions(postId) {
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
        assignPositions(child["postId"])
      })
    }
    return post
  }

  let root = children["null"][0]
  root.x = ROOT_POST_RECT_X
  root.y = ROOT_POST_RECT_Y
  assignPositions(root["postId"])

  let edges = r2d3.data
    .filter((row) => row["parentId"] !== null)
    .map((row) => {
      return {
        parent: postLookup[row["parentId"]],
        post: postLookup[row["postId"]]
      }
    })

  // -----------------------------------
  // --- EDGES -------------------------
  // -----------------------------------

  let edgeData = r2d3.svg
    .selectAll("line")
    .data(edges)

  edgeData
    .join("line")
    .attr("x1", (d) => d.parent.x + POST_RECT_WIDTH / 2)
    .attr("y1", (d) => d.parent.y + POST_RECT_HEIGHT)
    .attr("x2", (d) => d.post.x + POST_RECT_WIDTH / 2)
    .attr("y2", (d) => d.post.y)
    .attr("stroke-width", (d) => {
      // measured in bits (i.e., [0, Inf)), we clamp at 10 and scale down to [0, 1]
      let maxWidth = 10
      let width = Math.min(maxWidth, d.post.effect_on_parent_magnitude) / maxWidth
      return 1 + width * 100 + 30
    })
    .attr("stroke", (d) => {
      return d.post.parentP > d.post.parentQ ? "forestgreen" : "tomato"
    })
    .attr("opacity", 0.3)
    .style("stroke-linecap", "round")

  edgeData
    .join("line")
    .attr("x1", (d) => d.parent.x + POST_RECT_WIDTH / 2)
    .attr("y1", (d) => d.parent.y + POST_RECT_HEIGHT)
    .attr("x2", (d) => d.post.x + POST_RECT_WIDTH / 2)
    .attr("y2", (d) => d.post.y)
    .attr("stroke-width", (d) => {
      // measured in bits (i.e., [0, Inf)), we clamp at 10 and scale down to [0, 1]
      let maxWidth = 10
      let width = Math.min(maxWidth, d.post.effect_on_parent_magnitude) / maxWidth
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
    .selectAll("g")
    .data(r2d3.data, (d) => d["postId"])

  let nodeGroup = nodeData
    .join("g")
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

  // Informed upvote probability bar
  nodeGroup.append("rect")
    .attr("x", -15)
    .attr("y", (d) => POST_RECT_HEIGHT - d.p * POST_RECT_HEIGHT)
    .attr("width", 10)
    .attr("height", (d) => d.p * POST_RECT_HEIGHT)
    .style("fill", "steelblue")
    .attr("opacity", 0.5)

  // Informed upvote probability bar without Bayesian averaging
  nodeGroup.append("rect")
    .attr("x", -15)
    .attr("y", (d) => POST_RECT_HEIGHT - d.p * POST_RECT_HEIGHT)
    .attr("width", 4)
    .attr("height", (d) => d.p * POST_RECT_HEIGHT) // TODO: without Bayesian averaging
    .style("fill", "steelblue")

  // Uninformed upvote probability bar
  nodeGroup.append("rect")
    .attr("x", -30)
    .attr("y", (d) => POST_RECT_HEIGHT - d.q * POST_RECT_HEIGHT)
    .attr("width", 10)
    .attr("height", (d) => d.q * POST_RECT_HEIGHT)
    .style("fill", "black")
    .attr("opacity", 0.5)

  // Uninformed upvote probability bar without Bayesian averaging
  nodeGroup.append("rect")
    .attr("x", -30)
    .attr("y", (d) => POST_RECT_HEIGHT - d.q * POST_RECT_HEIGHT)
    .attr("width", 4)
    .attr("height", (d) => d.q * POST_RECT_HEIGHT) // TODO: without Bayesian averaging
    .style("fill", "black")

  let voteGroup = nodeGroup
    .append("g")
    .attr("transform", "translate(-50, 10)")

  // Upvote arrow
  voteGroup
    .append("g")
    .attr("transform", "translate(-15, 10)")
    .append("polygon")
    .attr("points", "0,10 10,10 5,0")
    .attr("opacity", (d) => d.count / d.sampleSize)

  // Downvote arrow
  voteGroup
    .append("g")
    .attr("transform", "translate(-15, 30)")
    .append("polygon")
    .attr("points", "0,0 10,0 5,10")
    .attr("opacity", (d) => 1 - (d.count / d.sampleSize))

  // Upvote count
  voteGroup.append("text")
    .text((d) => d.count)
    .attr("x", 0)
    .attr("y", 20)

  // Downvote count
  voteGroup.append("text")
    .text((d) => d.sampleSize - d.count)
    .attr("x", 0)
    .attr("y", 40)

} catch (e) {
  console.error(e)
}
