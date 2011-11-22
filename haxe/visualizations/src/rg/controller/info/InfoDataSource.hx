/**
 * ...
 * @author Franco Ponticelli
 */

package rg.controller.info;
import rg.data.DataPoint;
import rg.util.Periodicity;
import thx.date.DateParser;
import thx.error.Error;

class InfoDataSource
{
	public var query : Null<String>;
	public var path : Null<String>;
	public var event : Null<String>;
	public var namedData : Null<String>;
	public var data : Null<Array<DataPoint>>;
	public var groupBy : Null<String>;
	public var timeZone : Null<String>;
	public var groups : Null<Array<String>>;
	public var start : Null<Float>;
	public var end : Null<Float>;
	
	public function new() {}

	public static function filters() : Array<FieldFilter>
	{
		return [{
			field : "query",
			validator : function(v) return Std.is(v, String),
			filter : null
		}, {
			field : "path",
			validator : function(v) return Std.is(v, String),
			filter : null
		}, {
			field : "event",
			validator : function(v) return Std.is(v, String),
			filter : null
		}, {
			field : "start",
			validator : validateDate,
			filter : function(v) return [{ field : "start", value : filterDate(v) }]
		}, {
			field : "end",
			validator : validateDate,
			filter : function(v) return [{ field : "end", value : filterDate(v) }]
		}, {
			field : "timezone",
			validator : function(v) return Std.is(v, String),
			filter : function(v) {
				return [{ field : "timeZone", value : v }];
			}
		}, {
			field : "data",
			validator : function(v) return Std.is(v, String) || (Std.is(v, Array) && Arrays.all(v, function(v) return Types.isAnonymous(v))),
			filter : function(v)
			{
				if(Std.is(v, Array))
					return [{ field : "data", value : v }];
				else
					return [{ field : "namedData", value : v }];
			}
		}, {
			field : "groupby",
			validator : function(v : Dynamic) return Std.is(v, String) && Periodicity.isValid(v),
			filter : function(v)
			{
				return [{ field : "groupBy", value : v }];
			}
		}, {
			field : "groupfilter",
			validator : function(v : Dynamic) return Std.is(v, String) || Std.is(v, Array),
			filter : function(v)
			{
				return [{ field : "groups", value : Std.is(v, String) ? cast v.split(",") : v }];
			}
		}];
	}
	
	static function validateDate(v : Dynamic) return Std.is(v, Float) || Std.is(v, Date) || Std.is(v, String)
	
	static function filterDate(v : Dynamic) : Dynamic
	{
		if (null == v)
			return null;
		if (Std.is(v, Float))
			return v;
		if (Std.is(v, Date))
			return cast(v, Date).getTime();
		if (Std.is(v, String))
			return DateParser.parse(v).getTime();
		return throw new Error("invalid date '{0}' for start or end", [v]);
	}
}