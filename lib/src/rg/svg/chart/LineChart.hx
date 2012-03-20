/**
 * ...
 * @author Franco Ponticelli
 */

package rg.svg.chart;
import dhx.Dom;
import rg.data.VariableDependent;
import rg.data.VariableIndependent;
import rg.data.Variable;
import rg.axis.IAxis;
import rg.svg.panel.Panel;
import rg.data.DataPoint;
import rg.util.RGColors;
import thx.color.Hsl;
import dhx.Selection;
import rg.util.DataPoints;
import thx.svg.Line;
import rg.axis.Stats;
import thx.svg.LineInterpolator;
import dhx.Access;
import thx.svg.Area;
import rg.svg.widget.Label;
import rg.svg.widget.Sensible;
using Arrays;

// TODO transition animation
// TODO expose options: label.orientation
// TODO expose options: label.place (distance, angle)
// TODO expose options: label.anchor

class LineChart extends CartesianChart<Array<Array<Array<DataPoint>>>>
{
	public var symbol : DataPoint -> Stats<Dynamic> -> String;
	public var symbolStyle : DataPoint -> Stats<Dynamic> -> String;
	public var lineInterpolator : LineInterpolator;
	public var lineEffect : LineEffect;
	public var y0property : String;

	var linePathShape : Array<Array<DataPoint> -> Int -> String>;
	var chart : Selection;
	var dps : Array<Array<Array<DataPoint>>>;
	var segment : Int;
	var stats : Array<Stats<Dynamic>>;


	public function new(panel : Panel)
	{
		super(panel);

		addClass("line-chart");
		chart = g.append("svg:g");
	}

	override function setVariables(variables : Array<Variable<Dynamic, IAxis<Dynamic>>>, variableIndependents : Array<VariableIndependent<Dynamic>>, variableDependents : Array<VariableDependent<Dynamic>>, data : Array<Array<Array<DataPoint>>>)
	{
		super.setVariables(variables, variableIndependents, variableDependents, data);
		if (y0property != null && y0property != "")
		{
			var t, dp;
			for (v in variableDependents)
				v.meta.max = Math.NEGATIVE_INFINITY;
			// y axis
			for (i in 0...data.length)
			{
				var v = variableDependents[i];
				// segment
				for (j in 0...data[i].length)
				{
					// datapoints
					for (k in 0...data[i][j].length)
					{
						dp = data[i][j][k];
						t = DataPoints.valueAlt(dp, v.type, 0.0) + DataPoints.valueAlt(dp, y0property, 0.0);
						if (v.meta.max < t)
							v.meta.max = t;
					}
				}
			}
		}
	}

	function x(d : DataPoint, ?i)
	{
		var value   = DataPoints.value(d, xVariable.type),
			scaled  = xVariable.axis.scale(xVariable.min(), xVariable.max(), value),
			scaledw = scaled * width;
		return scaledw;
	}

	function getY1(pos : Int)
	{
		var v = yVariables[pos],
			scale = callback(v.axis.scale, v.min(), v.max());
		if (null != y0property)
		{
			var min = scale(v.min()) * height;
			return function(d : DataPoint, i : Int)
			{
				return getY0(pos)(d, i) - (scale(DataPoints.value(d, v.type)) * height) + min;
			}
		} else {
			return function(d : DataPoint, i : Int)
			{
				var value   = DataPoints.value(d, v.type),
					scaled  = scale(value),
					scaledh = scaled * height;
				return height - scaledh;
			}
		}
	}

	function getY0(pos : Int)
	{
		var v = yVariables[pos],
			scale = callback(v.axis.scale, v.min(), v.max());
		return function(d : DataPoint, i : Int)
		{
			return height - (scale(DataPoints.valueAlt(d, y0property, v.min())) * height);
		}
	}

	var segments : Array<Array<DataPoint>>;

	public function classsf(pos : Int, cls : String)
	{
		return function(_, i : Int)
		{
			return cls + " stroke-" + (pos + i);
		}
	}

	public function classff(pos : Int, cls : String)
	{
		return function(_, i : Int)
		{
			return cls + " fill-" + (pos + i);
		}
	}

