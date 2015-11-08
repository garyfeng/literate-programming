normalize = (str) -> str.replace(/(\r\n|\r|\n)/gm, '\n')

oldE = ""

queue = []

doDiff = (e) ->
  newE = normalize(e.target.value)
  rslt =
    #newE: newE
    #oldE: oldE
    timestamp: (new Date()).toJSON()
    diff: JsDiff.diffChars(oldE, newE)
    patch: JsDiff.createPatch("t", oldE, newE)
  # console.log(rslt)
  oldE = newE
  #logDiff2(rslt)
  queue.push rslt

currentText = ""

patchDiff = (diff) ->
  currentText = JsDiff.applyPatch(currentText, diff.patch)
  return currentText

logDiff = (m) ->
  str1="<p> <b>time:</b>#{m.timestamp}, <b>diff</b>:"
  strend=", <b>reconstructed</b>: #{patchDiff(m)}</p>"
  strdiff=""
  #console.log(m.diff)
  for part in m.diff
    do (part)->
    # green for additions, red for deletions
    # grey for common parts
    style = if part.added then 'color:blue; text-decoration: underline;' else if part.removed then 'color:red; text-decoration: line-through;' else 'color:grey;'
    strdiff +="<span style=#{style}>#{part.value}</span>"
    #console.log(strdiff)
  $('#results').prepend  str1+strdiff+strend

log = () ->
  if queue.length > 0
    logDiff queue.shift() # not at all efficient in JavaScript.
  setTimeout(log, 50)
log()

$ () ->
  $('#textinput').on('input', doDiff)