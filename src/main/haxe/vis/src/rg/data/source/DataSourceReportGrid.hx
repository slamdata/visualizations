/**
 * ...
 * @author Franco Ponticelli
 */

package rg.data.source;
import hxevents.Dispatcher;
import rg.data.IDataSource;
import rg.data.source.rgquery.IExecutorReportGrid;
import rg.data.source.rgquery.QueryAst;
import rg.data.source.rgquery.transform.TransformCount;
import rg.data.source.rgquery.transform.TransformIntersectGroup;
import rg.data.source.rgquery.transform.TransformIntersectGroupUtc;
import rg.data.source.rgquery.transform.TransformIntersect;
import rg.data.source.rgquery.transform.TransformTimeSeries;
import rg.data.source.rgquery.transform.TransformIntersectTime;
import rg.data.source.rgquery.transform.TransformIntersectUtc;
import thx.error.Error;
import rg.data.source.ITransform;
import rg.util.Properties;
import rg.util.Periodicity;
using Arrays;

class DataSourceReportGrid implements IDataSource
{
	var executor : IExecutorReportGrid;
	
	// specific query stuff
	var exp : Array<{ property : String, event : String, limit : Int, order : String }>;
	var operation : QOperation;
	var where : Array<{ property : String, event : String, value : Dynamic }>;
	var periodicity : String;
	
	// general query stuff
	public var event(default, null) : String;
	public var path(default, null) : String;
	public var timeStart : Float;
	public var timeEnd : Float;
	public var groupBy : Null<String>;
	public var timeZone : Null<String>;
	
	var transform : ITransform<Dynamic>;
	
	public var query(default, null) : Query;
	public var onLoad(default, null) : Dispatcher<Array<DataPoint>>;
	
	function mapProperties(d, _)
	{
		switch(d)
		{
			case Property(name, limit, descending):
				return {
					event : event,
					property : name,
					limit : null == limit ? 10 : limit,
					order : false == descending ? "ascending" : "descending"
				};
			case Event:
				return {
					event : event,
					property : null,
					limit : null,
					order : null	
				};
			default:
				throw new Error("normalization failed, only Property values should be allowed");
		}
	}
	
	public function new(executor : IExecutorReportGrid, path : String, event : String, query : Query, ?groupby : String, ?timezone : String, ?start : Float, ?end : Float)
	{
		this.query = query;
		this.executor = executor;
		this.groupBy = groupby;
		this.timeZone = timezone;
		var e = normalize(query.exp);
		this.event = event;
		this.periodicity = switch(e.pop()) { case Time(p): p; default: throw new Error("normalization failed, the last value should always be a Time expression"); };
		this.exp = e.map(mapProperties);
		this.where = query.where.map(function(d, i) return switch(d) { case Equality(property, value): {
			event : event,
			property : property,
			value : value
		}; default: throw new Error("invalid data for 'where' condition"); } );
		this.operation = query.operation;
		
		switch(operation)
		{
			case Count: //
			default: throw new Error("RGDataSource doesn't support operation '{0}'", operation);
		}
		
		this.path = path;
		this.timeStart = start;
		this.timeEnd = end;
		this.onLoad = new Dispatcher();
	}
	
	function basicOptions(appendPeriodicity = true) : Dynamic
	{
		var opt = { };
		if (null != timeStart)
			Reflect.setField(opt, "start", timeStart);
		if (null != timeEnd)
		{
			var e = Periodicity.next(periodicity, timeEnd);
			Reflect.setField(opt, "end", e); // since end is not inclusive we have to extend the query span
		}
		if (appendPeriodicity)
		{
			Reflect.setField(opt, "periodicity", periodicity);
			if (null != groupBy)
				Reflect.setField(opt, "groupBy", groupBy);
			if (null != timeZone)
				Reflect.setField(opt, "timeZone", timeZone);
		}
			
		if (where.length > 1)
		{
			var w : Dynamic = { };
			for (c in where)
			{
				w.variable = propertyName(c);
				w.value = c.value;
			}
			Reflect.setField(opt, "where", w);
		}
		return opt;
	}
	
	function unit()
	{
		return switch(operation)
		{
			case Count: "count";
			default: throw new Error("unsupported operation '{0}'", operation);
		}
	}

