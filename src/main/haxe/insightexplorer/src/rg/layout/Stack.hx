package rg.layout;

/**
 * ...
 * @author Franco Ponticelli
 */

import rg.layout.Orientation;

class Stack
{
	var children : Array<StackFrame>;
	public var width(default, null) : Int;
	public var height(default, null) : Int;
	public var orientation(default, null) : Orientation;
	
	public dynamic function moreSpaceRequired(size : Int) {}
	public function new(width : Int, height : Int, ?orientation : Orientation)
	{
		this.orientation = null == orientation ? Vertical : orientation;
		children = [];
		this.width = width;
		this.height = height;
	}
	
	public function addChild(child : StackFrame)
	{
		children.push(child);
		var f : FriendPanel = child;
		f.setParent(this);
		reflow();
		return this;
	}
	
	public function addMany(it : Iterable<StackFrame>)
	{
		var added = false;
		for (child in it)
		{
			added = true;
			children.push(child);
			var f : FriendPanel = child;
			f.setParent(this);
		}
		if(added)
			reflow();
		return this;
	}
	
	public function removeChild(child : StackFrame)
	{
		if (!children.remove(child))
			return false;
		
		var f : FriendPanel = child;
		f.setParent(null);
		reflow();
		return true;
	}
	
	public function iterator()
	{
		return children.iterator();
	}
	
	public function reflow()
	{
		var available = switch(orientation) { case Vertical: height; case Horizontal: width; };
		var required = 0, values = [], variables = [], i = 0, variablespace = 0;
		for (child in children)
		{
			switch(child.disposition)
			{
				case Fixed(before, after, size):
					required += size + before + after;
					values.push(size + before + after);
				case Variable(before, after, percent, min, max):
					var size = Math.round(percent / 100 * available);
					if (null != min && size < min)
						size = min;
					if (null != max && size > max)
						size = max;
					required += size + before + after;
					values.push(size + before + after);
				case Fill(before, after, min, max):
					if (null == min)
						min = 0;
					if (null == max)
						max = available;
					required += min + before + after;
					variablespace += variables[i] = (max - min);
					values.push(min + before + after);
				case Floating(x, y, w, h):
					values.push(0);
			}
			i++;
		}

		available -= required;
		if (available > 0)
		{
			i = 0;
			for (child in children)
			{
				switch(child.disposition)
				{
					case Fill(_, _, _, _):
						var size = Math.round(variables[i] /  variablespace * available);
						values[i] += size;
					default:
						//
				}
				i++;
			}
		}
		
		i = 0;
		var sizeable : SizeableFriend;
		var pos = 0;
		switch(orientation)
		{
			case Vertical:
				for (child in children)
				{
					sizeable = child;
					switch(child.disposition)
					{
						case Floating(x, y, w, h):
							sizeable.setLayout(x, y, w, h);
						case 
							Fixed(before, after, _),
							Variable(before, after, _, _, _),
							Fill(before, after, _, _):
							
							sizeable.setLayout(0, pos + before, this.width, values[i] - after - before);
					}
					pos += values[i++];
				}
			case Horizontal:
				for (child in children)
				{
					sizeable = child;
					switch(child.disposition)
					{
						case Floating(x, y, w, h):
							sizeable.setLayout(x, y, w, h);
						case 
							Fixed(before, after, _),
							Variable(before, after, _, _, _),
							Fill(before, after, _, _):
							
							sizeable.setLayout(pos + before, 0, values[i] - after - before, this.height);
					}
					pos += values[i++];
				}
		}
		
		if (available < 0)
			moreSpaceRequired(required);
	}
	
	public function setSize(width : Int, height : Int)
	{
		if (this.width == width && this.height == height)
			return this;
		this.width = width;
		this.height = height;
		reflow();
		return this;
	}
	
	public function toString() return "Stack [width: " + width + ", height: " + height + ", children: " + children.length + "]"
}

typedef FriendPanel = {
	private function setParent(v : Stack) : Stack;
}

typedef SizeableFriend = {
	private function setLayout(x : Int, y : Int, width : Int, height : Int) : Void;
}