/**
 * ...
 * @author Franco Ponticelli
 */

package rg.controller.factory;
import rg.controller.info.InfoDataSource;
import rg.data.IDataSource;
import rg.data.source.DataSourceLoader;
import thx.error.Error;
import rg.data.DataPoint;

class FactoryDataSource<T : InfoDataSource>
{
	var cache : Hash<IDataSource>;
	public function new(cache : Hash<IDataSource>)
	{
		this.cache = cache;
	}

	public function create(info : T) : IDataSource
	{
		if (null != info.loader)
		{
			return new DataSourceLoader(info.loader);
		}
		throw new Error("the arguments object doesn't contain any reference to data");
	}
}