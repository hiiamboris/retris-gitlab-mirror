Red [
    title: "Tetris Redborn!"
    description: "Red Tetris Game YAY!"
    file: %retris.red
    author: @hiiamboris
    needs: 'view
]

; TODO: score board?, resize?, autosnapshots?, comments!

now': does [now/time/precise]
random/seed now'

sz: context [
	block: 16x16  map: 16x32
	full: map * block
	band: 1x5 * line: as-pair full/x block/y
	edge: block/x
]
half-life: 60
if error? bgimg: try/all [
	load rejoin [https://picsum.photos/ sz/full/x '/ sz/full/y '?random]
] [bgimg: make image! sz/full]

xyloop: func ['p s c /local i] [
	any [pair? s  s: s/size]
	i: 0	loop s/x * s/y [
		set p 1x1 + as-pair i % s/x i / s/x
		do c
	i: i + 1	]
]

pieces: collect [
	foreach spec [
		[cyan "" "" "++++" "" ""]
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
	if white <> p: map'/:o [
		o1: (o2: sz/block * o) - sz/block
		box: reduce/into ['box o1 o2 sz/edge / 5] clear []
		fp: 'fill-pen
		append cmds compose/into [
			pen off  (fp) off (fp) (p)
			(box)
 			pen coal  (fp) radial (grad) (o2) (sz/edge * 1.5)
			(box)
		] clear []
	]]
	canvas/draw: last reverse stor
]

draw-pc: has [o] [
	pc: random/only pieces
	o: -3
	until [
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

game-over: does [
	rea/pause: yes
	view [
		text center wrap 160x100 font-size 30 "GAME OVER"
		return
		button 70x30 focus "Restart" [restart unview]
		button 70x30 "Quit" [quit]
	]
]

restart: does [start  draw-pc]
start: does [set rea rea'  map': copy map: make image! sz/map]

lines: []
whit2: to-tuple #{FFFFFFFF}
cyan2: to-tuple #{00FFFF80}
rea': copy rea: make reactor! [
	elapsed: 0:0:0  score: 0  pause: no  t0: is [elapsed pause now']
	interval: is [(atan (to-float elapsed) / half-life) / (pi / -2) + 1.0]
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

	return
	text (sz/line * 1x4 * 0.6) center font-size 20
		react [face/data: reduce/into ["Score:" rea/score] clear []]
	
	text (sz/line * 1x6 * 0.4) font-size 11
		react [face/data: reduce/into ["Time:" round rea/elapsed "^/Difficulty:" round 10% * -1 * log-2 rea/interval] clear []]

	at 0x0 canvas: base (sz/full) glass
		on-created [restart]
		react [face/rate: all [not rea/pause 30]] on-time [clean]
	
	at (sz/full - sz/band / 2 * 0x1) base (sz/band) glass coffee bold font-size 30 "Taking a breath..."
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