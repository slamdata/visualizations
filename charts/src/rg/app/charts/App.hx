/**
 * ...
 * @author Franco Ponticelli
 */

package rg.app.charts;
import rg.controller.factory.FactoryLayout;
import rg.controller.factory.FactoryVariable;
import rg.controller.factory.FactoryHtmlVisualization;
import rg.controller.factory.FactorySvgVisualization;
import rg.controller.info.InfoDataSource;
import rg.controller.info.InfoDomType;
import rg.controller.info.InfoDownload;
import rg.controller.info.InfoGeneral;
import rg.controller.info.InfoLayout;
import rg.controller.info.InfoTrack;
import rg.controller.info.InfoVisualizationOption;
import rg.controller.info.InfoVisualizationType;
import rg.controller.interactive.Downloader;
import rg.controller.visualization.Visualization;
import rg.data.DataLoader;
import rg.data.DataPoint;
import rg.data.DependentVariableProcessor;
import rg.data.IndependentVariableProcessor;
import rg.data.VariableDependent;
import rg.data.VariableIndependent;
import rg.view.html.widget.DownloaderMenu;
import rg.view.html.widget.Logo;
import rg.view.layout.Layout;
import thx.error.Error;
import thx.js.Selection;
using rg.controller.info.Info;
using Arrays;

class App
{
	static var lastid = 0;
	static function nextid()
	{
		return ":RGVIZ-" + (++lastid);
	}

	var layouts : Hash<Layout>;
	public function new()
	{
		this.layouts = new Hash();
	}

	public function visualization(el : Selection, jsoptions : Dynamic)
	{
		var node = el.node(),
			id = node.id;
		if (null == id)
			node.id = id = nextid();

		var params    = new InfoVisualizationOption().feed(jsoptions),
			loader    = new DataLoader(new InfoDataSource().feed(jsoptions).loader),
			variables = new FactoryVariable().createVariables(params.variables),
			general   = new InfoGeneral().feed(params.options),
			infoviz   = new InfoVisualizationType().feed(params.options);

		var visualization : Visualization = null;
		params.options.marginheight = 29;
		var ivariables : Array<rg.data.VariableIndependent<Dynamic>> = cast variables.filter(function(v) return Std.is(v, VariableIndependent));
		var dvariables : Array<rg.data.VariableDependent<Dynamic>> = cast variables.filter(function(v) return Std.is(v, VariableDependent));

		switch(new InfoDomType().feed(params.options).kind)
		{
			case Svg:
				var layout = getLayout(id, params.options, el, infoviz.replace);
				visualization = new FactorySvgVisualization().create(infoviz.type, layout, params.options);
			case Html:
				if (infoviz.replace)
					el.selectAll("*").remove();
				visualization = new FactoryHtmlVisualization().create(infoviz.type, el, params.options);
		}

		visualization.setVariables(variables, ivariables, dvariables);
		visualization.init();
		if (null != general.ready)
			visualization.addReady(general.ready);

		loader.onLoad.addOnce(function(data) {
			new IndependentVariableProcessor().process(data, ivariables);
			new DependentVariableProcessor().process(data, dvariables);
		});

		loader.onLoad.addOnce(function(datapoints : Array<DataPoint>) {
			visualization.feedData(datapoints);
		});
		loader.load();

		var brandPadding = 0;
		// download
		var download = new InfoDownload().feed(jsoptions.options.download);
		if(!supportsSvg())
		{
			// IMAGE RENDERING FOR DEVICES
			var downloader = new Downloader(visualization.container, download.service, download.background);
			visualization.addReadyOnce(function() {
				downloader.download("png", "#ffffff", function(url : String) {
					visualization.container.selectAll("*").remove();
					visualization.container.append("img")
						.attr("src").string(url);
					return false;
				}, null);
			});
		} else if (null != download.position || null != download.handler)
		{
			var downloader = new Downloader(visualization.container, download.service, download.background);

			if (null != download.handler)
				visualization.addReadyOnce(function() {
					download.handler(downloader.download);
				});
			else
			{
				visualization.addReadyOnce(function()
				{
					var widget = new DownloaderMenu(downloader.download, download.position, download.formats, visualization.container);
					brandPadding = 24;
				});

			}
		}

		if(!jsoptions.options.a)
		{
			visualization.addReadyOnce(function()
			{
				var widget = new Logo(visualization.container, brandPadding);
			});
		}
		return visualization;
	}

	public function getLayout(id : String, options : Dynamic, container : Selection, replace : Bool)
	{
		var old = layouts.get(id);
		if (null != old)
		{
			if (replace)
				old.destroy();
			else
				return old;
		}
		var info = new InfoLayout().feed(options),
			layout = new FactoryLayout().create(info, options.marginheight, container);
		layouts.set(id, layout);
		return layout;
	}

	public static function supportsSvg() : Bool
	{
		return untyped __js__("!!document.createElementNS && !!document.createElementNS('http://www.w3.org/2000/svg', 'svg').createSVGRect");
	}
}