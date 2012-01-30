package rg.svg.chart;
import rg.svg.panel.Panel;
import rg.data.VariableDependent;
import rg.data.VariableIndependent;
import rg.data.DataPoint;
import thx.color.NamedColors;
import thx.js.Selection;
import rg.svg.widget.Label;
import rg.svg.widget.GridAnchor;
import rg.svg.widget.DiagonalArea;
import rg.svg.widget.ElbowArea;
import rg.svg.widget.HookConnectorArea;
import rg.graph.GraphLayout;
import rg.graph.GEdge;
import rg.graph.GNode;
import rg.axis.Stats;
using Arrays;

// TODO wire labels

class Sankey extends Chart
{
	public var layerWidth : Float;
	public var nodeSpacing : Float;
	public var dummySpacing : Float;
	public var extraWidth : Float;
	public var backEdgeSpacing : Float;
	public var extraHeight : Float;
	public var extraRadius : Float;
	public var imageWidth : Float;
	public var imageHeight : Float;
	public var imageSpacing : Float;
	public var labelNodeSpacing : Float;

	public var labelEdge : { head : DataPoint, tail : DataPoint, edgeweight : Float, nodeweight : Float } -> Stats<Dynamic> -> String;
	public var labelEdgeOver : { head : DataPoint, tail : DataPoint, edgeweight : Float, nodeweight : Float } -> Stats<Dynamic> -> String;
	public var labelNode : DataPoint -> Stats<Dynamic> -> String;

	public var imagePath : DataPoint -> String;
	public var clickEdge : { head : DataPoint, tail : DataPoint, edgeweight : Float, nodeweight : Float } -> Stats<Dynamic> -> Void;

	var layout : GraphLayout<NodeData, Dynamic>;
	var maxweight : Float;
	var availableheight : Float;
	var padBefore : Float;
	var padAfter : Float;
	var layerstarty : Array<Float>;

	var styleNode : String;
	var styleExtraIn : String;
	var styleExtraOut : String;
	var styleEdgeBackward : String;
	var styleEdgeForward : String;
	var dependentVariable : VariableDependent<Dynamic>;
	var mapelements : Hash<Selection>;
	var maphi : Hash<Selection>;

	public function new(panel : Panel)
	{
		super(panel);
		addClass("sankey");
		layerWidth = 61;
		nodeSpacing = 28;
		dummySpacing = 18;
		extraWidth = 28;
		backEdgeSpacing = 4.0;
		extraHeight = 5;
		extraRadius = 5;

		imageWidth = 60;
		imageHeight = 48;
		imageSpacing = 0;

		labelNodeSpacing = 4;

		styleNode = "0"; // 4
		styleExtraIn = "4";
		styleExtraOut = "6";
		styleEdgeBackward = "3";
		styleEdgeForward = "0";
	}

	public function setVariables(variableIndependents : Array<VariableIndependent<Dynamic>>, variableDependents : Array<VariableDependent<Dynamic>>, data : Array<DataPoint>)
	{
		dependentVariable = variableDependents[0];
	}

	public function data(graphlayout : GraphLayout<NodeData, Dynamic>)
	{
		layout = graphlayout.clone();
		// remove nodes between back edges
		// - must be dummy
		// - must be directed right to left
		var nodes = Iterables.filter(layout.graph.nodes, function(node) return isdummy(node)).filter(function(node) {
			var edge = node.positives().next(),
				cellhead = layout.cell(edge.head),
				celltail = layout.cell(edge.tail);
			return celltail.layer > cellhead.layer;
		});
		var layers = layout.layers();

		for(node in nodes)
		{
			var cell  = layout.cell(node),
				ehead = node.positives().next(),
				etail = node.negatives().next();
			// remove from layout
			layers[cell.layer].splice(cell.position, 1);
			// create new replacement edge
			layout.graph.edges.create(etail.tail, ehead.head, ehead.weight, ehead.data);
			// remove the node (and the edges)
			node.remove();
		}

//		this.layout = graphlayout;

		redraw();
	}

