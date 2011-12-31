/**
 * ...
 * @author Franco Ponticelli
 */

package rg.view.svg.widget;
import thx.js.Selection;
import rg.view.svg.widget.LabelOrientation;
import rg.view.svg.widget.GridAnchor;
using Arrays;

class Label
{
	public var text(default, setText) : String;
	public var orientation(default, setOrientation) : LabelOrientation;
	public var anchor(default, setAnchor) : GridAnchor;
	public var x(default, null) : Float;
	public var y(default, null) : Float;
	public var angle(default, null) : Float;
	public var dontFlip(default, null) : Bool;
	public var shadowOffsetX(default, null) : Float;
	public var shadowOffsetY(default, null) : Float;
	public var shadow(default, null) : Bool;
	public var outline(default, null) : Bool;

	var g : Selection;
	var gshadow : Selection;
	var gtext : Selection;
	var gshadowrot : Selection;
	var ttext : Selection;
	var toutline : Selection;
	var tshadow : Selection;
//	var b : Selection;

	public function new(container : Selection, dontflip = true, shadow : Bool, outline : Bool)
	{
		this.shadow = shadow;
		this.outline = outline;

		g = container.append("svg:g").attr("class").string("label");
		if (shadow)
		{
			gshadow = g.append("svg:g").attr("transform").string("translate(0,0)");
			gshadowrot = gshadow.append("svg:g");
			tshadow = gshadowrot.append("svg:text").attr("class").string("shadow" + (outline ? "" : " nooutline"));
		}

//		b = gtext.append("svg:rect").style("fill").string("none");
//		b.style("stroke").string("#333");

		gtext = g.append("svg:g");
		if(outline)
			toutline = gtext.append("svg:text").attr("class").string("outline" + (shadow ? "" : " noshadow"));
		var cls = ["text"].addIf(!outline, "nooutline").addIf(!shadow, "noshadow");
		ttext = gtext.append("svg:text").attr("class").string(cls.join(" "));

		this.dontFlip = dontflip;
		if (outline)
		{
			setShadowOffset(1, 1.25);
		} else {
			setShadowOffset(0.5, 0.5);
		}
		x = 0;
		y = 0;
		angle = 0;
		orientation = FixedAngle(0);
		anchor = Center;
	}

	public function addClass(name : String)
	{
		g.classed().add(name);
	}

	public function removeClass(name : String)
	{
		g.classed().remove(name);
	}

	public function getSize() : { width : Float, height : Float }
	{
		try {
			return untyped g.node().getBBox();
		} catch (e : Dynamic) {
			return { width : 0.0, height : 0.0 };
		}
	}

	public function place(x : Float, y : Float, angle : Float)
	{
		this.x = x;
		this.y = y;
		this.angle = angle % 360;
		if (this.angle < 0)
			this.angle += 360;
		g.attr("transform").string("translate(" + x + "," + y + ")");
		switch(orientation)
		{
			case FixedAngle(a):
				gtext.attr("transform").string("rotate(" + a + ")");
			case Aligned:
				if (dontFlip && this.angle > 90 && this.angle < 270)
					angle += 180;
				gtext.attr("transform").string("rotate(" + angle + ")");
			case Orthogonal:
				if (dontFlip && this.angle > 180)
					angle -= 180;
				gtext.attr("transform").string("rotate(" + (-90 + angle) + ")");
		}
		if (shadow)
			gshadowrot.attr("transform").string(gtext.attr("transform").get());
		reanchor();
	}

	function setShadowOffset(x : Float, y : Float)
	{
		shadowOffsetX = x;
		shadowOffsetY = y;
		if (shadow)
			gshadow.attr("transform").string("translate("+shadowOffsetX+","+shadowOffsetY+")");
	}

	function setText(v : String)
	{
		this.text = v;
		if (outline)
			toutline.text().string(v);
		ttext.text().string(v);
		if (shadow)
			tshadow.text().string(v);
		reanchor();
		return v;
	}

	function setOrientation(v : LabelOrientation)
	{
		this.orientation = v;
		place(x, y, angle);
		return v;
	}

	function setAnchor(v : GridAnchor)
	{
		this.anchor = v;
		reanchor();
		return v;
	}

	function getBB() : { width : Float, height : Float }
	{
		var n = ttext.node(),
			h = ttext.style("font-size").getFloat();
		if (null == h || 0 >= h)
		{
			try {
				h = untyped n.getExtentOfChar("A").height;
			} catch(e : Dynamic)
			{
				h = thx.js.Dom.selectNode(n).style("height").getFloat();
			}
		}
		var w;
		try {
			w = untyped n.getComputedTextLength();
		} catch(e : Dynamic)
		{
			w = thx.js.Dom.selectNode(n).style("width").getFloat();
		}
		return {
			width : w,
			height : h
		}
	}

	function reanchor()
	{
		if (null == anchor)
			return;
		var bb = getBB(),
			x : Float, y : Float;
//		b.attr("width").float(bb.width).attr("height").float(bb.height);
		var a = anchor;
		if (dontFlip)
		{
			switch(orientation)
			{
				case Aligned:
					if (angle > 90 && angle < 270)
					{
						a = switch(a)
						{
							case TopLeft:  BottomRight;
							case Top: Bottom;
							case TopRight: BottomLeft;
							case Left: Right;
							case Center: Center;
							case Right: Left;
							case BottomLeft: TopRight;
							case Bottom: Top;
							case BottomRight: TopLeft;
						}
					}
				case Orthogonal:
					if (angle > 180)
					{
						a = switch(a)
						{
							case TopLeft:  BottomRight;
							case Top: Bottom;
							case TopRight: BottomLeft;
							case Left: Right;
							case Center: Center;
							case Right: Left;
							case BottomLeft: TopRight;
							case Bottom: Top;
							case BottomRight: TopLeft;
						}
					}
				default:
					// do nothing
			}
		}

		switch(a)
		{
			case TopLeft:
				x = 0;
				y = bb.height;
			case Top:
				x = -bb.width / 2;
				y = bb.height;
			case TopRight:
				x = -bb.width;
				y = bb.height;
			case Left:
				x = 0;
				y = bb.height / 2;
			case Center:
				x = -bb.width / 2;
				y = bb.height / 2;
			case Right:
				x = -bb.width;
				y = bb.height / 2;
			case BottomLeft:
				x = 0;
				y = 0;
			case Bottom:
				x = -bb.width / 2;
				y = 0;
			case BottomRight:
				x = -bb.width;
				y = 0;
		}
		if (outline)
			toutline.attr("x").float(x+0.5).attr("y").float(y-1.5);
		ttext.attr("x").float(x + 0.5).attr("y").float(y - 1.5);
		if (shadow)
			tshadow.attr("x").float(x+0.5).attr("y").float(y-1.5);
//		b.attr("x").float(x).attr("y").float(y-bb.height);
	}

	public function destroy()
	{
		g.remove();
	}
}