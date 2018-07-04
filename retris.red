Red [
    title: "Tetris Redborn!"
    description: "Red Tetris Game YAY!"
    file: %retris.red
    author: @hiiamboris
    license: 'MIT
    needs: 'view
]

; TODO: resize?, autosnapshots?, comments!

now': does [now/time/precise]
random/seed now'

sz: context [
	block: 16x16  map: 16x32
	full: map * block
	band: 1x5 * line: as-pair full/x block/y
	edge: block/x
	alpha: size-text/with system/view/screens/1 "O"
]
half-life: 60
user: get-env either system/platform = 'windows ['username]['user]
bgimg: any [attempt/safer [
	load rejoin [https://picsum.photos/ sz/full/x '/ sz/full/y '?random]
] make image! sz/full]

xyloop: func ['p s c /local i] [
	any [pair? s  s: s/size]
	i: 0	loop s/x * s/y [
		set p 1x1 + as-pair i % s/x i / s/x
		do c
	i: i + 1	]
]

pieces: collect [
	foreach spec [
		[cyan "  +" "  +" "  +" "  +" ""]
		[blue "+" "+++" ""]
		[brown "  +" "+++" ""]
		[yellow "++" "++"]
		[green " ++" "++" ""]
		[purple " +" "+++" ""]
		[red "++" " ++" ""]
	] [
		c: get spec/1
		w: length? spec: next spec
		keep p: make image! 1x1 * w
		xyloop o p [ if #"+" = spec/(o/y)/(o/x) [p/:o: c] ]
	]
]

grad: collect [foreach x #{FF F0 C8 5A FF} [keep to-tuple rejoin [#{FF FF FF} x]]]
redraw: function [] [
	cmds: clear first stor: [[] []]
	xyloop o map' [
		o1: (o2: sz/block * o) - sz/block
		box: reduce/into ['box o1 o2 sz/edge / 5] clear []
		fp: 'fill-pen  pfx: compose [pen off  (fp) off (fp)]
		grid: o/x + o/y % 2 * 2 - 1 * 40.40.40.0 + 99.99.130.140
		append cmds compose/into either white = p: map'/:o
			[[ (pfx) (grid) box (o1) (o2) ]]
			[[ (pfx) (p) (box)  pen coal (fp) radial (grad) (o2) (sz/edge * 1.5)  (box) ]]
			clear []
	]
	canvas/draw: last reverse stor
]

redraw-next: function [pc] [
	also append cmds: clear [] [pen sienna text 0x0 "next:" pen off]
	if pc [xyloop o pc [if white <> p: pc/:o [
		o1: (o2: o + 1x2 * sz/block * 0.7) - (sz/block * 0.7)
		append cmds compose/into [fill-pen (p + 0.0.0.120) box (o1) (o2)] clear []
	]]]
]

draw-pc: has [o] [
	pc: until [also  attempt [rea/next-pc]  rea/next-pc: random/only pieces]
	o: -3  until [
		pc-pos: as-pair sz/map/x - pc/size/x + 1 / 2 o
		if 3 < o: o + 1 [game-over]
		'bad <> imprint
	]
]

imprint: has [o p r] [
	draw map' [image map]
	r: xyloop o pc [
		if white <> pc/:o [
			p: o + pc-pos
			unless all [ within? p 1x1 sz/map  white = map'/:p ] 
				[return 'bad]
			map'/:p: pc/:o
		]
	]
	if 'bad <> r [redraw]
	r
]

rotate: has [p] [
	p: copy pc
	draw pc compose/deep/into [matrix [0 1 -1 0 (p/size/x) 0] image p] clear []
	if 'bad = imprint [pc: p  imprint]
]

advance: func [by /force /local bk] [
	until [
		pc-pos: by + bk: pc-pos
		if 'bad = imprint [
			pc-pos: bk
			if 0 <> by/y [imprint  draw map [image map']  draw-pc]
			break
		]
		not force
	]
	imprint
]

clean: has [x y h ln mul] [
	mul: 0
	repeat y h: sz/map/y [
		ln: lines/:y
		if repeat x sz/map/x [
			if white = map/(as-pair x y) [break/return no]
			yes
		] [
			if 0 = ln/extra: ln/extra + 1 % 7 [
				draw map compose/into [image map crop 0x-1 (as-pair h y)] clear []
				rea/score: 100 * (mul: mul + 1) + rea/score
			]
			ln/visible?: make logic! ln/extra % 2
		]
	]
]

json-escape: func [s] [ cs: charset [0 - 20 "\^""]  parse s [any [p: cs (insert p "\") skip | skip]]  s ]
update-hof: has [wnd] [
	wnd: view/no-wait [h5 "Please wait a sec..."]
	write/info https://gitlab.com/api/v4/snippets/1730317
		reduce ['PUT [PRIVATE-TOKEN: "TamaPeMajqEuohv4_Ycw" Content-Type: "application/json"]
			rejoin [{^{"content": "} json-escape mold rea/scores {"^}}]]
	unview/only wnd
]
read-hof: does [load https://gitlab.com/snippets/1730317/raw]

game-over: has [lowest] [
	rea/pause: yes
	rea/scores: any [attempt/safer [read-hof] []]
	lowest: pick tail rea/scores -2
	if any [lowest < rea/score  20 > length? rea/scores] [
		view compose/deep [
			h3 "You've entered the Top 10!" return
			h5 "Enter your name:"
			field center (user) react [user: face/text]
			button "Ha! Worship me!" [unview]
		]
		repend rea/scores [rea/score user]
		any [attempt/safer [update-hof]  append user " (unable to save)"]
	]
	
	view compose/deep/only [
		panel [
			h1 center wrap (sz/alpha * 16x8) "GAME OVER" return
			button (sz/alpha * 8x2) focus "Restart" [unview]
			button (sz/alpha * 8x2) "Quit" [quit]
		]
		panel [
			h5 "Hall of Fame:" return
			text-list (sz/alpha * 14x10) data
				(collect [ i: 0 foreach [sc u] rea/scores [keep rejoin [i: i + 1 ". " u " with " sc]] ])
		]
	]
	restart
]

restart: does [start  draw-pc]
start: does [set rea rea'  rea/t0: now'  map': copy map: make image! sz/map]

lines: []
whit2: to-tuple #{FFFFFFFF}
cyan2: to-tuple #{00FFFF80}
rea': copy rea: make deep-reactor! [
	elapsed: 0:0:0  score: 0  pause: no  t0: is [elapsed pause now']  next-pc: none
	interval: is [(atan (to-float elapsed) / half-life) / (pi / -2) + 1.0]
	scores: []  scores: is [head clear skip sort/skip/reverse scores 2 20]
]

start

wnd: view/tight/options/no-wait compose/deep [
	game: base (sz/full)
		draw [image (bgimg)]
		focus on-key [
			k: event/key
			keys: quote (func [s b] [ any [find s k find b k] ])
			case [
				i: keys "246sad" [down left right]
					[advance pick [0x1 -1x0 1x0] -1 + ([(index? i)]) % 3 + 1]
				keys " 0" [insert] 
					[advance/force 0x1]
				keys "^M58w" [up enter]
					[rotate]
				keys "^[" []
					[rea/pause: not rea/pause]
			]
		]
		rate 0:0:1 on-time [
			unless rea/pause [
				advance 0x1
				rea/elapsed: rea/elapsed + modulo now' - rea/t0 24:0:0
				face/rate: rea/interval * 0:0:1
			]
		]

	return middle
	h4 "Score: 00000" center
		react [face/data: reduce/into ["Score:" rea/score] clear []]

	text (sz/alpha * 12x3) font-size 11
		react [face/data: reduce/into [
			"Time:" round rea/elapsed "^/Difficulty:" round 10% * -1 * log-2 rea/interval
		] clear []]

	at 0x0 canvas: base (sz/full) glass
		on-created [restart]
		react [face/rate: all [not rea/pause 30]] on-time [clean]

	at 0x0 base (sz/block * 4) glass react [face/draw: redraw-next rea/next-pc]
	
	at (sz/full - sz/band / 2 * 0x1)
		base (sz/band) glass coffee bold font-size 30 "Taking a breath..."
		react [face/visible?: rea/pause]

	style line: base hidden glass (sz/line) extra 0
		on-create [append lines face]
		draw [
			pen off  fill-pen linear whit2 cyan2 0.3 white cyan2 0.7 whit2 0x0 (sz/edge * 0x1)
			box 0x0 (sz/line)
		]
	(repeat i sz/map/y [append [] reduce ['at i - 1 * sz/edge * 0x1 'line]])
] [text: "Retris"]

either error? e: try/all [do-events]
	[ view compose [area (form e)] ]
	[ quit ]