	function redraw()
	{
		mapelements = new Hash();
		maphi = new Hash();
		// space occupied by the node paddings
		maxweight = 0;
		layerstarty = [];
		for(i in 0...layout.length)
		{
			var v = layout.layer(i).reduce(function(cum, cur, _) return cum + cur.data.weight, 0);
			if(v > maxweight)
				maxweight = v;
		}

		var occupiedspace = 0.0;
		for(i in 0...layout.length)
		{
			var v = layout.layer(i).reduce(function(cum, cur, _){
				return cum + nodepadding(cur);
			}, 0.0);
			if(v > occupiedspace)
				occupiedspace = v;
		}
		availableheight = height - occupiedspace;

		// correct max available height and maxweight
		// remove space for back connections
		for(edge in layout.graph.edges)
		{
			if(layout.cell(edge.tail).layer < layout.cell(edge.head).layer)
				continue;
			availableheight -= backEdgeSpacing;
			maxweight += edge.weight;
		}
		availableheight -= extraRadius + extraHeight;


		var backedgesy  = 0.0;
		for(i in 0...layout.length)
		{
			var layer = layout.layer(i),
				t = 0.0;
			for(node in layer)
				t += nodepadding(node) + nheight(node.data.weight);
			layerstarty[i] = t;
			if(t > backedgesy)
				backedgesy = t;
		}

		for(i in 0...layerstarty.length)
		{
			layerstarty[i] = (backedgesy - layerstarty[i]) / 2; // STACK BOTTOM: backedgesy - layerstarty[i]
		}
		backedgesy += extraRadius + extraHeight;

		// nodeSpacing before
		padBefore = 0.0;
		for(node in layout.layer(0))
		{
			var extra = Math.min(nheight(node.data.extrain), extraWidth);
			for(edge in node.negatives())
			{
				var tail = edge.tail,
					parentweight = hafter(edge.id, node.negatives()) + nheight(edge.weight);
				if(parentweight > extra)
					extra = parentweight;
			}
			if(extra > padBefore)
				padBefore = extra;
		}
		padBefore += 2; // TODO border border width

		// nodeSpacing after
		padAfter = 0.0;
		for(node in layout.layer(layout.length-1))
		{
			var extra = Math.min(nheight(node.data.extraout), extraWidth);
			for(edge in node.positives())
			{
				var head = edge.head,
					childweight = hafter(edge.id, node.positives()) + nheight(edge.weight) + Math.min(nheight(node.data.extraout), extraWidth);
				if(childweight > extra)
					extra = childweight;
			}
			if(extra > padAfter)
				padAfter = extra;
		}
		padAfter += 2; // TODO better border width

		// DRAW
		var edgescontainer = g.select("g.edges");
		if(edgescontainer.empty())
			edgescontainer = g.append("svg:g").attr("class").string("edges");
		else
			edgescontainer.selectAll("*").remove();

		var edges = Iterables.array(layout.graph.edges).order(function(ea, eb) {
			var lena = layout.cell(ea.tail).layer - layout.cell(ea.head).layer,
				lenb = layout.cell(eb.tail).layer - layout.cell(eb.head).layer,
				comp = Ints.compare(lenb, lena);
			if(comp != 0)
				return comp;
			else
				return Floats.compare(eb.weight, ea.weight);
		});
		// back edges
		edges.each(function(edge, _) {
			if(edge.weight <= 0)
				return;
			var cellhead = layout.cell(edge.head),
				celltail = layout.cell(edge.tail);
			if(cellhead.layer > celltail.layer)
				return;
			var weight = nheight(edge.weight),
				hook   = new HookConnectorArea(edgescontainer, "fill fill-"+styleEdgeBackward, "stroke stroke-"+styleEdgeBackward),
				before = hafter(edge.id, edge.tail.positives()) + Math.min(extraWidth, nheight(edge.tail.data.extraout)),
				after  = hafter(edge.id, edge.head.negatives()),
				x1 = layerWidth / 2 + xlayer(celltail.layer),
				x2 = - layerWidth / 2 + xlayer(cellhead.layer),
				y1 = ynode(edge.tail) + ydiagonal(edge.id, edge.tail.positives()),
				y2 = nheight(edge.head.data.extrain) + ynode(edge.head) + ydiagonal(edge.id, edge.head.negatives());
			addToMap(edge.id, "edge", hook.g);
			hook.update(
				x1,
				y1,
				x2,
				y2,
				weight,
				backedgesy,
				before,
				after
			);
			hook.g.onNode("mouseover", callback(onmouseoveredge, (x1 + x2) / 2, backedgesy + weight / 2, edge));
			if(null != clickEdge)
			{
				hook.g.onNode("click", callback(edgeClickWithEdge, edge));
			}
			backedgesy += weight + backEdgeSpacing;
		});

// TODO edges must be ordered at the node level
		// forward edges
		edges.each(function(edge, _) {
			if(edge.weight <= 0)
				return;
			var head = edge.head,
				tail = edge.tail,
				cellhead = layout.cell(head),
				celltail = layout.cell(tail);
			if(cellhead.layer <= celltail.layer)
				return;
			var x1 = Math.round(layerWidth / 2 + xlayer(celltail.layer))-.5,
				x2 = Math.round(- layerWidth / 2 + xlayer(cellhead.layer))-.5,
				y1 = ynode(tail) + ydiagonal(edge.id, tail.positives()),
//				Iterators.array(tail.positives()).order(function(a, b){
//					return Floats.compare(b.weight, a.weight);
//				}).iterator()),
				y2 = ynode(head) + nheight(head.data.extrain) + ydiagonal(edge.id, head.negatives()),
				weight = nheight(edge.weight),
				diagonal = new DiagonalArea(edgescontainer, "fill fill-"+styleEdgeForward, "stroke stroke-"+styleEdgeForward);
			diagonal.update(
				x1,
				y1,
//				ynode(tail) + hnode(tail) / 2,
				x2,
				y2,
//				ynode(head) + hnode(head) / 2,
				weight,
				weight
			);
			addToMap(edge.id, "edge", diagonal.g);
			diagonal.g.onNode("mouseover", callback(onmouseoveredge, (x1 + x2) / 2, (y1 + y2 + weight) / 2, edge));
			if(null != clickEdge)
			{
				diagonal.g.onNode("click", callback(edgeClickWithEdge, edge));
			}
		});

		// fall-off
		function normMin(v : Float) return Math.max(0, Math.min(v - 3, extraRadius));
		layout.each(function(cell, node) {
			if(node.data.extraout <= 0 || extraWidth <= 0)
				return;
			var elbow = new ElbowArea(edgescontainer, "fill fill-"+styleExtraOut, "stroke stroke-"+styleExtraOut),
				extra = nheight(node.data.extraout),
				x = layerWidth / 2 + xlayer(cell.layer),
				y = ynode(node) + ydiagonal(null, node.positives()),
				minr = normMin(extra);
			elbow.update(
				RightBottom,
				extra,
				x,
				y + extra,
				minr,  // minr
				extraWidth, // maxweight
				0,  // before
				extraHeight  // after
			);

			if(null != labelEdge)
			{
				var label,
					text = labelEdge({ tail : node, head : null, nodeweight : node.data.weight, edgeweight : node.data.extraout }, dependentVariable.stats),
					nodeSpacing = 0;

				label = new Label(edgescontainer, true, true, false);
				label.addClass("edge");
				label.place(
					x,
					y + extra / 2,
					0);
				label.anchor = GridAnchor.Left;
				label.text = text;
				if(label.getSize().height > extra * .75)
				{
					label.destroy();
				}
			}
			elbow.g.onNode("mouseover", callback(onmouseoverextraout, x + minr + (-minr + Math.min(extraWidth, extra)) / 2, ynode(node) + hnode(node) + minr + extraHeight, node));
			if(null != clickEdge)
			{
				elbow.g.onNode("click", callback(edgeClickWithNode, node, true));
			}
			addToMap(node.id, "extraout", elbow.g);
		});

		// extra-in
		layout.each(function(cell, node) {
			if(node.data.extrain <= 0 || extraWidth <= 0)
				return;
			var elbow = new ElbowArea(edgescontainer, "fill fill-"+styleExtraIn, "stroke stroke-"+styleExtraIn),
				extra = nheight(node.data.extrain),
				minr = normMin(extra),
				x = - layerWidth / 2 + xlayer(cell.layer);
			elbow.update(
				LeftTop,
				extra,
				x,
				ynode(node), // + ydiagonal(null, node.positives()) + falloff
				minr,  // minr
				extraWidth, // maxweight
				0,  // before
				extraHeight  // after
			);

			if(null != labelEdge)
			{
				var label,
					text = labelEdge({ head : null, tail : node, nodeweight : node.data.weight, edgeweight : node.data.extrain }, dependentVariable.stats),
					nodeSpacing = 0;

				label = new Label(edgescontainer, true, true, false);
				label.addClass("edge");
				label.place(
					x,
					ynode(node) + extra / 2,
					0);
				label.anchor = GridAnchor.Right;
				label.text = text;
				if(label.getSize().height > extra * .75)
				{
					label.destroy();
				}
			}
			elbow.g.onNode("mouseover", callback(onmouseoverextrain,
				x  - minr + (minr - Math.min(extraWidth, extra)) / 2,
				ynode(node) - minr - extraHeight,
				node));
			if(null != clickEdge)
			{
				elbow.g.onNode("click", callback(edgeClickWithNode, node, false));
			}
			addToMap(node.id, "extrain", elbow.g);
		});

		// edge labels
		if(null != labelEdge)
		{
			edges.each(function(edge, _) {
				if(edge.weight <= 0)
					return;
				// label inside
				var tail = edge.tail;
				if(isdummy(tail))
					return;
				var celltail = layout.cell(tail),
					weight = nheight(edge.weight),
					label,
					text = labelEdge(edgeData(edge), dependentVariable.stats),
					nodeSpacing = 2;

				label = new Label(edgescontainer, true, true, false);
				label.addClass("edge");
				label.place(
					layerWidth / 2 + xlayer(celltail.layer) + nodeSpacing,
					ynode(tail) + ydiagonal(edge.id, tail.positives()) + weight / 2,
					0);
				label.anchor = GridAnchor.Left;
				label.text = text;
				if(label.getSize().height > weight * .75)
				{
					label.destroy();
				}
			});
		}

		var rules = g.selectAll("g.layer").data(layout.layers())
			.enter()
				.append("svg:g").attr("class").string("layer")
				.append("svg:line")
					.attr("class").stringf(function(_, i) return "rule rule-"+i)
					.attr("x1").float(0)
					.attr("x2").float(0)
					.attr("y1").float(0)
					.attr("y2").float(height)
			.update()
				.attr("transform").stringf(function(_, i) {
					return "translate("+xlayer(i)+",0)";
				})
			.exit()
				.remove();

		var choice = rules.update()
			.selectAll("g.node").dataf(function(d : Array<Int>, i) return layout.layer(i));

		var cont = choice
			.enter()
				.append("svg:g").attr("class").string("node");

		if(layerWidth > 0)
		{
			cont.append("svg:rect")
				.attr("class").stringf(function(n, _) return "fill fill-" + (isdummy(n) ? styleEdgeForward + " nonode" : styleNode + " node"))
				.attr("x").float(-layerWidth / 2)
				.attr("y").float(0)
				.attr("width").float(Math.round(layerWidth))
				.attr("height").floatf(hnode);
			cont.each(function(node, _) {
				addToMap(node.id, "node", Selection.current);
			});


			cont.append("svg:line")
				.attr("class").stringf(function(n, _) return "node stroke stroke-" + (isdummy(n) ? styleEdgeForward : styleNode))
				.attr("x1").float(-layerWidth / 2)
				.attr("y1").float(0)
				.attr("x2").float(layerWidth / 2)
				.attr("y2").float(0);

			cont.append("svg:line")
				.attr("class").stringf(function(n, _) return "node stroke stroke-" + (isdummy(n) ? styleEdgeForward : styleNode))
				.attr("x1").float(-layerWidth / 2)
				.attr("y1").floatf(hnode)
				.attr("x2").float(layerWidth / 2)
				.attr("y2").floatf(hnode);
		}

		choice.update().attr("transform").stringf(function(n, i) {
			return "translate(0,"+ynode(n)+")";
		});

		cont.each(function(n : GNode<NodeData, Dynamic>, i) {
			var node = Selection.current;
			if(isdummy(n))
				return;
			var nodeheight = hnode(n),
				label;

			// label inside
			if(null != labelDataPoint)
			{
				var lines = labelDataPoint(n.data.dp, dependentVariable.stats).split("\n"),
					nodeSpacing = 3,
					prev : Label = null,
					text,
					pos = 0.0;
				for(i in 0...lines.length)
				{
					text = lines[i];
					label = new Label(node, true, true, false);
					label.addClass("node");
					if(i == 0)
						label.addClass("first");
					pos = nodeSpacing;
					if(null != prev)
					{
						pos += prev.y + prev.getSize().height;
					}
					label.place(-layerWidth / 2 + nodeSpacing * 2, pos, 0);
					label.anchor = GridAnchor.TopLeft;
					label.text = text;
					if(label.y + label.getSize().height > nodeheight)
					{
						label.destroy();
						break;
					}
					prev = label;
				}
			}

			var hasimage = false;
			// thumbnail
			if(null != imagePath && !isdummy(n))
			{
				var path = imagePath(n.data.dp);
				if(path != null)
				{
					hasimage = true;
					var container = node.append("svg:g")
						.attr("transform").string("translate("+(Math.round(-imageWidth/2))+","+(Math.round(-imageHeight-imageSpacing))+")");
					container.append("svg:image")
						.attr("preserveAspectRatio").string("xMidYMid slice")
						.attr("width").float(imageWidth)
						.attr("height").float(imageHeight)
						.attr("xlink:href").string(path);
				}
			}

			// label top
			if(null != labelNode)
			{
				if(hasimage)
					label = new Label(node, true, true, true);
				else
					label = new Label(node, true, false, false);
				label.anchor = GridAnchor.Bottom;
				label.place(0, -labelNodeSpacing, 0);
				label.text = labelNode(n.data.dp, this.dependentVariable.stats);
			}
		});

		cont.each(function(n : GNode<NodeData, Dynamic>, i) {
			var node = Selection.current;
			node.onNode("mouseover", callback(onmouseovernode, n));
			if(null != click)
			{
				node.onNode("click", callback(nodeclick, n));
			}
		});

		ready.dispatch();
	}

