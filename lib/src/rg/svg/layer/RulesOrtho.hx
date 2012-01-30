/**
 * ...
 * @author Franco Ponticelli
 */

package rg.svg.layer;
import rg.axis.IAxis;
import rg.layout.Anchor;
import rg.svg.panel.Layer;
import rg.svg.panel.Panel;
import rg.axis.ITickmark;
import thx.js.Dom;
import rg.svg.widget.Label;
import rg.svg.widget.LabelOrientation;
import rg.svg.widget.GridAnchor;
import rg.frame.Orientation;
using Arrays;

class RulesOrtho extends Layer
{
	public var orientation(default, null) : Orientation;

	public var displayMinor : Bool;
	public var displayMajor : Bool;
	public var displayAnchorLine : Bool;

	var translate : ITickmark<Dynamic> -> Int -> String;
	var x1 : ITickmark<Dynamic> -> Int -> Float;
	var y1 : ITickmark<Dynamic> -> Int -> Float;
	var x2 : ITickmark<Dynamic> -> Int -> Float;
	var y2 : ITickmark<Dynamic> -> Int -> Float;
	var x : ITickmark<Dynamic> -> Int -> Float;
	var y : ITickmark<Dynamic> -> Int -> Float;

	public function new(panel : Panel, orientation : Orientation)
	{
		super(panel);
		this.orientation = orientation;

		displayMinor = true;
		displayMajor = true;
		displayAnchorLine = true;

		g.classed().add("tickmarks");
	}

	var axis : IAxis<Dynamic>;
	var min : Dynamic;
	var max : Dynamic;

	override function resize()
	{
		if (null == axis)
			return;
		if (displayAnchorLine)
			updateAnchorLine();
		redraw();
	}

	public function update(axis : IAxis<Dynamic>, min : Dynamic, max : Dynamic)
	{
		this.axis = axis;
		this.min = min;
		this.max = max;
		redraw();
	}

	function updateAnchorLine()
	{
		var line = g.select("line.anchor-line");
		switch(orientation)
		{
			case Horizontal:
				line.attr("x1").float(0)
					.attr("y1").float(0)
					.attr("x2").float(0)
					.attr("y2").float(height);
			case Vertical:
				line.attr("x1").float(0)
					.attr("y1").float(height)
					.attr("x2").float(width)
					.attr("y2").float(height);
		}
	}

	function maxTicks()
	{
		var size = switch(orientation)
		{
			case Horizontal: width;
			case Vertical: height;
		}
		return Math.round(size / 2.5);
	}

	function id(d : ITickmark<Dynamic>, i) return "" + d.value

	function redraw()
	{
		var ticks = maxTicks(),
			data = axis.ticks(min, max, ticks);

		// ticks
		var rule = g.selectAll("g.rule").data(data, id);
		var enter = rule.enter()
			.append("svg:g").attr("class").string("rule")
			.attr("transform").stringf(translate);

		if (displayMinor)
		{
			enter.filter(function(d, i) return !d.major)
				.append("svg:line")
					.attr("x1").floatf(x1)
					.attr("y1").floatf(y1)
					.attr("x2").floatf(x2)
					.attr("y2").floatf(y2)
					.attr("class").stringf(tickClass);
		}

		if (displayMajor)
		{
			enter.filter(function(d, i) return d.major)
				.append("svg:line")
					.attr("x1").floatf(x1)
					.attr("y1").floatf(y1)
					.attr("x2").floatf(x2)
					.attr("y2").floatf(y2)
					.attr("class").stringf(tickClass);
		}

		rule.update()
			.attr("transform").stringf(translate);

		rule.exit()
			.remove();
	}

	function initf()
	{
		switch(orientation)
		{
			case Horizontal:
				translate = translateHorizontal;
				x1 = x1Horizontal;
				y1 = y1Horizontal;
				x2 = x2Horizontal;
				y2 = y2Horizontal;
			case Vertical:
				translate = translateVertical;
				x1 = x1Vertical;
				y1 = y1Vertical;
				x2 = x2Vertical;
				y2 = y2Vertical;
		}
	}

	public function init()
	{
		initf();
		if (displayAnchorLine)
		{
			g.append("svg:line").attr("class").string("anchor-line");
			updateAnchorLine();
		}
	}

	inline function t(x : Float, y : Float) return "translate(" + x + "," + y + ")"

	function translateHorizontal(d : ITickmark<Dynamic>, i : Int)	return t(0, height - d.delta * height)
	function translateVertical(d : ITickmark<Dynamic>, i : Int)		return t(d.delta * width, 0)

	function x1Horizontal(d : ITickmark<Dynamic>, i : Int)	return 0
	function x1Vertical(d : ITickmark<Dynamic>, i : Int)	return 0
	function y1Horizontal(d : ITickmark<Dynamic>, i : Int)	return 0
	function y1Vertical(d : ITickmark<Dynamic>, i : Int)	return 0
	function x2Horizontal(d : ITickmark<Dynamic>, i : Int)	return width
	function x2Vertical(d : ITickmark<Dynamic>, i : Int)	return 0
	function y2Horizontal(d : ITickmark<Dynamic>, i : Int)	return 0
	function y2Vertical(d : ITickmark<Dynamic>, i : Int)	return height

	function tickClass(d : ITickmark<Dynamic>, i : Int)	return d.major ? "major" : null
}