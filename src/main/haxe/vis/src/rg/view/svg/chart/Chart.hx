/**
 * ...
 * @author Franco Ponticelli
 */

package rg.view.svg.chart;
import rg.view.svg.panel.Panel;
import rg.view.svg.panel.Layer;
import rg.data.DataPoint;
import rg.data.Stats;
import rg.view.svg.widget.Baloon;
import thx.math.Equations;
import rg.view.svg.panel.Panels;

class Chart extends Layer
{
	public var animated : Bool;
	public var animationDuration : Int;
	public var animationEase : Float -> Float;
	public var click : DataPoint -> Stats -> Void;
	public var labelDataPoint : DataPoint -> Stats -> String;
	public var labelDataPointOver : DataPoint -> Stats -> String;
	
	var panelx : Float;
	var panely : Float;
	var tooltip : Baloon;

	public function new(panel : Panel) 
	{
		super(panel);
		animated = true;
		animationDuration = 1500;
		animationEase = Equations.linear;
	}
	
	override function resize()
	{
		var coords = Panels.boundingBox(panel);
		panelx = coords.x;
		panely = coords.y;
	}
	
	public function init()
	{
		if (null != labelDataPointOver)
		{
			tooltip = new Baloon(g);
		}
		resize();
	}
	
	function moveTooltip(x : Float, y : Float, ?animated : Bool)
	{
		tooltip.moveTo(panelx + x, panely + y, animated);
	}
}