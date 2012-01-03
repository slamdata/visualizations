package rg.controller.visualization;
import rg.controller.info.InfoSankey;
//import rg.view.graph.Layout;
import rg.graph.EdgeSplitter;
import rg.view.svg.layer.Title;
import rg.view.svg.chart.Sankey;
import rg.data.DataPoint;
import rg.graph.LongestPathLayer;
import rg.graph.Graph;
import rg.graph.GraphLayout;
import rg.graph.GEdge;
import rg.graph.SugiyamaMethod;
import rg.graph.HeaviestNodeLayer;
import rg.graph.GreedySwitchDecrosser;

using Arrays;

class VisualizationSankey extends VisualizationSvg
{
	public var info : InfoSankey;
	var title : Null<Title>;
	var chart : Sankey;

	override function init()
	{
		// TITLE
		if (null != info.label.title)
		{
			var panelContextTitle = layout.getContext("title");
			if (null == panelContextTitle)
				return;
			title = new Title(panelContextTitle.panel, null, panelContextTitle.anchor);
		}

		// CHART
		var panelChart = layout.getPanel(layout.mainPanelName);
		chart = new Sankey(panelChart);
		chart.ready.add(function() ready.dispatch());
	}

	override function feedData(data : Array<DataPoint>)
	{
//		trace(data);
		chart.setVariables(independentVariables, dependentVariables, data);
		if (null != title)
		{
			if (null != info.label.title)
			{
				title.text = info.label.title(variables, data);
				layout.suggestSize("title", title.idealHeight());
			} else
				layout.suggestSize("title", 0);
		}
		var layout = (null != info.layoutmap) ? layoutDataWithMap(data, info.layoutmap) : layoutData(data);

		if(null != info.layerWidth)
			chart.layerWidth = info.layerWidth;
		if(null != info.nodeSpacing)
			chart.nodeSpacing = info.nodeSpacing;
		if(null != info.dummySpacing)
			chart.dummySpacing = info.dummySpacing;
		if(null != info.extraWidth)
			chart.extraWidth = info.extraWidth;
		if(null != info.backEdgeSpacing)
			chart.backEdgeSpacing = info.backEdgeSpacing;
		if(null != info.extraHeight)
			chart.extraHeight = info.extraHeight;
		if(null != info.extraRadius)
			chart.extraRadius = info.extraRadius;
		if(null != info.imageWidth)
			chart.imageWidth = info.imageWidth;
		if(null != info.imageHeight)
			chart.imageHeight = info.imageHeight;
		if(null != info.imageSpacing)
			chart.imageSpacing = info.imageSpacing;
		if(null != info.labelNodeSpacing)
			chart.labelNodeSpacing = info.labelNodeSpacing;


		chart.labelDataPoint = info.label.datapoint;
		chart.labelDataPointOver = info.label.datapointover;
		chart.labelNode = info.label.node;
		chart.labelEdge = info.label.edge;
		chart.labelEdgeOver = info.label.edgeover;
		chart.imagePath = info.imagePath;
		chart.click = info.click;
		chart.clickEdge = info.clickEdge;

		chart.init();
		chart.data(layout);
	}

	function layoutDataWithMap(data : Array<DataPoint>, map : { layers : Array<Array<String>>, dummies : Array<Array<String>> }, ?idf : NodeData -> String, ?weightf : DataPoint -> Float, ?edgesf : DataPoint -> Array<{ head : String, tail : String, weight : Float}>)
	{
		var graph = createGraph(data, idf, weightf, edgesf);

		for(path in map.dummies)
		{
			var tail   = graph.nodes.getById(path.first()),
				head   = graph.nodes.getById(path.last()),
				npath  = [tail],
				edge   = tail.connectedBy(head),
				weight = null == edge ? 0.0 : edge.weight;

			// add dummy nodes
			for(i in 1...path.length-1)
			{
				var id = path[i],
					data = {
						id : id,
						weight : weight,
						extrain : 0.0,
						extraout : 0.0,
						dp : null
					};
				npath.push(graph.nodes.create(data));
			}
			npath.push(head);
			// add dummy edges
			for(i in 0...npath.length-1)
			{
				graph.edges.create(npath[i], npath[i+1], weight);
			}
			if(null != edge)
				edge.remove();
		}


		// convert layers
		var layers = map.layers.map(function(layer : Array<String>, _) return layer.map(function(id, _) return graph.nodes.getById(id).id));
		return new GraphLayout(graph, layers);
	}

