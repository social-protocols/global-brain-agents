// !preview r2d3 data=c(0.3, 0.6, 0.8, 0.95, 0.40, 0.20)

let postLookup = {}
data.forEach((d) => {
  let postId = d["postId"]
  postLookup[postId] = d
})


let children = {}
data.forEach((d) => {
  let parentId = d["parentId"]
  if (parentId in children) {
    children[parentId].push(d)
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
      spread = 100
      stepSize = spread / (children[postId].length - 1)
    }
    children[postId].forEach((child, i) => {
      child.x = post.x - spread / 2 + i * stepSize
      child.y = post.y + 70
      visit(child["postId"])
    })
  }
  return post
}

let root = children["null"][0]
root.x = 500
root.y = 20

visit(root["postId"])


// console.log(JSON.stringify(postLookup, null, 2))

let edges = data
  .filter((row) => row["parentId"] !== null)
  .map((row) => {
    return {parent: postLookup[row["parentId"]], post: postLookup[row["postId"]]}
  })

// console.log(JSON.stringify(edges, null, 2))

let nodeData = svg
  // .append("g")
  .selectAll("circle")
  .data(data);

nodeData
  .enter()
  .append("circle")
  .attr("r", 20)
  .attr("cx", function (d) {
    return d.x;
  })
  .attr("cy", function (d) {
    return d.y;
  })
  // .append("text")

nodeData.exit().remove()

let edgeData = svg
  // .append("g")
  .selectAll("line")
  .data(edges)

edgeData
  .enter()
  .append("line")
  .attr("x1", function (d) {
    return d.parent.x;
  })
  .attr("y1", function (d) {
    return d.parent.y;
  })
  .attr("x2", function (d) {
    return d.post.x;
  })
  .attr("y2", function (d) {
    return d.post.y;
  })
  .attr("stroke", "black")

edgeData.exit().remove()
