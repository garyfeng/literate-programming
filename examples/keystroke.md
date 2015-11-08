
# Demo of Keystroke Logging

By Gary Feng, 2015

Original project hosted on CodePen (http://codepen.io/garyfeng/pen/BoqyGd) and (http://codepen.io/anon/pen/zGEBRG)

----

# To-dos

- [ ] Complete the design rationale; see the scrolling.md example.
- [ ] Modify the log structure to use JSON, or possibly the xAPI JS client
- [ ] Use my logging4javascript library fork for logging.
- [ ] Save log to local file using saveAs()
- [ ] Implement the R script for reading and analyzing the data
- [ ] Implement a Shiny server to visualize the results

----
This example uses the [JsDiff library](https://github.com/kpdecker/jsdiff) to compare text changes in a textarea and show the timestamp and diffs using simple inline CSS. In a real application you'd want to log the data in a structured way.

The project was inspired a CodePen by Lonnie Smith (http://codepen.io/lonnie-smith/pen/MYRGee/), which uses a custom function to do the text diffs. Its function is limited compared to JsDiff. For one, JsDiff offers diffing at char or word level (among other choices). In addition, Lonnie's algorithm will have difficulties handling multiple simultaneous changes that could happen in text editing when someone does a spell checking with the "change all" function. In that case, Lonnie's diff function will report the text from the beginning of the first change to the late of the last change as a single block of change, whereas the JsDiff will accurately report many minimal changes.

----

The document is written in [literate programing](http://www.literateprogramming.com/), i.e., the document is also runnable code. Specifically, this code generates 2 files:

* [keystroke.coffee](#coffeescript "save:"): This is the Coffeescript code for doing the keystroke logging. This can be compiled to javascript if necessary.

* [keystroke.html](#html-file "save:"): This is the HTML file in which you can test the Coffeescript code above. In fact, the HTML file includes the Coffeescript directly that runs in the browser.

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

----

First, we standardize line endings. This may or may not be strictly necessary, but we do want to be sure that Unix- and Windows-type line endings are treated as the same, and are always written as Unix-style line endings per the data spec.


    normalize = (str) -> str.replace(/(\r\n|\r|\n)/gm, '\n')

In order to capture diffs between the text value of a field before and after a keystroke event, remember what the last entry was. In any real implementation, you'd have multiple textboxes to track, so a single global variable like this wouldn't work.

    oldE = ""

Here, we use a queue for log events, because users may be typing very rapidly. Events are generated as they are produced, and then placed into a queue. A loop dequeues 1 event every 50 ms and logs it. In the context of a more typical SBT implementation, it may be reasonable to immediately append the event the object representing task state, or it may be more effective to periodically attach events in batches. We'd want to make sure that when the platform polls for task data, that what it collects is not more than a second or so behind what the user is actually doing, so that it won't be possible to lose much data in the event of a system crash or similar.

    queue = []

----

The `doDiff` function perform a diff. This method is fired on the input event (`e`) and returns an object representing the difference between the current and previous state of the text input. Text diff is done using (my copy of) [JsDiff](http://dl.dropboxusercontent.com/u/36045409/diff.js), which offers a lot of control over diff algorithms. Here we choose to use the `diffChars()` function. Alternatively, you can choose to diff by words, etc.

In addition, we get the event timestamp. Note that we did not use the timestamp in the event `e` but instead created a new timestamp at the time of `doDiff`. This saves the complexity of dealing with event-specific structures. The two methods shouldn't differ by more than a millisecond, but you should test before you decide how to implement.

Finally, we also create the patch here. This is used later in `patchDiff`.

    doDiff = (e) ->
      newE = normalize(e.target.value)
      rslt =
        timestamp: (new Date()).toJSON()
        diff: JsDiff.diffChars(oldE, newE)
        patch: JsDiff.createPatch("t", oldE, newE)
      # console.log(rslt)
      oldE = newE
      #logDiff2(rslt)
      queue.push rslt


----

While it is not strictly necessary to `patchDiff`, i.e., to reconstruct the current state of textarea from diffs, we implement it here for completeness. This would be done post-administration during analysis and does NOT need to be part of any keystroke capture implementation.

    currentText = ""

    patchDiff = (diff) ->
      currentText = JsDiff.applyPatch(currentText, diff.patch)
      return currentText

----

Our `logDiff` is a misnomer, because it simply displays result of diff on screen. In a real implementation, we should log the diff and any additional information associated with it. You should also consider the performance of the logging system. In particular, if you use ajax or other asynchronous methods, make sure the logging can keep up with the typing speed (I've seen high schoolers typing north of 100 WPM).

Back to our application. A line of text is printed after each triggering event (keyboard input), in reverse time order. Gray for unchanged characters; Green for additions, and Red for deletions. This is done using a simple inline CSS.

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
      $('#results').prepend  str1 + strdiff + strend

We need to log continuously. One approach is to attach the logging functionality to the `logDiff` function. That's fine. We take a different approach, where we check every `50msec` to see if we have somethings to log. This is the idea of caching. In one application we have to cache log entries for 15-20 seconds before we can unload the log entries to a server.

    log = () ->
      if queue.length > 0
        logDiff queue.shift() # not at all efficient in JavaScript.
      setTimeout(log, 50)
    log()

----

Finally, we need to attach the logging function to text input to the textarea. This example is bound to the input event, but, depending on the context, it may make more sense to bind to keypress or keyup or keydown.
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

Time for having a UI to test the keystroke code. We create a simple HTML page with a textarea. We embed the coffeescript code generated above directly, and use the `<script type="text/coffeescript">` trick (http://coffeescript.org/#literate) to run it inside the browser without needing to compile to javascript first.

Notice that we include blocks of code from previous literate programming blocks.

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
