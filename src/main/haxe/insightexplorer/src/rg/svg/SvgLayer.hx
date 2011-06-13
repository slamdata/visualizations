package rg.svg;

/**
 * ...
 * @author Franco Ponticelli
 */

import thx.js.Selection;

class SvgLayer
{
	var panel : SvgPanel;
	var svg : Selection;
	var width : Int;
	var height : Int;
	
	public var customClass(default, setCustomClass) : String;

	public function new(panel : SvgPanel)
	{
		this.panel = panel;
		var p : SvgPanelFriend = panel;
		p.addLayer(this);
		svg = cast panel.svg.append("svg:g");
		svg.attr("class").string("layer");
		panel.onResize.add(_resize);
		init();
		_resize();
	}
	
	function init() { }
	
	function _resize()
	{
		width = panel.frame.width;
		height = panel.frame.height;
		resize();
		redraw();
	}
	
	function resize() { }
	
	public function destroy()
	{
		var p : SvgPanelFriend = panel;
		p.removeLayer(this);
		svg.remove();
	}
	
	public function redraw()
	{
		
	}
	
	function setCustomClass(v : String)
	{
		if (null != customClass)
			svg.classed().remove(customClass);
		svg.classed().add(v);
		return this.customClass = v;
	}
}

typedef SvgPanelFriend = {
	private function addLayer(layer : SvgLayer) : Void;
	private function removeLayer(layer : SvgLayer) : Void;
}