	function createGraph(data : Array<DataPoint>, idf : NodeData -> String, weightf : DataPoint -> Float, edgesf : DataPoint -> Array<{ head : String, tail : String, weight : Float}>) : Graph<NodeData, Dynamic>
	{
		idf = defaultIdf(idf);
		edgesf = defaultEdgesf(idf, edgesf);
		weightf = defaultWeightf(weightf);
		var graph = new Graph(idf);

		for(dp in data)
		{
			graph.nodes.create({
				dp       : dp,
				id       : idf(dp),
				weight   : weightf(dp),
				extrain  : 0.0,
				extraout : 0.0
			});
		}

		for(dp in data)
		{
			var edges = edgesf(dp);
			for(edge in edges)
			{
				var head = graph.nodes.getById(edge.head);
				var tail = graph.nodes.getById(edge.tail);
				graph.edges.create(tail, head, edge.weight == null ? 0 : edge.weight);
			}
		}

		for(node in graph.nodes)
		{
			var win  = node.negativeWeight(),
				wout = node.positiveWeight();
			if(node.data.weight == 0)
			{
				node.data.weight = win;
			}
			node.data.extrain  = Math.max(0, node.data.weight - win);
			node.data.extraout = Math.max(0, node.data.weight - wout);
		}

		return graph;
	}

	function layoutData(data : Array<DataPoint>, ?idf : NodeData -> String, ?nodef : GEdge<NodeData, Dynamic> -> DataPoint, ?weightf : DataPoint -> Float, ?edgesf : DataPoint -> Array<{ head : String, tail : String, weight : Float}>) : GraphLayout<NodeData, Dynamic>
	{
		var graph = createGraph(data, idf, weightf, edgesf);

		nodef = defaultNodef(nodef);
/*
		if(REMOVEME)
		{
			REMOVEME = false;
			return sugiyama(graph, nodef);
		}
*/
		return weightBalance(graph, nodef);
	}

	static function defaultIdf(?idf : NodeData -> String)
	{
		if(idf == null)
			return function(data : NodeData) return data.id;
		else
			return idf;
	}

	static function defaultNodef(?nodef : GEdge<NodeData, Dynamic> -> DataPoint)
	{
		if(nodef == null)
		{
			var dummynodeid = 0;
			return function(edge : GEdge<NodeData, Dynamic>) {
				return {
					id : "#" + (++dummynodeid),
					weight : edge.weight,
					extrain : 0.0,
					extraout : 0.0
				};
			};
		} else
			return nodef;
	}

	static function defaultEdgesf(idf : NodeData -> String, ?edgesf : DataPoint -> Array<{ head : String, tail : String, weight : Float}>)
	{
		if(edgesf == null)
		{
			return function(dp : Dynamic) {
				var r = [],
					id = idf(dp);
				for(parent in Reflect.fields(dp.parents))
				{
					r.push(cast {
						head : id,
						tail : parent,
						weight : Reflect.field(dp.parents, parent)
					});
				}
				return r;
			};
		} else
			return edgesf;
	}

	static function defaultWeightf(?weightf : DataPoint -> Float)
	{
		if(null == weightf)
		{
			return function(dp) {
				return null != dp.count ? dp.count : 0.0;
			};
		} else
			return weightf;
	}

//	static var REMOVEME = true;

	function weightBalance(graph : Graph<NodeData, Dynamic>, nodef : GEdge<NodeData, Dynamic> -> DataPoint)
	{
		var layout = new GraphLayout(graph, new HeaviestNodeLayer().lay(graph));
		layout = new EdgeSplitter().split(layout, [], nodef);
		layout = GreedySwitchDecrosser.best().decross(layout);

		return layout;
	}

