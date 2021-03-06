/**
 * ...
 * @author Franco Ponticelli
 */

package rg.factory;
import rg.info.InfoBarChart;
import rg.info.InfoFunnelChart;
import rg.info.InfoGeo;
import rg.info.InfoHeatGrid;
import rg.info.InfoLineChart;
import rg.info.InfoPieChart;
import rg.info.InfoSankey;
import rg.info.InfoScatterGraph;
import rg.info.InfoStreamGraph;
import rg.visualization.VisualizationBarChart;
import rg.visualization.VisualizationFunnelChart;
import rg.visualization.VisualizationGeo;
import rg.visualization.VisualizationHeatGrid;
import rg.visualization.VisualizationLineChart;
import rg.visualization.VisualizationPieChart;
import rg.visualization.VisualizationSankey;
import rg.visualization.VisualizationScatterGraph;
import rg.visualization.VisualizationStreamGraph;
import rg.visualization.VisualizationSvg;
import rg.layout.Layout;
import thx.error.Error;
import thx.error.NotImplemented;
using rg.info.Info;

class FactorySvgVisualization
{
	public function new() { }

	public function create(type : String, layout : Layout, options : Dynamic) : VisualizationSvg
	{
		switch(type)
		{
			case "barchart":
				var chart = new VisualizationBarChart(layout);
				chart.info = chart.infoBar = new InfoBarChart().feed(options);
				return chart;
			case "funnelchart":
				var chart = new VisualizationFunnelChart(layout);
				chart.info = new InfoFunnelChart().feed(options);
				return chart;
			case "geo":
				var chart = new VisualizationGeo(layout);
				chart.info = new InfoGeo().feed(options);
				return chart;
			case "heatgrid":
				var chart = new VisualizationHeatGrid(layout);
				chart.info = chart.infoHeatGrid = new InfoHeatGrid().feed(options);
				return chart;
			case "linechart":
				var chart = new VisualizationLineChart(layout);
				chart.info = chart.infoLine = new InfoLineChart().feed(options);
				return chart;
			case "piechart":
				var chart = new VisualizationPieChart(layout);
				chart.info = new InfoPieChart().feed(options);
				return chart;
			case "sankey":
				var chart = new VisualizationSankey(layout);
				chart.info = new InfoSankey().feed(options);
				return chart;
			case "scattergraph":
				var chart = new VisualizationScatterGraph(layout);
				chart.info = chart.infoScatter = new InfoScatterGraph().feed(options);
				return chart;
			case "streamgraph":
				var chart = new VisualizationStreamGraph(layout);
				chart.info = chart.infoStream = new InfoStreamGraph().feed(options);
				return chart;
			default:
				throw new Error("unsupported visualization type '{0}'", type);
		}
	}
}