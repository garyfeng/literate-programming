# Wrap each word in <span id="word-X"><span>; X represents a word number for
# each word in the stimulus; the first and last words on the screen are
# reported as observables on every scroll event.
markupWords = () ->
  ct = 0 # count of words found.

  # this RegExp does a decent job of discovering word boundaries, but may
  # need to be tweaked.
  rx = /((\w+[-,.'’]*)+\w+|\b\w\b)/g

  # every time rx is matched in a string, replace it with the output of
  # this function
  replacer = (match, p1) ->
    "<span class='word' id='word-#{++ct}'>#{p1}</span>"

  swap = (node, swapWith) ->
    if typeof(swapWith) is 'string'
      $(node).replaceWith(swapWith)

  # this function called recursively in a depth-first traversal of the
  # tree rooted at node
  markupNode = (node) ->
    # Base case: if node is a text node, and it contains any words, return a
    # HTML string where each word has been wrapped in span markup.
    if node.nodeType is node.TEXT_NODE
      if rx.test(node.textContent)
        return node.textContent.replace(rx, replacer)
    # Recursive case: if it's not a text node, process the node's children
    # if it has any. If the result of recursive processing of a child node
    # results in an HTML string, then use swap() to replace that child node
    # with the nodes represented by converting the HTML string into a node.
    # Finally, return the parent node.
    else
      if node.hasChildNodes()
        oldChildren = (n for n in node.childNodes)
        newChildren = (markupNode(n) for n in oldChildren)
        swap(n, newChildren[idx]) for n, idx in oldChildren
      return node
  root = $('.scroll')[0]
  swap root, markupNode(root)

# utility to make word IDs visible/invisible. The look here is is similar to
# what is required for the new SelectionCodeToggle API -- though, of course,
# the units marked up for that feature depend on what a given question is
# asking users to do, whereas the units here are just words.  
wordState = false
window.toggleWords = () ->
  wordState = !wordState
  if wordState
    $('.word').each () ->
      $(this).addClass('shown').append("<sub class='word-count'>#{this.id.substr(5)}</sub>")
  else
    $('.word').removeClass('shown')
    $('sub.word-count').remove()

# determine the scroll position. Returns 4 values:
#  loc - pixel offset of the top of the screen.
#  pct - position of the screen calculated as a percent.
#    0 = top, 100 = bottom
#  firstWd - number of first word visible on screen
#  lastWd - number of last word visible on screen.
getScrollPos = () ->
  console.debug $('#word-1').offset().top
  $scroll = $('.scroll')
  loc = Math.round($scroll.scrollTop())
  pageHeight = $scroll.get(0).scrollHeight
  windowHeight = $scroll.innerHeight()
  windowTop = $scroll.offset().top
  windowBottom = windowTop + windowHeight
  pct = loc/(pageHeight - windowHeight)
  pct = Math.round(pct*100)
  [firstWd, lastWd] = [null,null]
  for wd in $('.word')
    break if lastWd?
    $wd = $(wd)
    wdTop = $wd.offset().top
    wdBottom = wdTop + $wd.outerHeight()
    visible = wdTop >= windowTop and wdBottom <= windowBottom
    if visible and !firstWd?
      firstWd = wd
      continue
    if firstWd? and !visible
      lastWd = parseInt(wd.id.substr(5)) - 1
      break
  firstWd = firstWd.id.substr(5)
  lastWd = 0 unless firstWd > 0
  unless lastWd?
    lastWd = parseInt($('.word').last()[0]?.id.substr(5))
  return [loc, pct, firstWd, lastWd]

scrolled = () ->
  [oldLoc, oldPct, oldFirstWd, oldLastWd] = window.oldPosition
  [newLoc, newPct, newFirstWd, newLastWd] = getScrollPos()
  $('#scroll-output').prepend """
		<div class=".output">
		  <b>from:</b> #{oldLoc}px, #{oldPct}%,
			word #{oldFirstWd}&ndash;#{oldLastWd}
			<b>to:</b> #{newLoc}px, #{newPct}%,
			word #{newFirstWd}&ndash;#{newLastWd}
		</div>
	"""
  window.oldPosition = [newLoc, newPct, newFirstWd, newLastWd]

# hold the initial position of screen.
window.oldPosition = []

$ () ->
  # add markup once page is loaded
  markupWords()

  # set initial position of screen
  window.oldPosition = getScrollPos()

  # log scroll event once the user has stopped scrolling for at least
  # 250 ms.
  scrollTimeout = null
  scrollStop = () ->
    clearTimeout(scrollTimeout)
    scrollTimeout = setTimeout(scrolled, 250)
  $('.scroll').scroll(scrollStop)