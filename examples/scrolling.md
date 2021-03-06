
# Demo of Scrolling Event Logging

By Gary Feng, 2015

Original project hosted on CodePen, version by [Lonnie Smith](http://codepen.io/lonnie-smith/pen/pJgbGv) (http://codepen.io/garyfeng/pen/BoqyGd) and [Gary Feng](http://codepen.io/garyfeng/pen/XmxZWw)

----

# To-dos

- [ ] Complete the design rationale
- [ ] Modify the log structure to use JSON, or possibly the xAPI JS client
- [ ] Use my logging4javascript library fork for logging.
- [ ] Save log to local file using saveAs()
- [ ] Implement the R script for reading and analyzing the data
- [ ] Implement a Shiny server to visualize the results

----

# Overview

In this chapter we illustrate how to design and implement the logging of scrolling events.

* We need to first ask ourselves what inferences we want to make from scrolling behaviors.
* Design a data structure and mechanism that will capture such data.
* Implement everything and test it once and twice.
* Once we get some data, how do we pre-process and then analyze the data?
* Visualize and report on the data.

----

The document is written in [literate programing](http://www.literateprogramming.com/). In other words, this document is designed for both humans and machines to read. The code segments embedded in this document will be automatically assembled into several files once you follow the simple steps below. It will generate the following files.

* [scrolling.coffee](#coffeescript "save:"): This is the Coffeescript code for doing the scrolling event logging. This can be compiled to javascript if necessary.

* [scrolling.html](#html-file "save:"): This is the HTML file in which you can test the Coffeescript code above. In fact, the HTML file includes the Coffeescript directly that runs in the browser. Just launch the file in a browser to test the code.

* [scrolling.R](#r-script "save:"): This is the R script that will take the scrolling event log generated when you test the [scrolling.html](#html-file), analyze the data in [R](https://www.r-project.org/), and generate a report.

### How to extract the code

We use the literate programming package developed by [James Taylor](https://github.com/jostylr/literate-programming/), or more specifically with my fork at (https://github.com/garyfeng/literate-programming).

* Install [literate programming](https://github.com/jostylr/literate-programming): `npm install -g literate-programming`
* Compile the Markdown to code: `literate-programming keystroke.md`

That's it. If all goes right, this will generate the above files. If not, you [call me] (mailto:gary.feng@gmail.com).

----

# Design thinking

This section will talk about why we want to log scrolling events in reading, and what inference we plan to make from such data. This will determine the kind of data we need to capture, and the kind of analyses we need to perform.

----

# R script

This section will anticipate the data structure we will get, and then outline the analyses we will perform.

Later we will expand this to include visualization using Shiny.

```{r}
# We will follow the RMarkdown (http://rmarkdown.rstudio.com/) convention for R scripts.

```

----

# Coffeescript

Code Overview

```{coffeescript}

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
```

# JavaScript libraries

We need to include the following javascript libraries.

jQuery is a no-brainer; we always have it just in case.

```{javascript}
<script type="text/javascript" src="http://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.3/jquery.min.js" ></script>
```
Next up is [FileSaver.js](https://github.com/eligrey/FileSaver.js/), which is an implementation of the HTML5 saveAs() function as part of the [W3C File API](http://www.w3.org/TR/FileAPI/). We use this to save the scrolling log to the local file system, so that we can analyze the data.

```{javascript}
<script type="text/javascript" src="https://dl.dropboxusercontent.com/u/36045409/FileSaver.min.js" ></script>
```
We also include the Coffeescript preprocessor, so that we can run the coffeescript inside the test html in browser directly.

```{javascript}
<script type="text/javascript" src="http://coffeescript.org/extras/coffee-script.js" ></script>
```
# HTML file

Time for having a UI to test the keystroke code. We create a simple HTML page with a textarea. We embed the coffeescript code generated above directly, and use the `<script type="text/coffeescript">` trick (http://coffeescript.org/#literate) to run it inside the browser without needing to compile to javascript first.

Notice that we include blocks of code from previous literate programming blocks.

```{html}
<!DOCTYPE html>
<html>
  <head>
    <title>keystrokeTest</title>
    _"JavaScript libraries"
    _"CSS"
  </head>
  <body style="padding: 20px 20px 20px;">
    <script type="text/coffeescript">
      _"Coffeescript"
      compileSource()
    </script>

    <div class="leftCol">
    <div class="controls">
      <button type="button" onclick="toggleWords()">Toggle word numbers</button>
    </div>
    <div class="scroll">
        <h2>
          CHAPTER 1. Loomings.
        </h2>
        <p>
          Call me Ishmael. Some years ago&mdash;never mind how long precisely&mdash;having
          little or no money in my purse, and nothing particular to interest me on
          shore, I thought I would sail about a little and see the watery part of
          the world. It is a way I have of driving off the spleen and regulating the
          circulation. Whenever I find myself growing grim about the mouth; whenever
          it is a damp, drizzly November in my soul; whenever I find myself
          involuntarily pausing before coffin warehouses, and bringing up the rear
          of every funeral I meet; and especially whenever my hypos get such an
          upper hand of me, that it requires a strong moral principle to prevent me
          from deliberately stepping into the street, and methodically knocking
          people's hats off&mdash;then, I account it high time to get to sea as soon
          as I can. This is my substitute for pistol and ball. With a philosophical
          flourish Cato throws himself upon his sword; I quietly take to the ship.
          There is nothing surprising in this. If they but knew it, almost all men
          in their degree, some time or other, cherish very nearly the same feelings
          towards the ocean with me.
        </p>
        <p>
          There now is your insular city of the Manhattoes, belted round by wharves
          as Indian isles by coral reefs&mdash;commerce surrounds it with her surf.
          Right and left, the streets take you waterward. Its extreme downtown is
          the battery, where that noble mole is washed by waves, and cooled by
          breezes, which a few hours previous were out of sight of land. Look at the
          crowds of water-gazers there.
        </p>
        <p>
          Circumambulate the city of a dreamy Sabbath afternoon. Go from Corlears
          Hook to Coenties Slip, and from thence, by Whitehall, northward. What do
          you see?&mdash;Posted like silent sentinels all around the town, stand
          thousands upon thousands of mortal men fixed in ocean reveries. Some
          leaning against the spiles; some seated upon the pier-heads; some looking
          over the bulwarks of ships from China; some high aloft in the rigging, as
          if striving to get a still better seaward peep. But these are all
          landsmen; of week days pent up in lath and plaster&mdash;tied to counters,
          nailed to benches, clinched to desks. How then is this? Are the green
          fields gone? What do they here?
        </p>
        <p>
          But look! here come more crowds, pacing straight for the water, and
          seemingly bound for a dive. Strange! Nothing will content them but the
          extremest limit of the land; loitering under the shady lee of yonder
          warehouses will not suffice. No. They must get just as nigh the water as
          they possibly can without falling in. And there they stand&mdash;miles of
          them&mdash;leagues. Inlanders all, they come from lanes and alleys,
          streets and avenues&mdash;north, east, south, and west. Yet here they all
          unite. Tell me, does the magnetic virtue of the needles of the compasses
          of all those ships attract them thither?
        </p>  
        <p>
          Once more. Say you are in the country; in some high land of lakes. Take
          almost any path you please, and ten to one it carries you down in a dale,
          and leaves you there by a pool in the stream. There is magic in it. Let
          the most absent-minded of men be plunged in his deepest reveries&mdash;stand
          that man on his legs, set his feet a-going, and he will infallibly lead
          you to water, if water there be in all that region. Should you ever be
          athirst in the great American desert, try this experiment, if your caravan
          happen to be supplied with a metaphysical professor. Yes, as every one
          knows, meditation and water are wedded for ever.
        </p>
        <p>
          But here is an artist. He desires to paint you the dreamiest, shadiest,
          quietest, most enchanting bit of romantic landscape in all the valley of
          the Saco. What is the chief element he employs? There stand his trees,
          each with a hollow trunk, as if a hermit and a crucifix were within; and
          here sleeps his meadow, and there sleep his cattle; and up from yonder
          cottage goes a sleepy smoke. Deep into distant woodlands winds a mazy way,
          reaching to overlapping spurs of mountains bathed in their hill-side blue.
          But though the picture lies thus tranced, and though this pine-tree shakes
          down its sighs like leaves upon this shepherd's head, yet all were vain,
          unless the shepherd's eye were fixed upon the magic stream before him. Go
          visit the Prairies in June, when for scores on scores of miles you wade
          knee-deep among Tiger-lilies&mdash;what is the one charm wanting?&mdash;Water&mdash;there
          is not a drop of water there! Were Niagara but a cataract of sand, would
          you travel your thousand miles to see it? Why did the poor poet of
          Tennessee, upon suddenly receiving two handfuls of silver, deliberate
          whether to buy him a coat, which he sadly needed, or invest his money in a
          pedestrian trip to Rockaway Beach? Why is almost every robust healthy boy
          with a robust healthy soul in him, at some time or other crazy to go to
          sea? Why upon your first voyage as a passenger, did you yourself feel such
          a mystical vibration, when first told that you and your ship were now out
          of sight of land? Why did the old Persians hold the sea holy? Why did the
          Greeks give it a separate deity, and own brother of Jove? Surely all this
          is not without meaning. And still deeper the meaning of that story of
          Narcissus, who because he could not grasp the tormenting, mild image he
          saw in the fountain, plunged into it and was drowned. But that same image,
          we ourselves see in all rivers and oceans. It is the image of the
          ungraspable phantom of life; and this is the key to it all.
        </p>
        <p>
          Now, when I say that I am in the habit of going to sea whenever I begin to
          grow hazy about the eyes, and begin to be over conscious of my lungs, I do
          not mean to have it inferred that I ever go to sea as a passenger. For to
          go as a passenger you must needs have a purse, and a purse is but a rag
          unless you have something in it. Besides, passengers get sea-sick&mdash;grow
          quarrelsome&mdash;don't sleep of nights&mdash;do not enjoy themselves
          much, as a general thing;&mdash;no, I never go as a passenger; nor, though
          I am something of a salt, do I ever go to sea as a Commodore, or a
          Captain, or a Cook. I abandon the glory and distinction of such offices to
          those who like them. For my part, I abominate all honourable respectable
          toils, trials, and tribulations of every kind whatsoever. It is quite as
          much as I can do to take care of myself, without taking care of ships,
          barques, brigs, schooners, and what not. And as for going as cook,&mdash;though
          I confess there is considerable glory in that, a cook being a sort of
          officer on ship-board&mdash;yet, somehow, I never fancied broiling fowls;&mdash;though
          once broiled, judiciously buttered, and judgmatically salted and peppered,
          there is no one who will speak more respectfully, not to say
          reverentially, of a broiled fowl than I will. It is out of the idolatrous
          dotings of the old Egyptians upon broiled ibis and roasted river horse,
          that you see the mummies of those creatures in their huge bake-houses the
          pyramids.
        </p>
    </div>
    </div>
    <div class="rightCol">
      <h4>Scroll event data</h4>
      <small>(XML markup not shown for concision)</small>
      <div id="scroll-output"></div>
    </div>        
  </body>
</html>
```

# CSS

This is the CSS that Lonnie used in his original CodePen example (http://codepen.io/lonnie-smith/pen/pJgbGv).

```{CSS}
<style type="text/css">
  /* Page setup */
  html, button {
    font-size: 20px;
    line-height: 1.5;
  }
  html {
    width: 100%; height: 100%;
  }
  .leftCol, .rightCol {
    width: 40rem;
    display: inline-block;
  }
  .controls {
    margin: 1rem;
  }
  .scroll, .rightCol {
    height: 500px;
    border: 1px solid black;
    padding: 1rem;
    overflow-y: scroll;
    margin: 1rem;
  }

  /* word highlighting */
  .word {
    position: relative;
  }

  .word.shown {
    background-color: rgba(0,0,255,0.1);
  }

  sub.word-count {
    text-indent: 0;
    color: red;
    font-size: 10px;
    font-weight: bold;
    font-style: italic;
    position: absolute;
    left: 0;
    bottom: -6px;
    line-height: 1;
  }
</style>
```
