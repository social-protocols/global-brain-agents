// !preview r2d3 data=c(0.3, 0.6, 0.8, 0.95, 0.40, 0.20)

try {
  let postLookup = {}
  r2d3.data.forEach((d) => {
    let postId = d["postId"]
    postLookup[postId] = d
  })


  let children = {}
  r2d3.data.forEach((d) => {
    let parentId = d["parentId"]
    if (parentId in children) {
      children[parentId].push(d)
      children[parentId].sort((a, b) => b["effect_on_parent_magnitude"] - a["effect_on_parent_magnitude"])
    } else {
      children[parentId] = [d]
    }
  })

  function visit(postId) {
    // console.log(`Visiting post ${postId}`)
    let post = postLookup[postId]
    // console.log(`Post is ${JSON.stringify(post)}`)
    if (postId in children) {
      let spread = 0
      let stepSize = 0
      if (children[postId].length > 1) {
        spread = 400
        stepSize = spread / (children[postId].length - 1)
      }
      children[postId].forEach((child, i) => {
        child.x = post.x + i * stepSize
        child.y = post.y + 150
        visit(child["postId"])
      })
    }
    return post
  }

  let root = children["null"][0]
  root.x = 80
  root.y = 20

  visit(root["postId"])

  let rectWidth = 250
  let rectHeight = 65

  // console.log(JSON.stringify(postLookup, null, 2))

  let edges = r2d3.data
    .filter((row) => row["parentId"] !== null)
    .map((row) => {
      return {parent: postLookup[row["parentId"]], post: postLookup[row["postId"]]}
    })

  let edgeData = r2d3.svg
    .selectAll("line")
    .data(edges)

  edgeData
    .join("line")
    .attr("x1", (d) => d.parent.x + rectWidth / 2)
    .attr("y1", (d) => d.parent.y + rectHeight)
    .attr("x2", (d) => d.post.x + rectWidth / 2)
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
    .attr("x1", (d) => d.parent.x + rectWidth / 2)
    .attr("y1", (d) => d.parent.y + rectHeight)
    .attr("x2", (d) => d.post.x + rectWidth / 2)
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

  let nodeData = r2d3.svg
    .selectAll("g")
    .data(r2d3.data, (d) => d["postId"])

  let nodeGroup = nodeData
    .join("g")
    .attr("transform", (d) => `translate(${d.x}, ${d.y})`)

  nodeGroup.append("rect")
    .attr("x", 0)
    .attr("y", 0)
    .attr("width", rectWidth)
    .attr("height", rectHeight)
    .style("fill", "white")
    .attr("stroke", (d) => {
      if (d.parentP == d.parentQ) {
        return "black"
      }
      return d.parentP > d.parentQ ? "forestgreen" : "tomato"
    })

  // nodeGroup.append("circle")
  //   .attr("cx", 0)
  //   .attr("cy", 0)
  //   .attr("r", 20)

  // insert html div with max width into group to allow text wrapping
  nodeGroup.append("foreignObject")
    .attr("x", 0)
    .attr("y", 0)
    .attr("width", rectWidth)
    .attr("height", rectHeight)
    .append("xhtml:div")
    .style("width", `${rectWidth}px`)
    .style("height", `${rectHeight}px`)
    .style("overflow", "auto")
    .style("box-sizing", "border-box")
    .style("padding", "5px")
    .html((d) => d.content)

  nodeGroup.append("rect")
    .attr("x", -15)
    .attr("y", (d) => rectHeight - d.p * rectHeight)
    .attr("width", 10)
    .attr("height", (d) => d.p * rectHeight)
    .style("fill", "steelblue")
    .attr("opacity", 0.5)

  nodeGroup.append("rect")
    .attr("x", -15)
    .attr("y", (d) => rectHeight - d.p * rectHeight)
    .attr("width", 4)
    .attr("height", (d) => d.p * rectHeight) // TODO: without Bayesian averaging
    .style("fill", "steelblue")

  nodeGroup.append("rect")
    .attr("x", -30)
    .attr("y", (d) => rectHeight - d.q * rectHeight)
    .attr("width", 10)
    .attr("height", (d) => d.q * rectHeight)
    .style("fill", "black")
    .attr("opacity", 0.5)

  nodeGroup.append("rect")
    .attr("x", -30)
    .attr("y", (d) => rectHeight - d.q * rectHeight)
    .attr("width", 4)
    .attr("height", (d) => d.q * rectHeight)
    .style("fill", "black")

  let voteGroup = nodeGroup
    .append("g")
    .attr("transform", "translate(-50, 10)")

  voteGroup
    .append("g")
    .attr("transform", "translate(-15, 10)")
    .append("polygon")
    .attr("points", "0,10 10,10 5,0")
    .attr("opacity", (d) => d.count / d.sampleSize)

  voteGroup
    .append("g")
    .attr("transform", "translate(-15, 30)")
    .append("polygon")
    .attr("points", "0,0 10,0 5,10")
    .attr("opacity", (d) => 1 - (d.count / d.sampleSize))

  voteGroup.append("text")
    .text((d) => d.count)
    .attr("x", 0)
    .attr("y", 20)

  voteGroup.append("text")
    .text((d) => d.sampleSize - d.count)
    .attr("x", 0)
    .attr("y", 40)

} catch (e) {
  console.error(e)
}

