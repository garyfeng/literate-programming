
# Demo of Keystroke Logging

By Gary Feng, Copyleft, 2015

[CodePen Project](http://codepen.io/garyfeng/pen/BoqyGd), inspired a CodePen by Lonnie Smith

This example uses the [JsDiff library](https://github.com/kpdecker/jsdiff) to compare the text in the textarea, and shows the timestampe and diffs using simple inline CSS. In a real application you'd want to log the data in a structured way.

The document is written in [literate programing](http://www.literateprogramming.com/), i.e., the document is also runnable code. Specifically, this code generates 2 files:

* [keystroke.coffee](#Coffeescript "save:"): This is the Coffeescript code for doing the keystroke logging. This can be compiled to javascript if necessary.

* [keystroke.html](#HTML-file "save:"): This is the HTML file in which you can test the Coffeescript code above. In fact, the HTML file includes the Coffeescript directly that runs in the browser.

To do so:

* Install [literate programming](https://github.com/jostylr/literate-programming): `npm install -g literate-programming`
* Compile the Markdown to code: `literate-programming keystroke.md`

That's it. If all goes right, this will generate the above 2 files. 

----

# Coffeescript

We first build the keystroke logging logic in Coffeescript, before we think about UI issues.
So we need to write the following components:

* doDiff: this is the function that compares the old text with the current text, and generate the text diff.
* patchDiff: this is not strictly necessary for what we do. We implement it here just for completeness.
* logDiff: take the output of doDiff and do something, such as to log every x msec.
* attaching doDiff to a triggering event, such as the "input" event.

Standardize line endings; this may or may not be strictly necessary, but we do want to be sure that Unix- and Windows-type line endings are treated as the same, and are always written as Unix-style line endings per the data spec.


    normalize = (str) -> str.replace(/(\r\n|\r|\n)/gm, '\n')

In order to capture diffs between the text value of a field before and after a keystroke event, remember what the last entry was. In any real implementation, you'd have multiple textboxes to track, so a single global variable like this wouldn't work.

    oldE = ""

Here, we use a queue for log events, because users may be typing very rapidly. Events are generated as they are produced, and then placed into a queue. A loop dequeues 1 event every 50 ms and logs it. In the context of a more typical SBT implementation, it may be reasonable to immediately append the event the object representing task state, or it may be more effective to periodically attach events in batches. We'd want to make sure that when the platform polls for task data, that what it collects is not more than a second or so behind what the user is actually doing, so that it won't be possible to lose much data in the event of a system crash or similar.

    queue = []

Perform a diff. This method is fired on the input event and returns an object representing the difference between the current and previous state of the text input: {changed, position, removedText, addedText}

Using my copy of [JsDiff](http://dl.dropboxusercontent.com/u/36045409/diff.js)

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

Demo reconstructing the current state of textbox based on diffs. This would be done post-administration during analysis and does NOT need to be part of any SBT implementation.

    currentText = ""

    patchDiff = (diff) ->
      currentText = JsDiff.applyPatch(currentText, diff.patch)
      return currentText

Display result of diff on screen. In an SBT implementation, this would add a diff to cached task state data. When the state data is sent to the platform via a StateInfo_Reply, it should comform to the data capture specification.

Using [JsDiff.js](https://github.com/kpdecker/jsdiff), e.g., diffDiff = JsDiff.diffChars(one, other);

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

Unload cached events at regular intervals. See comment at top of file regarding the use of a queue in this example.

    log = () ->
      if queue.length > 0
        logDiff queue.shift() # not at all efficient in JavaScript.
      setTimeout(log, 50)
    log()


Attach diff function to textarea. This example is bound to the input event, but, depending on the context, it may make more sense to bind to keypress or keyup or keydown.
For example, in one application we were interested in tracking the key travel time, which is the time duration between the keydown and keyup of the same key. This requires slightly more logic to keep track.

    $ () ->
      $('#textinput').on('input', doDiff)


# JavaScript libraries

We need to include 2 javascript libraries, namely JsDiff and jquery.

jQuery is a no-brainer, although I am actually not sure we use it here ;-).
Might have at some point.

    <script type="text/javascript" src="http://cdnjs.cloudflare.com/ajax/libs/jquery/2.1.3/jquery.min.js" ></script>

Next up is JsDiff, an excellent javascript library for doing text diffs.

    <script type="text/javascript" src="http://dl.dropboxusercontent.com/u/36045409/diff.js" ></script>

We may also include the Coffeescript preprocessor.

    <script type="text/javascript" src="http://coffeescript.org/extras/coffee-script.js" ></script>

# HTML file

    <!DOCTYPE html>
    <html>
      <head>
        <title>keystrokeTest</title>
        _"JavaScript libraries"
      </head>
      <body style="padding: 20px 20px 20px;">

        <p style="width: 25%;">
          Type some stuff in the box below. The grey output shows reconstituting the students response, event by event, based on the diffs saved as observable events.<br />
          <br />
          An event is generated every time input occurs, but events are <em>logged</em> asynchronously every 50ms to help smooth out fast bursts of typing.
        </p>
        <textarea id="textinput" rows="10" columns="300" style="width: 25%;"></textarea>

        <div id="results" style="width:50%;"></div>


        <script type="text/coffeescript">
          _"Coffeescript"
          compileSource()
        </script>
      </body>
    </html>
