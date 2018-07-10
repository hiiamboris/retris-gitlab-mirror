## RETRIS.RED Explained

This document aims to outline the inner workings and techniques used in Retris code.
It can be read on different levels.

For the **TLDR-dudes**, the **ideas** are marked in **bold**. For them it might be enough to skim the whole thing over.

**Beginners** might have a glance at how Red code might feel like and throw away the habits useful in other languages. Although I suggest they understand at least the syntactical basics and evaluation order and learn the most often used functions, otherwise many things will be hard to grasp.

**Perfectionists** seeking to empower themselves with every available trick might examine all the intricacies and (with luck) discover new ways to look at their own code.

Seasoned **gurus** might just feel content that Reduction goes on ☻
<br>

[[_TOC_]]
<br>

##### Naming convention

Many words I'm using are 1-letter **abbreviations** meaning of which is usually clear from the context:
- r for **r**esult
- p for **p**oint or **p**osition
- o for **o**ffset
- s for **s**ize (also sz) or **s**tring
- w for **w**idth
- h for **h**eight
- c for **c**ode
- i for **i**nteger counter
- k for **k**ey
- ln for **l**i**n**e
- pc for **p**ie**c**e (tetromino)
- ~~v for **v**endetta~~

### The header
```
Red [
    title: "Tetris Redborn!"
    description: "Red Tetris Game YAY!"
    author: @hiiamboris
    license: 'MIT
    version: 1.0.0
    needs: 'view
]
```
▲ The header can contain any junk I'd like it to. The only (not really enforced yet) rule is `needs: 'view` that loads the View module.

### Initialization
```
now': does [now/time/precise]
```
▲ I aim to reduce the repetition of words and make the code more readable.
`now'` function I will use a lot to tell me what's on the clock, with **milliseconds** precision or better.
<br>
```
random/seed now'
```
▲ I'm gonna be using the random number generator so I have to seed it.
<br>
```
half-life: 0:01:30
```
▲ This is the **difficulty** constant, the time (90 seconds) the falling rate doubles.
<br>
```
sz: context [
	■': block': 0.7 * ■: block: 17x17
	full: ■ * map: 15x30
	band: 1x5 * line: as-pair full/x ■/y
	alpha: size-text/with system/view/screens/1 "O"
]
```
▲ `sz` will contain various **size metrics**:
- `block` is for the normal single block. I'm aliasing it with a `■` symbol (ascii #254) because it's repeated a lot and the symbol looks very self-explanatory. <small>In fact, I'm not even using the `sz/block` anywhere :p but leave it here to better state the `■` symbol's intent.</small>
- The `■'` variant is scaled down to 70% for the next-piece preview widget.
- `map` is the game field size in blocks
- `full` is the game field size in pixels
- `line` is the size of one full block line in pixels (used by lightning effect before the blocks disappear)
- `band` is size in pixels of the pause announcement
- `alpha` is the size of the "O" letter using system default font, used for predicting the size of text elements