	override function data(dps : Array<Array<Array<DataPoint>>>)
	{
		linePathShape = [];
		for (i in 0...yVariables.length)
		{
			var line = new Line(x, getY1(i));
			if (null != lineInterpolator)
				line.interpolator(lineInterpolator);
			linePathShape[i] = function(dp, i)
			{
				segment = i;
				return line.shape(dp, i);
			};
		}

		var axisgroup = chart.selectAll("g.group").data(dps);
		// axis enter
		var axisenter = axisgroup.enter()
			.append("svg:g")
			.attr("class").stringf(function(_, i) return "group group-" + i);

		// axis exit
		axisgroup.exit().remove();
		stats = [];
		for (i in 0...dps.length)
		{
			segments = dps[i];

			var gi = chart.select("g.group-" + i)//,
			;
			stats[i] = new Stats(yVariables[i].type);
			stats[i].addMany(DataPoints.values(segments.flatten(), yVariables[i].type));


			if (null != y0property)
			{
				var area = new Area(x, getY0(i), getY1(i));
				if (null != lineInterpolator)
					area.interpolator(lineInterpolator);
				gi.selectAll("path.area")
					.data(segments)
					.enter()
						.append("svg:path")
						.attr("class").stringf(classff(i, "area area-"+i))
						.attr("d").stringf(area.shape);
			}

			// TODO add id function
			var segmentgroup = gi.selectAll("path.main").data(segments);
			switch(lineEffect)
			{
				case LineEffect.Gradient(lightness, levels):
					var fs = [];
					segmentgroup.enter()
						.append("svg:path")
						.attr("class").stringf(classsf(i, "line"))
						.eachNode(function(n, i) {
							var start = Hsl.toHsl(RGColors.parse(Dom.selectNode(n).style("stroke").get(), "#000000")),
								end = RGColors.applyLightness(start, lightness);
							fs[i] = Hsl.interpolatef(end, start);
						}).remove();

					for (j in 0...levels)
					{
						segmentgroup.enter()
							.append("svg:path")
							.attr("class").string("line grad-" + (levels-j-1))
							.style("stroke").stringf(function(_,i) {
								return fs[i](j/levels).toCss();
							})
							.attr("d").stringf(linePathShape[i]);
					}
				case LineEffect.DropShadow(ox, oy, levels):
					for (j in 0...levels)
					{
						segmentgroup.enter()
							.append("svg:path")
							.attr("transform").string("translate("+((1+j)*ox)+","+((1+j)*oy)+")")
							.attr("class").stringf(classsf(i, "line shadow shadow-" + (j)))
							.attr("d").stringf(linePathShape[i]);
					}
				default: // do nothing
			}

			var path = segmentgroup.enter()
				.append("svg:path")
				.attr("class").stringf(classsf(i, "line"))
				.attr("d").stringf(linePathShape[i]);

			switch(lineEffect)
			{
				case LineEffect.Gradient(_, _):
					path.classed().add("gradient");
				case LineEffect.DropShadow(_, _, _):
					path.classed().add("dropshadow");
				case LineEffect.NoEffect:
					path.classed().add("noeffect");
			}

			segmentgroup.update()
				.attr("d").stringf(linePathShape[i]);

			segmentgroup.exit().remove();

			var gsymbols = gi.selectAll("g.symbols").data(segments),
				vars = this.yVariables;
			var enter = gsymbols.enter()
				.append("svg:g")
				.attr("class").stringf(classsf(i, "symbols"));

			// TODO add id function
			var gsymbol = enter.selectAll("g.symbol").dataf(function(d,i) return d).enter()
				.append("svg:g")
				.attr("transform").stringf(getTranslatePointf(i));

			var circle = gsymbol.append("svg:circle")
				.attr("r").float(6)
				.attr("opacity").float(0.0)
				.style("fill").string("#000000")
			;
			if (null != labelDataPointOver)
				circle
					.classed().add("rgdata");
			RGColors.storeColorForSelection(cast circle, "stroke");

			if (null != symbol)
			{
				var sp = this.symbol;
				var spath = gsymbol.append("svg:path")
					.attr("d").stringf(function(dp, _) return sp(dp, stats[i]));
				RGColors.storeColorForSelection(cast spath, "stroke");
				if (null != symbolStyle)
				{
					var ss = this.symbolStyle;
					spath.attr("style").stringf(function(dp, _) return ss(dp, stats[i]));
				}
			}

			if (null != labelDataPoint)
			{
				var f = this.labelDataPoint;
				gsymbol.eachNode(function(n, _) {
					var dp = Access.getData(n),
						label = new Label(dhx.Dom.selectNode(n), true, false, false);
					label.text = f(dp, stats[i]);
				});
			}

			gsymbols.update()
				.selectAll("g.symbol")
				.dataf(function(d, i) return d)
				.update()
				.attr("transform").stringf(getTranslatePointf(i))
			;

			gsymbols.exit().remove();
		}
		Sensible.sensibleZone(g, panel, null == click ? null : onclick, null == labelDataPointOver ? null : onmouseover, null, 100); // TODO ADD STATS
		ready.dispatch();
	}

	function getTranslatePointf(pos : Int)
	{
		var x = this.x,
			y = getY1(pos);
		return function(dp, i)
		{
			return "translate("+x(dp)+","+y(dp,i)+")";
		};
	}

	function getStats(dp : Dynamic)
	{
		for(s in stats)
			if(Reflect.field(dp, s.type) != null)
				return s;
		return null;
	}

	function onmouseover(n : js.Dom.HtmlDom)
	{
		var dp = Access.getData(n),
			stats = getStats(dp),
			text = labelDataPointOver(dp, stats);
		if (null == text)
			tooltip.hide();
		else
		{
			var sel = dhx.Dom.selectNode(n.parentNode),
				coords = Coords.fromTransform(sel.attr("transform").get());
			tooltip.html(text.split("\n").join("<br>"));
			moveTooltip(coords[0], coords[1], RGColors.extractColor(n));
		}
	}

	function onclick(n : js.Dom.HtmlDom)
	{
		var dp = Access.getData(n),
			stats = getStats(dp);
		click(dp, stats);
	}
}