	function addToMap(id : Int, type : String, el : Selection)
	{
		mapelements.set(type+":"+id, el);
	}

	function isbackward(edge : GEdge<NodeData, Dynamic>)
	{
		return layout.cell(edge.head).layer <= layout.cell(edge.tail).layer;
	}

	function highlight(id : Int, type : String)
	{
		for(el in maphi)
			el.classed().remove("over");

		maphi = new Hash();

		var hiedgep = null,
			hinodep = null,
			hiedgen = null,
			hinoden = null;


		function hielement(id : Int, type : String) 
		{
			var key = type+":"+id;
			maphi.set(key, mapelements.get(key).classed().add("over"));
		}

		function hiextrain(id : Int)
		{
			var key = "extrain:"+id,
				extra = mapelements.get(key);
			if(null == extra)
				return;
			maphi.set(key, extra.classed().add("over"));
		}

		function hiextraout(id : Int)
		{
			var key = "extraout:"+id,
				extra = mapelements.get(key);
			if(null == extra)
				return;
			maphi.set(key, extra.classed().add("over"));
		}

		function ishi(id : Int, type : String)
		{
			return maphi.exists(type + ":" + id);
		}

		hiedgep = function(edge : GEdge<NodeData, Dynamic>)
		{
			if(ishi(edge.id, "edge"))
				return;
			hielement(edge.id, "edge");
			if(!isbackward(edge))
				hinodep(edge.head);
		}

		hinodep = function(node : GNode<NodeData, Dynamic>)
		{
			if(ishi(node.id, "node"))
				return;
			hielement(node.id, "node");
			hiextraout(node.id);
			for(edge in node.positives())
				hiedgep(edge);
		}

		hiedgen = function(edge : GEdge<NodeData, Dynamic>)
		{
			if(!isbackward(edge))
				hinoden(edge.tail);
			if(ishi(edge.id, "edge"))
				return;
			if(!isbackward(edge))
				hielement(edge.id, "edge");
		}

		hinoden = function(node : GNode<NodeData, Dynamic>)
		{
			for(edge in node.negatives())
				hiedgen(edge);
			if(ishi(node.id, "node"))
				return;
			hielement(node.id, "node");
			hiextrain(node.id);
		}

		if(type == "edge")
		{
			hiedgep(layout.graph.edges.get(id));
			hiedgen(layout.graph.edges.get(id));
		} else if(type == "node")
		{
			hinodep(layout.graph.nodes.get(id));
			hinoden(layout.graph.nodes.get(id));
			hiextrain(id);
		}
		// descend

		// ascend
	}

