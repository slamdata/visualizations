/**
 * ...
 * @author Franco Ponticelli
 */

package rg.info;
import rg.svg.chart.StreamEffect;
import rg.svg.chart.StreamEffects;
import thx.svg.LineInterpolator;
import thx.svg.LineInterpolators;
import rg.data.DataPoint;
import rg.axis.Stats;
using rg.info.Info;

class InfoStreamGraph extends InfoCartesianChart
{
	public var interpolation : LineInterpolator;
	public var effect : StreamEffect;
	public var segment : InfoSegment;

	public function new()
	{
		super();
		segment = new InfoSegment();
		interpolation = LineInterpolator.Cardinal();
		effect = GradientVertical(1.25);
	}

	public static function filters()
	{
		return [{
			field : "interpolation",
			validator : function(v : Dynamic) return Std.is(v, String),
			filter : function(v : Dynamic) return [{
				field : "interpolation",
				value : LineInterpolators.parse(v)
			}]
		}, {
			field : "effect",
			validator : function(v : Dynamic) return Std.is(v, String),
			filter : function(v : Dynamic) return [ {
				field : "effect",
				value : StreamEffects.parse(v)
			}]
		}, {
			field : "segmenton",
			validator : function(v) return Std.is(v, String),
			filter : function(v) return [{
				field : "segment",
				value : new InfoSegment().feed( { on : v } )
			}]
		}, {
			field : "segment",
			validator : function(v) return Types.isAnonymous(v),
			filter : function(v) return [{
				field : "segment",
				value : new InfoSegment().feed(v)
			}]
		}].concat(cast InfoCartesianChart.filters());
	}
}