Inline definitions (`.. * map: ...` etc) work the same, just spare me repeating the words.
<br>
```
block': rejoin [block: reduce ['box 0x0 sz/■] sz/■/x / 5]
```
▲ These are draw dialect commands that will draw: a square (`block`) and a rounded square (`block'`). I'm gonna inline them a few times later. `block` will be smth like `[box 0x0 16x16]`, `block'` - like `[box 0x0 16x16 3]` (the last digit is the rounding radius).

<br>
<a id="username" name="username"></a>

```
user: get-env either system/platform = 'windows ['username]['user]
```
▲ Get the **OS username** (from the environment vars) to use as a default for when player enters the Top Ten. I wonder if case matters on some OSes?
<br>
```
bgimg: any [
	attempt/safer [ load rejoin [https://picsum.photos/ sz/full/x '/ sz/full/y '?random] ]
	make image! sz/full
]
```
▲ Here I'm trying to download a **random background** image from *picsum*, and if it fails I create an empty white image of the same size.
Works like this:
1. `load` raises an error,
1. `attempt` catches it and returns `none`,
1. `any` encounters `none` and tries to evaluate the next expression (which makes an empty image)
<br>

```
→: make op! func [exp tgt] [compose/deep/into exp clear tgt]
```
▲ At some point I realized I'm using [`compose`](#http://www.red-by-example.org/index.html#compose) way too often so I shortened it into an arrow operator `→` (ascii #26).
`clear tgt` part saves the RAM by clearing the block contents and thus reusing the same block over and over. <small><i>(This was written when Red had no working garbage collector and required manual memory management)</small></i>

**Works like this**: `[expressions] → target` becomes `compose/deep/into [expressions] clear target`.
<br>

```
xyloop: func ['p s c /local i] [
	any [pair? s  s: s/size]
	i: 0  loop s/x * s/y [
		set p 1x1 + as-pair i % s/x i / s/x
		do c
	i: i + 1 ]
]
```
▲ I'm gonna **iterate over 2D objects** (images) a lot so better be prepared: I define `xyloop` as sort of a user-defined loop (with the only exception that it also catches `exit`/`return`). It takes a word to hold the coordinate (`p` = point), size (`s` = size) (or object that has a `/size` property) and a block of code (`c` = code).
<br>
<a id="spec" name="spec"></a>

```
pieces: collect [	foreach spec [
	[cyan "  +" "  +" "  +" "  +" ""]
	[blue "+" "+++" ""]
	[brown "  +" "+++" ""]
	[yellow "++" "++"]
	[green " ++" "++" ""]
	[purple " +" "+++" ""]
	[red "++" " ++" ""]
][
```
▲ [`spec`](#spec) contains all the **tetrominoes definitions**. Color *name*, then line-by-line layout. For example: 	`[blue "+" "+++" ""]` is a 3x3 tetromino that I could express like:
<small>
```
[blue
"+  "
"+++"
"   "]
```

</small>You can see it's a `J`, but in the code I omitted the extra spaces since I'm only concerned about `+`s.

<br>

▼ [`foreach`](#spec) loop **transforms each** spec line into a **separate image**:
```
	w: length? spec: next spec
	keep p: make image! 1x1 * w
	xyloop o p [ if #"+" = spec/(o/y)/(o/x) [p/:o: get spec/-1] ]
]]
```
`w` (for width) becomes the number of rows/columns I defined for each tetromino. `spec` head is advanced by 1 so `spec/1` now refers to the first line, `spec/-1` to the color name. <small>Note that indexes can be either negative or positive, `0` being skipped</small>

`p` (for piece) holds a new (white by default) image of `w`x`w` size and that image is fed by `keep` to `collect` to be added to `pieces`.

`xyloop` loops over the `p` image (doing `w * w` iterations), putting coordinates into `o` (for offset): e.g. 1x1, 2x1, 3x1, 1x2, 2x2, and so on. When `"+"` is encountered, the color of point of `p` at offset `o` is changed from white to what's defined by `spec`. <small>`get` is there because colors are just words and weren't evaluated into color (tuple) values.</small>
<br>
<a id="sheen" name="sheen"></a>

```
grad: collect [foreach x #{FF F0 C8 5A FF} [keep 0.0.0.1 * x + white]]
draw sheen: make image! reduce [sz/■ glass] compose [
	pen (coal + 0.0.0.160)  fill-pen radial (grad) (sz/■) (sz/■/x * 1.5) (block')
]
```
▲ To speed up the animation I have to **prerender** most of the images I'm gonna use. This here is the **"sheen" effect** rendered on an image of `block` size:

`grad` is filled with a chain of white color points of different opacity (0 = opaque, 255 = transparent): <small>The result is rather ugly: `[255.255.255.255 255.255.255.240 255.255.255.200 255.255.255.90 255.255.255.255]`</small>

Then `sheen` is assigned a new image (`glass` = filled with transparent color) and `draw` renders a `radial` gradient on that image in a box previously defined as `block'`. <small>The gradient center `sz/■` and radius `sz/■/x * 1.5` parameters were derived via pure experimentation.</small>

`(coal + 0.0.0.160)` adds transparency to the `coal` color to make it look softer.

<br>

## Finally, meaningful functions

#### Render

This is a more or less **generic rendering mechanism** that takes:
- a `map` - an image where 1 pixel should expand into 1 visible block: this will be either the whole game area or only one tetromino
- a `stor` (for storage) block that contains the buffer into which the rendering will go
- an `init` block that contains the common set of commands to prefix the result with
- a `plan` that is *bound* to this very function and *composed* for each pixel that is not white

It then should return this block of `draw` commands (that should be assigned to a `draw` facet of some face to be *actually* drawn).
```
render: function [map stor init plan] [
	also cmds: append clear first reverse stor init
	if map [xyloop o map [if white <> p: map/:o [ (bind plan 'plan) → tail cmds ]]]
]
```
▲ Now this is gonna be a little tricky.
- The block `cmds` returned from this function (of that `also` takes care) will be assigned to a `draw` facet of some face, that in turn will actually draw it.
- To **avoid flickering** I should not change this *assigned* block until I'm finished preparing it. On the other hand I don't wanna allocate any new blocks, I want to reuse the same block over and over again. So as you'll see below, `stor` takes a **set of two blocks** - `[[][]]` - one is being drawn and a spare one that I'm going to modify. This block set is *persistent* between calls to `redraw`.
- A call to `reverse stor` ensures that at each call these blocks **are swapped** and I'm choosing the other one.
- `first` fetches one of them, that is then being `clear`ed and filled with the `init` data.
- Then looping over the `map`s pixels <small>(each being assigned to the `p` word)</small>, and only when they're not white (empty), I'm *composing* (with the `→` operator) the `plan` into the `cmds` block that I'm to return. 
- `bind` allows me to give meaning to words `p` and `o` from inside the `plan` declared in another function.

<br>

#### Render-map

A wrapper of `render` that renders the** whole game area**, given to it as `map` argument.
```
render-map: func [map] [
	render map [[][]] [pen off] [ fill-pen (p) translate (o - 1x1 * sz/■) [(block') image sheen] ]
]
```
As explained [previously](#render), `[[][]]` takes care of flickering.
The `init` is `[pen off]` since I wanna draw no lines but only solid squares.
The `plan` contains a coordinate translation at which then a solid square `block'` is rendered and over it - a prerendered [`sheen`](#sheen) effect.
<small>As you probably know the operators in Red/Rebol have no precedence and are evaluated from left to right (`-` then `*` in this case).</small>

<br>

#### Render-next

It's a tiny widget in the upper left corner that shows the **next tetromino** *(piece)* that will appear (given to it as `pc` argument). It wraps `render` to do so.
```
render-next: func [pc] [
	render pc [[]] [pen sienna text 5x0 "next:" pen off]
		[fill-pen (p + 0.0.0.120) translate (o + -1x1 * sz/■' + 5x5) [box 0x0 (sz/■' - 1x1)]]
]
```
Here I could care less about flickering, so I'm giving `stor` only one block `[[]]`.
`init` block also contains the explanatory label.
And `plan` is the same idea as before, with minor adjustments: semi-transparent blocks and more sophisticated positioning to account for the text label.

<br>

#### Summon-pc

Takes the **next tetromino** and allows it to be moved/rotated, and also chooses **another random** one to be the next.
```
summon-pc: has [o] [
	pc: until [also  rea/next-pc  rea/next-pc: random/only pieces]
	o: -3  until [
		pc-pos: as-pair sz/map/x - pc/size/x + 1 / 2 o
		if 1 < o: o + 1 [game-over]
		'bad <> imprint
	]
]
```
Again, a little bit of tricks. On the first invocation, `rea/next-pc` (that contains the next piece) is `none` so I need to **call `random` twice**: once to choose the current piece, and second time to choose the next one. `also` follows 2 goals at once: makes sure `until` fires again in case `rea/next-pc` is `none`, and returns the previous `next-pc` to be assigned to `pc`. After that it will always take one iteration.
So, a global word `pc` now holds the chosen tetromino, `next-pc` - next one.

Then I need to try to summon the piece **as high as possible** but it must be wholly visible. I start with the vertical offset of `-3` blocks and increment it until the whole piece fits in. In case it doesn't - it must be obstructed by the other blocks and so it's a **game over condition**.
`pc-pos` is a global word that contains the current tetromino offset in the game map. It's `x` offset is calculated from the map size and the tetromino size, and `y` offset is being tried continuously from `-3` to `1`, until [`imprint`](#imprint) function stops returning `bad` flag (which means that some occlusion happened and I should continue trying).

<br>

#### Imprint

Globally I have two maps of the game area - **`map`** that only contains the **stationary blocks**, and **`map'`** that is a copy of `map` with the currently **moving tetromino imprinted** on it. In both maps one pixel is one block, that's why they're *maps*.

So the point of this function is to prepare the `map'` from `map` and show it, or return a `bad` flag if it can't do so. In case of `bad` the caller should restore the `map'` back manually or call `imprint` again.

```
imprint: has [o p r] [
	draw map' [image map]
	if 'bad <> r: xyloop o pc [
		if white <> pc/:o [
			p: o + pc-pos
			unless all [ within? p 1x1 sz/map  white = map'/:p ] [return 'bad]
			map'/:p: pc/:o
		]
	] [canvas/draw: render-map map']
	r
]
```
First of all, to save some RAM I do not copy images (I could write `map': copy map`). Instead I'm drawing the `map` over `map'`. This is a temporary necessity, but also an optimization idea that might be worth leaving as is.

`xyloop` goes over the whole current tetromino (global `pc`) and tries to replace (with `map'/:p: ...` expression) every empty (white) point of `map'` with this tetromino color.
There's a couple of conditions checked: non-white points of `pc` should fit into the game area (`within?` condition), and `map'` in their place should be empty (white) or else it's invalid to imprint there.
In case any of these conditions fail, `bad` flag is returned - from the `xyloop` <small>(I could've used `break/return 'bad` as well, but since `xyloop` is a function normal return works also)</small>. The result is saved (into `r:`) to be returned, and if it's *not* a `bad` flag then the `map'` is actually rendered on the `/draw` facet of `canvas` face dedicated for that purpose. This is why when *Space* key is pressed, the **tetromino runs down** line by line and not just pops up at the bottom - **`imprint` draws it** while being called repeatedly by [`advance`](#advance).

<br>

#### Rotate

What can be simpler than **rotate a tetromino**? Thing is however that `rotate` keyword used by `draw` expects a pair of **integer** coordinates, but in case of 3x3 and 5x5 tetrominoes the center appears at **1.5x1.5 and 2.5x2.5** points and is impossible to express with `pair!` datatype *yet*.
```
rotate: has [p /back] [
	draw pc [matrix [0 1 -1 0 (pc/size/x) 0] (pick [invert-matrix []] back) image pc] → []
	if 'bad = imprint [rotate/back  imprint]
]
```
Matrix to the rescue.
X axis is rightwise, Y is downwards. Rotated clockwise, new axes become: X' = -Y, Y' = X. So the matrix core is:

|   |   X|   Y|
|---|---:|---:|
|X' |   0|  -1|
|Y' |   1|   0|

My X becomes negative however so I have to add the *piece width* `pc/size/x` to it to obtain the final matrix:

|   |   X|   Y| constant|
|---|---:|---:|     ---:|
|X' |   0|  -1|pc/size/x|
|Y' |   1|   0|        0|

Using the ordering specified by [`draw` documentation](https://doc.red-lang.org/en/draw.html#_matrix) it's trivial to lay these numbers out into a block: `matrix [0 1 -1 0 (pc/size/x) 0]`.

I **rotate** `pc` <small>(global word referring to the current tetromino)</small> *in place* **by drawing it over itself**, so in case my rotation fails (obstructed or out of game area) I need a **backwards rotation** too. For that I can just **invert the matrix**. `pick` chooses the 1st argument `invert-matrix` if `/back` refinement is `true`, and the 2nd `[]` otherwise.

Now all that's left is try to `imprint` the rotated piece and restore it when that fails (with `bad` flag).

<br>

#### Advance

Supposedly triggered by timer (or key press) this func should **move the tetromino** in some direction, specified with `by` argument: -1x0/1x0 for left/right, 0x1 for downward shift.
`/force` is used to move the piece until it hits the bottom.
```
advance: func [by /force /local prev-pos] [
	until [
		pc-pos: by + prev-pos: pc-pos
		if 'bad = imprint [
			pc-pos: prev-pos  imprint
			if 0 <> by/y [draw map [image map']  summon-pc]
			break
		]
		not force
	]
]
```
It's logic is probably the easiest. Back up the piece position `pc-pos` as `prev-pos` then advance it, try to imprint.
Fails? Restore the correct position, imprint it there. If it was a downward move (`by/y` is non-zero), use the imprinted `map'` as a new game area `map` then summon the next piece.

This happens once if `/force` was not specified. Otherwise until `imprint` returns `bad` and thus `break` quits the loop.

<br>

#### Clean

Does 3 things:
- **scans** the game field for **complete horizontal lines**
- animates them with **flashes** 3 times
- **destroys** them after that and moves the upper content downwards

```
clean: function [] [
	repeat y h: sz/map/y [
```
▲ Going line by line with `y` from 1 to `h` (height)
```
		if full: repeat x sz/map/x [
			also yes  if white = map/(as-pair x y) [break/return no]
		] [
```
▲ `repeat` over the line goes pixel by pixel, checking: if pixel isn't white, stop and return `no` (false). Otherwise the loop returns the result of last expression evaluated, which is `also`, that yields `yes`. <small>`full` is never used and is there to state the intent only.</small>

The result is passed to `if`, and then the if-body can be reached!
```
			ln: lines/:y
```
▲ What is [`lines`](#lines)? It's a block (array) of (normally hidden) faces that contain the lightning effect, one face for each horizontal line.
I need two things from `lines`: **show** and **hide** them repeatedly, and **hold the counter** of shows-hides until it hits 3+3+1=7 - 3 times shown, 3 times hidden, now is the time to remove the line. I use the `/extra` facet of every line face to store the counter:
```
			if 0 = ln/extra: ln/extra + 1 % 7 [
```
▲ Increment it until it's 7 then:
```
				draw map [image map crop 0x-1 (as-pair h y)] → []
```
▲ I take `map` with an extra empty line above it (`crop 0x-1`) and draw it over itself at 0x0. As a result, **everything shifts down** and the current line is lost.
```
				rea/score: 100 * (mul: 1 + any [mul 0]) + rea/score
```
▲ Every line destroyed should be reflected on player's score. `mul` is the **score multiplier** that is incremented for each line destroyed in a row. So, 100+200=300 for 2 lines, 100+200+300=600 for 3 lines, and 1000 for 4 lines. <small>`any [mul 0]` returns 0 on the first use of `mul`.</small>
```
			]
			ln/visible?: ln/extra % 2 = 1
		]
	]
]
```
▲ Line visibility state changes every time until it's destroyed and is no more a *complete* line: `ln/extra % 2` switches from 0 to 1 and back, ` = 1` transforms that into false/true values.

<small>

Full function source overview for convenience:
```
clean: function [] [
	repeat y h: sz/map/y [
		if full: repeat x sz/map/x [
			also yes  if white = map/(as-pair x y) [break/return no]
		] [
			ln: lines/:y
			if 0 = ln/extra: ln/extra + 1 % 7 [
				draw map [image map crop 0x-1 (as-pair h y)] → []
				rea/score: 100 * (mul: 1 + any [mul 0]) + rea/score
			]
			ln/visible?: ln/extra % 2 = 1
		]
	]
]
```

</small>

<br>

### Hall of Fame support

This part is mostly **boring** and contains the **bloat** necessary to interface with the bloated external system. Although...
<br>
```
read-hof: does [load https://gitlab.com/snippets/1730317/raw]
```
▲ Reads the hall of fame stored at a secret location ☺
<br>
```
update-hof: has [r] [
	unview/only also view/no-wait/flags [h5 "Please wait a sec..."][modal no-title]
		r: write/info https://gitlab.com/api/v4/snippets/1730317
			reduce ['PUT [PRIVATE-TOKEN: "TamaPeMajqEuohv4_Ycw" Content-Type: "application/json"]
				rejoin [{^{"content": "} replace/all mold rea/scores {"} {\"} {"^}}]]
	200 = r/1
]
```
▲ Stores the hall of fame there using the **undocumented** `write/info` trick discovered from @rebolek's [`http-tools`](https://github.com/rebolek/red-tools/blob/master/http-tools.red) (thanks!). <small>It allows one to send **custom http requests**, in my case I need a `PUT` request, provide a token and specify the only content type that my secret vault seemingly accepts (`json`, hence the need to escape every double-quote `mold` will produce).</small>

This operation **takes a while** (up to a few seconds), so it's a good practice to tell the user that Retris did not hang: for that reason `view` shows **a message**, then `also` makes the request and once it's over - passes the returned window face to `unview/only` to remove it from the screen.

Function returns `true` in case everything's good (the server returns 200 OK) so the calling func may tell the user if his precious score was recorded or blocked by Illuminati firewalls.

<br>

### Game over logic

Once [`summon-pc`](#summon-pc) fails it calls `game-over`.
Does 3 things:
- **pauses** the game event loop
- reads the **score board** and (if applicable) puts the player there and writes it back
- shows the score, the board and allows to **restart or quit**
<br>

```
game-over: has [lowest saved] [
	rea/pause: saved: yes
```
▲ `pause` is a reactive variable, that is it is using the [builtin reactivity of Red](https://doc.red-lang.org/en/reactivity.html) to trigger events when it changes. I have all reactive variables I'm using [in one place](#rea).
So, setting it to `yes` is enough to trigger a game-pause event. How it works? Below are a few places where `pause` is used: [one](#pause0), [two](#pause1), [three](#pause2), [four](#pause3)
<small>`saved` is just a flag I'm gonna later set to `no` if `update-hof` fails. It's purpose is purely informative.</small>
<br>
```
	rea/scores: any [attempt/safer [read-hof] []]
```
▲ `read-hof` reads the Hall of Fame or fails - in that case `attempt` yields `none` and `any` chooses the alternative - the empty list `[]`.
<br>
```
	lowest: any [pick tail rea/scores -2  0]
	if any [lowest < rea/score  20 > length? rea/scores] [
```
▲ `scores` are [automatically sorted and trimmed to 10 places](#scores) so to **choose the lowest** it's enough to look at the tail: [.... lowest-score player-name]. In case the block is empty, zero score is used.

Player has to beat the lowest score to **enter the Hall of Fame** (`lowest < score`). Or alternatively he can enter there if any of the Top Ten places aren't claimed (`20 < length? scores`).

If that happens I dare ask winner his name, defaulting it to [OS username](#username) - with `(user)` substitution:
```
		view/flags/options [
			h3 "You've entered the Top 10!" return
			h5 "Enter your name:"
			field center (user) react [user: replace/all face/text (charset [0 - 31 {"\}]) "_"]
			button focus "Ha! Worship me!" [unview]
		] → [] [modal] [text: "Top Score!"]
```
▲ A reactive relation `[user: ...]` automatically updates my global `user` word with the text entered. It's filtered from unacceptable characters that JSON won't accept easily (and I'm lazy to properly escape them as \uXXXX).
<small>`(charset [..])` is evaluated at compose stage into a `bitset!` value, else every char entered would have recreated it.
`[modal]` flag is used everywhere to block the other windows until this one is dealt with. `[text: ...]` facet of a window is it's title.</small>
<br>
```
		repend rea/scores [rea/score user]
		saved: attempt/safer [update-hof]
	]
```
▲ Once name is confirmed, **current score and username** is added to the `scores` block (which then sorts and trims itself), and I'm trying to **update the score board** on the server.
<br>
Okay, now that window is closed, time for the primary game-over window.
```
	view/flags/options [
		panel [
			h1 center wrap (sz/alpha * 16x8) "GAME OVER" return
			button (sz/alpha * 8x2) focus "Restart" [unview]
			button (sz/alpha * 8x2) "Quit" [quit]
		]
```
▲ This panel holds **items on the left**: a big announcement and 2 buttons.
<br>
```
		panel [
			h5 "Hall of Fame:" return
			text-list (sz/alpha * 18x10) data
				[(collect [ i: 0 foreach [sc u] rea/scores [keep rejoin [i: i + 1 ". " u " with " sc]] ])]
		]
```
▲ And this one holds **items to the right**: the score board list and it's title. The contents of the list is composed on the fly using `collect`/`foreach`/`keep` common technique.
<br>
```
	] → [] [modal][ text: rejoin ["Hall of Fame" pick ["" " (unable to save)"] saved] ]
```
▲ Note as usual the handy `→` composition operator and the adaptive title text: it contains an "(unable to save)" warning in case Illuminati have you on their list. So watch out!
<br>
```
	restart
]
```
▲ As you've probably noticed already, there are 2 ways to close the window:
- by hitting "Restart" button (or closing it by OS means) - which leads execution to continue and `restart` starts a new game
- by hitting "Quit" in which case the program stops.

<small>

Full function source overview for convenience:
```
game-over: has [lowest saved] [
	rea/pause: saved: yes
	rea/scores: any [attempt/safer [read-hof] []]
	lowest: any [pick tail rea/scores -2  0]
	if any [lowest < rea/score  20 > length? rea/scores] [
		view/flags/options [
			h3 "You've entered the Top 10!" return
			h5 "Enter your name:"
			field center (user) react [user: replace/all face/text (charset [0 - 31 {"\}]) "_"]
			button focus "Ha! Worship me!" [unview]
		] → [] [modal] [text: "Top Score!"]
		repend rea/scores [rea/score user]
		saved: attempt/safer [update-hof]
	]
	view/flags/options [
		panel [
			h1 center wrap (sz/alpha * 16x8) "GAME OVER" return
			button (sz/alpha * 8x2) focus "Restart" [unview]
			button (sz/alpha * 8x2) "Quit" [quit]
		]
		panel [
			h5 "Hall of Fame:" return
			text-list (sz/alpha * 18x10) data
			[(collect [ i: 0 foreach [sc u] rea/scores [keep rejoin [i: i + 1 ". " u " with " sc]] ])]
		]
	] → [] [modal][ text: rejoin ["Hall of Fame" pick ["" " (unable to save)"] saved] ]
	restart
]
```

</small>

### Restart
Starts the game, again.
```
restart: does [set rea rea'  rea/t0: now'  map': copy map: make image! sz/map  summon-pc]
```
2 images are created: **`map`** to hold the **imprinted blocks**, and **`map'`** to also hold the **moving one**. The latter is being shown on screen.

`rea/t0` is assigned the current time, that will be used to advance the **game clock** (minus moments when it's paused).

<a id="rea" name="rea"></a>

`rea` is right below. It's a **reactor** object that contains all the data that (by my design) when changed will **trigger some events**. `rea'` simply contains it's initial state so it's easier to reset `rea` back. `set rea rea'` does just that by overwriting all fields of `rea` with those from `rea'`. 
<small>Note that `rea'` is technically a reactor too but it won't "work" since `copy` does not register any new reactive relations.</small>
<a id="pause0" name="pause0"></a>

### Reactive stuff
<a id="scores" name="scores"></a>

```
rea': copy rea: make deep-reactor! [
	elapsed: 0:0:0  score: 0  pause: no  t0: is [elapsed pause now']  next-pc: none
	interval: is [0.5 ** (elapsed / half-life)]
	scores: []  scores: is [head clear skip sort/skip/reverse scores 2 20]
]
```
`deep-reactor!` is a kind of object that recursively detects every change in all the series it contains.

`elapsed` will hold the **true game time**. `score` - player's **score**. When these change they are **automatically reflected** on the window.

`pause` will enable/disable game events and show/hide a [huge notice](#pause3).

`t0` is trickier: it sets itself to current time by calling `now'` when any of `elapsed` or `pause` are changed. Trick is these words' **values are discarded** by `[elapsed pause now']` expression but `is` will **make reactions** for them so that the expression is evaluated when they change.

`next-pc` is not known yet, will be set by [`summon-pc`](#summon-pc).

`interval` **controls the rate** at which the tetromino moves automatically, thus affecting the difficulty, using simplest exponential formula:
*<center>interval = 2<sup> ―t/T<sub><small>1/2</small></sub></sup></center>*

I hold scores as a block: `[score player score player ...]`

Interesting thing is that I make them **automatically sorted** and cut to the **length of 10** pairs (score + name). `sort/skip/reverse scores 2` sorts scores (in descending order) using each 1st of 2 items as the key. `clear skip .. 20` part removes everything after the 20th item, and `head` returns the head of the block rather than the point at which it was cleared.
I define `scores` twice because the sorting expression requires scores already be defined, so the 1st definition acts as an initial state, while the 2nd defines a reactive relation with `is` operator.
<br>

## The game window

Here's where the most of the high level logic happens. VID dialect combined with `compose` is unbelievably powerful. Note how little supporting info it requires: most of the words just designate what data a face should hold. <small>The only problem is using ([ ]) to wrap expressions that should *not* be evaluated on compose stage. Can get quite ugly...</small>
<br>
```
view/tight/options [
	style base': base glass coffee
```
▲ By default most of the `base` faces I'm using are transparent so I define a style for them with `glass` (invisible) background.

The **order of faces** declaration sets their Z-ordering, thus later ones are drawn on top of the former.
<br>
```
	base (sz/full) (bgimg)
```
▲ This covers the whole window and displays a background image.
<br>
```
		focus on-key [
			k: event/key
			keys: quote (function [s b c] [ if i: any [find s k find b k] [i: index? i  do bind c 'i] ])
			keys "246sad"   [down left right] [advance pick [0x1 -1x0 1x0] i - 1 % 3 + 1]
			keys " 0"       [insert]          [advance/force 0x1]
			keys "^M58w"    [up]              [rotate]
			keys "^["       []                [rea/pause: not rea/pause]
		]
```
▲ I'm giving it `focus` so it will receive the **keyboard** events. There's no other face that can accept focus with mouse clicks so it's safe to assume the focus stays there always.

`on-key` fires when the key is pressed/held, providing me with the key name as `event/key`. Sometimes it's a **word**, sometimes a **char**, so I need to **accept both** to be able to easily declare **multiple key aliases** - keypad with Numlock on and off, plus WASD for left hand cowboys.

I declare a `keys` function that accepts some chars (as a string `s`) + some words (in a block `b`) and executes the code `c` when `k` matches any of those keys. I could just declare it there, but then it would've been recreated each time `on-key` is called. Since I'm really tight on RAM and can't spare more than a few KBs, I'm making this function on the **`compose` stage** and it becomes a ready **`function!` value** inside the code block. It would have been executed outright had I not prefixed it with `quote`.

`bind` is there to make index `i` available to the provided code `c`.

Then I declare which keys should trigger what actions. Note that Down/Left/Right keys do almost the same - move the tetromino, only in different directions. So instead of declaring:
<small>
```
	keys "2s" [down] [advance 0x1]
	keys "4a" [left] [advance -1x0]
	keys "6d" [right] [advance 1x0]
```

<a id="pause1" name="pause1"></a>
</small>I **arrange the keys in triplets** and deal with the index `i` in the triplet to choose a proper move direction.
Tip: `^M` = 13 is Enter key, `^[` = 27 is Esc.

<br>

```
		rate 0:0:1 on-time [
			unless rea/pause [
				advance 0x1
				rea/elapsed: rea/elapsed + modulo now' - rea/t0 24:0:0
				face/rate: rea/interval * 0:0:1
			]
		]
```
▲ I set a **timer** to this background face, defaulting to every 1 second. It **moves the tetromino down** when not paused, but also counts the true game time, and based on that - **changes it's own rate**.

As you've seen in [`rea` definition](#rea), setting `rea/elapsed` triggers a change in `rea/interval`. Reactions are propagated synchronously so `face/rate:` gets the up to date rate.
<small>`interval` is a `float!`, so I have to **convert it to `time!`** by multiplying by 1 second.
`modulo (...) 24:0:0` ensures the timer doesn't glitch when the clock **hits midnight**.
`now' - rea/t0` is **time passed** since last on-time event, or since last change of `pause` which is important when the game is restarted - last event was long ago.</small>
<br>
```
	return middle
```
▲ `return` starts a new line of faces below, while `middle` tells it should be centered vertically
<br>
```
	h4 "Score: 00000" center react ([ [face/data: ["Score:" (rea/score)] → []] ])
```
▲ `h4` is the smallest of headings, `"Score: 00000"` tells it it should be long enough to fit this string, so I can omit the manual size calculation.

Reactive relation is used to set the `data` facet to reflect the `score`. <small>Setting `data` of a text face automatically triggers a change of it's `text` facet as `text: form data`. That text is then displayed.
`([ ])` block tells `compose` to leave this part as is, otherwise `(rea/score)` would have been replaced with the value right now, not when the reaction is triggered.</small>
<br>
```
	text (sz/alpha * 12x3) font-size 11 react [
		([ ["Time:" (round rea/elapsed) "^/Difficulty:" (round -20% * log-2 rea/interval)] ])
		→ face/data: []
	]
```
▲ To the right of that heading, I make a 2-line label (note the line-break "^/"). Automatic size calculation won't work for multiline text so I'm specifying it manually as `(sz/alpha * 12x3)`.
Another reactive relation tells what text it should display, and renew when `rea/elapsed` or `rea/interval` change.

The idea behind `difficulty` value is that it should **start with zero** and **linearly reach 100%** at the point when player is definitely about to lose. The 20% constant was selected experimentally.
<br>
```
	at 0x0 image (
		also grid: make image! reduce [sz/full glass]
		xyloop o sz/map [
			c: o/x + o/y % 2 * 2 - 1 * 40.40.40 + 99.99.130.140
			draw grid [pen off fill-pen (c) translate (o - 1x1 * sz/■) [(block)]] → []
		])
```
▲ Note all faces from now on use absolute positioning - `at 0x0`.

I'm making a new image and drawing a **translucent grid** on it, then passing it as data to the `image` face to display. <small>`also` discards the result of the loop and returns the image.</small>

`o/x + o/y % 2` makes a **checkered 0/1 pattern**, then with ` * 2 - 1` it's transformed into -1/1 pattern, which is then multiplied by an "offset" color 40.40.40 and is added to the "base" color 99.99.130.140 <small>(which is translucent bluish grey). The colors were handpicked to make grid visible on most backgrounds without obscuring them.</small>
<br>
```
	at 0x0 base' (sz/■ * 5x7) react [face/draw: redraw-next rea/next-pc]
```
<a id="pause2" name="pause2"></a>
▲ Transparent base 5x7 blocks in size to display the **next tetromino**. Note how the reactive relation should include the trigger - `rea/next-pc`, that causes a redraw.
<br>

```
	at 0x0 canvas: base' (sz/full) on-created [restart] rate 30 on-time [clean]
```
<a id="pause3" name="pause3"></a>
▲ Another base - `canvas` - on which all the blocks are being drawn. It also serves as a trigger for game start event ([`restart`](#restart)) and performs the scan of the game area with [`clean`](#clean) 30 times per second. The number affects how fast the lightning effect happens. <small>It's name is used in the [`imprint` func](#imprint).</small>
<br>

```
	at (sz/full - sz/band / 2 * 0x1)
		base' (sz/band) bold font-size 30 "Taking a breath..."
		react [face/visible?: rea/pause]
```
<a id="lines" name="lines"></a>
▲ This is the huge text announcement that appears visible when `rea/pause` is true. Size is adjusted so it sits at the center vertically.
<br>

```
	style line: base' hidden (sz/line) extra 0 (lines: [])
```
▲ The `line` style is used to fill the whole area with neon lines (initially hidden) used by lightning effect. `extra` facet is used to hold the show/hide counter (see [`clean` func](#clean)).

`lines: []` is a global word, I just initialize it here since it's closely related to this face.
<br>
```
		on-create [face/offset: sz/■/x * 0x1 * length? lines  append lines face]
```
▲ Every line created should add itself to `lines` list and automatically decide at which height it should appear.
<br>
```
		draw [
			fill-pen linear (white + 0.0.0.255) (cyan + 0.0.0.128) 0.6 white 0x0 (sz/■ * 0x1 / 2) reflect
			pen off  box 0x0 (sz/line)
		]
```
▲ Here's a list of commands to draw the line. A long horizontal `box` with vertical gradient `reflect`ed from it's middle point. Fully transparent - to semi-transparent cyan - to white - and then back.
<br>
```
	(append/dup [] [at 0x0 line] sz/map/y)
] → [] [text: "Retris 1.0"]
```
▲ `[at 0x0 line at 0x0 line at 0x0 line ...]` block is made to create as many lines as `map` can hold. Initially at the 0x0 coordinate they will reposition themselves (0x0 is specified to hold the main window from growing up). The composition operator `→` inlines the resulting block.
<br>

<small>

Full window source overview for convenience:
```
view/tight/options [
	style base': base glass coffee
	base (sz/full) (bgimg)
		focus on-key [
			k: event/key
			keys: quote (function [s b c] [if i: any [find s k find b k] [i: index? i  do bind c 'i]])
			keys "246sad"  [down left right] [advance pick [0x1 -1x0 1x0] i - 1 % 3 + 1]
			keys " 0"      [insert]          [advance/force 0x1]
			keys "^M58w"   [up]              [rotate]
			keys "^["      []                [rea/pause: not rea/pause]
		]
		rate 0:0:1 on-time [
			unless rea/pause [
				advance 0x1
				rea/elapsed: rea/elapsed + modulo now' - rea/t0 24:0:0
				face/rate: rea/interval * 0:0:1
			]
		]

	return middle
	h4 "Score: 00000" center react ([ [face/data: ["Score:" (rea/score)] → []] ])
	text (sz/alpha * 12x3) font-size 11 react [
		([ ["Time:" (round rea/elapsed) "^/Difficulty:" (round -20% * log-2 rea/interval)] ])
		→ face/data: []
	]

	at 0x0 image (
		also grid: make image! reduce [sz/full glass]
		xyloop o sz/map [
			c: o/x + o/y % 2 * 2 - 1 * 40.40.40 + 99.99.130.140
			draw grid [pen off fill-pen (c) translate (o - 1x1 * sz/■) [(block)]] → []
		])

	at 0x0 base' (sz/■ * 5x7) react [face/draw: render-next rea/next-pc]
	at 0x0 canvas: base' (sz/full) on-created [restart] rate 30 on-time [clean]

	at (sz/full - sz/band / 2 * 0x1)
		base' (sz/band) middle bold font-size 30 "Taking a breath..."
		react [face/visible?: rea/pause]

	style line: base' hidden (sz/line) extra 0 (lines: [])
		on-create [face/offset: sz/■/x * 0x1 * length? lines  append lines face]
		draw [
			fill-pen linear (white + 0.0.0.255) (cyan + 0.0.0.128) 0.6 white 0x0 (sz/■ * 0x1 / 2) reflect
			pen off  box 0x0 (sz/line)
		]
	(append/dup [] [at 0x0 line] sz/map/y)
] → [] [text: "Retris 1.0"]
```

</small>

<br>

###### Found something obscure yet unexplained?
Ask me in [gitter](https://gitter.im/hiiamboris).

<br>

[[_TOC_]]