	function edgeData(edge : GEdge<NodeData, Dynamic>)
	{
		var head = edge.head,
			tail = edge.tail;
		while(isdummy(head))
			head = head.positives().next().head;
		while(isdummy(tail))
			tail = tail.negatives().next().tail;
		return {
			head : head.data.dp,
			tail : tail.data.dp,
			edgeweight : edge.weight,
			nodeweight : tail.data.weight
		};
	}

	function edgeDataWithNode(node : GNode<NodeData, Dynamic>, out : Bool) 
	{
		return {
			tail : out ? node.data.dp : null,
			head : out ? null : node.data.dp,
			edgeweight : out ? node.data.extraout : node.data.extrain,
			nodeweight : node.data.weight
		};
	}

	function nodeclick(node : GNode<NodeData, Dynamic>, el : js.Dom.HtmlDom, i : Int)
	{
		click(node.data.dp, dependentVariable.stats);
	}

	function edgeclick(data : { head : DataPoint, tail : DataPoint, edgeweight : Float, nodeweight : Float }, el : js.Dom.HtmlDom, i : Int)
	{
		clickEdge(data, dependentVariable.stats);
	}

	function edgeClickWithEdge(edge : GEdge<NodeData, Dynamic>, el : js.Dom.HtmlDom, i : Int)
	{
		edgeclick(edgeData(edge), el, i);
	}