	function sugiyama(graph : Graph<NodeData, Dynamic>, nodef)
	{
		return new SugiyamaMethod().resolve(graph, nodef);
	}
/*
	function layoutMap(map : Hash<Node>) : Array<Array<Node>>
	{
		var sugiyama = null, //new SugiyamaMethod(),
			vertices = [],
			edges = [];
		Iterables.each(map, function(node : Node, _) {
			vertices.push(node.id);
			for(child in node.children)
				edges.push({ a : node.id, b : child.id });
		});
		var glayout = null,//sugiyama.resolve(vertices, edges),
			gmap = Graphs.toMap(glayout);
		var layout = [], tmap;
		for(i in 0...glayout.length)
		{
			layout[i] = [];
			for (j in 0...glayout[i].length)
			{
				var gnode = glayout[i][j],
					onode = map.get(gnode.vertex),
					nnode = {
						dp : null,
						id : gnode.vertex,
						weight : 0.0,
						extraweight : 0.0,
						falloffweight : 0.0,
						parents : [],
						children : [],
						level : i,
						pos : j
					};
				if(null != onode)
				{
					nnode.dp = onode.dp;
					nnode.weight = onode.weight;
					nnode.extraweight = onode.extraweight;
					nnode.falloffweight = onode.falloffweight;
					tmap = new Hash();
					for(c in onode.children)
					{
						tmap.set(c.id, c.weight);
					}
					for(dst in gnode.edgesp)
					{
						var id = dst;
						while(Graphs.isDummy(id))
							id = gmap.get(id).edgesp[0];
						nnode.children.push({
							id : dst,
							weight : tmap.get(id)
						});
					}
					tmap = new Hash();
					for(c in onode.parents)
					{
						tmap.set(c.id, c.weight);
					}
					for(dst in gnode.edgesn)
					{
						var id = dst;
						while(Graphs.isDummy(id))
							id = gmap.get(id).edgesn[0];
						nnode.parents.push({
							id : dst,
							weight : tmap.get(id)
						});
					}
				} else {
					// dummy node, needs to be created
					trace(gnode);
					var dstid = gnode.edgesp[0];
					while(Graphs.isDummy(dstid))
						dstid = gmap.get(dstid).edgesp[0];
					trace(dstid);
					for(src in gnode.edgesn)
					{
						var id = src;
						while(Graphs.isDummy(id))
							id = gmap.get(id).edgesn[0];
						trace(src + " TO " + id);
						var parent = map.get(id);
						trace(parent);
						for(edge in parent.children)
						{
							trace(edge);
							if(edge.id == dstid)
							{
								nnode.parents.push({ id : src, weight : edge.weight });
								break;
							}
						}
					}
					trace(nnode);
				}
				layout[i][j] = nnode;
			}
		}
		return layout;
	}

	function layoutMap2(map : Hash<Node>) : Array<Array<Node>>
	{
		var result = [],
			i = -1,
			keys = map.keys().order(function(a, b) {
				return Floats.compare(map.get(b).weight, map.get(a).weight);
			});

		function addAt(id : String, lvl)
		{
			var node = map.get(id);
			if(!keys.remove(id))
				return;
			var level = result[lvl];
			if(null == level)
				level = result[lvl] = [];
			level.push(node);
			node.pos = level.length - 1;
			node.level = lvl;
			for(child in node.children)
			{
				addAt(child.id, lvl+1);
			}
		}

		while(keys.length > 0)
		{
			addAt(keys[0], 0);
		}

		for(key in map.keys())
		{
			var n = map.get(key);
			n.parents.sort(function(a, b) {
				var c = Ints.compare(map.get(a.id).level, map.get(b.id).level);
				if(c > 0)
					return c;
				return Floats.compare(b.weight, a.weight);
			});
		}

		return result;
	}

	function mapData(data : Array<DataPoint>)
	{
		var map          = new Hash(),
			idfield      = info.idproperty,
			weightfield   = info.weightproperty,
			parentsfield = info.parentsproperty,
			id : String, weight : Float, o, Dynamic, parents : Array<{ id : String, weight : Float }>;
		for(dp in data)
		{
			id = Reflect.field(dp, idfield);
			if(null == id) continue;
			o = Reflect.field(dp, parentsfield);
			parents = Reflect.fields(o).map(function(field, _) : { id : String, weight : Float } {
				return { id : field, weight : Reflect.field(o, field) };
			});
			var derivedweight = parents.reduce(function(tot, cur, _) {
				return tot + cur.weight;
			}, 0.0);
			weight = Reflect.field(dp, weightfield);
			if(null == weight)
				weight = derivedweight;
			map.set(id, {
				dp : dp,
				id : id,
				weight : weight,
				extraweight : weight - derivedweight,
				falloffweight : 0.0,
				parents : parents,
				children : [],
				level : 0,
				pos : 0
			});
		}

		for(key in map.keys())
		{
			var n = map.get(key);
			for(p in n.parents)
			{
				var pn = map.get(p.id);
				pn.children.add({ id : n.id, weight : p.weight });
				pn.children.sort(function(a,b) return Floats.compare(b.weight, a.weight));
			}
		}

		for(key in map.keys())
		{
			var n = map.get(key),
				falloff = n.weight;
			for(child in n.children)
			{
				falloff -= child.weight;
			}
			n.falloffweight = falloff;
		}
		return map;
	}
*/
	override public function destroy()
	{
		chart.destroy();
		if (null != title)
			title.destroy();
		super.destroy();
	}
}