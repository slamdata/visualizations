/**
 * ...
 * @author Franco Ponticelli
 */

package rg.view.svg.chart;
import rg.data.VariableIndependent;
import rg.data.VariableDependent;
import rg.util.RGStrings;
import rg.view.svg.panel.Panel;
import rg.view.svg.panel.Layer;
import rg.data.DataPoint;
import rg.data.Stats;
import rg.view.svg.widget.GridAnchor;
import rg.view.svg.widget.Label;
import thx.culture.FormatNumber;
import thx.js.Selection;
import thx.js.Dom;
import rg.view.svg.util.RGColors;
import thx.color.Hsl;
import thx.color.NamedColors;
import thx.math.scale.Linear;
import thx.svg.Diagonal;
import rg.view.svg.widget.Balloon;
import thx.svg.Symbol;
import rg.util.DataPoints;
using Arrays;

class FunnelChart extends Chart
{
//	public var click : DataPoint -> Stats -> Void;
	public var padding : Float;
	public var flatness : Float;
	public var displayGradient : Bool;
	public var gradientLightness : Float;
	public var arrowSize : Float;
	public var labelArrow : DataPoint -> Stats<Dynamic> -> String;

	var variableIndependent : VariableIndependent<Dynamic>;
	var variableDependent : VariableDependent<Dynamic>;
	var defs : Selection;
	var dps : Array<DataPoint>;
	
	public function new(panel : Panel) 
	{
		super(panel);
		padding = 2.5;
		flatness = 1.0;
		arrowSize = 30;
		gradientLightness = 1;
		displayGradient = true;
		
		labelArrow = defaultLabelArrow;
		labelDataPoint = defaultLabelDataPoint;
		labelDataPointOver = defaultLabelDataPointOver;
	}
	
	public function defaultLabelArrow(dp : DataPoint, stats : Stats<Dynamic>)
	{
		var value = Reflect.field(dp, variableDependent.type) / stats.max;
		return FormatNumber.percent(100 * value, 0);
	}
	
	public function defaultLabelDataPoint(dp : DataPoint, stats : Stats<Dynamic>)
	{
		return RGStrings.humanize(DataPoints.value(dp, variableIndependent.type)).split(" ").join("\n");
	}
	
	public function defaultLabelDataPointOver(dp : DataPoint, stats : Stats<Dynamic>)
	{
		return Ints.format(Reflect.field(dp, variableDependent.type));
	}

	public function setVariables(variableIndependents : Array<VariableIndependent<Dynamic>>, variableDependents : Array<VariableDependent<Dynamic>>)
	{
		variableIndependent = variableIndependents[0];
		variableDependent = variableDependents[0];
	}
	
	public function data(dps : Array<DataPoint>)
	{
		this.dps = dps;
		redraw();
	}
	
	override function resize() 
	{
		super.resize();
		redraw();
	}
	
	function dpvalue(dp : DataPoint) return DataPoints.value(dp, variableDependent.type)
	
	var stats : Stats<Dynamic>;
	var topheight : Float;
	var h : Float;
	function scale(value : Dynamic)
	{
		return variableDependent.axis.scale(0, variableDependent.max, value);
	}

	function next(i : Int) return dpvalue(dps[(i + 1) < dps.length ? i + 1 : i])
	