	function edgeClickWithNode(node : GNode<NodeData, Dynamic>, out : Bool, el : js.Dom.HtmlDom, i : Int)
	{
		edgeclick(edgeDataWithNode(node, out), el, i);
	}

	function onmouseovernode(node : GNode<NodeData, Dynamic>, el : js.Dom.HtmlDom, i : Int)
	{
		highlight(node.id, "node");
		if(isdummy(node))
		{
			if(null == labelEdgeOver)
				return;
			var text = labelEdgeOver(edgeData(node.positives().next()), dependentVariable.stats);
			if (null == text)
				tooltip.hide();
			else
			{
				var cell = layout.cell(node);
				tooltip.preferredSide = 2;
				tooltip.text = text.split("\n");
				moveTooltip(
					xlayer(cell.layer),
					ynode(node) + hnode(node) / 2
				);
			}
		} else {
			if(null == labelDataPointOver)
				return;
			var text = labelDataPointOver(node.data.dp, dependentVariable.stats);
			if (null == text)
				tooltip.hide();
			else
			{
				var cell = layout.cell(node);
				tooltip.preferredSide = 0;
				tooltip.text = text.split("\n");
				moveTooltip(
					xlayer(cell.layer),
					ynode(node) + hnode(node) / 2
				);
			}
		}
	}

