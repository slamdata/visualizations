/**
 * ...
 * @author Franco Ponticelli
 */

package rg.util;

class ChainedExecutor<T>
{
	var handler : Dynamic -> Void;
	var actions : Array<T -> (T -> Void) -> Void>;
	
	public function new(handler : T -> Void)
	{
		this.handler = handler;
		actions = [];
	}
	
	public function addAction(handler : T -> (T -> Void) -> Void )
	{
		actions.push(handler);
	}
	
	public function execute(ob : T)
	{
		if (actions.length == 0)
			handler(ob);
		else
			actions.shift()(ob, execute);
	}
}