Red [
    title: "Tetris Redborn!"
    description: "Red Tetris Game YAY!"
    author: @hiiamboris
    license: 'MIT
    version: 1.0.0
    needs: 'view
]	; TODO: resize?, autosnapshots?, clear KB buffer between piece drops?

now': does [now/time/precise]
random/seed now'

half-life: 90
sz: context [
	■': block': 0.7 * ■: block: 17x17
	full: ■ * map: 15x30
	band: 1x5 * line: as-pair full/x ■/y
	alpha: size-text/with system/view/screens/1 "O"
]
block': rejoin [block: reduce ['box 0x0 sz/■] sz/■/x / 5]

user: get-env either system/platform = 'windows ['username]['user]
bgimg: any [
	attempt/safer [ load rejoin [https://picsum.photos/ sz/full/x '/ sz/full/y '?random] ]
	make image! sz/full
]

→: make op! func [exp tgt] [compose/deep/into exp clear tgt]
xyloop: func ['p s c /local i] [
	any [pair? s  s: s/size]
	i: 0	loop s/x * s/y [
		set p 1x1 + as-pair i % s/x i / s/x
		do c
	i: i + 1	]
]

pieces: collect [	foreach spec [
	[cyan "  +" "  +" "  +" "  +" ""]
	[blue "+" "+++" ""]
	[brown "  +" "+++" ""]
	[yellow "++" "++"]
	[green " ++" "++" ""]
	[purple " +" "+++" ""]
	[red "++" " ++" ""]
][
	w: length? spec: next spec
	keep p: make image! 1x1 * w
	xyloop o p [ if #"+" = spec/(o/y)/(o/x) [p/:o: get spec/-1] ]
]]

grad: collect [foreach x #{FF F0 C8 5A FF} [keep 0.0.0.1 * x + white]]
draw sheen: make image! reduce [sz/■ glass] compose [
	pen (coal + 0.0.0.160)  fill-pen radial (grad) (sz/■) (sz/■/x * 1.5) (block')
]

render: function [map stor init plan] [
	also cmds: append clear first reverse stor init
	if map [xyloop o map [if white <> p: map/:o [ (bind plan 'plan) → tail cmds ]]]
]
render-map: func [map] [
	render map [[][]] [pen off] [ fill-pen (p) translate (o - 1x1 * sz/■) [(block') image sheen] ]
]
render-next: func [pc] [
	render pc [[]] [pen sienna text 5x0 "next:" pen off]
		[fill-pen (p + 0.0.0.120) translate (o + -1x1 * sz/■' + 5x5) [box 0x0 (sz/■' - 1x1)]]
]

summon-pc: has [o] [
	pc: until [also  rea/next-pc  rea/next-pc: random/only pieces]
	o: -3  until [
		pc-pos: as-pair sz/map/x - pc/size/x + 1 / 2 o
		if 1 < o: o + 1 [game-over]
		'bad <> imprint
	]
]

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

rotate: has [p /back] [
	draw pc [matrix [0 1 -1 0 (pc/size/x) 0] (pick [invert-matrix []] back) image pc] → []
	if 'bad = imprint [rotate/back  imprint]
]

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

clean: function [] [
	repeat y h: sz/map/y [
		if repeat x sz/map/x [
			also yes  if white = map/(as-pair x y) [break/return no]
		] [
			ln: lines/:y
			if 0 = ln/extra: ln/extra + 1 % 7 [
				draw map [image map crop 0x-1 (as-pair h y)] → []
				rea/score: 100 * (mul: 1 + any [mul 0]) + rea/score
			]
			ln/visible?: make logic! ln/extra % 2
		]
	]
]

read-hof: does [load https://gitlab.com/snippets/1730317/raw]
update-hof: has [r] [
	unview/only also view/no-wait/flags [h5 "Please wait a sec..."][modal no-title]
		r: write/info https://gitlab.com/api/v4/snippets/1730317
			reduce ['PUT [PRIVATE-TOKEN: "TamaPeMajqEuohv4_Ycw" Content-Type: "application/json"]
				rejoin [{^{"content": "} replace/all mold rea/scores {"} {\"} {"^}}]]
	200 = r/1
]

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

restart: does [set rea rea'  rea/t0: now'  map': copy map: make image! sz/map  summon-pc]

rea': copy rea: make deep-reactor! [
	elapsed: 0:0:0  score: 0  pause: no  t0: is [elapsed pause now']  next-pc: none
	interval: is [0.5 ** ((to-float elapsed) / half-life)]
	scores: []  scores: is [head clear skip sort/skip/reverse scores 2 20]
]

view/tight/options [
	style base': base glass coffee
	base (sz/full) (bgimg)
		focus on-key [
			k: event/key
			keys: quote (function [s b c] [if i: any [find s k find b k] [i: index? i  do bind c 'i]])
			keys "246sad"	[down left right]	[advance pick [0x1 -1x0 1x0] i - 1 % 3 + 1]
			keys " 0"		[insert]				[advance/force 0x1]
			keys "^M58w"	[up]					[rotate]
			keys "^["		[]						[rea/pause: not rea/pause]
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