	function onmouseoveredge(x : Float, y : Float, edge : GEdge<NodeData, Dynamic>, el : js.Dom.HtmlDom, i : Int)
	{
		highlight(edge.id, "edge");
		if(null == labelEdgeOver)
			return;
		var text = labelEdgeOver(edgeData(edge), dependentVariable.stats);
		if (null == text)
			tooltip.hide();
		else
		{
			tooltip.preferredSide = 2;
			tooltip.text = text.split("\n");
			moveTooltip(x, y);
		}
	}

	function onmouseoverextrain(x : Float, y : Float, node : GNode<NodeData, Dynamic>, el : js.Dom.HtmlDom, i : Int)
	{
		highlight(node.id, "node");
		if(null == labelEdgeOver)
			return;
		var text = labelEdgeOver(edgeDataWithNode(node, false), dependentVariable.stats);
		if (null == text)
			tooltip.hide();
		else
		{
			tooltip.preferredSide = 2;
			tooltip.text = text.split("\n");
			moveTooltip(x, y);
		}
	}

	function onmouseoverextraout(x : Float, y : Float, node : GNode<NodeData, Dynamic>, el : js.Dom.HtmlDom, i : Int)
	{
		highlight(node.id, "node");
		if(null == labelEdgeOver)
			return;
		var text = labelEdgeOver(edgeDataWithNode(node, true), dependentVariable.stats);
		if (null == text)
			tooltip.hide();
		else
		{
			tooltip.preferredSide = 0;
			tooltip.text = text.split("\n");
			moveTooltip(x, y);
		}
	}

