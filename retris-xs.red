Red [title: "Tetris Redborn XS!" description: "Minimal version of Retris" file: %retris-xs.red author: @hiiamboris needs: 'view]

random/seed now/precise/time

sz: context [
	block: 16x16  map: 20x40
	full: map * block
	line: as-pair full/x block/y
]

if error? bgimg: try/all [
	load rejoin [https://picsum.photos/ sz/full/x '/ sz/full/y '?random]
] [bgimg: make image! sz/full]

;save/as %bgimg bgimg 'png
;bgimg: load/as %bgimg 'png

xyloop: func ['p s c /local i] [
	any [pair? s  s: s/size]
	i: 0	loop s/x * s/y [
		set p 1x1 + as-pair i % s/x i / s/x
		do c
	i: i + 1	]
]

pieces: collect [
	foreach spec [
		[cyan "" "++++" "" ""]
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

redraw: function [] [
	canvas/draw: collect [ xyloop o map' [
		if white <> p: map'/:o [
			o1: (o2: sz/block * o) - sz/block
			keep reduce ['pen 'coal 'fill-pen p 'box o1 o2 sz/block/x / 5]
		]]]
]

draw-pc: does [
	pc: random/only pieces
	pc-pos: sz/map - pc/size / 2 + 1x0 * 1x0
	if 'bad = imprint [view [button "GAME OVER" [quit]]]
]

imprint: has [o p r] [
	map': copy map
	also r: xyloop o pc [
		if white <> pc/:o [
			p: o + pc-pos
			unless all [ within? p 1x1 sz/map  white = map'/:p ] 
				[return 'bad]
			map'/:p: pc/:o
		]
	]
	if 'bad <> r [redraw]
]

rotate: has [p] [
	p: copy pc
	draw pc compose/deep [matrix [0 1 -1 0 (p/size/x) 0] image p]
	if 'bad = imprint [pc: p  imprint]
]

advance: func [by /force /local bk] [
	until [
		pc-pos: by + bk: pc-pos
		any [	all ['bad = imprint (also  pc-pos: bk  if 0 <> by/y [imprint  map: map'  draw-pc])]
				not force ]
	]
	imprint
]

clean: has [x y h] [
	repeat y h: sz/map/y [
		if repeat x sz/map/x [
			if white = map/(as-pair x y) [break/return no]
			yes
		] [ draw map compose [image map crop 0x-1 (as-pair h y)] ]
	]
]

restart: does [start  draw-pc]
start: does [map': map: make image! sz/map]

start

view/tight/options compose/deep [
	base (sz/full)
		draw [image (bgimg)]
		rate 1 on-time [advance 0x1]
		focus on-key [ switch event/key [
			down [advance 0x1]
			left [advance -1x0]
			right [advance 1x0]
			#" " [advance/force 0x1]
			up [rotate]
		] ]
	return at 0x0 canvas: base (sz/full) glass  on-created [restart]  rate 10 on-time [clean]
] [text: "Retris Mini"]

quit