	public function load()
	{
		if (0 == exp.length)
		{
			throw new Error("invalid empty query");
		} else if (exp.length == 1 && null == exp[0].property || where.length > 0)
		{
			if (periodicity == "eternity")
			{
				transform = new TransformCount( { }, event, unit());
				var opt : Dynamic = basicOptions(false);
				if (where.length > 1)
					executor.searchCount(path, opt, success, error);
				else if (where.length == 1)
				{
					opt.property = propertyName(exp[0]);
					opt.value = where[0].value;
					executor.propertyValueCount(path, opt, success, error);
				} else {
					opt.property = propertyName(exp[0]);
					executor.propertyCount(path, opt, success, error);
				}
			} else {
				transform = new TransformTimeSeries( { periodicity : periodicity }, event, periodicity, unit());
				var opt : Dynamic = basicOptions(true);
				if (where.length > 1)
					executor.searchSeries(path, opt, success, error);
				else if (where.length == 1)
				{
					opt.property = propertyName(exp[0]);
					opt.value = where[0].value;
					executor.propertyValueSeries(path, opt, success, error);
				} else {
					opt.property = propertyName(exp[0]);
					executor.propertySeries(path, opt, success, error);
				}
			}
		} else {
			if (groupBy != null)
			{
				if (timeZone != null)
					transform = new TransformIntersectGroupUtc( { }, exp.map(function(d, _) return d.property), event, periodicity, unit());
				else
					transform = new TransformIntersectGroup( { }, exp.map(function(d, _) return d.property), event, periodicity, unit());
			} else if (periodicity == "eternity")
				transform = new TransformIntersect( { }, exp.map(function(d, _) return d.property), event, exp[0].order != "ascending");
			else if (timeZone != null)
				transform = new TransformIntersectUtc( { }, exp.map(function(d, _) return d.property), event, periodicity, unit());
			else
				transform = new TransformIntersectTime( { }, exp.map(function(d, _) return d.property), event, periodicity, unit());
			var opt = basicOptions(true);
			opt.properties = exp.map(function(p, i) {
				return {
					property : propertyName(p),
					limit : p.limit,
					order : p.order
				};
			});
			executor.intersect(path, opt, success, error);
		}
	}
	
	public dynamic function error(msg : String)
	{
		throw new Error(msg);
	}
	
	function success(src : Dynamic)
	{
		var data = transform.transform(src);
		onLoad.dispatch(data);
	}
	
	public static function normalize(exp : Array<QExp>)
	{
		if (exp.length > 1)
		{
			var pos = -1;
			for (i in 0...exp.length)
			{
				if (isTimeProperty(exp[i]))
				{
					if (pos >= 0)
						throw new Error("cannot perform intersections on two or more time properties");
					pos = i;
				}
			}
			if (pos >= 0)
			{
				return exp.slice(0, pos).concat(exp.slice(pos + 1)).concat([exp[pos]]);
			} else {
				return exp.copy().concat([Time("eternity")]);
			}
		} else if (exp.length == 1)
		{
			switch(exp[0])
			{
				case Property(name, _, _):
					return [exp[0], Time("eternity")];
				case Time(periodicity):
					return [Event, exp[0]];
				case Event:
					return [Event, Time("eternity")];
			}
		} else {
			return [Event, Time("eternity")];
		}
		/*
		switch(exp)
		{
			case Property(name, type):
				switch(type)
				{
					case Time(_):
						return Cross(Property(name, Unbound(None)), Property(name, type));
					default:
						return Cross(Property(name, type), Property(name, Time("eternity"));
				}
			case Cross(left, right):
				if (isTimeProperty(left))
				{
					if (isTimeProperty(right))
						throw new Error("cannot perform intersections on two time properties");
					return normalize(Cross(right, left));
				}
			default:
				//
		}
		*/
	}
	
	static function propertyName(p : { property : String, event : String } )
	{
		if (null == p.property)
			return p.event;
		else
			return p.event + p.property;
	}

	static function isTimeProperty(exp : QExp) : Bool
	{
		switch(exp)
		{
			case Time(_):
				return true;
			default:
				return false;
		}
	}
}