	function nheight(v : Float)
	{
		return Math.round(v / maxweight * availableheight);
	}

	function ydiagonal(id : Int, edges : Iterator<GEdge<NodeData, Dynamic>>)
	{
		var weight = 0.0;
		for(edge in edges)
		{
			if(edge.id == id)
				break;
			weight += edge.weight;
		}
		return nheight(weight);
	}

	function hafter(id : Int, edges : Iterator<GEdge<NodeData, Dynamic>>)
	{
		var found = false,
			pad = backEdgeSpacing / nheight(1),
			weight = pad;
		for(edge in edges)
		{
			if(!found)
			{
				if(edge.id == id)
					//	continue;
					found = true;
				continue;
			}
			weight += edge.weight + pad;
		}
		return nheight(weight);
	}

	function xlayer(pos : Int, ?_)
	{
		if(layout.length <= 1)
			return width / 2;
		return Math.round((width - padBefore - padAfter - layerWidth) / (layout.length - 1) * pos + (layerWidth / 2) + padBefore); // + 0.5;
	}

	function ynode(node : GNode<NodeData, Dynamic>, ?_)
	{
		var cell = layout.cell(node),
			before = 0.0 + layerstarty[cell.layer];
		for(i in 0...cell.position)
		{
			var prev = layout.nodeAt(cell.layer, i);
			before += hnode(prev) + nodepadding(prev);
		}
		before += nodepadding(node);
		return Math.round(before) + 0.5;
	}

	function nodepadding(node : GNode<NodeData, Dynamic>)
	{
		return isdummy(node) ? dummySpacing : nodeSpacing;
	}

	function isdummy(node : GNode<NodeData, Dynamic>)
	{
		return node.data.id.substr(0, 1) == "#";
	}

	function hnode(node : GNode<NodeData, Dynamic>, ?_)
	{
		return nheight(node.data.weight);
	}
}

typedef NodeData =
{
	dp       : DataPoint,
	id       : String,
	weight   : Float,
	extrain  : Float,
	extraout : Float
}