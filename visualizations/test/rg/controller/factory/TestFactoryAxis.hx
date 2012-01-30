/**
 * ...
 * @author Franco Ponticelli
 */

package rg.factory;

import rg.axis.AxisTime;
import rg.axis.AxisOrdinal;
import rg.axis.AxisGroupByTime;
import thx.collection.Set;
import utest.Assert;
import rg.util.Properties;

class TestFactoryAxis
{
	public function testAxisTime()
	{
		var factory = new FactoryAxis();
		var axis = Types.as(factory.createDiscrete(Properties.timeProperty("hour"), [1, 2, 3], null), AxisTime);
		Assert.notNull(axis);
		Assert.equals("hour", axis.periodicity);
	}

	public function testAxisGroupByTime()
	{
		var factory = new FactoryAxis();
		var axis = Types.as(factory.createDiscrete(Properties.timeProperty("hour"), [1, 2, 3], "day"), AxisGroupByTime);
		Assert.notNull(axis);
		Assert.equals("day", axis.groupBy);
	}

	public function testAxisOrdinal()
	{
		var factory = new FactoryAxis();
		var axis = Types.as(factory.createDiscrete("count", [1, 2, 3], null), AxisOrdinal);
		Assert.equals(1, axis.first);
		Assert.equals(3, axis.last);
		Assert.same(Set.ofArray([1, 2, 3]), axis.values);

		axis = Types.as(factory.createDiscrete("count", null, null), AxisOrdinal);
		Assert.isNull(axis.first);
		Assert.isNull(axis.last);
		Assert.equals(0, axis.values.length);
	}

	public function new() { }
}