	function redraw()
	{

		if (null == dps || 0 == dps.length)
			return;

		// cleanup
		g.selectAll("g").remove();
		g.selectAll("radialGradient").remove();
		
		// prepare
		stats = variableDependent.stats;
		var max = scale(stats.max),
			wscale = function(v) {
				return scale(v) / max * (width-2) / 2;
			},
			fx1 = function(v) return (width / 2 - wscale(v)),
			fx2 = function(v) return width - fx1(v),
			diagonal1 = new Diagonal()
				.sourcef(function(o, i) return [ fx1(dpvalue(o)), 0.0 ] )
				.targetf(function(o, i) return [ fx1(next(i)), h ] ),
			diagonal2 = new Diagonal()
				.sourcef(function(o, i) return [ fx2(next(i)), h ] )
				.targetf(function(o, i) return [ fx2(dpvalue(o)), 0.0 ] ),
			conj = function(v : Float, r : Bool, dir : Int) 
			{
				var x2 = r ? fx1(v) - fx2(v) : fx2(v) - fx1(v),
					a = 5,
					d = r ? (dir == 0 ? 1 : 0) : dir
				;
				return " a " + a + " " + flatness + " 0 0 " + d + " " + x2 + " 0";
			},
			conj1 = function(d, ?i)
			{
				return conj(dpvalue(d), true, 0);
			},
			conj2 = function(d, ?i)
			{
				return conj(next(i), false, 0);
			},
			conjr = function(d, ?i)
			{
				var v = dpvalue(d);
				return " M " + fx1(v) + " 0 " +conj(v, false, 0) + conj(v, true, 1);
			}
		;
		
		var top = g.append("svg:g");
		var path = top
			.append("svg:path")
			.attr("class").string("funnel-inside fill-0")
			.attr("d").string(conjr(dps[0]))
		;
		if (null != click)
			top.onNode("click", function(_, _) click(dps[0], stats));
		if(displayGradient)
			internalGradient(path);
		top.onNode("mouseover", function(_, _) mouseOver(dps[0], 0, stats));
		topheight = Math.ceil(untyped path.node().getBBox().height / 2) + 1;
		
		// calculate bottom
		var index = dps.length - 1,
			bottom = g
				.append("svg:path")
				.attr("class").string("funnel-inside fill-" + index)
				.attr("d").string(conjr(dps[index])),
			bottomheight : Float = Math.ceil(untyped bottom.node().getBBox().height / 2) + 1;
		bottom.remove();
		
		// calculate h
		h = ((height - topheight - bottomheight) - (dps.length - 1) * padding) / dps.length;

		top.attr("transform").string("translate(0," + topheight + ")");

		var section = g.selectAll("g.section").data(dps);
		var enter = section.enter()
			.append("svg:g")
			.attr("class").string("section")
			.attr("transform").stringf(function(d, i) return "translate(0," 
			+ (topheight + i * (padding + h))
			+ ")")
		;
		if (null != click)
			enter.on("click", function(d, _) click(d, stats));
		enter.on("mouseover", function(d, i) mouseOver(d, i, stats));
		var funnel = enter
			.append("svg:path")
			.attr("class").stringf(function(d, i) return "funnel-outside fill-" + i)
			.attr("d").stringf(function(d, i) {
				var t = diagonal2.diagonal(d, i).split('C');
				t.shift();
				var d2 = 'C' + t.join('C');
				return diagonal1.diagonal(d, i) + conj2(d, i) + d2 + conj1(d, i);
			});
		if(displayGradient)
			enter.eachNode(externalGradient);
		
		var ga = g.selectAll("g.arrow")
			.data(dps)
			.enter()
			.append("svg:g")
			.attr("class").string("arrow")
			.attr("transform").stringf(function(d, i) {
				return "translate(" + (width / 2) + "," + (topheight + h * i + arrowSize / 2) + ")";
			});
		
		ga.each(function(d, i) {
			if (null == labelArrow)
				return;
			var text = labelArrow(d, stats);
			if (null == text)
				return;
			var node = Selection.current;
			
			node
				.append("svg:path")
				.attr("transform").string("scale(1.1,0.85)translate(1,1)")
				.attr("class").string("shadow")
				.style("fill").string("#000")
				.attr("opacity").float(.25)
				.attr("d").string(Symbol.arrowDownWide(arrowSize*arrowSize))
			;
				
			node
				.append("svg:path")
				.attr("transform").string("scale(1.1,0.8)")
				.attr("d").string(Symbol.arrowDownWide(arrowSize*arrowSize))
			;
			
			var label = new Label(node, true, true, true);
			label.anchor = GridAnchor.Bottom;
			label.text = text;
		});
		
		ga.each(function(d, i) {
			if (null == labelDataPoint)
				return;
			var text = labelDataPoint(d, stats);
			if (null == text)
				return;
			var balloon = new Balloon(g);
			balloon.boundingBox = cast {
				x : width / 2 + arrowSize / 3 * 2,
				y : 0,
				width : width,
				height : height
			};
			balloon.preferredSide = 3;
			
			balloon.text = text.split("\n");
			balloon.moveTo(width / 2, topheight + h * .6 + (h + padding) * i, false);
		});
	}
	
	function mouseOver(dp : DataPoint, i : Int, stats : Stats<Dynamic>)
	{
		if (null == labelDataPointOver)
			return;
		var text = labelDataPointOver(dp, stats);
		if (null == text)
			tooltip.hide()
		else
		{
			tooltip.show();
			tooltip.text = text.split("\n");
			moveTooltip(width / 2, topheight + h * .6 + (h + padding) * i, true);
		}
	}
	
	override public function init()
	{
		super.init();
		if (null != tooltip)
		{
			tooltip.preferredSide = 1;
		}
		defs = g.classed().add("funnel-chart")
			.append("svg:defs");
	}

	function internalGradient(d : Selection)
	{
		var color = RGColors.parse(d.style("fill").get(), "#cccccc"),
			stops = defs
			.append("svg:radialGradient")
			.attr("id").string("rg_funnel_int_gradient_0")
			.attr("cx").string("50%")
			.attr("fx").string("75%")
			.attr("cy").string("20%")
			.attr("r").string(Math.round(75) + "%")
		;
		stops.append("svg:stop")
			.attr("offset").string("0%")
			.attr("stop-color").string(Hsl.darker(Hsl.toHsl(color), 1.25 * gradientLightness).toRgbString())
		;

		stops.append("svg:stop")
			.attr("offset").string("100%")
			.attr("stop-color").string(Hsl.darker(Hsl.toHsl(color), 0.4 * gradientLightness).toRgbString())
		;
			
		d.attr("style").string("fill:url(#rg_funnel_int_gradient_0)");
	}

	function externalGradient(n, i : Int)
	{
		var g = Dom.selectNode(n),
			d = g.select("path"),
			color = Hsl.toHsl(RGColors.parse(d.style("fill").get(), "#cccccc")),
			vn = next(i),
			vc = dpvalue(dps[i]),
			ratio = Math.round(vn / vc * 100) / 100,
			id = "rg_funnel_ext_gradient_" + color.toCss() + "-" + ratio;

		var stops = defs
			.append("svg:radialGradient")
			.attr("id").string(id)
			.attr("cx").string("50%")
			.attr("cy").string("0%")
			.attr("r").string("110%")
		;
		
		var top = color.toCss();
		
		stops.append("svg:stop")
			.attr("offset").string("10%")
			.attr("stop-color").string(top)
		;
		
		var middlecolor = Hsl.darker(color, 1 + Math.log(ratio) / (2.5 * gradientLightness)).toCss();

		stops.append("svg:stop")
			.attr("offset").string("50%")
			.attr("stop-color").string(middlecolor)
		;
		
		stops.append("svg:stop")
			.attr("offset").string("90%")
			.attr("stop-color").string(top)
		;
			
		d.attr("style").string("fill:url(#" + id + ")");
	}
}